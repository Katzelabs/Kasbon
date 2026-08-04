-- =============================================================================
-- KASBON POS - Every aggregate the dashboard and the reports read
-- =============================================================================
-- Fourteen functions. All SECURITY DEFINER with an empty search_path, all
-- scoped to `auth.uid()` in their own body, all returning JSONB so the Dart side
-- decodes one shape.
--
-- ## Conventions that hold throughout
--
-- **1. Time zone.** `transaction_date` is TIMESTAMPTZ. Range filters compare
-- against the bare column so `idx_transactions_user_date` stays usable, but any
-- *bucketing* - day, week, month, hour, day-of-week - first converts to local
-- wall-clock via `AT TIME ZONE p_tz`. Without that a WIB shop's sales before
-- 07:00 local fall into the previous UTC day. This is also why
-- get_dashboard_summary computes the local day's boundaries as timestamptz and
-- then filters on a plain half-open range, rather than wrapping the column: the
-- wrapped form was correct and unsargable, and read 99,907 rows to answer a
-- question about 113 of them (289.526 ms -> 1.026 ms once inverted).
--
-- **2. Half-open ranges** `[p_from, p_to)` everywhere, so a boundary instant
-- belongs to exactly one bucket.
--
-- **3. Debt is revenue.** `payment_status = 'debt'` rows count toward revenue and
-- profit. A hutang is a completed sale whose goods left the shop, and an owner
-- asking "how much did I sell this month" means it included. Only
-- get_payment_method_distribution and get_top_customers.outstanding_debt treat
-- debt separately. No function filters on a 'cancelled' status, because there
-- has never been one - see the CHECK constraint in 010002.
--
-- **4. Category filter semantics.** `p_category_id` is not a plain row filter,
-- because a transaction can mix categories. When NULL, revenue is the sum of
-- transaction totals (including transaction-level discount and tax). When set,
-- only transactions containing at least one item in that category are
-- considered, and revenue becomes the sum of the *matching line items'*
-- subtotals - transaction-level discount and tax cannot be attributed to one
-- category. Filtered and unfiltered revenue are therefore not comparable, which
-- is what the `revenue_basis` field in the payload exists to let the UI say.
--
-- **5. ORDER BY sits inside the subquery, before LIMIT.** An earlier version of
-- get_top_products and get_top_profitable_products applied `LIMIT p_limit` to an
-- unordered subquery and sorted afterwards in jsonb_agg, so Postgres was free to
-- return any p_limit groups: "Top 10 Produk Terlaris" was an arbitrary 10
-- products for any shop with more than 10 selling products. Both now rank with
-- row_number() over an ordered, limited subquery, with `name` as the tiebreak so
-- the order is total.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. DASHBOARD
-- ---------------------------------------------------------------------------
-- Five queries, of which today's sales and today's count are one pass rather
-- than the two they used to be. Low stock reads `is_low_stock` through
-- idx_products_user_low_stock; `stock <= min_stock` and `is_low_stock` differ on
-- rows with a NULL min_stock, and the generated column agrees with ProductModel
-- in Dart where the old expression quietly did not.
CREATE OR REPLACE FUNCTION public.get_dashboard_summary(p_tz text DEFAULT 'Asia/Jakarta'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;

-- ---------------------------------------------------------------------------
-- 2. SALES
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_sales_summary(p_from timestamp with time zone, p_to timestamp with time zone, p_category_id uuid DEFAULT NULL::uuid, p_payment_method text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_revenue DECIMAL;
  v_txn_count INTEGER;
  v_profit DECIMAL;
  v_items_sold INTEGER;
BEGIN
  WITH filtered_txn AS (
    SELECT t.id, t.total
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
      AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
      AND (
        p_category_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM public.transaction_items ti
          JOIN public.products pr ON pr.id = ti.product_id
          WHERE ti.transaction_id = t.id
            AND pr.category_id = p_category_id
        )
      )
  ),
  scoped_items AS (
    SELECT
      ti.quantity,
      ti.subtotal,
      (ti.selling_price - ti.cost_price) * ti.quantity AS profit
    FROM public.transaction_items ti
    JOIN filtered_txn ft ON ft.id = ti.transaction_id
    LEFT JOIN public.products pr ON pr.id = ti.product_id
    WHERE p_category_id IS NULL OR pr.category_id = p_category_id
  )
  SELECT
    CASE
      WHEN p_category_id IS NULL
        THEN (SELECT COALESCE(SUM(ft.total), 0) FROM filtered_txn ft)
      ELSE (SELECT COALESCE(SUM(si.subtotal), 0) FROM scoped_items si)
    END,
    (SELECT COUNT(*) FROM filtered_txn),
    (SELECT COALESCE(SUM(si.profit), 0) FROM scoped_items si),
    (SELECT COALESCE(SUM(si.quantity), 0) FROM scoped_items si)
  INTO v_revenue, v_txn_count, v_profit, v_items_sold;

  RETURN jsonb_build_object(
    'total_revenue', v_revenue,
    'transaction_count', v_txn_count,
    'total_profit', v_profit,
    'items_sold', v_items_sold,
    -- Lets the UI label a category-filtered total as line-item revenue.
    'revenue_basis', CASE WHEN p_category_id IS NULL THEN 'transaction' ELSE 'items' END
  );
END;
$function$;

-- Deprecated in favour of get_sales_trend, which also returns profit and
-- supports week/month granularity. Kept working, and time-zone correct, so the
-- existing sales report screen keeps functioning until it is migrated.
CREATE OR REPLACE FUNCTION public.get_daily_sales(p_from timestamp with time zone, p_to timestamp with time zone, p_tz text DEFAULT 'Asia/Jakarta'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY sub.sale_date)
  INTO v_result
  FROM (
    SELECT
      to_char((transaction_date AT TIME ZONE p_tz)::date, 'YYYY-MM-DD') AS sale_date,
      COALESCE(SUM(total), 0)::DECIMAL AS revenue,
      COUNT(*)::INTEGER AS transaction_count
    FROM public.transactions
    WHERE user_id = v_uid
      AND transaction_date >= p_from
      AND transaction_date < p_to
    GROUP BY (transaction_date AT TIME ZONE p_tz)::date
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_top_products(p_from timestamp with time zone, p_to timestamp with time zone, p_sort text DEFAULT 'quantity'::text, p_limit integer DEFAULT 10, p_category_id uuid DEFAULT NULL::uuid, p_payment_method text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(ranked) - 'rn' ORDER BY ranked.rn)
  INTO v_result
  FROM (
    SELECT
      agg.*,
      row_number() OVER (
        ORDER BY
          CASE WHEN p_sort = 'revenue' THEN agg.total_revenue END DESC NULLS LAST,
          CASE WHEN p_sort = 'profit'  THEN agg.total_profit  END DESC NULLS LAST,
          CASE WHEN p_sort NOT IN ('revenue', 'profit') THEN agg.quantity_sold END DESC NULLS LAST,
          agg.name
      ) AS rn
    FROM (
      SELECT
        p.id,
        p.name,
        COALESCE(SUM(ti.quantity), 0)::INTEGER AS quantity_sold,
        COALESCE(SUM(ti.subtotal), 0)::DECIMAL AS total_revenue,
        COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL AS total_profit
      FROM public.transaction_items ti
      JOIN public.products p ON ti.product_id = p.id
      JOIN public.transactions t ON ti.transaction_id = t.id
      WHERE t.user_id = v_uid
        AND t.transaction_date >= p_from
        AND t.transaction_date < p_to
        AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
        AND (p_category_id IS NULL OR p.category_id = p_category_id)
      GROUP BY p.id
      HAVING COALESCE(SUM(ti.quantity), 0) > 0
      ORDER BY
        CASE WHEN p_sort = 'revenue'
          THEN COALESCE(SUM(ti.subtotal), 0) END DESC NULLS LAST,
        CASE WHEN p_sort = 'profit'
          THEN COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) END DESC NULLS LAST,
        CASE WHEN p_sort NOT IN ('revenue', 'profit')
          THEN COALESCE(SUM(ti.quantity), 0) END DESC NULLS LAST,
        p.name
      LIMIT p_limit
    ) agg
  ) ranked;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 3. PROFIT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_profit_summary(p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_profit DECIMAL;
  v_sales DECIMAL;
  v_txn_count INTEGER;
BEGIN
  SELECT
    COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0),
    COALESCE(SUM(t.total), 0),
    COUNT(DISTINCT t.id)
  INTO v_profit, v_sales, v_txn_count
  FROM public.transactions t
  LEFT JOIN public.transaction_items ti ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date >= p_from
    AND t.transaction_date < p_to;

  RETURN jsonb_build_object(
    'total_profit', v_profit,
    'total_sales', v_sales,
    'transaction_count', v_txn_count
  );
END;
$function$;

-- Deliberately all-time: no date range. A product's profitability is a property
-- of the product, and the screen that reads this shows a lifetime ranking.
CREATE OR REPLACE FUNCTION public.get_top_profitable_products(p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(ranked) - 'rn' ORDER BY ranked.rn)
  INTO v_result
  FROM (
    SELECT
      agg.*,
      row_number() OVER (ORDER BY agg.total_profit DESC, agg.name) AS rn
    FROM (
      SELECT
        p.id,
        p.name,
        COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL AS total_profit,
        COALESCE(SUM(ti.quantity), 0)::INTEGER AS total_sold,
        CASE
          WHEN COALESCE(SUM(ti.cost_price * ti.quantity), 0) > 0
          THEN (COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) /
                COALESCE(SUM(ti.cost_price * ti.quantity), 1)) * 100
          ELSE 0
        END::DECIMAL AS average_margin
      FROM public.products p
      LEFT JOIN public.transaction_items ti ON ti.product_id = p.id
      WHERE p.user_id = v_uid
        AND p.is_active = true
      GROUP BY p.id
      HAVING COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) > 0
      ORDER BY COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) DESC, p.name
      LIMIT p_limit
    ) agg
  ) ranked;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_product_profitability(p_product_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT row_to_json(sub)::jsonb INTO v_result
  FROM (
    SELECT
      p.id,
      p.name,
      COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL as total_profit,
      COALESCE(SUM(ti.quantity), 0)::INTEGER as total_sold,
      CASE
        WHEN COALESCE(SUM(ti.cost_price * ti.quantity), 0) > 0
        THEN (COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) /
              COALESCE(SUM(ti.cost_price * ti.quantity), 1)) * 100
        ELSE 0
      END::DECIMAL as average_margin
    FROM public.products p
    LEFT JOIN public.transaction_items ti ON ti.product_id = p.id
    LEFT JOIN public.transactions t ON ti.transaction_id = t.id
    WHERE p.id = p_product_id
      AND p.user_id = v_uid
    GROUP BY p.id
  ) sub;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 4. TREND AND DISTRIBUTION (charts)
