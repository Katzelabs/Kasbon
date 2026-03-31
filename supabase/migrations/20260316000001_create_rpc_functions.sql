-- =============================================================================
-- KASBON POS - RPC Functions for Atomic Operations & Aggregates
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. ATOMIC TRANSACTION CREATION
-- ---------------------------------------------------------------------------
-- Creates a transaction with items and updates product stock atomically.
-- Returns the new transaction ID.

CREATE OR REPLACE FUNCTION public.create_pos_transaction(
  p_user_id UUID,
  p_transaction JSONB,
  p_items JSONB
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_txn_id UUID;
  v_item JSONB;
BEGIN
  -- Verify caller matches p_user_id
  IF auth.uid() IS DISTINCT FROM p_user_id THEN
    RAISE EXCEPTION 'Unauthorized: user_id mismatch';
  END IF;

  -- Generate transaction UUID
  v_txn_id := gen_random_uuid();

  -- Insert transaction
  INSERT INTO public.transactions (
    id, user_id, transaction_number, customer_name,
    subtotal, discount_amount, discount_percentage, tax_amount,
    total, payment_method, payment_status,
    cash_received, cash_change, notes, cashier_name,
    transaction_date, debt_paid_at
  ) VALUES (
    v_txn_id,
    p_user_id,
    p_transaction->>'transaction_number',
    p_transaction->>'customer_name',
    (p_transaction->>'subtotal')::DECIMAL(12,2),
    COALESCE((p_transaction->>'discount_amount')::DECIMAL(12,2), 0),
    COALESCE((p_transaction->>'discount_percentage')::DECIMAL(5,2), 0),
    COALESCE((p_transaction->>'tax_amount')::DECIMAL(12,2), 0),
    (p_transaction->>'total')::DECIMAL(12,2),
    p_transaction->>'payment_method',
    p_transaction->>'payment_status',
    (p_transaction->>'cash_received')::DECIMAL(12,2),
    (p_transaction->>'cash_change')::DECIMAL(12,2),
    p_transaction->>'notes',
    p_transaction->>'cashier_name',
    (p_transaction->>'transaction_date')::TIMESTAMPTZ,
    (p_transaction->>'debt_paid_at')::TIMESTAMPTZ
  );

  -- Insert items and update stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.transaction_items (
      id, user_id, transaction_id, product_id,
      product_name, product_sku, quantity,
      cost_price, selling_price, discount_amount, subtotal
    ) VALUES (
      gen_random_uuid(),
      p_user_id,
      v_txn_id,
      (v_item->>'product_id')::UUID,
      v_item->>'product_name',
      v_item->>'product_sku',
      (v_item->>'quantity')::INTEGER,
      (v_item->>'cost_price')::DECIMAL(12,2),
      (v_item->>'selling_price')::DECIMAL(12,2),
      COALESCE((v_item->>'discount_amount')::DECIMAL(12,2), 0),
      (v_item->>'subtotal')::DECIMAL(12,2)
    );

    -- Update product stock
    UPDATE public.products
    SET stock = stock - (v_item->>'quantity')::INTEGER
    WHERE id = (v_item->>'product_id')::UUID
      AND user_id = p_user_id;
  END LOOP;

  RETURN v_txn_id::TEXT;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. DASHBOARD SUMMARY
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_dashboard_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_today_sales DECIMAL;
  v_today_profit DECIMAL;
  v_txn_count INTEGER;
  v_yesterday_sales DECIMAL;
  v_yesterday_profit DECIMAL;
  v_low_stock INTEGER;
BEGIN
  -- Today's sales
  SELECT COALESCE(SUM(total), 0) INTO v_today_sales
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date::date = CURRENT_DATE
    AND payment_status != 'cancelled';

  -- Today's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_today_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date::date = CURRENT_DATE
    AND t.payment_status != 'cancelled';

  -- Today's transaction count
  SELECT COUNT(*) INTO v_txn_count
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date::date = CURRENT_DATE
    AND payment_status != 'cancelled';

  -- Yesterday's sales
  SELECT COALESCE(SUM(total), 0) INTO v_yesterday_sales
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date::date = CURRENT_DATE - 1
    AND payment_status != 'cancelled';

  -- Yesterday's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_yesterday_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date::date = CURRENT_DATE - 1
    AND t.payment_status != 'cancelled';

  -- Low stock count
  SELECT COUNT(*) INTO v_low_stock
  FROM public.products
  WHERE user_id = v_uid
    AND is_active = true
    AND stock <= min_stock;

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
-- 3. SALES SUMMARY
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_sales_summary(
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
  v_revenue DECIMAL;
  v_txn_count INTEGER;
  v_profit DECIMAL;
  v_items_sold INTEGER;
BEGIN
  SELECT COALESCE(SUM(total), 0), COUNT(*)
  INTO v_revenue, v_txn_count
  FROM public.transactions
  WHERE user_id = v_uid
    AND transaction_date >= p_from
    AND transaction_date < p_to
    AND payment_status != 'cancelled';

  SELECT
    COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0),
    COALESCE(SUM(ti.quantity), 0)
  INTO v_profit, v_items_sold
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND t.transaction_date >= p_from
    AND t.transaction_date < p_to
    AND t.payment_status != 'cancelled';

  RETURN jsonb_build_object(
    'total_revenue', v_revenue,
    'transaction_count', v_txn_count,
    'total_profit', v_profit,
    'items_sold', v_items_sold
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. TOP PRODUCTS
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_top_products(
  p_from TIMESTAMPTZ,
  p_to TIMESTAMPTZ,
  p_sort TEXT DEFAULT 'quantity',
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
  v_order_col TEXT;
BEGIN
  v_order_col := CASE p_sort
    WHEN 'revenue' THEN 'total_revenue'
    WHEN 'profit' THEN 'total_profit'
    ELSE 'quantity_sold'
  END;

  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY
    CASE WHEN p_sort = 'revenue' THEN sub.total_revenue END DESC NULLS LAST,
    CASE WHEN p_sort = 'profit' THEN sub.total_profit END DESC NULLS LAST,
    CASE WHEN p_sort NOT IN ('revenue','profit') THEN sub.quantity_sold END DESC NULLS LAST
  )
  INTO v_result
  FROM (
    SELECT
      p.id,
      p.name,
      COALESCE(SUM(ti.quantity), 0)::INTEGER as quantity_sold,
      COALESCE(SUM(ti.subtotal), 0)::DECIMAL as total_revenue,
      COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)::DECIMAL as total_profit
    FROM public.transaction_items ti
    JOIN public.products p ON ti.product_id = p.id
    JOIN public.transactions t ON ti.transaction_id = t.id
    WHERE t.user_id = v_uid
      AND t.transaction_date >= p_from
      AND t.transaction_date < p_to
      AND t.payment_status != 'cancelled'
    GROUP BY p.id
    HAVING COALESCE(SUM(ti.quantity), 0) > 0
    LIMIT p_limit
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. DAILY SALES (for chart)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_daily_sales(
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
  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY sub.sale_date)
  INTO v_result
  FROM (
    SELECT
      transaction_date::date::text as sale_date,
      COALESCE(SUM(total), 0)::DECIMAL as revenue,
      COUNT(*)::INTEGER as transaction_count
    FROM public.transactions
    WHERE user_id = v_uid
      AND transaction_date >= p_from
      AND transaction_date < p_to
      AND payment_status != 'cancelled'
    GROUP BY transaction_date::date
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. PROFIT SUMMARY
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_profit_summary(
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
    AND t.transaction_date < p_to
    AND t.payment_status != 'cancelled';

  RETURN jsonb_build_object(
    'total_profit', v_profit,
    'total_sales', v_sales,
    'transaction_count', v_txn_count
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. TOP PROFITABLE PRODUCTS
-- ---------------------------------------------------------------------------

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
  SELECT jsonb_agg(row_to_json(sub)::jsonb ORDER BY sub.total_profit DESC)
  INTO v_result
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
      AND t.payment_status != 'cancelled'
    WHERE p.user_id = v_uid
      AND p.is_active = true
    GROUP BY p.id
    HAVING COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0) > 0
    LIMIT p_limit
  ) sub;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

-- ---------------------------------------------------------------------------
-- 8. PRODUCT PROFITABILITY (single product)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_product_profitability(
  p_product_id UUID
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
      AND t.payment_status != 'cancelled'
    WHERE p.id = p_product_id
      AND p.user_id = v_uid
    GROUP BY p.id
  ) sub;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;
