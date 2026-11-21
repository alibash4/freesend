#!/usr/bin/env bash
# Attaches one built file to a GitLab release as a downloadable asset.
#
# Usage: attach_release_asset.sh "Asset link name" path/to/file
#
# Environment:
#   RELEASE_TOKEN      GitLab project access token with the api scope (required)
#   RELEASE_TAG        Tag/name of the release to attach to (required)
#   GITLAB_PROJECT_ID  Numeric project id (default 88767048)
#   GITLAB_API         Full API base override (testing)
set -euo pipefail

ASSET_NAME="${1:?asset link name required}"
FILE="${2:?file path required}"
: "${RELEASE_TOKEN:?Set RELEASE_TOKEN.}"
: "${RELEASE_TAG:?Set RELEASE_TAG.}"

API="${GITLAB_API:-https://gitlab.com/api/v4/projects/${GITLAB_PROJECT_ID:-88767048}}"

if [ ! -f "$FILE" ]; then
  echo "$FILE was not produced" >&2
  exit 1
fi

# Upload to GitLab first: a release asset link points at the uploaded file.
UPLOAD_RESPONSE="$(
  curl --silent --show-error --fail \
    --request POST \
    --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
    --form "file=@${FILE}" \
    "${API}/uploads"
)"
UPLOAD_PATH="$(printf '%s' "$UPLOAD_RESPONSE" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
if [ -z "$UPLOAD_PATH" ]; then
  echo "Upload failed: $UPLOAD_RESPONSE" >&2
  exit 1
fi
UPLOAD_URL="https://gitlab.com${UPLOAD_PATH}"
echo "Uploaded ${FILE} to ${UPLOAD_URL}"

BODY="$(
  printf '{"name":"%s","url":"%s","direct_asset_url":"%s","link_type":"package"}' \
    "$ASSET_NAME" "$UPLOAD_URL" "$UPLOAD_URL"
)"
HTTP_CODE="$(
  curl --silent --show-error \
    --request POST \
    --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "${BODY}" \
    --output /dev/null \
    --write-out '%{http_code}' \
    "${API}/releases/${RELEASE_TAG}/assets/links"
)"
case "$HTTP_CODE" in
  2*) echo "Attached ${ASSET_NAME} to release ${RELEASE_TAG}." ;;
  *)
    echo "Could not attach ${ASSET_NAME} to release ${RELEASE_TAG} (HTTP ${HTTP_CODE})." >&2
    echo "Create the release in GitLab before pushing the tag." >&2
    exit 1
    ;;
esac
