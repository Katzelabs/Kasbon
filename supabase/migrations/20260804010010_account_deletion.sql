-- =============================================================================
-- KASBON POS - Account deletion: the one query it needs from Postgres
-- =============================================================================
-- Both stores block submission without it: Play wants an in-app route and a
-- web-reachable one, Apple wants in-app deletion from anything that creates
-- accounts.
--
-- Almost all of the work is a cascade nobody has to write. Every tenant table
-- keys off `auth.users(id) ON DELETE CASCADE` (010002), so removing the auth row
-- takes user_profiles, shop_settings, categories, products, transactions and
-- transaction_items with it in one statement.
--
-- Storage is the exception, and the only reason this file exists. Objects live in
-- `storage.objects`, which has no foreign key to `auth.users` - a deleted
-- account's photos would simply stay in the buckets. The janitor's orphan sweep
-- (010009) would eventually collect them, but "eventually" is 24h+ and a
-- data-deletion promise should not be settled by a nightly cron.
--
-- ## Order is load-bearing: the auth row first, storage second
--
-- If the auth delete fails, nothing has been destroyed and the user retries. If a
-- storage batch fails afterwards, the rows are already gone, so those objects are
-- orphans and `storage-janitor` sweeps them within 24h - the failure degrades to
-- the slow path instead of leaking. The reverse order deletes photos out from
-- under an account that still exists.
--
-- ## Auth here is the opposite of the janitor's
--
-- The janitor must be callable by cron and nobody else, so it compares the
-- presented credential against the service key. The `delete-account` function is
-- called by every user and must act only on themselves, so `verify_jwt` is off
-- (see config.toml) and it verifies the caller's token with `auth.getUser()`,
-- deriving the uid from that. There is no uid parameter, so there is nothing to
-- tamper with - and a service key presented there is rejected, since it
-- identifies no user.
--
-- The query below is the service-role half: the function calls it *after*
-- establishing who the caller is.
--
--   supabase functions deploy delete-account   # no Vault secrets, unlike the janitor
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. WHO MAY ASK
-- ---------------------------------------------------------------------------
-- The same check as `assert_janitor_caller()` (010009), under a name that does
-- not claim to be about the janitor. Both exist for the reason that file records
-- at length: 010003 grants EXECUTE on every new `public` function to
-- `authenticated`, so a REVOKE is a statement about today and this guard is a
-- statement about the function.
CREATE OR REPLACE FUNCTION public.assert_service_role_caller()
 RETURNS void
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'auth'
AS $function$
BEGIN
  IF COALESCE(auth.role(), 'service_role') <> 'service_role' THEN
    RAISE EXCEPTION 'this function is service-role only'
      USING ERRCODE = '42501';
  END IF;
END;
$function$;

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
-- pattern would also match a different uuid that happened to share a prefix. No
-- uuid is a prefix of another in practice, but the pattern is one character away
-- from being right and this one deletes files.
--
-- p_limit is a page size, not a cap on what gets deleted, and paging is keyset
-- rather than OFFSET. That matters because the caller reads every page *before*
-- it deletes anything - so nothing shifts underneath the cursor, but also nothing
-- shrinks, and a plain LIMIT with no cursor would hand back the same hundred
-- names forever. `p_after` is the last name of the previous page; `name` is unique
-- within a bucket and the order is on it, so the comparison is a total order with
-- no ties to skip past.
CREATE OR REPLACE FUNCTION public.account_object_paths(p_bucket text, p_user_id uuid, p_limit integer DEFAULT 1000, p_after text DEFAULT ''::text)
 RETURNS TABLE(object_path text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'auth'
AS $function$
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
$function$;

COMMENT ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) IS
  'One keyset page of the objects under an account''s folder in the bucket, referenced or not. Service role only. Read-only: the caller deletes through the Storage API.';

-- ---------------------------------------------------------------------------
-- 3. GRANTS
-- ---------------------------------------------------------------------------
-- `assert_service_role_caller` is deliberately not revoked, matching
-- `assert_janitor_caller`: it reads nothing and returns nothing.
REVOKE ALL ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.account_object_paths(TEXT, UUID, INTEGER, TEXT) TO service_role;
