#!/usr/bin/env bash
# Attaches one built file to a GitHub release as a downloadable asset.
#
# The release is created when missing, so a bare tag still publishes. The
# asset name carries the platform/format markers the in-app updater matches
# on, plus the real file extension so the saved download keeps it.
#
# Usage: attach_release_asset.sh "Asset name" path/to/file
#
# Environment:
#   GH_TOKEN          token with contents:write (GITHUB_TOKEN works)
#   GITHUB_REPOSITORY owner/repo (required)
#   RELEASE_TAG       tag of the release (required)
#   GITHUB_API        API base override (testing)
#   GITHUB_UPLOADS    upload host override (testing)
set -euo pipefail

ASSET_NAME="${1:?asset name required}"
FILE="${2:?file path required}"
: "${GH_TOKEN:?Set GH_TOKEN (GITHUB_TOKEN works).}"
: "${GITHUB_REPOSITORY:?Set GITHUB_REPOSITORY.}"
: "${RELEASE_TAG:?Set RELEASE_TAG.}"

API="${GITHUB_API:-https://api.github.com}"
UPLOADS="${GITHUB_UPLOADS:-https://uploads.github.com}"
AUTH=(
  --header "Authorization: Bearer ${GH_TOKEN}"
  --header "Accept: application/vnd.github+json"
  --header "X-GitHub-Api-Version: 2022-11-28"
)

if [ ! -f "$FILE" ]; then
  echo "$FILE was not produced" >&2
  exit 1
fi

# Extension for the download name; order matters (tar.gz before gz).
EXT=""
case "$FILE" in
  *.apk) EXT=apk ;;
  *.AppImage) EXT=AppImage ;;
  *.deb) EXT=deb ;;
  *.rpm) EXT=rpm ;;
  *.tar.gz) EXT=tar.gz ;;
  *.zip) EXT=zip ;;
  *.dmg) EXT=dmg ;;
esac
if [ -z "$EXT" ]; then
  echo "Cannot derive an extension from $FILE" >&2
  exit 1
fi
ASSET_NAME="${ASSET_NAME}.${EXT}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Find the release for this tag, creating it when the tag went out bare.
CODE="$(
  curl --silent --show-error \
    --output "$TMP_DIR/release.json" \
    --write-out '%{http_code}' \
    "${AUTH[@]}" \
    "${API}/repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}"
)"
if [ "$CODE" = "404" ]; then
  CODE="$(
    curl --silent --show-error \
      --request POST \
      "${AUTH[@]}" \
      --header "Content-Type: application/json" \
      --data "{\"tag_name\":\"${RELEASE_TAG}\",\"name\":\"${RELEASE_TAG}\",\"generate_release_notes\":true}" \
      --output "$TMP_DIR/release.json" \
      --write-out '%{http_code}' \
      "${API}/repos/${GITHUB_REPOSITORY}/releases"
  )"
fi
if [ "$CODE" != "200" ] && [ "$CODE" != "201" ]; then
  echo "Release lookup failed for ${RELEASE_TAG} (HTTP ${CODE}):" >&2
  cat "$TMP_DIR/release.json" >&2
  exit 1
fi

RELEASE_ID="$(
  sed -n 's/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' \
    "$TMP_DIR/release.json" | head -n 1
)"
if [ -z "$RELEASE_ID" ]; then
  echo "No release id in the API response." >&2
  exit 1
fi

# Spaces are the only character needing encoding in the asset name query.
ENCODED_NAME="${ASSET_NAME// /%20}"
CODE="$(
  curl --silent --show-error \
    --request POST \
    "${AUTH[@]}" \
    --header "Content-Type: application/octet-stream" \
    --data-binary "@${FILE}" \
    --output "$TMP_DIR/asset.json" \
    --write-out '%{http_code}' \
    "${UPLOADS}/repos/${GITHUB_REPOSITORY}/releases/${RELEASE_ID}/assets?name=${ENCODED_NAME}"
)"
if [ "$CODE" != "201" ]; then
  echo "Upload of ${ASSET_NAME} failed (HTTP ${CODE}):" >&2
  cat "$TMP_DIR/asset.json" >&2
  exit 1
fi

echo "Attached ${ASSET_NAME} to release ${RELEASE_TAG}."
