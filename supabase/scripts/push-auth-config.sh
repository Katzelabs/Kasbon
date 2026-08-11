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
#   SUPABASE_AUTH_SITE_URL    Defaults to https://kasbonapp.katzeapps.com.
#                             Override while the app still lives on a
#                             *.pages.dev preview domain. Note this is the APP
#                             host, not the landing page at kasbon.katzeapps.com
#                             — it is where the auth flow returns to.
#   SUPABASE_PROJECT_REF      Defaults to the linked project.
#   SUPABASE_AUTH_PRO         Set to 1 on a Pro-or-above project to include the
#                             settings that need a paid plan. Off by default,
#                             because the Management API rejects the WHOLE patch
#                             with 402 when one of them appears on a Free
#                             project — so a single paid-only field silently
#                             costs you every other setting in this file.
#                             Today that is leaked-password protection.
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

SITE_URL="${SUPABASE_AUTH_SITE_URL:-https://kasbonapp.katzeapps.com}"

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
#
# NO APOSTROPHES IN THE COMMENTS BELOW. Everything from the opening quote of the
# jq program to its closing quote is one single-quoted shell string, so a `'` in
# a jq comment ends that string, and the rest of the payload is then parsed as
# shell. Every original comment in this block avoids them for that reason; an
# edit that wrote "Resend's" broke the script at parse time, which is a failure
# you only meet when you next try to run it. `bash -n` catches it in a second
# and CI now does exactly that.

if [[ "${SUPABASE_AUTH_PRO:-0}" == "1" ]]; then
  PRO_JSON=true
else
  PRO_JSON=false
  echo "note: leaked-password protection is NOT being set, because it needs a" >&2
  echo "      Pro project and the API would reject the entire patch with 402." >&2
  echo "      Set SUPABASE_AUTH_PRO=1 after upgrading." >&2
fi

PAYLOAD="$(jq -n \
  --argjson pro "$PRO_JSON" \
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
    # An address at the APEX, and a monitored one rather than a noreply.
    #
    # Apex, because the Resend free plan allows exactly one verified domain, and
    # Resend verifies a domain rather than a tree: a verified katzeapps.com does
    # NOT authorise anything@kasbonapp.katzeapps.com - every subdomain needs
    # its own records and its own slot. One slot on the apex covers every Katzelabs
    # app through the local part; spent on a subdomain it covers one app. The
    # advice from Resend is the reverse - one subdomain per product, so that one
    # product cannot sink the reputation of another - and that becomes right
    # again on Pro, which allows ten domains.
    #
    # Monitored, because this is the same address that gets delivered to a real
    # inbox, and it is SupportContacts.supportEmail. A warung owner who replies
    # to a verification code asking for help then reaches a human rather than a
    # black hole. Neither mail template tells anyone not to reply, so a noreply
    # sender would have been quietly lying. The cost is bounces landing in that
    # same inbox, which at this volume is nothing.
    smtp_admin_email: "kasbon@katzeapps.com",
    smtp_sender_name: "KASBON",
    smtp_max_frequency: 1,

    # The repo is the source of truth for these, not the dashboard editor.
    mailer_subjects_confirmation: "Kode verifikasi KASBON",
    mailer_templates_confirmation_content: $confirmation_content,
    mailer_subjects_recovery: "Kode reset password KASBON",
    mailer_templates_recovery_content: $recovery_content
  }
  + (if $pro then
       # Rejects passwords found in known breaches. No config.toml equivalent -
       # this one really is production-only, but it is API-settable rather than
       # click-only.
       #
       # Omitted entirely rather than sent as false on a Free project. Sending
       # false would look harmless and would silently switch the protection back
       # off the day after someone upgrades and turns it on in the dashboard.
       { password_hibp_enabled: true }
     else {} end)')"

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
# The response body is the only thing that says WHY a patch was refused, so it
# is captured rather than discarded. This used to end in `> /dev/null`, which
# threw away the explanation at exactly the moment it was needed and left
# "PATCH failed." as the entire diagnosis of a 402.
RESPONSE="$(curl -sS -X PATCH \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  -w $'\n%{http_code}' \
  "$API")" || fail "could not reach the Management API."

HTTP_CODE="${RESPONSE##*$'\n'}"
BODY="${RESPONSE%$'\n'*}"

if [[ "$HTTP_CODE" != 2?? ]]; then
  echo "error: the API refused the patch (HTTP ${HTTP_CODE})." >&2
  jq . <<<"$BODY" >&2 2>/dev/null || echo "$BODY" >&2
  if [[ "$HTTP_CODE" == "402" ]]; then
    cat >&2 <<'EOF'

402 means a setting in this payload needs a paid plan. The API rejects the
ENTIRE patch rather than the offending field, so nothing was applied - not the
OTP length, not the password policy, not the templates.

The usual cause is SUPABASE_AUTH_PRO=1 on a project that is not Pro. Unset it
and re-run; leaked-password protection is then left alone rather than set.
EOF
  fi
  exit 1
fi

cat <<EOF

==> Applied.

    Re-run without --apply; it should now report no changes. That round trip is
    the only thing that proves the settings took — a 200 on the PATCH does not.

    Then verify end to end, which this cannot: register a real address and
    confirm a 6-digit code actually arrives. SMTP credentials are accepted by
    the API without being tested, so a wrong Resend key looks identical to a
    working one until the first signup silently fails.
EOF
