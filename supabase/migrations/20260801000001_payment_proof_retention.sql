-- =============================================================================
-- KASBON POS - Payment proof retention, and the queries a janitor needs
-- =============================================================================
-- Nothing has ever deleted a payment proof on a schedule. `RemovePaymentProof`
-- deletes one a human decided was filed against the wrong sale, which is a
-- correctness feature, not a retention policy - so the bucket only grows.
--
-- The arithmetic recorded in `payment_proof_compression.dart`:
--
--   ~300 KB per proof x 50 QRIS sales/day = ~15 MB/day, ~5.5 GB/year
--
-- against a 1 GB free-tier quota. One busy shop fills the whole project in
-- about ten weeks, and no amount of extra compression fixes that - it buys
-- weeks against something that grows without bound. Retention is the only lever
-- with the right shape, because a proof stops being useful once the sale it
-- documents is too old to argue about.
--
-- This migration adds the window and the read-side queries. The deleting itself
-- cannot happen here: `storage.protect_delete()` is a BEFORE DELETE trigger on
-- `storage.objects` that raises
--
--   'Direct deletion from storage tables is not allowed. Use the Storage API instead.'
--
-- so removing an object means an HTTP call, which means the `storage-janitor`
-- Edge Function. What lives in SQL is the *policy* - which proofs have expired,
-- and which objects nothing references - because those are questions about this
-- schema and belong next to it. The function does I/O and nothing else.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. THE WINDOW
-- ---------------------------------------------------------------------------
-- Per shop rather than a constant, because the right answer is a business
-- question, not a technical one: a warung selling snacks settles arguments
-- within days, a shop taking large QRIS payments for furniture may want a
-- season. 90 days is a generous default for the former and the point at which a
-- busy shop's proofs stop growing at ~40 MB rather than ~5.5 GB/year.
--
-- The lower bound is 7 rather than 0 or 1: a window short enough to delete a
-- proof before the weekend it was taken on is a data-loss bug wearing a
-- settings row, and nothing in the app has any business offering it.
ALTER TABLE public.shop_settings
  ADD COLUMN IF NOT EXISTS payment_proof_retention_days INTEGER NOT NULL DEFAULT 90
    CHECK (payment_proof_retention_days BETWEEN 7 AND 3650);

COMMENT ON COLUMN public.shop_settings.payment_proof_retention_days IS
  'Days a payment proof is kept before storage-janitor deletes it. 7..3650, default 90.';

-- ---------------------------------------------------------------------------
-- 2. WHO MAY ASK
-- ---------------------------------------------------------------------------
-- Every function below reads across all tenants, which is the exact opposite of
-- what every other function in this schema does. Two things keep them shut, and
-- both are needed:
--
--   * The GRANTs at the bottom of this file. On their own they are not enough:
--     `20260725000001_grant_api_role_privileges.sql` sets ALTER DEFAULT
--     PRIVILEGES so that *every* new function in `public` is executable by
--     `authenticated`. A REVOKE here is undone the moment someone adds another
--     blanket grant, and that migration exists because a blanket grant was
--     already needed once.
--
--   * The guard below, called first in each body. It does not care what the
--     grants say. If a future migration re-opens execute to `authenticated`,
--     the worst outcome is an error rather than one shop reading another's
--     transaction ids.
--
-- `auth.role()` reads the JWT the request arrived with; the Edge Function calls
-- these with the service key, so it sees 'service_role'. A direct psql session
-- has no JWT at all, hence the null branch - useful for testing this migration,
-- and unreachable through PostgREST, which always presents a role.
CREATE OR REPLACE FUNCTION public.assert_janitor_caller()
RETURNS VOID
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  IF COALESCE(auth.role(), 'service_role') <> 'service_role' THEN
    RAISE EXCEPTION 'storage janitor functions are service-role only'
      USING ERRCODE = '42501';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. WHICH PROOFS HAVE EXPIRED
