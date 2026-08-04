-- =============================================================================
-- KASBON POS - Security invariants, asserted
-- =============================================================================
-- Run against a freshly reset local stack:
--
--   supabase db reset
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/security_invariants.sql
--
-- Every check RAISEs on failure, so ON_ERROR_STOP makes a violation a non-zero
-- exit and a red build. The whole file runs inside one transaction that rolls
-- back, so it leaves no rows behind and is safe to re-run.
--
-- These are the findings from the August 2026 audit turned into something that
-- notices if they come back. Each was verified by hand once; a check here is
-- the difference between "was fixed" and "stays fixed". The structural ones
-- (4, 5) matter most, because they fail for a policy or function that does not
-- exist yet - which is the only way to catch the next instance rather than the
-- last one.
-- =============================================================================

BEGIN;

\set ON_ERROR_STOP on
\echo '--- security invariants ---'

-- ---------------------------------------------------------------------------
-- Fixtures: a second tenant to be excluded from.
-- ---------------------------------------------------------------------------
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000000','bbbbbbbb-0000-4000-8000-0000000000ff',
        'authenticated','authenticated','invariant-other@kasbon.id','x',NOW(),NOW());

INSERT INTO public.products (id, user_id, sku, name, cost_price, selling_price, stock)
VALUES ('cccccccc-0000-4000-8000-0000000000ff','bbbbbbbb-0000-4000-8000-0000000000ff',
        'SKU-OTHER','Produk Tetangga', 1000, 5000, 50);

-- ---------------------------------------------------------------------------
-- 1. tier is not writable by its owner
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_tier TEXT; v_name TEXT;
BEGIN
  PERFORM set_config('request.jwt.claims',
    '{"sub":"a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d","role":"authenticated"}', true);

  UPDATE public.user_profiles
     SET tier = 'premium', subscription_expires_at = '2099-01-01', full_name = 'Renamed'
   WHERE id = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';

  SELECT tier, full_name INTO v_tier, v_name
    FROM public.user_profiles WHERE id = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';

  IF v_tier <> 'free' THEN
    RAISE EXCEPTION 'INVARIANT 1 FAILED: a user escalated their own tier to %', v_tier;
  END IF;
  -- The trigger must freeze the entitlement columns without freezing the row:
  -- a profile edit that happens to echo `tier` back has to still work.
  IF v_name <> 'Renamed' THEN
    RAISE EXCEPTION 'INVARIANT 1 FAILED: the trigger blocked a legitimate profile edit';
  END IF;
  RAISE NOTICE 'ok  1. user_profiles.tier is frozen against client writes';
END $$;

