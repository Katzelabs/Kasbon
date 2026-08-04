-- =============================================================================
-- KASBON POS - Extensions
-- =============================================================================
-- Only the two this project creates. pg_net, pgcrypto, uuid-ossp,
-- pg_stat_statements and supabase_vault are already present on a Supabase
-- database and are not ours to declare.
--
-- First, because everything after it depends on one or the other: the trigram
-- indexes in 010002 need pg_trgm's operator classes, and the schedule in 010009
-- needs pg_cron.
-- =============================================================================

-- `WITH SCHEMA extensions`, and the clause is the whole point.
--
-- A bare `CREATE EXTENSION pg_trgm` installs into the current schema, which put
-- ~30 C functions - similarity, show_trgm, the whole gtrgm_* and gin_trgm_*
-- family - into `public`. Every other extension here lives in `extensions`, and
-- `public` is the schema PostgREST exposes: the fewer things in it that are not
-- this app's own API, the better.
--
-- It also keeps the search_path invariant in
-- `supabase/tests/security_invariants.sql` meaningful. That check asserts every
-- function in `public` pins its search_path; extension-owned C functions have no
-- proconfig and never will, so leaving pg_trgm there would have meant either a
-- permanently failing check or one special-cased into uselessness.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

-- No schema clause, deliberately: pg_cron is not relocatable and its control
-- file installs it into `pg_catalog`. Asking for `extensions` here fails.
CREATE EXTENSION IF NOT EXISTS pg_cron;
