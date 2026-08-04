-- =============================================================================
-- KASBON POS - Account deletion: the one query it needs from Postgres
-- =============================================================================
-- Google Play requires an in-app route to delete the account and a
-- web-reachable one; Apple requires in-app deletion from any app that creates
-- accounts. Until now there was no delete path at all.
--
-- Almost all of the work is a cascade nobody has to write. Every tenant table
-- keys off `auth.users(id) ON DELETE CASCADE` (see 20260207070429), so removing
-- the auth row takes user_profiles, shop_settings, categories, products,
-- transactions and transaction_items with it in one statement.
--
-- Storage is the exception, and the only reason this migration exists. Objects
-- live in `storage.objects`, which has no foreign key to `auth.users` - a
-- deleted account's product photos and payment proofs would simply stay in the
-- buckets. `storage-janitor`'s orphan sweep would eventually collect them
-- (nothing references them once the rows are gone), but "eventually" is 24h+
-- and a data-deletion promise should not be settled by a nightly cron.
--
-- So the Edge Function deletes them explicitly, and this is the query that
-- tells it what to delete. Same split as the janitor: Postgres decides *what*,
-- the function only does the I/O, because `storage.protect_delete()` blocks a
-- direct DELETE on `storage.objects` and removal has to be an HTTP call.
--
-- The tenant key in both buckets is the first path segment
-- (`<user_id>/<product_id>/<file>`), enforced by the bucket policies with
-- `storage.foldername()`. That is what makes one prefix query sufficient here.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. WHO MAY ASK
-- ---------------------------------------------------------------------------
-- The same check as `assert_janitor_caller()` in 20260801000001, under a name
-- that does not claim to be about the janitor. Both are needed for the same
-- reason that one records at length: 20260725000001 sets ALTER DEFAULT
-- PRIVILEGES granting EXECUTE on every new `public` function to
-- `authenticated`, so a REVOKE is a statement about today and this guard is a
-- statement about the function. A cross-tenant read that is private only
-- because of a grant is one blanket migration away from being public.
--
-- `auth.role()` reads the JWT the request arrived with. The Edge Function calls
-- with the service key, so it sees 'service_role'; a direct psql session has no
-- JWT at all, hence the null branch, which is how the invariant tests reach
-- these.
CREATE OR REPLACE FUNCTION public.assert_service_role_caller()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = public, auth
AS $$
BEGIN
  IF COALESCE(auth.role(), 'service_role') <> 'service_role' THEN
    RAISE EXCEPTION 'this function is service-role only'
      USING ERRCODE = '42501';
  END IF;
END;
$$;

COMMENT ON FUNCTION public.assert_service_role_caller() IS
  'Raises unless the caller presents the service role. Guard for functions that read across tenants.';

-- ---------------------------------------------------------------------------
-- 2. EVERYTHING ONE ACCOUNT OWNS IN A BUCKET
-- ---------------------------------------------------------------------------
-- Prefix match on the tenant folder, not a join against the rows that name the
-- objects. That difference is deliberate and it is the whole point:
-- `referenced_object_paths` would miss exactly the objects an account deletion
-- must not leave behind - an upload whose form was never saved, a proof whose
-- column was cleared, anything the janitor has not swept yet. The account is
-- being erased, so what is wanted is the folder, referenced or not.
--
-- `p_user_id || '/'` and not `LIKE p_user_id || '%'`: without the separator the
-- pattern would also match a different uuid that happened to share a prefix.
-- No uuid is a prefix of another in practice, but the pattern is one character
-- away from being right and this one deletes files.
--
-- The `LIKE` is against an unindexed `name` on a table that stays small for
-- this project; if it ever stops being small, `storage.objects` already indexes
-- `(bucket_id, name)` and this is a left-anchored prefix, so it stays cheap.
--
-- p_limit is a page size, not a cap on what gets deleted, and paging is keyset
-- rather than OFFSET. That matters because the caller reads every page
-- *before* it deletes anything - so nothing shifts underneath the cursor, but
-- also nothing shrinks, and a plain `LIMIT` with no cursor would hand back the
-- same hundred names forever. `p_after` is the last name of the previous page;
-- `name` is unique within a bucket and the order is on it, so the comparison is
-- a total order with no ties to skip past.
CREATE OR REPLACE FUNCTION public.account_object_paths(
  p_bucket TEXT,
  p_user_id UUID,
  p_limit INTEGER DEFAULT 1000,
  p_after TEXT DEFAULT ''
)
RETURNS TABLE (object_path TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage, auth
AS $$
BEGIN
  PERFORM public.assert_service_role_caller();

  RETURN QUERY
  SELECT o.name
  FROM storage.objects o
  WHERE o.bucket_id = p_bucket
    AND o.name LIKE p_user_id::TEXT || '/%'
    AND o.name > p_after
  ORDER BY o.name
  LIMIT p_limit;
END;
$$;

COMMENT ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) IS
  'One keyset page of the objects under an account''s folder in the bucket, referenced or not. Service role only. Read-only: the caller deletes through the Storage API.';

-- ---------------------------------------------------------------------------
-- 3. GRANTS
-- ---------------------------------------------------------------------------
-- Belt to the guard's braces - section 1 for why one is not enough.
--
-- `assert_service_role_caller` is deliberately not revoked, matching
-- `assert_janitor_caller`: it reads nothing and returns nothing, so a signed-in
-- user calling it learns only that they are not the service role.
REVOKE ALL ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) TO service_role;
