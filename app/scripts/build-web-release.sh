#!/usr/bin/env bash
#
# Build the KASBON web release and upload its source maps to Sentry.
#
# Build, upload, *then* deploy — in that order, from this one script, because
# the middle step rewrites the thing the first step produced.
#
# `sentry_dart_plugin` runs `sentry-cli sourcemaps inject`, which writes a debug
# ID **into the .js files in build/web** and into the maps beside them. That is
# what ties a minified frame to its source. Deploying a build/web captured
# before the upload ships JavaScript with no debug ID, and nothing tells you:
# the upload succeeded, the dashboard lists the maps, the release exists, and
# every production stack trace stays minified anyway.
#
# So: never `flutter build web` in one place and upload in another, and never
# deploy an artifact built before the upload ran.
#
# Usage:
#   SENTRY_AUTH_TOKEN=… SENTRY_ORG=… SENTRY_PROJECT=… ./scripts/build-web-release.sh
#   ./scripts/build-web-release.sh --no-upload     # build only, no symbolication
#
# The auth token is a real secret (unlike the DSN) — it can write to your
# Sentry org. Create it at Settings → Auth Tokens with the `project:releases`
# scope, and keep it out of shell history: prefer an env file your shell sources
# or a secret in the CI/deploy environment over typing it inline.

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$APP_DIR"

UPLOAD=1
if [[ "${1:-}" == "--no-upload" ]]; then
  UPLOAD=0
elif [[ $# -gt 0 ]]; then
  echo "error: unknown argument '$1' (only --no-upload is accepted)" >&2
  exit 2
fi

fail() { echo "error: $*" >&2; exit 1; }

# --- preflight -------------------------------------------------------------
# All of it before the build, because the build is four minutes and finding out
# afterwards that a token is missing means doing it twice.

[[ -f env.prod.json ]] || fail "env.prod.json not found. Copy env.example.json \
and fill in the production Supabase URL, publishable key and SENTRY_DSN."

if ! grep -q '"SENTRY_DSN"[[:space:]]*:[[:space:]]*"[^"]\+"' env.prod.json; then
  echo "warning: env.prod.json has no non-empty SENTRY_DSN — this build will" >&2
  echo "         not report crashes at all, so uploading maps for it is" >&2
  echo "         pointless. See CLAUDE.md → Crash reporting." >&2
fi

if [[ $UPLOAD -eq 1 ]]; then
  for var in SENTRY_AUTH_TOKEN SENTRY_ORG SENTRY_PROJECT; do
    [[ -n "${!var:-}" ]] || fail "$var is not set. Set all three, or pass \
--no-upload to build without symbolication."
  done
fi

# The release string has to be byte-identical to what the SDK reports at
# runtime, or Sentry holds maps it will never apply to an event. The SDK builds
# it in LoadReleaseIntegration from package_info, which on web reads the
# version.json that Flutter generates from these two pubspec fields — and
# sentry_dart_plugin reconstructs it from the same two. Printed so it can be
# compared against the release shown on an actual issue.
APP_NAME="$(awk '/^name:/ {print $2; exit}' pubspec.yaml)"
APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
RELEASE="${APP_NAME}@${APP_VERSION}"

# --- build -----------------------------------------------------------------

echo "==> Building web release (${RELEASE})"
flutter build web --dart-define-from-file=env.prod.json --source-maps

# --source-maps is easy to drop, and without it the upload has nothing to send
# but still reports success.
shopt -s nullglob
maps=(build/web/*.js.map)
shopt -u nullglob
[[ ${#maps[@]} -gt 0 ]] || fail "no .js.map files in build/web — the build ran \
without --source-maps."

# --- upload ----------------------------------------------------------------

if [[ $UPLOAD -eq 0 ]]; then
  echo "==> Skipping Sentry upload (--no-upload)"
  echo "    build/web is deployable, but its stack traces will stay minified."
  exit 0
fi

echo "==> Injecting debug IDs and uploading source maps"
dart run sentry_dart_plugin

cat <<EOF

==> Done. Release: ${RELEASE}

    Deploy **this** build/web — it now carries the injected debug IDs.
    Rebuilding before deploying silently undoes the symbolication.

    Verify: open an issue in Sentry and check its Release matches
    ${RELEASE} and the frames name Dart functions rather than minified ones.
EOF