-- ---------------------------------------------------------------------------
-- One row per non-empty bucket; empty buckets are omitted and the client fills
-- the gaps so the line chart keeps a continuous x-axis. p_granularity is
-- 'day' | 'week' | 'month', anything else falls back to 'day'.
CREATE OR REPLACE FUNCTION public.get_sales_trend(p_from timestamp with time zone, p_to timestamp with time zone, p_granularity text DEFAULT 'day'::text, p_category_id uuid DEFAULT NULL::uuid, p_payment_method text DEFAULT NULL::text, p_tz text DEFAULT 'Asia/Jakarta'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_trunc TEXT;
  v_result JSONB;
BEGIN
  v_trunc := CASE lower(COALESCE(p_granularity, 'day'))
    WHEN 'week' THEN 'week'
    WHEN 'month' THEN 'month'
    ELSE 'day'
  END;

  WITH filtered_txn AS (
    SELECT
      t.id,
      t.total,
      date_trunc(v_trunc, t.transaction_date AT TIME ZONE p_tz) AS bucket
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
      AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
      AND (
        p_category_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM public.transaction_items ti
          JOIN public.products pr ON pr.id = ti.product_id
          WHERE ti.transaction_id = t.id
            AND pr.category_id = p_category_id
        )
      )
  ),
  txn_agg AS (
    SELECT
      ft.bucket,
      COALESCE(SUM(ft.total), 0)::DECIMAL AS txn_revenue,
      COUNT(*)::INTEGER AS transaction_count
    FROM filtered_txn ft
    GROUP BY ft.bucket
  ),
  item_agg AS (
    SELECT
      ft.bucket,
      COALESCE(SUM(ti.subtotal), 0)::DECIMAL AS item_revenue,
      COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL AS profit,
      COALESCE(SUM(ti.quantity), 0)::INTEGER AS items_sold
    FROM public.transaction_items ti
    JOIN filtered_txn ft ON ft.id = ti.transaction_id
    LEFT JOIN public.products pr ON pr.id = ti.product_id
    WHERE p_category_id IS NULL OR pr.category_id = p_category_id
    GROUP BY ft.bucket
  )
  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.bucket_start)
  INTO v_result
  FROM (
    SELECT
      to_char(ta.bucket, 'YYYY-MM-DD') AS bucket_start,
      v_trunc AS granularity,
      CASE
        WHEN p_category_id IS NULL THEN ta.txn_revenue
        ELSE COALESCE(ia.item_revenue, 0)
      END AS revenue,
      COALESCE(ia.profit, 0) AS profit,
      ta.transaction_count,
      COALESCE(ia.items_sold, 0) AS items_sold,
      CASE WHEN p_category_id IS NULL THEN 'transaction' ELSE 'items' END AS revenue_basis
    FROM txn_agg ta
    LEFT JOIN item_agg ia ON ia.bucket = ta.bucket
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- Line-item level by necessity: a transaction can span categories, so
-- transaction totals cannot be attributed to one slice. Items whose product was
-- deleted (product_id NULL) or whose product has no category both fall into
-- "Tanpa Kategori". Percentages are left to the client so slices sum to exactly
-- 100%.
CREATE OR REPLACE FUNCTION public.get_category_distribution(p_from timestamp with time zone, p_to timestamp with time zone, p_payment_method text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.revenue DESC, sub.category_name)
  INTO v_result
  FROM (
    SELECT
      c.id AS category_id,
      COALESCE(c.name, 'Tanpa Kategori') AS category_name,
      COALESCE(c.color, '#9E9E9E') AS category_color,
      COALESCE(SUM(ti.subtotal), 0)::DECIMAL AS revenue,
      COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL AS profit,
      COALESCE(SUM(ti.quantity), 0)::INTEGER AS quantity_sold
    FROM public.transaction_items ti
    JOIN public.transactions t ON t.id = ti.transaction_id
    LEFT JOIN public.products p ON p.id = ti.product_id
    LEFT JOIN public.categories c ON c.id = p.category_id
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
      AND (p_payment_method IS NULL OR t.payment_method = p_payment_method)
    GROUP BY c.id, c.name, c.color
    HAVING COALESCE(SUM(ti.quantity), 0) > 0
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- Transaction level, and the one place 'debt' is its own slice rather than being
-- folded into revenue, so the shop can see how much of its turnover is unpaid.
CREATE OR REPLACE FUNCTION public.get_payment_method_distribution(p_from timestamp with time zone, p_to timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.total DESC, sub.payment_method)
  INTO v_result
  FROM (
    SELECT
      t.payment_method,
      COUNT(*)::INTEGER AS transaction_count,
      COALESCE(SUM(t.total), 0)::DECIMAL AS total,
      COALESCE(SUM(t.total) FILTER (
        WHERE t.payment_status = 'debt' AND t.debt_paid_at IS NULL
      ), 0)::DECIMAL AS unpaid_total
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
    GROUP BY t.payment_method
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- One row per non-empty (day_of_week, hour_of_day) cell; the client fills the
-- full 7x24 grid. day_of_week is ISODOW - 1 = Senin ... 7 = Minggu - and
-- deliberately not Postgres' default DOW (0 = Sunday), so the Dart side can
-- index a Monday-first Indonesian week without an off-by-one remap.
CREATE OR REPLACE FUNCTION public.get_hourly_heatmap(p_from timestamp with time zone, p_to timestamp with time zone, p_tz text DEFAULT 'Asia/Jakarta'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.day_of_week, sub.hour_of_day)
  INTO v_result
  FROM (
    SELECT
      EXTRACT(ISODOW FROM (t.transaction_date AT TIME ZONE p_tz))::INTEGER AS day_of_week,
      EXTRACT(HOUR  FROM (t.transaction_date AT TIME ZONE p_tz))::INTEGER AS hour_of_day,
      COUNT(*)::INTEGER AS transaction_count,
      COALESCE(SUM(t.total), 0)::DECIMAL AS revenue
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
    GROUP BY 1, 2
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5. CUSTOMERS
-- ---------------------------------------------------------------------------
-- There is no customer table: a customer is a `transactions.customer_name`.
-- Names are trimmed before grouping to merge whitespace variants, but grouping
-- stays case-sensitive - silently merging "Budi" and "budi" would misattribute a
-- real shop's data. Ranking metrics respect [p_from, p_to); the lifetime_* fields
-- are all-time by definition and ignore the range.
CREATE OR REPLACE FUNCTION public.get_top_customers(p_from timestamp with time zone, p_to timestamp with time zone, p_limit integer DEFAULT 10)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  WITH scoped AS (
    SELECT
      btrim(t.customer_name) AS customer_name,
      t.id,
      t.total,
      t.transaction_date,
      t.payment_status,
      t.debt_paid_at
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
      AND t.customer_name IS NOT NULL
      AND btrim(t.customer_name) <> ''
  ),
  ranged AS (
    SELECT
      s.customer_name,
      COUNT(*)::INTEGER AS transaction_count,
      COALESCE(SUM(s.total), 0)::DECIMAL AS total_spent,
      (COALESCE(SUM(s.total), 0) / NULLIF(COUNT(*), 0))::DECIMAL AS average_transaction,
      MAX(s.transaction_date) AS last_transaction_at,
      COALESCE(SUM(s.total) FILTER (
        WHERE s.payment_status = 'debt' AND s.debt_paid_at IS NULL
      ), 0)::DECIMAL AS outstanding_debt
    FROM scoped s
    GROUP BY s.customer_name
    ORDER BY total_spent DESC, s.customer_name
    LIMIT p_limit
  ),
  ranged_profit AS (
    SELECT
      s.customer_name,
      COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL AS total_profit
    FROM scoped s
    JOIN public.transaction_items ti ON ti.transaction_id = s.id
    GROUP BY s.customer_name
  ),
  lifetime AS (
    SELECT
      btrim(t.customer_name) AS customer_name,
      COUNT(*)::INTEGER AS lifetime_transaction_count,
      COALESCE(SUM(t.total), 0)::DECIMAL AS lifetime_spent,
      MIN(t.transaction_date) AS first_transaction_at
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.customer_name IS NOT NULL
      AND btrim(t.customer_name) <> ''
    GROUP BY btrim(t.customer_name)
  )
  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.total_spent DESC, sub.customer_name)
  INTO v_result
  FROM (
    SELECT
      r.customer_name,
      r.transaction_count,
      r.total_spent,
      r.average_transaction,
      r.last_transaction_at,
      r.outstanding_debt,
      COALESCE(rp.total_profit, 0)::DECIMAL AS total_profit,
      COALESCE(l.lifetime_transaction_count, r.transaction_count) AS lifetime_transaction_count,
      COALESCE(l.lifetime_spent, r.total_spent)::DECIMAL AS lifetime_spent,
      COALESCE(l.first_transaction_at, r.last_transaction_at) AS first_transaction_at
    FROM ranged r
    LEFT JOIN ranged_profit rp ON rp.customer_name = r.customer_name
    LEFT JOIN lifetime l ON l.customer_name = r.customer_name
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- Backs the autocomplete on the customer name field, which is what keeps one
-- customer one row: "Bu Sri", "bu sri" and "Bu Sri " are three customers to a
-- database and one person to a shop owner. Ordered by most recent use rather
-- than alphabetically, because a warung has a handful of regulars who buy
-- constantly and a long tail who came once.
CREATE OR REPLACE FUNCTION public.get_customer_names(p_query text DEFAULT NULL::text, p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(sub.name ORDER BY sub.last_used DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      t.customer_name AS name,
      MAX(t.transaction_date) AS last_used
    FROM public.transactions t
    WHERE t.user_id = v_uid
      AND t.customer_name IS NOT NULL
      AND btrim(t.customer_name) <> ''
      -- Unanchored ILIKE so "sri" finds "Bu Sri". A prefix match would miss
      -- every name the shop records with an honorific, which in Indonesian is
      -- most of them.
      AND (p_query IS NULL OR t.customer_name ILIKE '%' || p_query || '%')
    GROUP BY t.customer_name
    ORDER BY MAX(t.transaction_date) DESC
    LIMIT p_limit
  ) sub;

  RETURN v_result;
END;
$function$;

COMMENT ON FUNCTION public.get_customer_names(TEXT, INTEGER) IS
  'Distinct customer_name values for the caller, most recently used first. '
  'Feeds the POS customer name autocomplete.';

-- ---------------------------------------------------------------------------
-- 6. INVENTORY
-- ---------------------------------------------------------------------------
-- One row per active product, *including* products with zero sales - those are
-- the entire point of the slow-moving report. Ordered by name, a deterministic
-- order that biases neither the turnover ranking nor the slow-moving list, both
-- of which the client derives from this one payload.
--
-- turnover_ratio approximates COGS / average inventory value using *current*
-- stock value as the denominator: the schema keeps no historical stock levels, so
-- a true period average is not computable. NULL when the product has no stock
-- value.
CREATE OR REPLACE FUNCTION public.get_product_movement(p_from timestamp with time zone, p_to timestamp with time zone, p_slow_days integer DEFAULT 90, p_limit integer DEFAULT 500)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_days DECIMAL;
  v_result JSONB;
BEGIN
  -- Guard against a zero-length or inverted range producing a division by zero.
  v_days := GREATEST(EXTRACT(EPOCH FROM (p_to - p_from)) / 86400.0, 1);

  SELECT jsonb_agg(to_jsonb(sub) ORDER BY sub.name)
  INTO v_result
  FROM (
    SELECT
      base.*,
      CASE
        WHEN base.stock_value > 0 THEN (base.total_cogs / base.stock_value)::DECIMAL
        ELSE NULL
      END AS turnover_ratio,
      CASE
        WHEN base.quantity_sold > 0
          THEN (base.current_stock / (base.quantity_sold / v_days))::DECIMAL
        ELSE NULL
      END AS days_of_supply,
      COALESCE(
        (base.quantity_sold = 0 AND base.current_stock > 0)
        OR (
          base.quantity_sold > 0
          AND (base.current_stock / (base.quantity_sold / v_days)) > p_slow_days
        ),
        FALSE
      ) AS is_slow_moving
    FROM (
      SELECT
        p.id,
        p.name,
        p.sku,
        p.stock::INTEGER AS current_stock,
        p.cost_price::DECIMAL AS cost_price,
        (p.stock * p.cost_price)::DECIMAL AS stock_value,
        COALESCE(SUM(s.quantity), 0)::INTEGER AS quantity_sold,
        COALESCE(SUM(s.subtotal), 0)::DECIMAL AS total_revenue,
        COALESCE(SUM(s.cost_price * s.quantity), 0)::DECIMAL AS total_cogs,
        COALESCE(SUM((s.selling_price - s.cost_price) * s.quantity), 0)::DECIMAL AS total_profit,
        MAX(s.transaction_date) AS last_sold_at
      FROM public.products p
      -- The date filter must live inside this subquery. Putting it on a
      -- LEFT JOIN to transactions instead would leave the transaction_items
      -- rows in place, so out-of-range sales would still be summed.
      LEFT JOIN (
        SELECT
          ti.product_id,
          ti.quantity,
          ti.subtotal,
          ti.cost_price,
          ti.selling_price,
          t.transaction_date
        FROM public.transaction_items ti
        JOIN public.transactions t ON t.id = ti.transaction_id
        WHERE t.user_id = v_uid
          AND t.transaction_date >= p_from
          AND t.transaction_date < p_to
      ) s ON s.product_id = p.id
      WHERE p.user_id = v_uid
        AND p.is_active = true
      GROUP BY p.id
      ORDER BY p.name
      LIMIT p_limit
    ) base
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$function$;

-- ---------------------------------------------------------------------------
-- 7. GRANTS
-- ---------------------------------------------------------------------------
-- Redundant with the default privilege from 010003, and kept as belt and braces:
-- these are the functions PostgREST must be able to call, stated where a reader
-- can check the list against the app. Anything NOT in this list and not covered
-- by that default privilege is not callable by a signed-in user - which is the
-- property 010009 and 010010 depend on.

GRANT EXECUTE ON FUNCTION public.get_dashboard_summary(TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ, UUID, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_sales(TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_products(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, UUID, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_profitable_products(INTEGER)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_sales_trend(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, UUID, TEXT, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_category_distribution(TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_payment_method_distribution(TIMESTAMPTZ, TIMESTAMPTZ)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_hourly_heatmap(TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_customers(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_product_movement(TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER)
  TO authenticated, service_role;
