-- =============================================================================
-- KASBON POS - Make the reads that grow with the shop stop growing with it
-- =============================================================================
-- Everything here was measured against a local stack loaded with 100k
-- transactions and 2k products per tenant across two tenants, ~280 distinct
-- customer names - roughly two years of a busy warung. At the seed's 20 rows
-- every plan looks the same and none of this is visible.
--
-- The numbers are milliseconds per call, warm, averaged over 20-30 calls, with
-- the old and new versions run back to back against the same rows in the same
-- session. One laptop's figures: trust the ratios, not the absolutes.
--
--   get_dashboard_summary()          289.526  ->   1.026     (282x)
--   get_customer_names('sri')        256.646  ->  14.319      (18x)
--   product search ILIKE               5.137  ->   1.439     (3.6x)
--   janitor retention scan            27.189  ->   0.536      (51x)
--   RLS (SELECT auth.uid())            27.623 ->  25.099   (no change)
--
-- That last row is not a typo and is discussed in section 4.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. THE DASHBOARD READS THE WHOLE HISTORY TO DRAW TODAY
-- ---------------------------------------------------------------------------
-- `(transaction_date AT TIME ZONE p_tz)::date = v_today` is correct and was the
-- fix for a real bug (20260726000002 - a WIB shop's morning counted as
-- yesterday). It is also not sargable: wrapping the column in an expression
-- means `idx_transactions_user_date (user_id, transaction_date)` cannot serve
-- the date half, so the plan narrows by user_id and then filters every row the
-- shop has ever written.
--
--   Bitmap Heap Scan on transactions (actual rows=113)
--     Filter: ((transaction_date AT TIME ZONE 'Asia/Jakarta')::date = ...)
--     Rows Removed by Filter: 99907
--
-- 99,907 rows read to answer a question about 113 of them - and the function
-- does that five times over, for today's sales, today's profit, today's count
-- and yesterday's two. 289 ms per call, on every dashboard open, growing with
-- the shop's lifetime history: slowest for the shops that have used the app
-- longest, which is exactly backwards.
--
-- The fix keeps the timezone behaviour exactly and moves the conversion to the
-- other side of the comparison: compute the local day's boundaries once, as
-- timestamptz, then ask for a plain half-open range on the bare column. Same
-- rows, same answer - verified by running both versions on the same data and
-- diffing the output, 2818500.00 and 113 either way - and now an index range
-- scan.
--
--   289.526 ms -> 1.026 ms
--
-- Two of the five queries also collapse into one: today's sales and today's
-- count were separate passes over identical rows.
--
-- Half-open [start, end) rather than BETWEEN, so the boundary instant belongs
-- to exactly one day - the same convention the report RPCs already use.
--
-- Low stock also switches to `is_low_stock`, the generated column added in
-- 20260730000002 together with a partial index that nothing was using here.
-- `stock <= min_stock` and `is_low_stock` differ on rows with a NULL min_stock:
-- the column reads it as 5, and so does ProductModel in Dart, so this agrees
-- with the app where the old expression quietly did not.

