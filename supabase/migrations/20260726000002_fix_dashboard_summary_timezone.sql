-- =============================================================================
-- KASBON POS - Fix get_dashboard_summary time zone
-- =============================================================================
-- get_dashboard_summary compared `transaction_date::date = CURRENT_DATE`, which
-- evaluates in the server's zone (UTC on Supabase). For a WIB shop that means
-- "today" began at 07:00 local: every sale between midnight and 07:00 was
-- counted against yesterday, and the dashboard read zero each morning until the
-- shop had been open for hours.
--
-- Same class of bug as the report RPCs fixed in 20260726000001, kept in its own
-- migration because the dashboard is outside TASK_019 and changing its numbers
-- should be revertible on its own.
--
-- p_tz defaults to Asia/Jakarta, matching the report RPCs and
-- `app/lib/core/utils/business_time.dart`. Those three must agree or the
-- dashboard and the reports will disagree about which day it is.
-- =============================================================================

DROP FUNCTION IF EXISTS public.get_dashboard_summary();

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
  v_today_sales DECIMAL;
  v_today_profit DECIMAL;
  v_txn_count INTEGER;
  v_yesterday_sales DECIMAL;
  v_yesterday_profit DECIMAL;
  v_low_stock INTEGER;
BEGIN
  -- "Today" as the shop experiences it, not as UTC does.
  v_today := (NOW() AT TIME ZONE p_tz)::date;

  -- Today's sales
  SELECT COALESCE(SUM(total), 0) INTO v_today_sales
  FROM public.transactions
  WHERE user_id = v_uid
    AND (transaction_date AT TIME ZONE p_tz)::date = v_today;

  -- Today's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_today_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND (t.transaction_date AT TIME ZONE p_tz)::date = v_today;

  -- Today's transaction count
  SELECT COUNT(*) INTO v_txn_count
  FROM public.transactions
  WHERE user_id = v_uid
    AND (transaction_date AT TIME ZONE p_tz)::date = v_today;

  -- Yesterday's sales
  SELECT COALESCE(SUM(total), 0) INTO v_yesterday_sales
  FROM public.transactions
  WHERE user_id = v_uid
    AND (transaction_date AT TIME ZONE p_tz)::date = v_today - 1;

  -- Yesterday's profit
  SELECT COALESCE(SUM((ti.selling_price - ti.cost_price) * ti.quantity), 0)
  INTO v_yesterday_profit
  FROM public.transaction_items ti
  JOIN public.transactions t ON ti.transaction_id = t.id
  WHERE t.user_id = v_uid
    AND (t.transaction_date AT TIME ZONE p_tz)::date = v_today - 1;

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

-- The original grants went with the dropped definition.
GRANT EXECUTE ON FUNCTION public.get_dashboard_summary(TEXT)
  TO authenticated, service_role;
