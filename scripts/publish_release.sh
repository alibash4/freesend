#!/bin/sh
# Attaches the built Android APK to the release for this tag.
#
# The release is expected to already exist: you create it in GitLab (or with
# glab) so the notes and timing are yours. This script only uploads the binary
# and links it to the release, and creates the release itself as a fallback for
# when a tag has no release yet.
#
# The asset link name must carry the platform suffix the in-app updater matches
# on, so keep "android" in LINK_NAME.
#
# Required CI/CD variables:
#   RELEASE_TOKEN  project access token with the `api` scope
# Optional:
#   PROJECT_NAME   used for the asset file name (default: the project name)
set -eu

: "${RELEASE_TOKEN:?Set the RELEASE_TOKEN CI/CD variable to a project access token with the api scope.}"
: "${CI_COMMIT_TAG:?This job only runs on tags.}"
: "${CI_PROJECT_ID:?CI_PROJECT_ID is missing.}"
: "${CI_PROJECT_URL:?CI_PROJECT_URL is missing.}"

PROJECT_NAME="${PROJECT_NAME:-${CI_PROJECT_NAME:-freesend}}"
APK="$CI_PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK" ]; then
  echo "APK not found at $APK" >&2
  exit 1
fi

VERSION="${CI_COMMIT_TAG#v}"
ASSET_NAME="${PROJECT_NAME}-${VERSION}-android.apk"
LINK_NAME="Free Send for Android"

# Changelog: every commit since the previous tag, newest first. Only used when
# the script has to create the release itself.
PREVIOUS_TAG="$(git describe --tags --abbrev=0 "${CI_COMMIT_TAG}^" 2>/dev/null || true)"
if [ -n "$PREVIOUS_TAG" ]; then
  CHANGELOG="$(git log --pretty=format:'- %s' "${PREVIOUS_TAG}..${CI_COMMIT_TAG}")"
else
  CHANGELOG="$(git log --pretty=format:'- %s' -n 20)"
fi
if [ -z "$CHANGELOG" ]; then
  CHANGELOG="Release ${VERSION}."
fi

echo "Uploading ${ASSET_NAME} (${APK})"

UPLOAD_RESPONSE="$(
  curl --silent --show-error --fail \
    --request POST \
    --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
    --form "file=@${APK}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/uploads"
)"

UPLOAD_PATH="$(printf '%s' "$UPLOAD_RESPONSE" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
if [ -z "$UPLOAD_PATH" ]; then
  echo "Upload failed: ${UPLOAD_RESPONSE}" >&2
  exit 1
fi
# The upload response path already starts with a slash.
UPLOAD_URL="${CI_PROJECT_URL}${UPLOAD_PATH}"
echo "Uploaded to ${UPLOAD_URL}"

LINK_PAYLOAD="$(cat <<JSON
{
  "name": "${LINK_NAME}",
  "url": "${UPLOAD_URL}",
  "direct_asset_url": "${UPLOAD_URL}",
  "link_type": "package"
}
JSON
)"

HTTP_CODE="$(
  curl --silent --show-error \
    --request POST \
    --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "${LINK_PAYLOAD}" \
    --output /dev/null \
    --write-out '%{http_code}' \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/releases/${CI_COMMIT_TAG}/assets/links"
)"

case "$HTTP_CODE" in
  2*)
    echo "Attached ${ASSET_NAME} to release ${CI_COMMIT_TAG}."
    exit 0
    ;;
  *)
    echo "Could not attach to ${CI_COMMIT_TAG} (HTTP ${HTTP_CODE}); creating the release."
    ;;
esac

# JSON-escape the changelog so quotes and newlines survive the API call.
DESCRIPTION="$(printf '%s' "$CHANGELOG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"

BODY="$(cat <<JSON
{
  "tag_name": "${CI_COMMIT_TAG}",
  "name": "${PROJECT_NAME} ${VERSION}",
  "description": ${DESCRIPTION},
  "assets": {
    "links": [
      {
        "name": "${LINK_NAME}",
        "url": "${UPLOAD_URL}",
        "direct_asset_url": "${UPLOAD_URL}",
        "link_type": "package"
      }
    ]
  }
}
JSON
)"

RELEASE_RESPONSE="$(
  curl --silent --show-error --fail \
    --request POST \
    --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "${BODY}" \
    "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/releases"
)"

echo "Published ${CI_COMMIT_TAG}: ${RELEASE_RESPONSE}"
