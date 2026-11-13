#!/bin/sh
# Turns the Flutter Linux bundle into the four packages the updater knows:
#   dist/freesend-<version>-linux-x86_64.AppImage
#   dist/freesend-<version>-linux-x86_64.deb
#   dist/freesend-<version>-linux-x86_64.rpm
#   dist/freesend-<version>-linux-x86_64.tar.gz   (the raw bundle)
#
# Each tree gets a package-kind file so a running install can tell the updater
# which asset to download next time.
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
VERSION="${VERSION:-${CI_COMMIT_TAG:-}}"
VERSION="${VERSION#v}"
if [ -z "$VERSION" ]; then
  VERSION="$(sed -n 's/^version:[[:space:]]*\([^+]*\).*/\1/p' "$ROOT/pubspec.yaml")"
fi
# Architecture word used in the file names: x86_64 or aarch64. Flutter spells
# its build directory differently, and Debian calls the same CPU amd64.
ARCH="${ARCH:-x86_64}"
case "$ARCH" in
  x86_64) FLUTTER_ARCH=x64; DEB_ARCH=amd64 ;;
  aarch64) FLUTTER_ARCH=arm64; DEB_ARCH=arm64 ;;
  *)
    echo "Unsupported ARCH: $ARCH (expected x86_64 or aarch64)" >&2
    exit 1
    ;;
esac
BUNDLE="$ROOT/build/linux/$FLUTTER_ARCH/release/bundle"
PROJECT_NAME="${PROJECT_NAME:-freesend}"
NAME="${PROJECT_NAME}-${VERSION}-linux-${ARCH}"

if [ ! -x "$BUNDLE/free_send" ]; then
  echo "Linux bundle is missing. Run: flutter build linux --release" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$DIST"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

copy_bundle() {
  dest="$1"
  kind="$2"
  mkdir -p "$dest"
  cp -a "$BUNDLE/." "$dest/"
  printf '%s\n' "$kind" > "$dest/package-kind"
}

# Raw compiled app: the bundle exactly as Flutter emits it, plus its kind.
copy_bundle "$STAGE/bundle" "bundle"
tar -C "$STAGE/bundle" -czf "$DIST/${NAME}.tar.gz" .
echo "Wrote $DIST/${NAME}.tar.gz"

# Debian package installs the bundle to /opt/freesend and a launcher on PATH.
copy_bundle "$STAGE/deb/opt/freesend" "deb"
mkdir -p "$STAGE/deb/DEBIAN" "$STAGE/deb/usr/bin" "$STAGE/deb/usr/share/applications" "$STAGE/deb/usr/share/icons/hicolor/256x256/apps"
cat > "$STAGE/deb/usr/bin/freesend" <<'EOF'
#!/bin/sh
exec /opt/freesend/free_send "$@"
EOF
chmod 755 "$STAGE/deb/usr/bin/freesend"
cp "$ROOT/linux/packaging/freesend.desktop" "$STAGE/deb/usr/share/applications/freesend.desktop"
if [ -f "$ROOT/freesend.png" ]; then
  cp "$ROOT/freesend.png" "$STAGE/deb/usr/share/icons/hicolor/256x256/apps/freesend.png"
fi
INSTALLED_SIZE="$(du -sk "$STAGE/deb" | awk '{print $1}')"
cat > "$STAGE/deb/DEBIAN/control" <<EOF
Package: freesend
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${DEB_ARCH}
Maintainer: FreeSend <freesend@localhost>
Installed-Size: ${INSTALLED_SIZE}
Depends: libgtk-3-0, libayatana-appindicator3-1 | libappindicator3-1
Description: Direct, hotspot-only file transfer.
 No cloud, no accounts.
EOF
dpkg-deb --root-owner-group --build "$STAGE/deb" "$DIST/${NAME}.deb"
echo "Wrote $DIST/${NAME}.deb"

# RPM from the same /opt layout, without the Debian control directory.
copy_bundle "$STAGE/rpmroot/opt/freesend" "rpm"
mkdir -p "$STAGE/rpmroot/usr/bin" "$STAGE/rpmroot/usr/share/applications" "$STAGE/rpmroot/usr/share/icons/hicolor/256x256/apps"
cp "$STAGE/deb/usr/bin/freesend" "$STAGE/rpmroot/usr/bin/freesend"
cp "$ROOT/linux/packaging/freesend.desktop" "$STAGE/rpmroot/usr/share/applications/freesend.desktop"
cp "$ROOT/linux/runner/resources/app_icon.png" "$STAGE/rpmroot/usr/share/icons/hicolor/256x256/apps/freesend.png"
# No brace expansion here: /bin/sh on the CI image is dash, which would create
# one directory literally named "{BUILD,RPMS,SOURCES,SPECS,SRPMS}".
mkdir -p "$STAGE/rpmbuild/BUILD" "$STAGE/rpmbuild/RPMS" "$STAGE/rpmbuild/SOURCES" "$STAGE/rpmbuild/SPECS" "$STAGE/rpmbuild/SRPMS"
cat > "$STAGE/rpmbuild/SPECS/freesend.spec" <<EOF
Name: freesend
Version: ${VERSION}
Release: 1
Summary: Direct, hotspot-only file transfer
License: LicenseRef-FreeSend
BuildArch: ${ARCH}

%description
No cloud, no accounts.

%install
mkdir -p %{buildroot}
cp -a %{_sourcedir}/root/. %{buildroot}/

%files
/opt/freesend
/usr/bin/freesend
/usr/share/applications/freesend.desktop
/usr/share/icons/hicolor/256x256/apps/freesend.png
EOF
cp -a "$STAGE/rpmroot" "$STAGE/rpmbuild/SOURCES/root"
rpmbuild --define "_topdir $STAGE/rpmbuild" -bb "$STAGE/rpmbuild/SPECS/freesend.spec"
cp "$STAGE/rpmbuild/RPMS/$ARCH/"*.rpm "$DIST/${NAME}.rpm"
echo "Wrote $DIST/${NAME}.rpm"

# AppImage: the bundle is the AppDir. APPIMAGE is set by the runtime, which
# the updater prefers over package-kind.
copy_bundle "$STAGE/AppDir" "appimage"
cat > "$STAGE/AppDir/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/free_send" "$@"
EOF
chmod 755 "$STAGE/AppDir/AppRun"
cp "$ROOT/linux/packaging/freesend.desktop" "$STAGE/AppDir/freesend.desktop"
if [ -f "$ROOT/freesend.png" ]; then
  cp "$ROOT/freesend.png" "$STAGE/AppDir/freesend.png"
fi
TOOL="$STAGE/appimagetool"
if [ ! -x "$TOOL" ]; then
  curl --silent --show-error --location --fail \
    -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod 755 "$TOOL"
fi
ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" "$STAGE/AppDir" "$DIST/${NAME}.AppImage"
echo "Wrote $DIST/${NAME}.AppImage"
