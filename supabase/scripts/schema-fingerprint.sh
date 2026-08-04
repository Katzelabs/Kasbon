#!/usr/bin/env bash
#
# Emit a deterministic, diffable description of everything this project's
# migrations create. Two migration sets that produce the same fingerprint are
# the same database.
#
# Why this exists: the 20 chronological migrations were collapsed into ~10
# topical baseline files (August 2026, before the first production push). The
# only way to make that safe was to prove the new set builds a byte-identical
# schema rather than to read 3469 lines and hope. That proof is:
#
#     git stash                                   # or: git checkout <pre-baseline>
#     supabase db reset
#     ./supabase/scripts/schema-fingerprint.sh > /tmp/before.txt
#     git stash pop                               # baseline files back
#     supabase db reset
#     ./supabase/scripts/schema-fingerprint.sh > /tmp/after.txt
#     diff /tmp/before.txt /tmp/after.txt         # must be empty
#
# It stays in the tree because the same proof is what makes any future
# refactor of the migration files safe, and because a non-empty diff names the
# object that changed - which reading cannot do.
#
# Deliberately NOT just `pg_dump --schema-only`:
#
#   - pg_dump omits data, and three things here are data: the two rows in
#     `storage.buckets`, the `cron.job` row that schedules the janitor, and
#     the default ACLs in `pg_default_acl`. All three are load-bearing.
#   - pg_dump interleaves objects by dependency, so an unrelated reordering
#     produces a large diff that hides the real one. Explicit ORDER BY per
#     object class keeps a one-line change a one-line diff.
#
# Note on function bodies: section 7 compares `pg_get_functiondef`, which
# preserves the body verbatim - including whitespace and comments inside the
# body. That is intentional. It forces a baseline to copy each function's live
# definition exactly rather than retype it, which is the whole point.

set -euo pipefail

DB_URL="${DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

# --tuples-only + --no-align: no headers, no padding, no row counts. Anything
# cosmetic that psql adds is something that could differ between runs for
# reasons that are not the schema.
psql() { command psql "$DB_URL" -v ON_ERROR_STOP=1 --tuples-only --no-align --field-separator=$'\t' "$@"; }

section() { printf '\n===== %s =====\n' "$1"; }

# The schemas this project owns. `storage` is here because 20260804010006 writes
# buckets and policies into it; `cron` and `extensions` because where an
# extension lives was itself an audit finding.
OWNED="'public', 'storage'"

section "extensions (name, schema)"
psql -c "
  select e.extname, n.nspname
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
   order by e.extname;
"

section "schemas"
psql -c "
  select nspname
    from pg_namespace
   where nspname not like 'pg_%' and nspname <> 'information_schema'
   order by nspname;
"

section "tables + RLS flags"
psql -c "
  select c.relname,
         c.relrowsecurity  as rls_enabled,
         c.relforcerowsecurity as rls_forced
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
   order by c.relname;
"

section "columns (table, ordinal, name, type, nullable, default, identity, generated)"
# is_generated / generation_expression are not decoration: products.is_low_stock
# is `GENERATED ALWAYS AS (stock <= COALESCE(min_stock, 5)) STORED`, and without
# these two columns a generated column and a plain nullable boolean of the same
# type are indistinguishable here - so a baseline that quietly dropped the
# GENERATED clause would still produce an identical fingerprint.
psql -c "
  select table_name, ordinal_position, column_name, data_type,
         coalesce(character_maximum_length::text, '') as len,
         coalesce(numeric_precision::text, '') || ',' || coalesce(numeric_scale::text, '') as num,
         is_nullable,
         coalesce(column_default, '-') as col_default,
         is_identity, coalesce(identity_generation, '-') as identity_gen,
         is_generated, coalesce(generation_expression, '-') as gen_expr
    from information_schema.columns
   where table_schema = 'public'
   order by table_name, ordinal_position;
"

section "constraints (table, name, definition)"
psql -c "
  select rel.relname, con.conname, pg_get_constraintdef(con.oid)
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_namespace n on n.oid = rel.relnamespace
   where n.nspname = 'public'
   order by rel.relname, con.conname;
"

section "indexes (definition)"
psql -c "
  select schemaname, tablename, indexname, indexdef
    from pg_indexes
   where schemaname in ($OWNED)
   order by schemaname, tablename, indexname;
"

