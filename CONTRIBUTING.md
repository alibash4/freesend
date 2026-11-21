# Contributing

## Self-update mechanics

The app checks GitLab Releases for a newer build and installs it.

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

Create the tag first, then the release. In GitLab: **Repository → Tags →
New tag** (or `git tag v1.2.3 && git push origin v1.2.3`), which triggers
the pipelines; then **Deploy → Releases → New release → Create from
existing tag** and write the notes. The builds take far longer than it
takes to create the release, so every asset finds its release when it
finishes — but if a tag ever goes out with no release, the attach steps
fail and you create the release afterwards and re-run them.

Both pipelines attach assets under the names in the table above and leave
your release notes alone; a missing package (for example the Windows zip,
when no Windows runner is available) is skipped while the rest still
attach. The GitLab `release:publish` job additionally creates a release
for a bare tag using the commit log since the previous tag; the GitHub
Actions attach step does not — it expects the release to exist.

Pushing to `main` runs the `test` job only — analyze plus the test suite,
no packages. A full build matrix costs roughly 45 runner-minutes against a
finite monthly compute quota, so packages are built on tags: `build:apk`
(analyze, test, the two ABI splits and the universal APK), `build:linux`
(AppImage, deb, rpm and the raw tar.gz), `build:linux:arm64` (the same four
for aarch64 on a hosted Arm runner) and `build:windows` (a zip of
`free_send.exe` and its DLLs, allowed to fail when no Windows runner is
available).

The `release` GitHub Actions workflow builds every package on `v*` tags —
Android splits, Linux x86_64 and aarch64, Windows and macOS — and attaches
them to the same GitLab release through `scripts/attach_release_asset.sh`.
It needs the `RELEASE_TOKEN` repository secret on GitHub, plus the four
`SIGNING_*` secrets for the Android keystore. GitLab CI remains as the
release host (the updater reads GitLab Releases) and its own tag pipeline
still builds the same packages, so disable it if the Actions builds should
be the only source.

Two things must be configured once:

1. **`RELEASE_TOKEN`** — a project access token with the `api` scope, set
   as a CI/CD variable (Settings → CI/CD → Variables). Creating a release
   in the UI does not remove the need for this: the job still has to upload
   the APK and attach it, and `CI_JOB_TOKEN` cannot do that. Mark the
   variable **masked**.

   Also check **Protect variable**. A protected variable only reaches
   pipelines on protected branches or tags. If you leave it off, every
   pipeline can see it. If you turn it on, you must also protect your
   release tags (Settings → Repository → Protected tags, rule `v*`) or the
   tag pipeline will not receive the token and the job will fail with a
   401.

2. **A signing keystore** — one stable key, or Android refuses to install
   an update over an existing copy. Locally, create
   `android/key.properties` (gitignored):

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

   For CI, add the same key as four CI/CD variables and the pipeline
   writes `key.properties` itself:

   | Variable | Value |
   | --- | --- |
   | `SIGNING_KEYSTORE_BASE64` | `base64 -w0 ~/freesend.keystore` |
   | `SIGNING_STORE_PASSWORD` | keystore password |
   | `SIGNING_KEY_ALIAS` | `freesend` |
   | `SIGNING_KEY_PASSWORD` | key password |

   Without these the build falls back to debug signing, which is fine for
   testing but will not update a properly signed release.
