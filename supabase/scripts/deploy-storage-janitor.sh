#!/usr/bin/env bash
# =============================================================================
# Deploy storage-janitor and give the nightly cron the two secrets it waits for
# =============================================================================
# The sweep ships in three pieces that are deployed in three different ways, and
# it does nothing at all until the last of them is in place:
#
#   the policy    20260801000001 - migration, ships with `db push`
#   the schedule  20260801000002 - migration, ships with `db push`
#   the deleting  functions/storage-janitor - needs `functions deploy`
#   the secrets   vault - neither, because they differ per environment
#
# The schedule is deliberately quiet about the missing secrets (it raises a
# NOTICE and returns), so an undeployed janitor looks exactly like a working one
# from the outside. This script is the step that makes it real, and the dry run
# at the end is how you find out it worked.
#
# ## Why a script and not the three commands from the migration header
#
# Three reasons, all of them things that bit us doing it by hand:
#
#   - `vault.create_secret` raises on a name that already exists
#     ("duplicate key value violates unique constraint secrets_name_idx"), so
#     the documented sequence works exactly once and fails on every rotation.
#     This upserts.
#
#   - the service key must not reach argv. `supabase db query "<sql>"` puts the
#     whole statement in the process table, where any local process can read it
#     for as long as the query runs. Every statement holding the key goes in
#     over stdin instead - not a temp file either, so it never touches disk.
#
#   - `select ... from net._http_response order by created desc limit 1` races.
#     pg_net performs the request from a background worker, so immediately after
#     `run_storage_janitor` returns there is usually no row yet, and the newest
#     row is whatever ran before. We poll for the id the call actually returned.
#
# ## Usage
#
#   ./supabase/scripts/deploy-storage-janitor.sh --linked
#   ./supabase/scripts/deploy-storage-janitor.sh --local
#   SUPABASE_SERVICE_ROLE_KEY=... ./supabase/scripts/deploy-storage-janitor.sh --linked
#
# --linked deploys the function and configures the linked project. --local
# configures the local stack only - there is nothing to deploy, because local
# Edge Functions are served by `supabase functions serve`, and the script tells
# you so if it is not running.
#
# The key is read from $SUPABASE_SERVICE_ROLE_KEY, or prompted for silently.
# --local reads it from `supabase status`, since it is a well-known demo key.
# =============================================================================

set -euo pipefail

readonly FUNCTION_NAME='storage-janitor'
readonly URL_SECRET='storage_janitor_url'
readonly KEY_SECRET='storage_janitor_service_key'

# How long to wait for pg_net's background worker to record the response. It
# normally lands in under a second; the ceiling is for a cold project where the
# function has to boot first.
readonly RESPONSE_TIMEOUT_SECONDS=30

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

TARGET=''
case "${1:-}" in
  --linked) TARGET='linked' ;;
  --local)  TARGET='local' ;;
  *)
    echo "usage: $0 --linked | --local" >&2
    exit 2
    ;;
esac
readonly TARGET

# `supabase db query` takes the same two flags, and every call below is against
# whichever one we were given.
db_query() {
  supabase db query "--$TARGET" -o json -f /dev/stdin
}

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# -----------------------------------------------------------------------------
# 1. WHERE, AND WITH WHAT
# -----------------------------------------------------------------------------
say "1/4  Resolving target"

if [[ "$TARGET" == linked ]]; then
  if [[ ! -f supabase/.temp/project-ref ]]; then
    echo "error: no linked project. Run: supabase link --project-ref <ref>" >&2
    exit 1
  fi
  PROJECT_REF="$(cat supabase/.temp/project-ref)"
  FUNCTION_URL="https://${PROJECT_REF}.supabase.co/functions/v1/${FUNCTION_NAME}"
  echo "     project  ${PROJECT_REF}"
else
  # pg_net runs inside the database container, so 127.0.0.1 there is the
  # database itself, not the API gateway. Kong is reachable from that container
  # by its service name on the compose network.
  PROJECT_REF='(local)'
  FUNCTION_URL="http://kong:8000/functions/v1/${FUNCTION_NAME}"
fi
readonly PROJECT_REF FUNCTION_URL
echo "     url      ${FUNCTION_URL}"

