-- =============================================================================
-- KASBON POS - Recording a sale, atomically
-- =============================================================================
-- One function, and the only write path in the app that is not a plain
-- PostgREST insert. It exists because a sale is three statements - the
-- transaction header, its line items, and the stock decrement - and a till that
-- can leave any two of them applied without the third is not a till.
--
-- SECURITY DEFINER, so every statement inside runs with RLS bypassed and each
-- one has to re-establish the tenant boundary itself. There are three such
-- checks and all three are load-bearing:
--
--   1. `auth.uid() IS DISTINCT FROM p_user_id` - the caller is who they claim.
--   2. Each non-NULL product_id belongs to the caller.
--   3. The stock update carries `AND user_id = p_user_id`.
--
-- Check 2 is the one that was missing. `product_id` came from client JSON, was
-- cast to UUID and written with nothing checking whose product it was, and the
-- leak read the wrong way round: the caller supplies a foreign product id, and
-- the *report* RPCs give it back enriched. Both get_top_products and
-- get_top_profitable_products join transaction_items -> products on that id and
-- filter only on the transaction's user_id, so another shop's product name
-- surfaced in the attacker's own top-sellers list. Product names are not the
-- crown jewels; cross-tenant is cross-tenant.
--
-- A NULL product_id is still allowed. transaction_items.product_id is nullable
-- (ON DELETE SET NULL) and the row carries product_name / product_sku for
-- exactly that case.
--
-- ## Two things this deliberately does not do
--
-- **No stock guard.** `stock = stock - qty` with no `stock >= qty` check will be
-- flagged by any audit as an oversell bug, and in most systems it is. Here it is
-- the product decision - see `exceedsStock` in pos/domain/entities/cart_item.dart,
-- "used to show warnings (but not block sales per MVP requirements)". A warung
-- sells what is physically on the shelf; the stock count is the thing that is
-- wrong when the two disagree, and a till that refuses money because a number is
-- stale is a worse till. Negative stock is a reporting signal, not a failure.
--
-- **Prices still come from the payload**, not from `products`. Sourcing them from
-- the table was the obvious tightening and is wrong here: the item rows are a
-- point-in-time snapshot, and a shop owner editing a price on their phone while
-- the counter tablet has a cart open would make the two disagree and reject an
-- honest sale. Nothing in the cart can override a price today - CartItem reads
-- product.sellingPrice straight through - so payload and table already agree in
-- every non-tampered case, and the threat model for a tampered one is a single
-- owner falsifying their own books. That changes the day a second cashier
-- account exists, and this paragraph is the note to revisit it then.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.create_pos_transaction(p_user_id uuid, p_transaction jsonb, p_items jsonb)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_txn_id UUID;
  v_item JSONB;
  v_product_id UUID;
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
    transaction_date, debt_paid_at,
    payment_confirmed_at, payment_confirmed_by, payment_reference
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
    (p_transaction->>'debt_paid_at')::TIMESTAMPTZ,
    (p_transaction->>'payment_confirmed_at')::TIMESTAMPTZ,
    p_transaction->>'payment_confirmed_by',
    p_transaction->>'payment_reference'
  );

  -- Insert items and update stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;

    -- A NULL product_id is allowed: transaction_items.product_id is nullable
    -- (ON DELETE SET NULL) and the row carries product_name / product_sku for
    -- exactly that case. A non-NULL one has to be the caller's.
    IF v_product_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM public.products
      WHERE id = v_product_id AND user_id = p_user_id
    ) THEN
      RAISE EXCEPTION 'Unauthorized: product % does not belong to the caller', v_product_id
        USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.transaction_items (
      id, user_id, transaction_id, product_id,
      product_name, product_sku, quantity,
      cost_price, selling_price, discount_amount, subtotal
    ) VALUES (
      gen_random_uuid(),
      p_user_id,
      v_txn_id,
      v_product_id,
      v_item->>'product_name',
      v_item->>'product_sku',
      (v_item->>'quantity')::INTEGER,
      (v_item->>'cost_price')::DECIMAL(12,2),
      (v_item->>'selling_price')::DECIMAL(12,2),
      COALESCE((v_item->>'discount_amount')::DECIMAL(12,2), 0),
      (v_item->>'subtotal')::DECIMAL(12,2)
    );

    -- Update product stock. Stock is allowed to go negative; see the header.
    UPDATE public.products
    SET stock = stock - (v_item->>'quantity')::INTEGER
    WHERE id = v_product_id
      AND user_id = p_user_id;
  END LOOP;

  RETURN v_txn_id::TEXT;
END;
$function$;