section "triggers (table, name, definition)"
psql -c "
  select n.nspname, rel.relname, tg.tgname, pg_get_triggerdef(tg.oid)
    from pg_trigger tg
    join pg_class rel on rel.oid = tg.tgrelid
    join pg_namespace n on n.oid = rel.relnamespace
   where not tg.tgisinternal
     and (n.nspname in ($OWNED) or n.nspname = 'auth')
   order by n.nspname, rel.relname, tg.tgname;
"

# The important one. Collapsing three definitions of create_pos_transaction
# into one is only correct if the surviving body is the one that was live, and
# this is what says so.
section "functions (full definition)"
psql -c "
  select n.nspname || '.' || p.proname
           || '(' || pg_get_function_identity_arguments(p.oid) || ')'
           || E'\n' || pg_get_functiondef(p.oid) as def
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ($OWNED)
     and p.prokind = 'f'
     -- Extension-owned functions are the extension's business, not ours.
     -- ~30 pg_trgm C functions would otherwise dominate this section.
     and not exists (
       select 1 from pg_depend d
        where d.objid = p.oid and d.deptype = 'e'
     )
   order by 1;
"

section "function attributes (volatility, security, search_path)"
psql -c "
  select n.nspname || '.' || p.proname
           || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         p.provolatile, p.prosecdef, p.proleakproof,
         coalesce(array_to_string(p.proconfig, ' '), '-')
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ($OWNED) and p.prokind = 'f'
     and not exists (
       select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'
     )
   order by 1;
"

section "RLS policies (schema, table, name, cmd, roles, using, check)"
psql -c "
  select schemaname, tablename, policyname, cmd,
         array_to_string(roles, ','),
         coalesce(qual, '-'),
         coalesce(with_check, '-')
    from pg_policies
   where schemaname in ($OWNED)
   order by schemaname, tablename, policyname;
"

section "table privileges"
psql -c "
  select table_schema, table_name, grantee, privilege_type
    from information_schema.role_table_grants
   where table_schema = 'public'
     and grantee in ('anon', 'authenticated', 'service_role', 'PUBLIC')
   order by table_schema, table_name, grantee, privilege_type;
"

# Where 20260804010003_api_grants sits relative to the objects it grants on is
# the single riskiest thing about the baseline's ordering: 'grant all on all
# tables' is a point-in-time statement, while 'alter default privileges' only
# covers what is created afterwards. These two sections are what decide whether
# that position is right.
section "routine privileges"
psql -c "
  select n.nspname || '.' || p.proname
           || '(' || pg_get_function_identity_arguments(p.oid) || ')',
         coalesce(array_to_string(p.proacl, E'\n'), 'default') as acl
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ($OWNED) and p.prokind = 'f'
     and not exists (
       select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e'
     )
   order by 1;
"

section "default ACLs (ALTER DEFAULT PRIVILEGES)"
psql -c "
  select coalesce(n.nspname, '-') as schema, d.defaclobjtype,
         array_to_string(d.defaclacl, E'\n')
    from pg_default_acl d
    left join pg_namespace n on n.oid = d.defaclnamespace
   order by 1, 2, 3;
"

section "schema privileges"
psql -c "
  select nspname, coalesce(array_to_string(nspacl, E'\n'), 'default')
    from pg_namespace
   where nspname in ($OWNED) or nspname = 'extensions'
   order by nspname;
"

section "sequences"
psql -c "
  select sequence_schema, sequence_name, data_type, start_value, increment
    from information_schema.sequences
   where sequence_schema = 'public'
   order by sequence_schema, sequence_name;
"

section "comments"
psql -c "
  select n.nspname || '.' || c.relname
           || coalesce('.' || a.attname, '') as obj,
         d.description
    from pg_description d
    join pg_class c on c.oid = d.objoid
    join pg_namespace n on n.oid = c.relnamespace
    left join pg_attribute a on a.attrelid = c.oid and a.attnum = d.objsubid
   where n.nspname in ($OWNED)
   order by 1, 2;
"

section "function comments"
psql -c "
  select n.nspname || '.' || p.proname, d.description
    from pg_description d
    join pg_proc p on p.oid = d.objoid
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ($OWNED)
   order by 1, 2;
"

# Data, not schema - pg_dump would miss all of it.
section "storage.buckets (rows)"
psql -c "
  select id, name, public, file_size_limit,
         coalesce(array_to_string(allowed_mime_types, ','), '-')
    from storage.buckets
   order by id;
"

section "cron.job (rows)"
psql -c "
  select jobname, schedule, command, nodename, database, active
    from cron.job
   order by jobname;
" 2>/dev/null || echo "(cron schema absent)"
