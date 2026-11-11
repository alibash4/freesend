#!/bin/sh
# Attaches the built Android APKs to the release for this tag.
#
# The release is expected to already exist: you create it in GitLab (or with
# glab) so the notes and timing are yours. This script only uploads the binaries
# and links them to the release, and creates the release itself as a fallback
# for when a tag has no release yet.
#
# Asset link names carry the platform and bitness the in-app updater matches
# on, so keep "android" and the bitness markers in LINK_NAME.
#
# Required CI/CD variables:
#   RELEASE_TOKEN  project access token with the `api` scope
# Optional:
#   PROJECT_NAME   used for the asset file names (default: the project name)
set -eu

: "${RELEASE_TOKEN:?Set the RELEASE_TOKEN CI/CD variable to a project access token with the api scope.}"
: "${CI_COMMIT_TAG:?This job only runs on tags.}"
: "${CI_PROJECT_ID:?CI_PROJECT_ID is missing.}"
: "${CI_PROJECT_URL:?CI_PROJECT_URL is missing.}"

PROJECT_NAME="${PROJECT_NAME:-${CI_PROJECT_NAME:-freesend}}"
APK_DIR="$CI_PROJECT_DIR/build/app/outputs/flutter-apk"
VERSION="${CI_COMMIT_TAG#v}"

# link name|file name|built artifact. Order matters only for readability.
ASSETS="
Free Send for Android (32-bit)|${PROJECT_NAME}-${VERSION}-android-32bit.apk|app-armeabi-v7a-release.apk
Free Send for Android (64-bit)|${PROJECT_NAME}-${VERSION}-android-64bit.apk|app-arm64-v8a-release.apk
Free Send for Android|${PROJECT_NAME}-${VERSION}-android-universal.apk|app-release.apk
"

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

LINK_FILE="$(mktemp)"
trap 'rm -f "$LINK_FILE"' EXIT

# Upload each built APK and record "link name<TAB>url" for the release call.
while IFS='|' read -r LINK_NAME FILE_NAME ARTIFACT; do
  [ -n "$LINK_NAME" ] || continue
  PATH_TO_APK="$APK_DIR/$ARTIFACT"
  if [ ! -f "$PATH_TO_APK" ]; then
    echo "Skipping $ARTIFACT (not built)."
    continue
  fi

  echo "Uploading $ARTIFACT as $LINK_NAME"
  UPLOAD_RESPONSE="$(
    curl --silent --show-error --fail \
      --request POST \
      --header "PRIVATE-TOKEN: ${RELEASE_TOKEN}" \
      --form "file=@${PATH_TO_APK}" \
      "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/uploads"
  )"

  UPLOAD_PATH="$(printf '%s' "$UPLOAD_RESPONSE" | sed -n 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [ -z "$UPLOAD_PATH" ]; then
    echo "Upload failed for $ARTIFACT: $UPLOAD_RESPONSE" >&2
    exit 1
  fi
  # The upload response path already starts with a slash.
  UPLOAD_URL="${CI_PROJECT_URL}${UPLOAD_PATH}"
  echo "Uploaded to ${UPLOAD_URL}"
  printf '%s\t%s\n' "$LINK_NAME" "$UPLOAD_URL" >> "$LINK_FILE"
done <<ENTRIES
${ASSETS}
ENTRIES

if [ ! -s "$LINK_FILE" ]; then
  echo "No APKs were uploaded; nothing to attach." >&2
  exit 1
fi

# Prefer attaching to the release you already made.
ATTACHED=0
while IFS="$(printf '\t')" read -r LINK_NAME UPLOAD_URL; do
  [ -n "$LINK_NAME" ] || continue
  LINK_PAYLOAD="$(
    printf '{"name":"%s","url":"%s","direct_asset_url":"%s","link_type":"package"}' \
      "$LINK_NAME" "$UPLOAD_URL" "$UPLOAD_URL"
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
      ATTACHED=$((ATTACHED + 1))
      echo "Attached ${LINK_NAME}."
      ;;
    *)
      echo "Could not attach ${LINK_NAME} (HTTP ${HTTP_CODE})."
      ;;
  esac
done < "$LINK_FILE"

if [ "$ATTACHED" -gt 0 ]; then
  echo "Attached ${ATTACHED} asset(s) to release ${CI_COMMIT_TAG}."
  exit 0
fi

echo "No release for ${CI_COMMIT_TAG} yet; creating one with every asset."

# JSON-escape the changelog so quotes and newlines survive the API call.
DESCRIPTION="$(printf '%s' "$CHANGELOG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')"

BODY="$(python3 - "$LINK_FILE" "$CI_COMMIT_TAG" "$PROJECT_NAME" "$VERSION" "$DESCRIPTION" <<'PY'
import json, sys

link_file, tag, name, version, description = sys.argv[1:6]
links = []
with open(link_file) as handle:
    for line in handle:
        line = line.rstrip("\n")
        if not line:
            continue
        link_name, url = line.split("\t")
        links.append({
            "name": link_name,
            "url": url,
            "direct_asset_url": url,
            "link_type": "package",
        })

print(json.dumps({
    "tag_name": tag,
    "name": f"{name} {version}",
    "description": description,
    "assets": {"links": links},
}))
PY
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
