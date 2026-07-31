-- =============================================================================
-- KASBON POS - Distinct customer names, most recently used first
-- =============================================================================
-- Backs the autocomplete on the customer name field.
--
-- The field itself is the point of this: customer_name is free text, and free
-- text fragments. "Bu Sri", "bu sri" and "Bu Sri " are three customers to a
-- database and one person to a shop owner, and once a month of sales is in,
-- the transaction list's customer filter is sorting a junk drawer. Suggesting
-- what has already been typed is what keeps one customer one row.
--
-- Which is why this ships alongside the name field rather than after it. There
-- is no version of "add autocomplete later" that does not also mean "and clean
-- up the names typed in the meantime".
--
-- Ordered by most recent use, not alphabetically: a warung has a handful of
-- regulars who buy constantly and a long tail who came once. The regular the
-- cashier is serving right now is almost always in the last few.
--
-- Reads through idx_transactions_user_customer (user_id, customer_name), which
-- has been on the table since the initial schema with nothing querying it.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.get_customer_names(
  p_query TEXT DEFAULT NULL,
  p_limit INTEGER DEFAULT 20
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
$$;

COMMENT ON FUNCTION public.get_customer_names(TEXT, INTEGER) IS
  'Distinct customer_name values for the caller, most recently used first. '
  'Feeds the POS customer name autocomplete.';
