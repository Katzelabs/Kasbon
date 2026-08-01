-- =============================================================================
-- KASBON POS - Run storage-janitor once a day
-- =============================================================================
-- The policy lives in 20260801000001 and the deleting lives in the
-- `storage-janitor` Edge Function. This is only the alarm clock.
--
-- pg_cron cannot make an HTTP request, so the job calls pg_net, which performs
-- the request from a background worker and records the response in
-- `net._http_response`. That indirection is why this is three objects rather
-- than one line.
--
-- ## The secrets are not in this file, on purpose
--
-- The function URL and the service key differ per environment, and the service
-- key is a credential that bypasses RLS for the whole project - committing
-- either to a migration would put a production key in git and apply the wrong
-- one to every other environment. They are read from Vault at call time, and
-- creating them is a deployment step (see below), not a schema change.
--
-- A missing secret is therefore the *normal* state of a fresh `db reset` or a
-- developer's local stack, and must not be an error. The function returns
-- quietly in that case, so nobody is trained to ignore a daily failure.
--
-- ## Deployment
--
--   supabase functions deploy storage-janitor
--
--   select vault.create_secret(
--     'https://<project-ref>.supabase.co/functions/v1/storage-janitor',
--     'storage_janitor_url');
--   select vault.create_secret('<service-role-key>', 'storage_janitor_service_key');
--
-- Then verify without deleting anything:
--
--   select public.run_storage_janitor(dry_run => true);
--   select * from net._http_response order by created desc limit 1;
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ---------------------------------------------------------------------------
-- 1. THE CALL
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.run_storage_janitor(dry_run BOOLEAN DEFAULT FALSE)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
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
$$;

COMMENT ON FUNCTION public.run_storage_janitor(BOOLEAN) IS
  'Fires the storage-janitor Edge Function via pg_net. Returns a net._http_response id, or null if Vault is not configured.';

-- Cron runs this as the job owner, not through PostgREST - so no role needs
-- execute, and `authenticated` picking up the default privilege from
-- 20260725000001 would let any signed-in user trigger a project-wide sweep.
REVOKE ALL ON FUNCTION public.run_storage_janitor(BOOLEAN) FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. THE SCHEDULE
-- ---------------------------------------------------------------------------
-- 20:00 UTC is 03:00 WIB - the middle of the night for every shop this app is
-- built for, and comfortably clear of the evening trade.
--
-- Daily rather than hourly because neither job is urgent: a proof that expired
-- this morning costs 300 KB to keep until tomorrow, and 24 hourly runs against
-- 500k free invocations would spend budget to save nothing.
--
-- Unscheduled by name first so re-running this migration replaces the job
-- rather than duplicating it. `cron.unschedule(name)` raises when the job does
-- not exist, so it is driven off the table instead.
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
