-- =============================================================================
-- KASBON POS - Two things the new invariant test found
-- =============================================================================
-- `supabase/tests/security_invariants.sql` asserts, among other things, that
-- every function in `public` pins its search_path. Written to stop
-- handle_updated_at (fixed in 20260801000003) from recurring, it failed on its
-- first run against two things that were already there. Which is the point of a
-- structural check: it does not know what it was written for.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. pg_trgm belongs in `extensions`
-- ---------------------------------------------------------------------------
-- `CREATE EXTENSION IF NOT EXISTS pg_trgm` in 20260801000004 defaulted to the
-- current schema, which put ~30 C functions - similarity, show_trgm, the whole
-- gtrgm_* and gin_trgm_* family - into `public`. Every other extension on this
-- project is in `extensions`: pg_net, pgcrypto, uuid-ossp, pg_stat_statements.
-- pg_trgm was the only one out of step, purely because the CREATE did not say
-- otherwise.
--
-- This is mostly hygiene - `public` is the schema PostgREST exposes, and the
-- fewer things in it that are not the app's own API, the better - but it also
-- makes the search_path invariant meaningful. Extension-owned C functions have
-- no proconfig and never will; leaving them in public would have meant either a
-- permanently failing check or one special-cased into uselessness.
--
-- ALTER rather than DROP/CREATE: the two trigram indexes from 20260801000004
-- depend on the operator classes and follow the extension across. Dropping it
-- would take them with it.
ALTER EXTENSION pg_trgm SET SCHEMA extensions;

-- ---------------------------------------------------------------------------
-- 2. assert_janitor_caller pins its search_path
-- ---------------------------------------------------------------------------
-- The genuine finding. Every other function written for this schema sets an
-- empty search_path; this one, added in 20260801000001, did not - and it is the
-- function that decides whether a caller is allowed to read across every
-- tenant's storage.
--
-- The exposure is small: it is SECURITY INVOKER, so it carries no privilege of
-- its own, and its body resolves `auth.role()` under an explicit schema. But it
-- is called from inside four SECURITY DEFINER functions as their only
-- authorisation check, which makes it precisely the wrong place to leave name
-- resolution up to whatever search_path the caller happens to have.
--
-- Body unchanged.
CREATE OR REPLACE FUNCTION public.assert_janitor_caller()
RETURNS VOID
LANGUAGE plpgsql
STABLE
SET search_path = ''
AS $$
BEGIN
  IF COALESCE(auth.role(), 'service_role') <> 'service_role' THEN
    RAISE EXCEPTION 'storage janitor functions are service-role only'
      USING ERRCODE = '42501';
  END IF;
END;
$$;