-- ---------------------------------------------------------------------------
-- Age is measured from `transaction_date` - when the sale happened - not from
-- `created_at` or `payment_confirmed_at`. The window is a dispute window, and
-- what a customer disputes is the sale.
--
-- LEFT JOIN with a COALESCE rather than an inner join: onboarding blocks until
-- a `shop_settings` row exists, so in practice every transaction has one, but a
-- janitor that silently skipped rows whose settings were missing would fail in
-- the one direction nobody would notice - by never deleting anything.
-- plpgsql rather than sql so the guard is a statement that runs before the
-- query, not a predicate the planner is free to reorder or fold away.
CREATE OR REPLACE FUNCTION public.expired_payment_proofs(p_limit INTEGER DEFAULT 1000)
RETURNS TABLE (transaction_id UUID, object_path TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.assert_janitor_caller();

  RETURN QUERY
  SELECT t.id, t.payment_proof_path
  FROM public.transactions t
  LEFT JOIN public.shop_settings s ON s.user_id = t.user_id
  WHERE t.payment_proof_path IS NOT NULL
    AND t.transaction_date
        < NOW() - (COALESCE(s.payment_proof_retention_days, 90) || ' days')::INTERVAL
  ORDER BY t.transaction_date
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.expired_payment_proofs(INTEGER) IS
  'Proofs past their shop retention window. Service role only. Read-only: the caller deletes the object, then calls clear_payment_proof_paths.';

-- ---------------------------------------------------------------------------
-- 4. WHAT IS STILL REFERENCED
-- ---------------------------------------------------------------------------
-- The other half of the janitor's job. Objects are orphaned whenever a delete
-- fails after the row that named them is already gone - both delete paths drop
-- their errors on purpose (`RemovePaymentProof`, `ProductFormScreen.
-- _releaseUnusedImages`) because a row pointing at a missing file is worse than
-- a file nobody points at. That trade is right, and it leaks.
--
-- `products.image_url` needs normalising and `transactions.payment_proof_path`
-- does not. The proof column is new, so every value in it is an object path.
-- The image column predates 20260730000001 and can still hold a full public URL
-- (rewritten there, but a row written by an older client can reappear) or an
-- absolute device path from the retired local storage.
--
-- Anything that is not a path into *this* bucket is excluded rather than
-- normalised. Being conservative is the whole point: a path missing from this
-- set gets deleted, so the failure mode of guessing wrong is destroying a live
-- photo. A device path names no object here and cannot orphan one.
CREATE OR REPLACE FUNCTION public.referenced_object_paths(p_bucket TEXT)
RETURNS TABLE (object_path TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
BEGIN
  PERFORM public.assert_janitor_caller();

  RETURN QUERY
  SELECT DISTINCT path
  FROM (
    SELECT t.payment_proof_path AS path
    FROM public.transactions t
    WHERE p_bucket = 'payment-proofs'
      AND t.payment_proof_path IS NOT NULL

    UNION ALL

    -- Already an object path: no scheme, not absolute, and at least one
    -- separator, matching the shape `<user_id>/<product_id>/<timestamp>.jpg`.
    SELECT p.image_url
    FROM public.products p
    WHERE p_bucket = 'product-images'
      AND p.image_url IS NOT NULL
      AND p.image_url <> ''
      AND p.image_url NOT LIKE '/%'
      AND p.image_url NOT LIKE '%://%'
      AND p.image_url LIKE '%/%'

    UNION ALL

    -- A legacy full URL into this bucket. Same extraction as
    -- 20260730000001, including the query-string trim, so a row that migration
    -- has not reached is still recognised as live rather than collected.
    SELECT split_part(
             split_part(p.image_url, '/object/public/product-images/', 2),
             '?',
             1
           )
    FROM public.products p
    WHERE p_bucket = 'product-images'
      AND p.image_url LIKE '%/object/public/product-images/%'
  ) refs
  WHERE path IS NOT NULL
    AND path <> '';
END;
$$;

COMMENT ON FUNCTION public.referenced_object_paths(TEXT) IS
  'Every object path a row still points at, for the named bucket. Service role only. The janitor deletes what is NOT in here.';

-- ---------------------------------------------------------------------------
-- 4b. WHAT NOTHING REFERENCES
-- ---------------------------------------------------------------------------
-- The diff itself, done here rather than in the Edge Function.
--
-- `storage.protect_delete()` blocks DELETE on `storage.objects`, but SELECT is
-- ordinary - so the bucket's contents are one indexed query away, and the
-- alternative was walking the Storage list API three levels deep
-- (`<user_id>/<owner_id>/<file>`), paginated, once per shop. That is hundreds of
-- round trips to answer a question Postgres can answer with a join.
--
-- `p_min_age` is the safety interval, and it is the only thing standing between
-- this function and a live photo. An upload writes the object *before* the row
-- that names it - `ProductImagePicker` uploads on pick, `ProductFormScreen`
-- writes the row on save - so an object with no referencing row is the normal
-- state of affairs for as long as someone has the form open. A default of 24
-- hours is far past any plausible editing session.
--
-- The caller still has to delete through the Storage API; this only says what.
CREATE OR REPLACE FUNCTION public.orphaned_object_paths(
  p_bucket TEXT,
  p_min_age INTERVAL DEFAULT INTERVAL '24 hours',
  p_limit INTEGER DEFAULT 1000
)
RETURNS TABLE (object_path TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, auth
AS $$
BEGIN
  PERFORM public.assert_janitor_caller();

  RETURN QUERY
  SELECT o.name
  FROM storage.objects o
  WHERE o.bucket_id = p_bucket
    AND o.created_at < NOW() - p_min_age
    AND NOT EXISTS (
      SELECT 1
      FROM public.referenced_object_paths(p_bucket) r
      WHERE r.object_path = o.name
    )
  ORDER BY o.created_at
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) IS
  'Objects in the bucket that no row points at and are older than p_min_age. Service role only.';

-- ---------------------------------------------------------------------------
-- 5. FORGETTING A DELETED PROOF
-- ---------------------------------------------------------------------------
-- Object first, row second - the opposite order to `RemovePaymentProof`, and
-- deliberately so.
--
-- That use case is a human saying "this photo is wrong", where a row still
-- naming a deleted object would show a broken image on a sale that is otherwise
-- fine; it clears the column first and lets the object leak. Here the object is
-- being deleted because it expired, and if this call is what fails, the proof is
-- gone while the column still names it - so the next run finds the same row,
-- asks storage to delete an object that is already gone, and clears the column
-- then. Retrying is free; a column cleared before a delete that never happened
-- would strand the object with nothing left to find it by.
CREATE OR REPLACE FUNCTION public.clear_payment_proof_paths(p_transaction_ids UUID[])
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  affected INTEGER;
BEGIN
  PERFORM public.assert_janitor_caller();

  UPDATE public.transactions
  SET payment_proof_path = NULL,
      updated_at = NOW()
  WHERE id = ANY(p_transaction_ids)
    AND payment_proof_path IS NOT NULL;

  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

COMMENT ON FUNCTION public.clear_payment_proof_paths(UUID[]) IS
  'Nulls payment_proof_path after the object is gone. Service role only. Safe to retry.';

-- ---------------------------------------------------------------------------
-- 6. GRANTS
-- ---------------------------------------------------------------------------
-- Belt to the guard's braces - see section 2 for why one is not enough.
REVOKE ALL ON FUNCTION public.expired_payment_proofs(INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.referenced_object_paths(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.clear_payment_proof_paths(UUID[]) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.expired_payment_proofs(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.referenced_object_paths(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.clear_payment_proof_paths(UUID[]) TO service_role;