if [[ -n "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
  SERVICE_KEY="$SUPABASE_SERVICE_ROLE_KEY"
  echo "     key      from \$SUPABASE_SERVICE_ROLE_KEY"
elif [[ "$TARGET" == local ]]; then
  SERVICE_KEY="$(supabase status -o json | sed -n 's/.*"SERVICE_ROLE_KEY": "\([^"]*\)".*/\1/p')"
  echo "     key      from supabase status"
else
  # -s so it is not echoed, and it is never passed on to anything that would
  # put it in argv or a file.
  read -rsp "     service role key for ${PROJECT_REF}: " SERVICE_KEY
  echo
fi
readonly SERVICE_KEY

if [[ -z "$SERVICE_KEY" ]]; then
  echo "error: no service role key" >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# 2. THE FUNCTION
# -----------------------------------------------------------------------------
say "2/4  Deploying ${FUNCTION_NAME}"

if [[ "$TARGET" == linked ]]; then
  supabase functions deploy "$FUNCTION_NAME"
else
  echo "     skipped - local functions are served by \`supabase functions serve\`."
  echo "     Start it in another terminal if the dry run below cannot connect."
fi

# -----------------------------------------------------------------------------
# 3. THE SECRETS
# -----------------------------------------------------------------------------
# Upsert, so this is safe to re-run and is also how you rotate the key: change
# it in the dashboard, run this again.
#
# The two are set in one statement so a failure cannot leave the pair
# half-updated - which is the one state that would have the cron posting a live
# request with a stale key.
say "3/4  Storing Vault secrets"

db_query >/dev/null <<SQL
DO \$\$
DECLARE
  wanted JSONB := jsonb_build_object(
    '${URL_SECRET}', \$secret\$${FUNCTION_URL}\$secret\$,
    '${KEY_SECRET}', \$secret\$${SERVICE_KEY}\$secret\$
  );
  secret_name TEXT;
  secret_value TEXT;
  existing UUID;
BEGIN
  FOR secret_name, secret_value IN SELECT * FROM jsonb_each_text(wanted) LOOP
    SELECT id INTO existing FROM vault.secrets WHERE name = secret_name;

    IF existing IS NULL THEN
      PERFORM vault.create_secret(secret_value, secret_name,
        'storage-janitor deployment - see supabase/scripts/deploy-storage-janitor.sh');
    ELSE
      PERFORM vault.update_secret(existing, secret_value, secret_name);
    END IF;
  END LOOP;
END;
\$\$;
SQL

# Read back names and lengths only. Enough to prove both landed and that the key
# is not the empty string or a truncated paste, without printing the key.
db_query <<SQL
SELECT name,
       length(decrypted_secret) AS length,
       CASE WHEN name = '${URL_SECRET}' THEN decrypted_secret ELSE '(hidden)' END AS value
FROM vault.decrypted_secrets
WHERE name IN ('${URL_SECRET}', '${KEY_SECRET}')
ORDER BY name;
SQL

# -----------------------------------------------------------------------------
# 4. THE DRY RUN
# -----------------------------------------------------------------------------
# Deletes nothing. Reports what a real run would have deleted, which is the
# thing worth seeing before the first real one against live shops.
say "4/4  Dry run"

REQUEST_ID="$(db_query <<<'SELECT public.run_storage_janitor(dry_run => true) AS id;' \
  | sed -n 's/.*"id": *\([0-9]*\).*/\1/p' | head -1)"

if [[ -z "$REQUEST_ID" ]]; then
  echo "error: run_storage_janitor returned null - the secrets did not take" >&2
  exit 1
fi
echo "     pg_net request ${REQUEST_ID}, waiting for the response"

# pg_net answers on its own schedule; polling by id rather than taking the
# newest row means we cannot mistake a previous night's response for this one.
for ((i = 0; i < RESPONSE_TIMEOUT_SECONDS; i++)); do
  RESPONSE="$(db_query <<SQL
SELECT status_code, content, error_msg
FROM net._http_response
WHERE id = ${REQUEST_ID};
SQL
)"
  if [[ "$RESPONSE" == *'"status_code"'* || "$RESPONSE" == *'"error_msg": "'* ]]; then
    break
  fi
  sleep 1
done

echo "$RESPONSE"

case "$RESPONSE" in
  *'"status_code": 200'*)
    say "Done. The janitor is deployed and runs nightly at 03:00 WIB."
    echo "Report above is what a real run would have deleted."
    ;;
  *'"status_code": 403'*)
    echo "error: the function rejected the key. The Vault secret and the" >&2
    echo "       project's SUPABASE_SERVICE_ROLE_KEY are not the same value." >&2
    exit 1
    ;;
  *)
    echo "error: no successful response - see status_code/error_msg above." >&2
    [[ "$TARGET" == local ]] && echo "       Is \`supabase functions serve\` running?" >&2
    exit 1
    ;;
esac
