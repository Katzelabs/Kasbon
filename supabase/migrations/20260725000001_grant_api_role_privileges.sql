-- Newer Supabase CLI versions no longer ship default privileges for the API
-- roles on the public schema, so every table/sequence/function needs explicit
-- grants or PostgREST returns 403 "permission denied". RLS still scopes rows
-- per user; anon gets no table access because authentication is mandatory.

grant usage on schema public to anon, authenticated, service_role;

grant all on all tables in schema public to authenticated, service_role;
grant all on all sequences in schema public to authenticated, service_role;
grant execute on all functions in schema public to authenticated, service_role;

-- Cover objects created by future migrations (which run as postgres)
alter default privileges in schema public
  grant all on tables to authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to authenticated, service_role;
