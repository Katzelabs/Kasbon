# KASBON database

The authoritative description of the schema is `supabase/migrations/` itself.
This file is the map: which file to open, what the conventions are, and what to
do when you need to change something.

## The migration set

Ten files, applied in filename order. Each object is created exactly once, in
the file that owns it.

| File | Owns |
|------|------|
| `20260804010001_extensions.sql` | `pg_trgm` (in `extensions`), `pg_cron` (in `pg_catalog`, not relocatable) |
| `20260804010002_core_schema.sql` | the six tables with every column, all indexes, `handle_updated_at`, `handle_new_user`, the `updated_at` and signup triggers, column comments |
| `20260804010003_api_grants.sql` | grants for `anon` / `authenticated` / `service_role`, and the `ALTER DEFAULT PRIVILEGES` that covers everything created after it |
| `20260804010004_rls_policies.sql` | RLS enabled, and all 23 policies on the public tables |
| `20260804010005_tenant_integrity.sql` | `freeze_privileged_profile_columns` and its trigger |
| `20260804010006_storage_buckets.sql` | both buckets and all 8 `storage.objects` policies |
| `20260804010007_pos_rpc.sql` | `create_pos_transaction` — the only non-PostgREST write path |
| `20260804010008_report_rpcs.sql` | the 14 read aggregates the dashboard and reports call |
| `20260804010009_storage_retention.sql` | `assert_janitor_caller`, the four janitor policy queries, `run_storage_janitor`, the cron schedule |
| `20260804010010_account_deletion.sql` | `assert_service_role_caller`, `account_object_paths` |

**Ordering constraints that are not obvious.** Three, and all three are the
reason the numbering is what it is:

- `010001` before `010002`, because the trigram indexes need `pg_trgm`'s
  operator classes.
- `010003` after `010002` but before `010007`–`010010`. `GRANT ... ON ALL TABLES`
  is a statement about tables that already exist; `ALTER DEFAULT PRIVILEGES` is
  a statement about objects not yet created. Sitting between the tables and the
  functions is the only position where both mean what they say.
- `010009` and `010010` after `010003`, because each has to `REVOKE` the default
  privilege that file grants.

## Conventions

- **Multi-tenant by `user_id`**, by `id` on `user_profiles`. Every tenant table
  keys off `auth.users(id) ON DELETE CASCADE`, which is what makes account
  deletion one `auth.admin.deleteUser()` call.
- **Every policy is `TO authenticated` plus an ownership predicate.** The role
  alone is authentication without authorisation. `security_invariants.sql`
  check 4 asserts this structurally, so it fails for a policy nobody has
  written yet.
- **Every function in `public` pins `search_path`** — check 5 asserts it.
- **Money is `DECIMAL(12,2)`** → `double` in Dart. Timestamps are `TIMESTAMPTZ`.
  IDs are UUID.
- **Half-open ranges** `[from, to)` in every report function.
- **Range filters compare the bare `transaction_date`**, so
  `idx_transactions_user_date` stays usable. Bucketing converts to local
  wall-clock with `AT TIME ZONE` on the *other* side of the comparison; wrapping
  the column is correct and unsargable, and cost a 282x dashboard regression
  once.
- **`payment_status` is `'paid' | 'debt'` only.** A hutang is a completed sale,
  so it counts as revenue everywhere. There is no `'cancelled'`, and nothing
  filters for one.
- **Anything that reads across tenants is service-role only, enforced twice**:
  by GRANT *and* by a guard inside the function body. The GRANT alone is not
  enough, because `010003` grants EXECUTE on every new `public` function to
  `authenticated` — so a REVOKE is a statement about today and the guard is a
  statement about the function.

## Changing the schema

**This baseline is not a live document.** Edit these ten files only while
nothing has been pushed to production. Once `supabase db push` has run against
the hosted project, the ten versions are recorded in
`supabase_migrations.schema_migrations` there, and editing a file that has
already been applied means the local and remote histories disagree.

From that point on, every change is a new file:

```bash
supabase migration new <name>     # never hand-write the filename
supabase db reset                 # applies everything from empty, then seeds
psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/security_invariants.sql
```

Run the invariants after touching any policy, function or GRANT. CI runs them
too, after a reset from an empty database.

### Proving a refactor changed nothing

`supabase/scripts/schema-fingerprint.sh` emits a deterministic, diffable
description of everything the migrations build — tables, columns (including
generated expressions), constraints, indexes, triggers, full function bodies,
policies, ACLs, default ACLs, comments, and the three things that are data
rather than schema (`storage.buckets` rows, the `cron.job` row, `pg_default_acl`).

