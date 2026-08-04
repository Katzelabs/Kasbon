-- =============================================================================
-- KASBON POS - Storage retention: what to delete, and the alarm clock
-- =============================================================================
-- Storage is the quota that runs out first. 1 GB on the free tier, against
-- ~150 KB per proof x 50 QRIS sales/day = ~7.5 MB/day, and until this existed
-- nothing deleted anything. Retention bounds the total but does not make it
-- small: 50 sales/day x 90 days is ~675 MB, most of a free-tier GB for one shop.
-- The window (shop_settings.payment_proof_retention_days, 010002) is the dial,
-- and a busy shop belongs nearer 30 days than 90.
--
-- ## Postgres decides what, the Edge Function only does I/O
--
-- `storage.protect_delete()` is a BEFORE DELETE trigger on `storage.objects` that
-- raises 'Direct deletion from storage tables is not allowed. Use the Storage API
-- instead.' So removing an object has to be an HTTP call, which means the
-- `storage-janitor` Edge Function. What lives here is the *policy* - which proofs
-- have expired, and which objects nothing references - because those are
-- questions about this schema, and they are testable with plain psql.
--
-- Two jobs: retention (proofs past their shop's window) and orphans (objects in
-- either bucket that no row points at and that are more than 24h old). The second
-- exists because both app delete paths drop their errors on purpose - a row
-- pointing at a missing file is worse than a file nobody points at - so leaks are
-- by design and this is the other half of that trade.
--
-- ## Every function here is service-role only, enforced twice
--
-- These read across all tenants, which is the exact opposite of everything else
-- in this schema. Both mechanisms are needed:
--
--   * The GRANTs. On their own they are not enough, because 010003 sets ALTER
--     DEFAULT PRIVILEGES so that *every* new function in `public` is executable
--     by `authenticated`. A REVOKE here is undone the moment someone adds another
--     blanket grant, and that default exists because a blanket grant was already
--     needed once.
--   * `assert_janitor_caller()`, called first in each body. It does not care what
--     the grants say. If a future migration re-opens execute to `authenticated`,
--     the worst outcome is an error rather than one shop reading another's
--     transaction ids.
--
-- ## Deployment is not automatic
--
-- The schedule at the bottom ships here, but it no-ops with a NOTICE until two
-- Vault secrets exist - they hold a service key and a per-environment URL, so
-- they cannot live in a migration. One script does the whole sequence:
--
--   ./supabase/scripts/deploy-storage-janitor.sh --linked   # or --local
--
-- Prefer it to doing this by hand: `vault.create_secret` raises on a name that
-- already exists, so the manual sequence works exactly once and fails on every
-- rotation.
--
-- Note that `functions deploy` and the secrets are genuinely independent, and a
-- project can sit in the state where the function is deployed, the cron job is
-- scheduled and active, and the sweep still runs nightly doing nothing at all -
-- because `run_storage_janitor` finds no secrets and returns early. Everything
-- an inspection would look at appears healthy. The only proof is a dry run that
-- comes back 200, which is why the script ends with one.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. WHO MAY ASK
-- ---------------------------------------------------------------------------
-- `auth.role()` reads the JWT the request arrived with; the Edge Function calls
-- with the service key, so it sees 'service_role'. A direct psql session has no
-- JWT at all, hence the null branch - which is how the invariant tests reach
-- these, and is unreachable through PostgREST, which always presents a role.
--
-- It pins an empty search_path. This is SECURITY INVOKER so it carries no
-- privilege of its own, but it is called from inside four SECURITY DEFINER
-- functions as their only authorisation check, which makes it precisely the wrong
-- place to leave name resolution up to the caller's search_path.
CREATE OR REPLACE FUNCTION public.assert_janitor_caller()
 RETURNS void
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
BEGIN
  IF COALESCE(auth.role(), 'service_role') <> 'service_role' THEN
    RAISE EXCEPTION 'storage janitor functions are service-role only'
      USING ERRCODE = '42501';
  END IF;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2. WHICH PROOFS HAVE EXPIRED
