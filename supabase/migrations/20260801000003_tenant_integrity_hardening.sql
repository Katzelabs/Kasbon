-- =============================================================================
-- KASBON POS - Three holes found in a security audit, none of them exploited
-- =============================================================================
-- Grouped into one migration because they share a premise: RLS is doing its job
-- on the tables, and everything below is a place where something reaches past
-- RLS and was trusted not to. A SECURITY DEFINER function, a column no policy
-- narrows, and a search_path that was left open.
--
-- What is deliberately NOT here: a stock check in create_pos_transaction. An
-- audit will flag `stock = stock - qty` with no `stock >= qty` guard as an
-- oversell bug, and in most systems it is. Here it is the product decision -
-- see `exceedsStock` in pos/domain/entities/cart_item.dart, "used to show
-- warnings (but not block sales per MVP requirements)". A warung sells what is
-- physically on the shelf; the stock count is the thing that is wrong when the
-- two disagree, and a till that refuses money because a number is stale is a
-- worse till. Negative stock is a reporting signal, not a failure.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. handle_updated_at: pin the search_path
-- ---------------------------------------------------------------------------
-- The only function in the schema without it. Every other one - the auth
-- trigger, the RPCs, the janitor policy functions - sets an empty search_path
-- so that an unqualified name cannot be resolved against a schema someone else
-- controls.
--
-- This one is SECURITY INVOKER and its body touches nothing but NEW, so there
-- is no live escalation to fix; it is the case Supabase's own linter flags as
-- `function_search_path_mutable`, and consistency here is worth more than the
-- argument about whether this particular body can be reached.

CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- 2. user_profiles.tier is not the client's to set
-- ---------------------------------------------------------------------------
-- "Users can update own profile" scopes rows and says nothing about columns, so
-- `update user_profiles set tier = 'premium', subscription_expires_at =
-- '2099-01-01'` was a valid statement for any signed-in user against their own
-- row. Nothing in the app reads `tier` today, so nothing is currently bypassed
-- - this is the day before it matters, which is the only good day to fix it.
--
-- A trigger rather than a column-scoped policy because Postgres RLS cannot
-- express "these columns are read-only to this role"; the alternative is
-- REVOKE ... ON COLUMN, which PostgREST reports as a blanket 403 on the whole
-- update and would be a confusing failure for a client that legitimately sends
-- the full row back.
--
-- Silently preserving the old values rather than raising, for the same reason.
-- A client that PATCHes a whole profile row should not fail because it echoed
-- back a `tier` it never intended to change. Today no client writes this table
-- at all - `auth_remote_datasource.dart` only ever SELECTs it - so this is
-- pre-emptive either way, and the quiet version is the one that stays correct
-- when a profile-edit screen eventually appears.
--
-- service_role is exempt: that is how billing will actually set the tier, from
-- a webhook or an admin path that never travels through PostgREST as the user.

CREATE OR REPLACE FUNCTION public.freeze_privileged_profile_columns()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF COALESCE(auth.role(), 'service_role') = 'service_role' THEN
    RETURN NEW;
  END IF;

  NEW.tier                    := OLD.tier;
  NEW.subscription_expires_at := OLD.subscription_expires_at;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION public.freeze_privileged_profile_columns() IS
  'Restores tier / subscription_expires_at to their previous values on any '
  'update that does not come from the service role. These are entitlements, '
  'not profile fields, and RLS cannot scope a policy to columns.';

DROP TRIGGER IF EXISTS freeze_tier_on_user_profiles ON public.user_profiles;
CREATE TRIGGER freeze_tier_on_user_profiles
  BEFORE UPDATE ON public.user_profiles
  FOR EACH ROW EXECUTE FUNCTION public.freeze_privileged_profile_columns();

-- ---------------------------------------------------------------------------
-- 3. create_pos_transaction: a line item must name the caller's own product
-- ---------------------------------------------------------------------------
-- The function is SECURITY DEFINER, so every statement in it runs with RLS
-- bypassed and each one has to re-establish the tenant boundary itself. The
-- stock update always did (`AND user_id = p_user_id`). The item insert never
-- did: `product_id` was taken from client JSON, cast to UUID and written, with
-- nothing checking whose product it was.
--
-- The leak is small but real and reads the wrong way round: the caller supplies
-- a foreign product id, and the *report* RPCs give it back enriched. Both
-- `get_top_products` and `get_top_profitable_products` join
-- transaction_items -> products on that id and filter only on the
-- transaction's user_id, so another shop's product name surfaces in the
-- attacker's own top-sellers list. Product names are not the crown jewels;
-- cross-tenant is cross-tenant.
--
-- Prices are deliberately still taken from the payload. Sourcing them from
-- `products` instead was the obvious tightening and is wrong here: the item
-- rows are a point-in-time snapshot (see transaction_items.cost_price /
-- selling_price), and a shop owner editing a price on their phone while the
-- counter tablet has a cart open would make the two disagree and reject an
-- honest sale at the till. Nothing in the cart can override a price today -
-- CartItem reads product.sellingPrice straight through - so the payload and
-- the table already agree in every non-tampered case, and the threat model for
-- a tampered one is a single owner falsifying their own books. That changes the
-- day a second cashier account exists, and this comment is the note to revisit
-- it then.
--
-- Everything else about the function is unchanged from 20260731000004: same
-- signature, same columns, same stock decrement, same auth.uid() check.

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
$$;