Two migration sets that produce the same fingerprint are the same database:

```bash
git stash                                  # or check out the pre-change commit
supabase db reset
./supabase/scripts/schema-fingerprint.sh > /tmp/before.txt
git stash pop
supabase db reset
./supabase/scripts/schema-fingerprint.sh > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt        # must be empty
```

This is how the baseline was verified against the 20 files it replaced. Of 2594
lines the diff was three: a comment inside `referenced_object_paths`'s body that
named a migration the baseline no longer contains, reworded deliberately. Every
table, column, constraint, index, trigger, policy, ACL, function body and bucket
row was identical.

The three-line diff is worth knowing about for a different reason: the
fingerprint compares `pg_get_functiondef`, so **a comment inside a function body
is part of what is compared**. That is intentional - it is what forces a
refactor to copy a body rather than retype it - but it means editing such a
comment is a deliberate act that shows up here, not a free change.

## Where the baseline came from

Twenty chronological migrations were collapsed into these ten on 2026-08-04,
before the first production push — the only moment when it was free. After a
push, restructuring means `supabase migration repair` for every version against
a live database.

The problem was not size (3469 lines) but that **11 of 26 functions were defined
more than once**, so the file a reader opened was often not the definition that
was live: `create_pos_transaction` had three definitions, `get_dashboard_summary`
three, and eight of the ten functions in the file the docs named as
authoritative for RPCs were dead on arrival. Policies were another case — created
with no role clause in one file and retrofitted with `TO authenticated` by an
`ALTER POLICY` loop in another, six months apart.

Function bodies in the baseline were **generated** from `pg_get_functiondef`
against the database the old migrations built, not retyped, because
transcription across three supersessions is exactly where a silent behaviour
change comes from.

Two files were dropped rather than merged: both were pure DML backfills
(`products.image_url` URL→path rewriting, and an onboarding-flag backfill) that
are no-ops against an empty database. The seed sets the onboarding flag itself.
Their reasoning survives as column comments in `010002` and in
`referenced_object_paths`, which still normalises the legacy URL shape so the
janitor cannot collect a live photo.

The old files remain in git history. `supabase/scripts/schema-fingerprint.sh`
predates the baseline in the same commit, so the proof is reproducible.

### Old → new

| Old | Now in |
|-----|--------|
| `20260207070429_initial_schema` | `010002` (tables, indexes, triggers), `010004` (RLS) |
| `20260316000001_create_rpc_functions` | `010007` (`create_pos_transaction`), `010008` (reports) |
| `20260725000001_grant_api_role_privileges` | `010003` |
| `20260726000001_advanced_report_rpcs` | `010008` |
| `20260726000002_fix_dashboard_summary_timezone` | `010008` — superseded by `20260801000004` |
| `20260727000001_create_product_images_bucket` | `010006` |
| `20260730000001_product_image_object_paths` | dropped (DML backfill); reasoning in `010002`, `010009` |
| `20260730000002_product_low_stock_column` | `010002` |
| `20260731000001_transaction_payment_proof` | `010002` |
| `20260731000002_create_payment_proofs_bucket` | `010006` |
| `20260731000003_drop_dead_cancelled_filters` | `010008` |
| `20260731000004_pos_transaction_payment_confirmation` | `010007` — superseded by `20260801000003` |
| `20260731000005_customer_names_rpc` | `010008` |
| `20260731000006_shop_business_type_and_onboarding` | `010002` (column); backfill dropped |
| `20260801000001_payment_proof_retention` | `010002` (column), `010009` (functions) |
| `20260801000002_schedule_storage_janitor` | `010009` |
| `20260801000003_tenant_integrity_hardening` | `010005`, `010007`, `010002` |
| `20260801000004_query_performance` | `010002` (indexes), `010008` (dashboard) |
| `20260801000005_extension_schema_and_janitor_search_path` | `010001`, `010009` |
| `20260804000001_account_deletion` | `010010` |

## Deployment

Not covered by `db push`, and each needs doing once per environment:

| Piece | Command |
|-------|---------|
| Schema | `supabase db push` |
| `storage-janitor` + its two Vault secrets | `./supabase/scripts/deploy-storage-janitor.sh --linked` |
| `delete-account` | `supabase functions deploy delete-account` |
| SMTP + the two OTP email templates | hosted project settings; `config.toml` governs local only |

Until `deploy-storage-janitor.sh` runs, the cron job no-ops with a `NOTICE` and
nothing is ever deleted from storage.