-- ---------------------------------------------------------------------------
-- Age is measured from `transaction_date` - when the sale happened - not from
-- `created_at` or `payment_confirmed_at`. The window is a dispute window, and
-- what a customer disputes is the sale.
--
-- LEFT JOIN with a COALESCE rather than an inner join: onboarding blocks until a
-- `shop_settings` row exists, so in practice every transaction has one, but a
-- janitor that silently skipped rows whose settings were missing would fail in
-- the one direction nobody would notice - by never deleting anything.
--
-- plpgsql rather than sql, so the guard is a statement that runs before the
-- query, not a predicate the planner is free to reorder or fold away.
CREATE OR REPLACE FUNCTION public.expired_payment_proofs(p_limit integer DEFAULT 1000)
 RETURNS TABLE(transaction_id uuid, object_path text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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
$function$;

COMMENT ON FUNCTION public.expired_payment_proofs(INTEGER) IS
  'Proofs past their shop retention window. Service role only. Read-only: the caller deletes the object, then calls clear_payment_proof_paths.';

-- ---------------------------------------------------------------------------
-- 3. WHAT IS STILL REFERENCED
-- ---------------------------------------------------------------------------
-- `products.image_url` needs normalising and `transactions.payment_proof_path`
-- does not: the proof column has only ever held object paths, while the image
-- column can still hold a full public URL written by an older client, or an
-- absolute device path from the retired local storage.
--
-- Anything that is not a path into *this* bucket is excluded rather than
-- normalised. Being conservative is the whole point: a path missing from this set
-- gets deleted, so the failure mode of guessing wrong is destroying a live photo.
-- A device path names no object here and cannot orphan one.
CREATE OR REPLACE FUNCTION public.referenced_object_paths(p_bucket text)
 RETURNS TABLE(object_path text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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

    -- A legacy full URL into this bucket, as an older client could still write.
    -- Same extraction the app applies on read, query-string trim included, so
    -- such a row is recognised as live rather than collected.
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
$function$;

COMMENT ON FUNCTION public.referenced_object_paths(TEXT) IS
  'Every object path a row still points at, for the named bucket. Service role only. The janitor deletes what is NOT in here.';

-- ---------------------------------------------------------------------------
-- 4. WHAT NOTHING REFERENCES
-- ---------------------------------------------------------------------------
-- The diff itself, done here rather than in the Edge Function. SELECT on
-- `storage.objects` is ordinary - only DELETE is blocked - so the bucket's
-- contents are one indexed query away. The alternative was walking the Storage
-- list API three levels deep, paginated, once per shop: hundreds of round trips
-- to answer a question Postgres can answer with a join.
--
-- `p_min_age` is the only thing standing between this function and a live photo.
-- An upload writes the object *before* the row that names it - ProductImagePicker
-- uploads on pick, ProductFormScreen writes the row on save - so an object with
-- no referencing row is the normal state of affairs for as long as someone has
-- the form open. 24 hours is far past any plausible editing session.
CREATE OR REPLACE FUNCTION public.orphaned_object_paths(p_bucket text, p_min_age interval DEFAULT '24:00:00'::interval, p_limit integer DEFAULT 1000)
 RETURNS TABLE(object_path text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'storage', 'auth'
AS $function$
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
$function$;

COMMENT ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) IS
  'Objects in the bucket that no row points at and are older than p_min_age. Service role only.';

-- ---------------------------------------------------------------------------
-- 5. FORGETTING A DELETED PROOF
-- ---------------------------------------------------------------------------
-- Object first, row second - the opposite order to `RemovePaymentProof`, and
-- deliberately so.
--
-- That use case is a human saying "this photo is wrong", where a row still naming
-- a deleted object would show a broken image on a sale that is otherwise fine; it
-- clears the column first and lets the object leak. Here the object is being
-- deleted because it expired, and if this call is what fails, the proof is gone
-- while the column still names it - so the next run finds the same row, asks
-- storage to delete an object that is already gone, and clears the column then.
-- Retrying is free; a column cleared before a delete that never happened would
-- strand the object with nothing left to find it by.
CREATE OR REPLACE FUNCTION public.clear_payment_proof_paths(p_transaction_ids uuid[])
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth'
AS $function$
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
$function$;

COMMENT ON FUNCTION public.clear_payment_proof_paths(UUID[]) IS
  'Nulls payment_proof_path after the object is gone. Service role only. Safe to retry.';

-- ---------------------------------------------------------------------------
-- 6. GRANTS
-- ---------------------------------------------------------------------------
-- Belt to the guard's braces - see the header for why one is not enough.
-- `assert_janitor_caller` is deliberately not revoked: it reads nothing and
-- returns nothing, so a signed-in user calling it learns only that they are not
-- the service role.

REVOKE ALL ON FUNCTION public.expired_payment_proofs(INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.referenced_object_paths(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.clear_payment_proof_paths(UUID[]) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.expired_payment_proofs(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.referenced_object_paths(TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.orphaned_object_paths(TEXT, INTERVAL, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.clear_payment_proof_paths(UUID[]) TO service_role;

-- ---------------------------------------------------------------------------
-- 7. THE CALL
-- ---------------------------------------------------------------------------
-- pg_cron cannot make an HTTP request, so the job calls pg_net, which performs
-- the request from a background worker and records the response in
-- `net._http_response`. That indirection is why this is three objects rather than
-- one line.
--
-- A missing secret is the *normal* state of a fresh `db reset` or a developer's
-- local stack, and must not be an error - so this returns quietly and nobody is
-- trained to ignore a daily failure.
--
-- The 60s timeout is generous because the sweep is O(objects) and a project that
-- has gone unswept for a while has a long first run. A timeout loses the
-- *report*, not the work: pg_net stops waiting, the function keeps running, and
-- every operation it performs is idempotent and batched.
CREATE OR REPLACE FUNCTION public.run_storage_janitor(dry_run boolean DEFAULT false)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'vault'
AS $function$
DECLARE
  janitor_url  TEXT;
  service_key  TEXT;
  request_id   BIGINT;
BEGIN
  SELECT decrypted_secret INTO janitor_url
  FROM vault.decrypted_secrets WHERE name = 'storage_janitor_url';

  SELECT decrypted_secret INTO service_key
  FROM vault.decrypted_secrets WHERE name = 'storage_janitor_service_key';

  -- Not configured. Expected locally and on any environment that has not been
  -- through the deployment steps above; see the header for why this is a notice
  -- and not an exception.
  IF janitor_url IS NULL OR service_key IS NULL THEN
    RAISE NOTICE 'storage-janitor not scheduled: vault secrets storage_janitor_url / storage_janitor_service_key are missing';
    RETURN NULL;
  END IF;

  SELECT net.http_post(
    url := janitor_url || CASE WHEN dry_run THEN '?dry_run=true' ELSE '' END,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || service_key
    ),
    body := '{}'::JSONB,
    -- Generous, because the sweep is O(objects) and a project that has gone
    -- unswept for a while has a long first run.
    --
    -- A timeout here loses the *report*, not the work: pg_net stops waiting,
    -- but the function keeps running, and every operation it performs is
    -- idempotent and batched. The next night picks up whatever was left.
    timeout_milliseconds := 60000
  ) INTO request_id;

  RETURN request_id;
END;
$function$;

COMMENT ON FUNCTION public.run_storage_janitor(BOOLEAN) IS
  'Fires the storage-janitor Edge Function via pg_net. Returns a net._http_response id, or null if Vault is not configured.';

-- Cron runs this as the job owner, not through PostgREST - so no role needs
-- execute, and `authenticated` picking up the default privilege from 010003 would
-- let any signed-in user trigger a project-wide sweep.
REVOKE ALL ON FUNCTION public.run_storage_janitor(BOOLEAN) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. THE SCHEDULE
-- ---------------------------------------------------------------------------
-- 20:00 UTC is 03:00 WIB - the middle of the night for every shop this app is
-- built for, and comfortably clear of the evening trade.
--
-- Daily rather than hourly because neither job is urgent: a proof that expired
-- this morning costs 150 KB to keep until tomorrow, and 24 hourly runs against
-- 500k free invocations would spend budget to save nothing.
--
-- Unscheduled by name first so re-running this replaces the job rather than
-- duplicating it. `cron.unschedule(name)` raises when the job does not exist, so
-- it is driven off the table instead.
DO $$
BEGIN
  PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'storage-janitor-daily';
END;
$$;

SELECT cron.schedule(
  'storage-janitor-daily',
  '0 20 * * *',
  $$SELECT public.run_storage_janitor()$$
);
