#!/usr/bin/env bash
#
# Apply KASBON's auth configuration to the hosted Supabase project.
#
# `supabase/config.toml` governs local dev ONLY. Everything in it that hardens
# auth — the 8-character minimum, the character requirements, OTP length and
# expiry, the confirmation and recovery templates — has no effect in production,
# where the same settings live in a dashboard as click-ops nobody wrote down.
# This script is the written-down version, so the repo is the source of truth
# and a re-run is a no-op rather than an archaeology exercise.
#
# It deliberately does NOT use `supabase config push`. That pushes the whole
# config.toml, which would also set production's Site URL to
# http://127.0.0.1:3000, and would apply [api], [storage] and [db.pooler]
# alongside — `pooler.enabled = false` locally, and the blast radius on a live
# project is not documented anywhere. The Management API patches auth and
# nothing else.
#
# Usage:
#   ./supabase/scripts/push-auth-config.sh                  # dry run: show the diff
#   ./supabase/scripts/push-auth-config.sh --apply          # actually apply it
#   ./supabase/scripts/push-auth-config.sh --print-payload   # build only, no network
#
# Required environment:
#   SUPABASE_ACCESS_TOKEN     Personal access token — Dashboard → Account →
#                             Access Tokens. NOT the service key, NOT the DSN.
#   SUPABASE_AUTH_SMTP_PASS   The Resend API key (re_…) used as the SMTP password.
#
# Optional:
#   SUPABASE_AUTH_SITE_URL    Defaults to https://kasbon.app. Override while the
#                             app still lives on a *.pages.dev preview domain.
#   SUPABASE_PROJECT_REF      Defaults to the linked project.
#
# Both required values are real secrets. Prefer a shell that sources them from a
# secret store, or CI secrets, over typing them inline where they land in shell
# history.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="dry-run"
case "${1:-}" in
  --apply)         MODE="apply" ;;
  --print-payload) MODE="print-payload" ;;
  "")              ;;
  *) echo "error: unknown argument '$1'" >&2; exit 2 ;;
esac

fail() { echo "error: $*" >&2; exit 1; }

command -v jq >/dev/null || fail "jq is required."

PROJECT_REF="${SUPABASE_PROJECT_REF:-$(cat supabase/.temp/project-ref 2>/dev/null || true)}"
[[ -n "$PROJECT_REF" ]] || fail "no project ref. Run 'supabase link' or set SUPABASE_PROJECT_REF."

SITE_URL="${SUPABASE_AUTH_SITE_URL:-https://kasbon.app}"

CONFIRMATION_TEMPLATE="supabase/templates/confirmation.html"
RECOVERY_TEMPLATE="supabase/templates/recovery.html"
for t in "$CONFIRMATION_TEMPLATE" "$RECOVERY_TEMPLATE"; do
  [[ -f "$t" ]] || fail "missing template: $t"
  # The whole reason these exist. A template that lost its {{ .Token }} would
  # send a working-looking email containing no code, and the app has no deep
  # link handler to fall back on — see app/CLAUDE.md → Authentication.
  grep -q '{{ \.Token }}' "$t" || fail "$t has no {{ .Token }} — refusing to \
push a template that cannot deliver a code."
done

if [[ "$MODE" != "print-payload" ]]; then
  [[ -n "${SUPABASE_ACCESS_TOKEN:-}" ]] || fail "SUPABASE_ACCESS_TOKEN is not set."
fi
SMTP_PASS="${SUPABASE_AUTH_SMTP_PASS:-}"
if [[ "$MODE" == "apply" && -z "$SMTP_PASS" ]]; then
  fail "SUPABASE_AUTH_SMTP_PASS is not set. Without it the SMTP block would be \
applied with an empty password and no OTP email would be delivered."
fi

# --- the desired state -----------------------------------------------------
#
# Mirrors supabase/config.toml. Two field names invert or retype on the way
# across and are the easy mistakes:
#   * mailer_autoconfirm is the INVERSE of config.toml's enable_confirmations.
#     true means "skip confirmation entirely" — the opposite of what we want.
#   * smtp_port is a STRING in this API, not an integer.

