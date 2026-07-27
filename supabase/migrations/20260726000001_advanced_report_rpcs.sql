-- =============================================================================
-- KASBON POS - Advanced Report RPCs (TASK_019)
-- =============================================================================
-- Adds the aggregate functions backing the advanced reports feature, and
-- repairs three correctness bugs in the original report RPCs.
--
-- CONVENTIONS USED THROUGHOUT
--
-- 1. TIME ZONE. transaction_date is TIMESTAMPTZ. Range filters compare against
--    the raw column so idx_transactions_user_date stays usable, but any
--    *bucketing* (day / week / month / hour / day-of-week) first converts to
--    local wall-clock via `AT TIME ZONE p_tz`. Without this, a WIB shop's
--    sales before 07:00 local fall into the previous UTC day.
--
-- 2. CANCELLED TRANSACTIONS. The original RPCs filter on
--    `payment_status != 'cancelled'`, but the CHECK constraint on
--    transactions.payment_status only permits 'paid' and 'debt' - so the
--    clause never excludes anything. It is dropped here rather than carried
--    forward. If cancellation is added later it needs a real status value plus
--    a revisit of every aggregate in this file.
--
-- 3. DEBT IS REVENUE. payment_status = 'debt' rows count toward revenue and
--    profit, matching the existing sales/profit reports. Only
--    get_payment_method_distribution and get_top_customers.outstanding_debt
--    treat debt separately.
--
-- 4. CATEGORY FILTER SEMANTICS. p_category_id is not a plain row filter: a
--    transaction can mix categories. When it is NULL, revenue is the sum of
--    transaction totals (includes transaction-level discount and tax). When it
--    is set, only transactions containing at least one item in that category
--    are considered, and revenue becomes the sum of the *matching line items'*
--    subtotals - transaction-level discount/tax cannot be attributed to a
--    single category. Filtered and unfiltered revenue are therefore not
--    directly comparable; the UI must label a filtered total accordingly.
-- =============================================================================


-- =============================================================================
-- PART A - REPAIRS TO EXISTING RPCs
-- =============================================================================

-- ---------------------------------------------------------------------------
-- A1. get_sales_summary - add category / payment filters
-- ---------------------------------------------------------------------------
-- Signature change (new params) means CREATE OR REPLACE would register an
-- overload instead of replacing, and PostgREST would then fail the call with
-- PGRST203 "could not choose the best candidate function". Drop first.

