-- =============================================================================
-- KASBON POS - Let create_pos_transaction record who confirmed the payment
-- =============================================================================
-- 20260731000001 added payment_confirmed_at / payment_confirmed_by /
-- payment_reference to transactions. create_pos_transaction inserts with an
-- explicit column list, so until this migration those three were unreachable at
-- insert time: the client could put them in the JSONB payload and the function
-- would drop them on the floor, silently and with no error.
--
-- They belong at insert, not in a follow-up UPDATE. For a QRIS sale the cashier
-- has already looked at the customer's phone before anything is written - the
-- confirmation is an input to the sale, not news that arrives later. Writing it
-- in the same statement means there is no instant where a confirmed sale is
-- stored as unconfirmed, and no second round trip to lose on a warung
-- connection between the two.
--
-- payment_proof_path is deliberately NOT here. The photo is compressed and
-- uploaded to a bucket, which is slow and fails independently of the sale, so
-- it is attached afterwards by an UPDATE. A sale must never wait on an upload -
-- the money has already changed hands and there is a queue at the counter.
--
-- Everything else about this function is unchanged: same signature, same items
-- loop, same stock decrement, same authorisation check.
-- =============================================================================

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