PAYLOAD="$(jq -n \
  --arg site_url "$SITE_URL" \
  --arg uri_allow_list "${SITE_URL},${SITE_URL}/*" \
  --arg pw_chars "abcdefghijklmnopqrstuvwxyz:ABCDEFGHIJKLMNOPQRSTUVWXYZ:0123456789" \
  --arg smtp_pass "$SMTP_PASS" \
  --arg confirmation_content "$(cat "$CONFIRMATION_TEMPLATE")" \
  --arg recovery_content "$(cat "$RECOVERY_TEMPLATE")" \
  '{
    site_url: $site_url,
    uri_allow_list: $uri_allow_list,

    # Finally agreeing with Validators.password(), which has always required 8
    # plus lower, upper and a digit. The server being weaker meant anything
    # reaching the API another way could set something the UI would reject.
    password_min_length: 8,
    password_required_characters: $pw_chars,

    # Rejects passwords found in known breaches. No config.toml equivalent —
    # this one really is production-only, but it is API-settable, not
    # click-only.
    password_hibp_enabled: true,

    # A stolen session must not become a permanent lockout by silently
    # changing the password. Does not affect recovery, which verifies an OTP
    # first and so already satisfies the recent-login condition.
    security_update_password_require_reauthentication: true,
    mailer_secure_email_change_enabled: true,

    # false = confirmations REQUIRED. See the note above.
    mailer_autoconfirm: false,

    mailer_otp_length: 6,
    # 15 minutes. A six-digit code has a million combinations and should not be
    # guessable for an hour; long enough to switch to a mail app and back.
    mailer_otp_exp: 900,

    rate_limit_email_sent: 30,

    smtp_host: "smtp.resend.com",
    smtp_port: "587",
    smtp_user: "resend",
    smtp_pass: $smtp_pass,
    smtp_admin_email: "noreply@kasbon.app",
    smtp_sender_name: "KASBON",
    smtp_max_frequency: 1,

    # The repo is the source of truth for these, not the dashboard editor.
    mailer_subjects_confirmation: "Kode verifikasi KASBON",
    mailer_templates_confirmation_content: $confirmation_content,
    mailer_subjects_recovery: "Kode reset password KASBON",
    mailer_templates_recovery_content: $recovery_content
  }')"

API="https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth"

if [[ "$MODE" == "print-payload" ]]; then
  echo "Project: ${PROJECT_REF}"
  echo "Payload (smtp_pass and template bodies elided):"
  jq '.smtp_pass = "<redacted>"
      | .mailer_templates_confirmation_content |= "<\(. | length) chars from '"$CONFIRMATION_TEMPLATE"'>"
      | .mailer_templates_recovery_content     |= "<\(. | length) chars from '"$RECOVERY_TEMPLATE"'>"' <<<"$PAYLOAD"
  exit 0
fi

# --- diff against what is live --------------------------------------------

echo "==> Reading current auth config for ${PROJECT_REF}"
CURRENT="$(curl -sS --fail-with-body \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  "$API")" || fail "could not read the current config (is SUPABASE_ACCESS_TOKEN a \
valid personal access token with access to ${PROJECT_REF}?)"

echo
echo "==> Settings that would change:"
CHANGES="$(jq -n --argjson current "$CURRENT" --argjson desired "$PAYLOAD" '
  $desired
  | to_entries
  | map(select(.value != ($current[.key])))
  | map({
      key: .key,
      from: (if (.key | test("smtp_pass")) then "<redacted>"
             elif (.key | test("_content$")) then "<\(($current[.key] // "") | length) chars>"
             else ($current[.key] // null) end),
      to:   (if (.key | test("smtp_pass")) then "<redacted>"
             elif (.key | test("_content$")) then "<\((.value) | length) chars>"
             else .value end)
    })')"

if [[ "$(jq 'length' <<<"$CHANGES")" -eq 0 ]]; then
  echo "    (none — production already matches)"
  exit 0
fi
jq -r '.[] | "    \(.key):\n        from: \(.from)\n        to:   \(.to)"' <<<"$CHANGES"

if [[ "$MODE" == "dry-run" ]]; then
  cat <<EOF

Dry run — nothing was changed. Re-run with --apply to write these.
EOF
  exit 0
fi

# --- apply -----------------------------------------------------------------

echo
echo "==> Applying to ${PROJECT_REF}"
curl -sS --fail-with-body -X PATCH \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "$API" > /dev/null || fail "PATCH failed."

cat <<EOF

==> Applied.

    Re-run without --apply; it should now report no changes. That round trip is
    the only thing that proves the settings took — a 200 on the PATCH does not.

    Then verify end to end, which this cannot: register a real address and
    confirm a 6-digit code actually arrives. SMTP credentials are accepted by
    the API without being tested, so a wrong Resend key looks identical to a
    working one until the first signup silently fails.
EOF