DROP FUNCTION IF EXISTS public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION public.get_sales_summary(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_category_id UUID DEFAULT NULL,
  p_payment_method TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- A2. get_top_products - fix arbitrary truncation, add filters
-- ---------------------------------------------------------------------------
-- BUG FIXED: the original applied LIMIT p_limit to an *unordered* subquery and
-- only sorted afterwards in jsonb_agg. Postgres was free to return any
-- p_limit groups, so "Top 10 Produk Terlaris" was an arbitrary 10 products
-- whenever the shop had more than 10 products with sales. ORDER BY now sits
-- inside the subquery, before LIMIT.

DROP FUNCTION IF EXISTS public.get_top_products(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.get_top_products(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_sort TEXT DEFAULT 'quantity',
  p_limit INTEGER DEFAULT 10,
  p_category_id UUID DEFAULT NULL,
  p_payment_method TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- A3. get_top_profitable_products - same truncation bug, fixed in place
-- ---------------------------------------------------------------------------
-- Signature is unchanged, so CREATE OR REPLACE is safe here.
-- Note this function is deliberately all-time (no date range) - unchanged.

CREATE OR REPLACE FUNCTION public.get_top_profitable_products(
  p_limit INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- A4. get_daily_sales - time zone fix
-- ---------------------------------------------------------------------------
-- DEPRECATED: superseded by get_sales_trend, which also returns profit and
-- supports week/month granularity. Kept working (and now time-zone correct) so
-- the existing sales report screen keeps functioning until it is migrated.

DROP FUNCTION IF EXISTS public.get_daily_sales(TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION public.get_daily_sales(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_tz TEXT DEFAULT 'Asia/Jakarta'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;


-- =============================================================================
-- PART B - NEW ADVANCED REPORT RPCs
-- =============================================================================

-- ---------------------------------------------------------------------------
-- B1. SALES / PROFIT TREND (line charts)
-- ---------------------------------------------------------------------------
-- Returns one row per non-empty bucket:
--   { bucket_start, granularity, revenue, profit, transaction_count,
--     items_sold, revenue_basis }
-- Buckets with no sales are omitted; the client fills gaps so the line chart
-- has a continuous x-axis.
-- p_granularity: 'day' | 'week' | 'month' (anything else falls back to 'day').

CREATE OR REPLACE FUNCTION public.get_sales_trend(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_granularity TEXT DEFAULT 'day',
  p_category_id UUID DEFAULT NULL,
  p_payment_method TEXT DEFAULT NULL,
  p_tz TEXT DEFAULT 'Asia/Jakarta'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- B2. CATEGORY DISTRIBUTION (pie chart)
-- ---------------------------------------------------------------------------
-- Line-item level by necessity: a transaction can span categories, so
-- transaction totals cannot be attributed to one slice. Items whose product
-- was deleted (product_id NULL via ON DELETE SET NULL) or whose product has no
-- category both fall into the "Tanpa Kategori" bucket.
-- Percentages are left to the client so slices always sum to exactly 100%.

CREATE OR REPLACE FUNCTION public.get_category_distribution(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_payment_method TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- B3. PAYMENT METHOD DISTRIBUTION (pie chart)
-- ---------------------------------------------------------------------------
-- Transaction level. 'debt' is its own slice here rather than being folded
-- into revenue, so the shop can see how much of its turnover is unpaid.
-- Only methods actually used in the period are returned.

CREATE OR REPLACE FUNCTION public.get_payment_method_distribution(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- B4. HOURLY HEATMAP / PEAK HOURS / DAY-OF-WEEK
-- ---------------------------------------------------------------------------
-- One row per non-empty (day_of_week, hour_of_day) cell. The client fills the
-- full 7x24 grid, so an all-zero cell is simply absent here.
--
-- day_of_week uses ISODOW: 1 = Senin ... 7 = Minggu. This is deliberately NOT
-- Postgres' default DOW (0 = Sunday) so the Dart side can index a
-- Monday-first Indonesian week without an off-by-one remap.
-- hour_of_day is 0-23 in p_tz local time.

CREATE OR REPLACE FUNCTION public.get_hourly_heatmap(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_tz TEXT DEFAULT 'Asia/Jakarta'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- B5. TOP CUSTOMERS / LIFETIME VALUE
-- ---------------------------------------------------------------------------
-- Customers are identified by transactions.customer_name - there is no
-- customer table - so names are trimmed before grouping to merge whitespace
-- variants. Grouping stays case-sensitive: "Budi" and "budi" remain distinct,
-- because silently merging them would misattribute a real shop's data.
-- Transactions with a blank/NULL customer_name are excluded entirely.
--
-- Ranking metrics respect [p_from, p_to). The lifetime_* fields are all-time
-- by definition and deliberately ignore the range.

CREATE OR REPLACE FUNCTION public.get_top_customers(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_limit INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;

-- ---------------------------------------------------------------------------
-- B6. PRODUCT MOVEMENT (inventory turnover + slow-moving)
-- ---------------------------------------------------------------------------
-- One row per active product, including products with zero sales - those are
-- the entire point of the slow-moving report. The client derives both the
-- turnover ranking and the slow-moving list from this single payload, so rows
-- are ordered by name (a deterministic order that biases neither list) and
-- truncated only at p_limit.
--
-- turnover_ratio approximates COGS / average inventory value using *current*
-- stock value as the denominator - the schema keeps no historical stock
-- levels, so a true period-average is not computable. It is NULL when the
-- product currently has no stock value.
--
-- days_of_supply = current stock / average units sold per day over the range.
-- NULL when nothing sold.
--
-- is_slow_moving = stocked but sold nothing in the range, OR carrying more
-- than p_slow_days of supply at the current rate.

CREATE OR REPLACE FUNCTION public.get_product_movement(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_slow_days INTEGER DEFAULT 90,
  p_limit INTEGER DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
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
$$;


-- =============================================================================
-- PART C - GRANTS
-- =============================================================================
-- 20260725000001 sets ALTER DEFAULT PRIVILEGES for functions created by
-- postgres, which covers everything above. These explicit grants are belt and
-- braces, and are required for the DROP+CREATE functions whose original grants
-- disappeared with the dropped definitions.

GRANT EXECUTE ON FUNCTION public.get_sales_summary(TIMESTAMPTZ, TIMESTAMPTZ, UUID, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_products(TIMESTAMPTZ, TIMESTAMPTZ, TEXT, INTEGER, UUID, TEXT)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_top_profitable_products(INTEGER)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_daily_sales(TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
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