CREATE OR REPLACE FUNCTION public.get_dashboard_summary(
  p_tz TEXT DEFAULT 'Asia/Jakarta'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today DATE;
  v_today_start TIMESTAMPTZ;
  v_tomorrow_start TIMESTAMPTZ;
  v_yesterday_start TIMESTAMPTZ;
  v_today_sales DECIMAL;
  v_today_profit DECIMAL;
  v_txn_count INTEGER;
  v_yesterday_sales DECIMAL;
  v_yesterday_profit DECIMAL;
  v_low_stock INTEGER;
BEGIN
  -- "Today" as the shop experiences it, not as UTC does. Converting the local
  -- date back to an instant is what lets the comparison touch the bare column:
  -- `<date>::timestamp AT TIME ZONE p_tz` reads the naive local midnight and
  -- returns the timestamptz it corresponds to.
  v_today           := (NOW() AT TIME ZONE p_tz)::date;
  v_today_start     := v_today::timestamp AT TIME ZONE p_tz;
  v_tomorrow_start  := (v_today + 1)::timestamp AT TIME ZONE p_tz;
  v_yesterday_start := (v_today - 1)::timestamp AT TIME ZONE p_tz;

  -- Today's sales and count, in one pass rather than the two it used to take.
  SELECT COALESCE(SUM(total), 0), COUNT(*)
  INTO v_today_sales, v_txn_count
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date >= v_today_start
    AND transaction_date <  v_tomorrow_start;

  -- Today's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_today_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date >= v_today_start
    AND t.transaction_date <  v_tomorrow_start;

  -- Yesterday's sales
  SELECT COALESCE(SUM(total), 0)
  INTO v_yesterday_sales
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date >= v_yesterday_start
    AND transaction_date <  v_today_start;

  -- Yesterday's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_yesterday_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date >= v_yesterday_start
    AND t.transaction_date <  v_today_start;

  -- Low stock count, through idx_products_user_low_stock.
  SELECT COUNT(*) INTO v_low_stock
  FROM public.products
  WHERE user_id = v_uid
    AND is_active
    AND is_low_stock;

  RETURN jsonb_build_object(
    'today_sales', v_today_sales,
    'today_profit', v_today_profit,
    'transaction_count', v_txn_count,
    'yesterday_sales', v_yesterday_sales,
    'yesterday_profit', v_yesterday_profit,
    'low_stock_count', v_low_stock
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. SUBSTRING SEARCH HAS NO INDEX TO USE
-- ---------------------------------------------------------------------------
-- Two unanchored ILIKEs, both deliberate and both unindexable by btree:
-- `searchProducts` in product_remote_datasource.dart, and `get_customer_names`
-- from 20260731000005, whose comment explains why the match cannot be anchored
-- ("sri" has to find "Bu Sri", because Indonesian names carry honorifics).
--
-- pg_trgm indexes exactly this shape. The customer one is the worse of the two
-- because it fires per keystroke while a cashier is mid-sale, on the largest
-- table in the schema:
--
--   256.646 ms -> 14.319 ms      get_customer_names('sri')
--     5.137 ms ->  1.439 ms      product search, 2k-product catalogue
--
-- The plan confirms the index is actually picked rather than merely present -
-- it BitmapAnds the trigram index against the per-user one:
--
--   BitmapAnd
--     -> Bitmap Index Scan on idx_transactions_customer_trgm  (rows=10065)
--          Index Cond: (customer_name ~~* '%sri%')
--     -> Bitmap Index Scan on idx_transactions_user           (rows=100020)
--
-- Worth knowing for whoever benchmarks this next: selectivity decides whether
-- the planner takes the trigram index at all. An early version of this
-- measurement used five distinct customer names, so '%sri%' matched 20% of the
-- table, and Postgres correctly ignored the index - a GIN scan returning a
-- fifth of the rows is not cheaper than the scan it replaces. With a realistic
-- 280 names it matches ~5% and the index wins. A synthetic dataset that is too
-- uniform will tell you this index is useless.
--
-- Both indexes are scoped with a WHERE to match how the queries actually read.
-- gin_trgm_ops rather than gist: slower to build, faster to search, and these
-- are read far more than written.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON public.products USING gin (name gin_trgm_ops)
  WHERE is_active;

CREATE INDEX IF NOT EXISTS idx_transactions_customer_trgm
  ON public.transactions USING gin (customer_name gin_trgm_ops)
  WHERE customer_name IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. THE JANITOR'S RETENTION SCAN HAS NO INDEX EITHER
-- ---------------------------------------------------------------------------
-- `expired_payment_proofs` (20260801000001) filters `payment_proof_path IS NOT
-- NULL` and orders by transaction_date across every tenant - it is the one
-- query in the schema that is deliberately not user-scoped, so none of the
-- `(user_id, ...)` indexes help it.
--
-- Partial, because the rows it wants are a small minority: only QRIS sales
-- with a photo attached ever have a path, and the retention sweep clears the
-- column as it goes. That keeps the index a fraction of the table's size and
-- means it is not touched at all by the ordinary POS insert path.
--
-- Measured with ~1% of 200k sales carrying a proof: 27.189 ms -> 0.536 ms.
-- This one runs once a night rather than in front of a cashier, so the wall
-- clock matters less than the shape - it was a full scan of every transaction
-- ever written, every night, for a job that usually deletes nothing.

CREATE INDEX IF NOT EXISTS idx_transactions_proof_retention
  ON public.transactions (transaction_date)
  WHERE payment_proof_path IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. RLS POLICIES: SCOPE TO `authenticated`, AND HOIST auth.uid()
-- ---------------------------------------------------------------------------
-- Two changes to all 22 policies, one clearly worth it and one worth being
-- honest about.
--
-- **`TO authenticated`** is the clear one. The policies were created with no
-- role clause, which means `TO public` - so every one of them is also evaluated
-- for `anon`, on a project where authentication is mandatory and an anonymous
-- caller can never match. Naming the role lets the planner skip the policy
-- entirely for anon rather than evaluating a predicate that cannot be true.
--
-- **`(SELECT auth.uid())`** is the widely-repeated Supabase tuning tip, and on
-- this schema it measured as a wash. The advice assumes the function is
-- re-evaluated per row; auth.uid() is STABLE, and the plans here already show
-- it folded into the index condition itself:
--
--   Bitmap Index Scan on idx_transactions_user
--     Index Cond: (user_id = (COALESCE(NULLIF(current_setting(...
--
-- so there was no per-row call left to hoist. Timed head to head over a 100k
-- row scan, 30 calls each: 27.623 ms bare against 25.099 ms wrapped, which is
-- inside the run-to-run noise on this machine and should be read as "no
-- change", not as a 9% win.
--
-- It is applied anyway because it is free, it is what every Supabase linter and
-- reviewer will expect to see, and it makes the behaviour explicit rather than
-- dependent on the planner continuing to inline a STABLE function. It is
-- recorded here as tidiness, not as a speedup, so that nobody later measures it
-- and concludes the migration did nothing.
--
-- ALTER rather than DROP/CREATE: the policy names are referenced in
-- 20260207070429 and changing them would make the two files disagree.

DO $$
DECLARE
  r RECORD;
  v_expr TEXT;
BEGIN
  FOR r IN
    SELECT tablename, policyname, cmd
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('user_profiles', 'shop_settings', 'categories',
                        'products', 'transactions', 'transaction_items')
  LOOP
    -- user_profiles keys on its own primary key; every other table on user_id.
    v_expr := CASE WHEN r.tablename = 'user_profiles'
                   THEN 'id = (SELECT auth.uid())'
                   ELSE 'user_id = (SELECT auth.uid())'
              END;

    -- INSERT policies have only WITH CHECK; everything else has USING, and
    -- UPDATE needs both or Postgres falls back to USING for the check.
    IF r.cmd = 'INSERT' THEN
      EXECUTE format('ALTER POLICY %I ON public.%I TO authenticated WITH CHECK (%s)',
                     r.policyname, r.tablename, v_expr);
    ELSIF r.cmd = 'UPDATE' THEN
      EXECUTE format('ALTER POLICY %I ON public.%I TO authenticated USING (%s) WITH CHECK (%s)',
                     r.policyname, r.tablename, v_expr, v_expr);
    ELSE
      EXECUTE format('ALTER POLICY %I ON public.%I TO authenticated USING (%s)',
                     r.policyname, r.tablename, v_expr);
    END IF;
  END LOOP;
END;
$$;
