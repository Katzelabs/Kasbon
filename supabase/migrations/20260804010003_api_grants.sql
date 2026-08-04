-- =============================================================================
-- KASBON POS - Privileges for the API roles
-- =============================================================================
-- Newer Supabase CLI versions no longer ship default privileges for the API
-- roles on `public`, so every table, sequence and function needs an explicit
-- grant or PostgREST answers 403 "permission denied". RLS still scopes rows per
-- user; `anon` gets no table access at all, because authentication is mandatory.
--
-- ## Why this file sits here and not first
--
-- The two halves do different jobs and the split matters:
--
--   * `GRANT ... ON ALL TABLES` is a statement about the tables that exist right
--     now. It has to run *after* 010002, or it grants on nothing.
--   * `ALTER DEFAULT PRIVILEGES` is a statement about the future. It has to run
--     *before* the RPC files (010005 and later), which is where every remaining
--     function in this schema is created.
--
-- Sitting between the tables and the functions is the only position that lets
-- both mean what they say.
--
-- ## The thing to know before adding a function
--
-- The default privilege below grants EXECUTE on *every* new function in `public`
-- to `authenticated`. That is the right default for a report RPC and exactly
-- wrong for anything that reads across tenants - which is why the janitor
-- functions (010009) and the account-deletion query (010010) each REVOKE it
-- back, and then do not trust the REVOKE either: they re-check the caller inside
-- the function body. A cross-tenant read that is private only because of a grant
-- is one blanket migration away from being public.
-- =============================================================================

grant usage on schema public to anon, authenticated, service_role;

grant all     on all tables    in schema public to authenticated, service_role;
grant all     on all sequences in schema public to authenticated, service_role;
grant execute on all functions  in schema public to authenticated, service_role;

-- Covers objects created by every migration after this one, which run as
-- postgres. Scoped to no role explicitly, so it applies to the current role -
-- and migrations are applied as postgres, which is the role that creates them.
alter default privileges in schema public
  grant all on tables to authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to authenticated, service_role;
