#!/bin/sh
# Writes android/key.properties from CI variables so release builds are signed
# with one stable key. Does nothing when the variables are absent, so local
# builds keep using the developer's own key.properties.
#
# Required CI/CD variables when signing in CI:
#   SIGNING_KEYSTORE_BASE64  the .keystore/.jks file, base64 encoded
#   SIGNING_STORE_PASSWORD
#   SIGNING_KEY_ALIAS
#   SIGNING_KEY_PASSWORD
set -eu

if [ -z "${SIGNING_KEYSTORE_BASE64:-}" ]; then
  echo "No SIGNING_KEYSTORE_BASE64 set; using a local key.properties if present."
  exit 0
fi

: "${SIGNING_STORE_PASSWORD:?Set SIGNING_STORE_PASSWORD.}"
: "${SIGNING_KEY_ALIAS:?Set SIGNING_KEY_ALIAS.}"
: "${SIGNING_KEY_PASSWORD:?Set SIGNING_KEY_PASSWORD.}"

PROJECT_DIR="${CI_PROJECT_DIR:-$PWD}"
KEYSTORE_PATH="${PROJECT_DIR}/android/freesend.keystore"
mkdir -p "$(dirname "$KEYSTORE_PATH")"
printf '%s' "$SIGNING_KEYSTORE_BASE64" | base64 -d > "$KEYSTORE_PATH"
chmod 600 "$KEYSTORE_PATH"

# printf rather than a heredoc, so passwords containing $ or backticks survive.
{
  printf 'STORE_FILE=%s\n' "$KEYSTORE_PATH"
  printf 'STORE_PASSWORD=%s\n' "$SIGNING_STORE_PASSWORD"
  printf 'KEY_ALIAS=%s\n' "$SIGNING_KEY_ALIAS"
  printf 'KEY_PASSWORD=%s\n' "$SIGNING_KEY_PASSWORD"
} > "${PROJECT_DIR}/android/key.properties"

echo "Wrote android/key.properties for alias ${SIGNING_KEY_ALIAS}."
