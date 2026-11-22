# Contributing

## Self-update mechanics

The app checks GitHub Releases for a newer build and installs it.

- **Settings → Updates → Check automatically** turns on a silent check each
  launch. A failure or an up-to-date app stays quiet.
- **Check for updates** always reports the outcome.
- When a release is found, a sheet shows the release notes and the download
  size. **Download update** pulls the asset, then **Install and restart**
  hands it to the OS installer and exits the app.

Releases are matched to the platform by a word in the asset name
(`android`, `linux`, `windows`, `macos`). Linux and Windows also carry a
format marker, Linux carries the architecture word (`x86_64`, `aarch64`),
and the app downloads the package that matches how it was installed:

| Asset name | File | Who gets it |
| --- | --- | --- |
| `FreeSend for Android (32-bit)` | armeabi-v7a APK | 32-bit phones |
| `FreeSend for Android (64-bit)` | arm64-v8a APK | 64-bit phones |
| `FreeSend for Android (universal)` | all ABIs, including emulators | x86_64, or when no split matches |
| `FreeSend for Linux x86_64 (AppImage)` | `.AppImage` for x86_64 | x86_64 AppImage (`APPIMAGE` is set) |
| `FreeSend for Linux x86_64 (deb)` | `.deb` for amd64 | Debian/Ubuntu package (`package-kind` is `deb`) |
| `FreeSend for Linux x86_64 (rpm)` | `.rpm` for x86_64 | Fedora/RHEL package (`package-kind` is `rpm`) |
| `FreeSend for Linux x86_64 (bundle)` | `.tar.gz` of the raw x86_64 build | an unpacked `free_send` bundle |
| `FreeSend for Linux aarch64 (AppImage)` | `.AppImage` for aarch64 | arm64 AppImage (`APPIMAGE` is set) |
| `FreeSend for Linux aarch64 (deb)` | `.deb` for arm64 | Debian/Ubuntu package on arm64 |
| `FreeSend for Linux aarch64 (rpm)` | `.rpm` for aarch64 | Fedora/RHEL package on arm64 |
| `FreeSend for Linux aarch64 (bundle)` | `.tar.gz` of the raw aarch64 build | an unpacked `free_send` bundle on arm64 |
| `FreeSend for Windows (exe)` | `.zip` containing `free_send.exe` | Windows |
| `FreeSend for macOS (dmg)` | `.dmg` disk image | macOS |

The Android ABI is read from the device, so a 64-bit phone downloads the
smaller split instead of the universal APK. On Linux the architecture is
read from the running process, so an arm64 machine downloads the aarch64
build and never the x86_64 one. A Linux install that cannot find its own
format falls back to the raw bundle, then the AppImage. Installing a deb
or rpm asks the system for permission (`pkexec`). An AppImage, the raw
bundle, and the Windows zip replace themselves after the app exits and
then relaunch.

Android requires the user to grant *install unknown apps* to FreeSend; the
install bridge checks for it and points at the system page when it is
missing. Android must also be signed with the same key as the installed
copy, or the installer refuses the update.

## Releasing

Push a `v*` tag (`git tag v1.2.3 && git push origin v1.2.3`) and the
`release` workflow builds every package — Android splits, Linux x86_64 and
aarch64, Windows and macOS — then attaches them to the GitHub release
through `scripts/attach_release_asset.sh`. The script creates the release
itself when the tag went out bare (with generated release notes), so a
bare tag still publishes; create the release first (**Releases → Draft a
new release → choose the tag**) if you want your own notes.

Asset names on the release are the names in the table above plus the real
file extension (for example `FreeSend for Android (64-bit).apk`); the
updater matches on those names. A missing package is skipped while the
rest still attach. Publishing uses the job's `GITHUB_TOKEN`
(`contents: write`), so no release token secret is needed.

One thing must be configured once — **a signing keystore**. Android must
be signed with one stable key, or it refuses to install an update over an
existing copy. Locally, create `android/key.properties` (gitignored):

```
STORE_FILE=/absolute/path/to/freesend.keystore
STORE_PASSWORD=...
KEY_ALIAS=freesend
KEY_PASSWORD=...
```

Generate the keystore once and keep it somewhere safe; losing it means
no further updates to installed copies:

```bash
keytool -genkeypair -v -keystore ~/freesend.keystore \
  -alias freesend -keyalg RSA -keysize 4096 -validity 10000
```

For CI, add the same key as four Actions secrets (Settings → Secrets
and variables → Actions) and the workflow writes `key.properties`
itself:

| Variable | Value |
| --- | --- |
| `SIGNING_KEYSTORE_BASE64` | `base64 -w0 ~/freesend.keystore` |
| `SIGNING_STORE_PASSWORD` | keystore password |
| `SIGNING_KEY_ALIAS` | `freesend` |
| `SIGNING_KEY_PASSWORD` | key password |

Without these the build falls back to debug signing, which is fine for
testing but will not update a properly signed release.