-- ---------------------------------------------------------------------------
-- 2. create_pos_transaction refuses another tenant's product
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_failed BOOLEAN := FALSE;
BEGIN
  PERFORM set_config('request.jwt.claims',
    '{"sub":"a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d","role":"authenticated"}', true);
  BEGIN
    PERFORM public.create_pos_transaction(
      'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
      '{"transaction_number":"TRX-INV-1","subtotal":5000,"total":5000,"payment_method":"cash","payment_status":"paid","transaction_date":"2026-08-01T10:00:00Z"}'::jsonb,
      '[{"product_id":"cccccccc-0000-4000-8000-0000000000ff","product_name":"x","product_sku":"y","quantity":1,"cost_price":1000,"selling_price":5000,"subtotal":5000}]'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN
    v_failed := TRUE;
  END;

  IF NOT v_failed THEN
    RAISE EXCEPTION 'INVARIANT 2 FAILED: a sale referencing another tenant''s product was accepted';
  END IF;
  RAISE NOTICE 'ok  2. create_pos_transaction rejects a cross-tenant product_id';
END $$;

-- ---------------------------------------------------------------------------
-- 3. ...but an ordinary sale still works, and still moves stock
-- ---------------------------------------------------------------------------
-- The check that keeps check 2 honest. An ownership test that also broke real
-- sales would pass every assertion above and take the till down.
DO $$
DECLARE v_pid UUID; v_before INT; v_after INT;
BEGIN
  PERFORM set_config('request.jwt.claims',
    '{"sub":"a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d","role":"authenticated"}', true);

  SELECT id, stock INTO v_pid, v_before FROM public.products
   WHERE user_id = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d' AND is_active
   ORDER BY sku LIMIT 1;

  PERFORM public.create_pos_transaction(
    'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
    '{"transaction_number":"TRX-INV-2","subtotal":5000,"total":5000,"payment_method":"cash","payment_status":"paid","transaction_date":"2026-08-01T10:00:00Z"}'::jsonb,
    jsonb_build_array(jsonb_build_object(
      'product_id', v_pid, 'product_name','x','product_sku','y',
      'quantity', 2, 'cost_price', 1000, 'selling_price', 5000, 'subtotal', 10000)));

  SELECT stock INTO v_after FROM public.products WHERE id = v_pid;
  IF v_after <> v_before - 2 THEN
    RAISE EXCEPTION 'INVARIANT 3 FAILED: stock went % -> %, expected % -> %',
      v_before, v_after, v_before, v_before - 2;
  END IF;

  -- A NULL product_id is legal: the column is nullable (ON DELETE SET NULL) and
  -- the row carries product_name/product_sku for exactly that case.
  PERFORM public.create_pos_transaction(
    'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
    '{"transaction_number":"TRX-INV-3","subtotal":3000,"total":3000,"payment_method":"cash","payment_status":"paid","transaction_date":"2026-08-01T10:00:00Z"}'::jsonb,
    '[{"product_id":null,"product_name":"Dihapus","product_sku":"z","quantity":1,"cost_price":1000,"selling_price":3000,"subtotal":3000}]'::jsonb);

  RAISE NOTICE 'ok  3. an ordinary sale still succeeds and decrements stock';
END $$;

-- ---------------------------------------------------------------------------
-- 4. every RLS policy is scoped to `authenticated`
-- ---------------------------------------------------------------------------
-- Structural, so it fails for a policy nobody has written yet. A policy created
-- without a TO clause defaults to `public`, which on this project means it is
-- also evaluated for `anon`.
DO $$
DECLARE v_bad TEXT;
BEGIN
  SELECT string_agg(tablename || '.' || policyname, ', ')
    INTO v_bad
    FROM pg_policies
   WHERE schemaname = 'public'
     AND roles::text <> '{authenticated}';

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'INVARIANT 4 FAILED: policies not scoped TO authenticated: %', v_bad;
  END IF;
  RAISE NOTICE 'ok  4. all % public policies are scoped TO authenticated',
    (SELECT count(*) FROM pg_policies WHERE schemaname = 'public');
END $$;

-- ---------------------------------------------------------------------------
-- 5. every public function pins its search_path
-- ---------------------------------------------------------------------------
-- Also structural. handle_updated_at was the one function in the schema without
-- it, found by an audit rather than by anything automatic; this is the
-- automatic thing.
DO $$
DECLARE v_bad TEXT;
BEGIN
  SELECT string_agg(p.proname, ', ')
    INTO v_bad
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.prokind = 'f'
     -- Extension-owned C functions have no proconfig and never will. pg_trgm
     -- is created `WITH SCHEMA extensions` (20260804010001), so this exclusion is
     -- currently matching nothing - it is
     -- here so that the next `CREATE EXTENSION` that forgets WITH SCHEMA fails
     -- this check as a schema-hygiene problem, not as 30 phantom findings.
     AND NOT EXISTS (
       SELECT 1 FROM pg_depend d
        WHERE d.objid = p.oid AND d.deptype = 'e')
     AND NOT EXISTS (
       SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) c
        WHERE c LIKE 'search_path=%');

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'INVARIANT 5 FAILED: functions with a mutable search_path: %', v_bad;
  END IF;
  RAISE NOTICE 'ok  5. every public function pins search_path';
END $$;

-- ---------------------------------------------------------------------------
-- 6. the cross-tenant policy functions stay service-role only
-- ---------------------------------------------------------------------------
-- 20260804010003 sets ALTER DEFAULT PRIVILEGES granting EXECUTE on every new
-- public function to `authenticated`, so these are only private because their
-- migration explicitly revokes it. A future migration that recreates one
-- without re-revoking would silently hand every signed-in user a cross-tenant
-- read - the grant is the default, not the exception.
--
-- `account_object_paths` is the newest and the sharpest: it takes a uuid and
-- answers with that account's storage folder, so an accidental grant here is a
-- read of every shop's object paths, keyed by a value the caller supplies.
DO $$
DECLARE v_bad TEXT;
BEGIN
  SELECT string_agg(p.proname, ', ')
    INTO v_bad
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
   WHERE n.nspname = 'public'
     AND p.proname IN ('expired_payment_proofs','orphaned_object_paths',
                       'referenced_object_paths','clear_payment_proof_paths',
                       'run_storage_janitor','account_object_paths')
     AND has_function_privilege('authenticated', p.oid, 'EXECUTE');

  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'INVARIANT 6 FAILED: authenticated can execute cross-tenant functions: %', v_bad;
  END IF;
  RAISE NOTICE 'ok  6. cross-tenant policy functions are not executable by authenticated';
