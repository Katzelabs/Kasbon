-- =============================================================================
-- KASBON POS - Remove filters on a payment_status that cannot exist
-- =============================================================================
-- Two report functions filter `payment_status != 'cancelled'`. There is no
-- 'cancelled' status and there never has been:
--
--   CHECK (payment_status IN ('paid', 'debt'))    -- initial schema, still current
--
-- So the predicate is always true and excludes nothing. It is not a bug in the
-- numbers - the reports are correct today - it is a lie in the source. It
-- states that cancelled sales are being kept out of profit, which reads as a
-- deliberate accounting decision, and a reader auditing why profit looks wrong
-- will spend time on a clause that does nothing.
--
-- The dishonesty is also load-bearing in the wrong direction. A future status -
-- 'pending', say, for a QRIS sale awaiting a webhook - would be silently
-- INCLUDED in profit by this predicate, because it only ever excluded a name
-- nobody uses. The clause looks like a guard and is not one.
--
-- What is deliberately NOT done here: no `IN ('paid','debt')` whitelist is
-- added, here or anywhere else. Every other report function already counts all
-- statuses, and that is correct - a hutang is a completed sale whose goods left
-- the shop, and a shop owner asking "how much did I sell this month" means it
-- to be included. Adding a whitelist to two functions out of eleven would
-- create the inconsistency this migration exists to remove.
--
-- If a status is ever added that genuinely must not count as revenue, the fix
-- is one considered pass over every report function, with a test per function.
-- Not a predicate quietly left behind in two of them.
--
-- Both functions are otherwise byte-identical to their current definitions.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_profit_summary(
  p_from timestamp with time zone,
  p_to timestamp with time zone
)
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
