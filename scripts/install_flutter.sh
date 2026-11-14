#!/bin/sh
# Install a pinned Flutter SDK for CI.
#
# The cirruslabs Flutter image is used only for its Android SDK and system
# packages: its newest tag is 3.44.0. The official Linux x86_64 tarball is used
# on Intel runners; arm64 runners clone the matching Flutter tag and let the
# tool fetch its own Dart SDK.
set -eu

VERSION="${FREESEND_FLUTTER_VERSION:-${FLUTTER_VERSION:-3.50.0}}"
ROOT="${FREESEND_FLUTTER_ROOT:-/opt/flutter-$VERSION}"
ARCHIVE="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${VERSION}-stable.tar.xz"

if [ -x "$ROOT/bin/flutter" ]; then
  git config --global --add safe.directory "$ROOT"
  "$ROOT/bin/flutter" --version
  exit 0
fi

mkdir -p "$(dirname "$ROOT")"
case "$(uname -m)" in
  x86_64 | amd64)
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL --retry 3 -o "$tmp/flutter.tar.xz" "$ARCHIVE"
    tar -xf "$tmp/flutter.tar.xz" -C "$tmp"
    rm -rf "$ROOT"
    mv "$tmp/flutter" "$ROOT"
    ;;
  aarch64 | arm64)
    git clone --depth 1 --branch "$VERSION" \
      https://github.com/flutter/flutter.git "$ROOT"
    ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

# The official tarball keeps the ownership of whatever machine packed it, so
# on the runner the SDK's .git belongs to a different uid and git refuses to
# touch it. Whitelisting the directory is what git itself suggests, and it also
# covers the flutter commands that run later in the job.
git config --global --add safe.directory "$ROOT"

"$ROOT/bin/flutter" --version