END $$;

-- ---------------------------------------------------------------------------
-- 6b. account_object_paths returns one account's folder and nothing else
-- ---------------------------------------------------------------------------
-- Structural checks cannot catch a wrong LIKE pattern, and this one deletes
-- files: every path it returns is handed straight to Storage `remove()`. The
-- shape that matters is the separator - `<uuid>/%` and not `<uuid>%` - so the
-- fixtures below are two folders whose names share a prefix.
--
-- Objects are inserted directly rather than through the Storage API because
-- this runs in a transaction that rolls back; `storage.protect_delete()` only
-- guards DELETE, so an INSERT here is fine and disappears with the ROLLBACK.
DO $$
DECLARE
  v_mine   UUID := '00000000-0000-4000-8000-00000000aaaa';
  v_theirs UUID := '00000000-0000-4000-8000-00000000bbbb';
  v_found  TEXT;
BEGIN
  -- Invariants 1-3 leave an `authenticated` claim set for the transaction, and
  -- `assert_service_role_caller` reads exactly that - so without this the
  -- function correctly refuses to answer and the block below fails for the
  -- wrong reason. This is also how the Edge Function actually reaches it.
  PERFORM set_config('request.jwt.claims', '{"role":"service_role"}', true);

  INSERT INTO storage.objects (bucket_id, name, owner)
  VALUES ('product-images', v_mine   || '/p1/a.webp', NULL),
         ('product-images', v_mine   || '/p2/b.webp', NULL),
         ('product-images', v_theirs || '/p3/c.webp', NULL),
         ('payment-proofs', v_mine   || '/t1/d.webp', NULL);

  SELECT string_agg(object_path, ', ' ORDER BY object_path)
    INTO v_found
    FROM public.account_object_paths('product-images', v_mine);

  IF v_found IS DISTINCT FROM
     (v_mine || '/p1/a.webp, ' || v_mine || '/p2/b.webp') THEN
    RAISE EXCEPTION 'INVARIANT 6b FAILED: wrong paths for own folder: %', v_found;
  END IF;

  -- The other bucket is a separate answer, not a merged one.
  SELECT string_agg(object_path, ', ')
    INTO v_found
    FROM public.account_object_paths('payment-proofs', v_mine);

  IF v_found IS DISTINCT FROM (v_mine || '/t1/d.webp') THEN
    RAISE EXCEPTION 'INVARIANT 6b FAILED: wrong paths in payment-proofs: %', v_found;
  END IF;

  -- The keyset cursor, which is what stops the caller looping on page one.
  SELECT string_agg(object_path, ', ')
    INTO v_found
    FROM public.account_object_paths('product-images', v_mine, 100,
                                     v_mine || '/p1/a.webp');

  IF v_found IS DISTINCT FROM (v_mine || '/p2/b.webp') THEN
    RAISE EXCEPTION 'INVARIANT 6b FAILED: p_after did not advance: %', v_found;
  END IF;

  RAISE NOTICE 'ok  6b. account_object_paths is scoped to one folder and pages';
END $$;

-- ---------------------------------------------------------------------------
-- 7. the indexes the hot reads depend on exist
-- ---------------------------------------------------------------------------
DO $$
DECLARE v_missing TEXT;
BEGIN
  SELECT string_agg(x, ', ') INTO v_missing
    FROM unnest(ARRAY['idx_products_name_trgm',
                      'idx_transactions_customer_trgm',
                      'idx_transactions_proof_retention',
                      'idx_transactions_user_date']) AS x
   WHERE NOT EXISTS (
     SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND indexname = x);

  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'INVARIANT 7 FAILED: missing indexes: %', v_missing;
  END IF;
  RAISE NOTICE 'ok  7. performance-critical indexes are present';
END $$;

\echo '--- all invariants held ---'

ROLLBACK;
