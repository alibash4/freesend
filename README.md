# Free Send

A free, open implementation of the SHAREit idea: move files between two devices
over a **direct Wi-Fi hotspot**, with no cloud, no account, no upload limit and
no per-file size ceiling. Built in Flutter for **Android, Windows, Linux and
macOS**.

Transfer speed is the whole point, so the transport is a raw TCP socket with
framed 512 KiB chunks instead of an HTTP file upload. Nothing is re-encoded,
compressed or staged — bytes are read from the source file and written to the
destination file as they arrive.

```
sender                                            receiver
──────                                            ────────
LocalOnlyHotspot  ─────── WPA2 hotspot ───────▶   joins the hotspot
TCP :47811 (ServerSocket)                         TCP :47811 (client)
broadcast beacons :47810  ───── UDP ─────────▶    session list
streams frames of file bytes  ──── Wi-Fi ────▶    writes straight to disk
```

## Platform support

| Capability                              | Android | Linux | Windows | macOS |
| --------------------------------------- | ------- | ----- | ------- | ----- |
| Host a session and send files           | ✅      | ✅    | ✅      | ✅    |
| Create the hotspot from inside the app  | ✅      | ✅ (NetworkManager) | manual (OS Mobile hotspot) | manual (OS Internet Sharing) |
| Join a hotspot from inside the app      | ✅      | ✅    | manual (Wi-Fi settings) | ✅ (`networksetup`) |
| Receive files                           | ✅      | ✅    | ✅      | ✅    |
| Scan a pairing QR code with the camera  | ✅      | —     | —       | ✅    |

Minimum Android is 8.0 (API 26) because `WifiManager.startLocalOnlyHotspot` is
needed to create a hotspot without user interaction. On Windows and macOS the
OS does not expose hotspot creation to applications, so the app shares over the
network the device is already on and tells you where to enable a system hotspot
if you want the fastest link.

iOS is intentionally not targeted: Apple does not allow an app to create a
hotspot.

## How it works

- `lib/services/hotspot/` — platform hotspot control. Android goes through a
  `MethodChannel` to `HotspotBridge.kt` (`LocalOnlyHotspot` to host,
  `WifiNetworkSpecifier` to join, plus `bindProcessToNetwork` so sockets route
  over the hotspot instead of mobile data). Linux shells out to `nmcli`; macOS
  joins with `networksetup`; Windows falls back to guided steps.
- `lib/services/transfer/` — the wire protocol and both endpoints.
  - `protocol.dart`: `[type:u8][length:u32][payload]` frames, JSON for control
    and raw bytes for file data.
  - `frame_channel.dart`: socket ⇄ frame pump with a 4 MiB write buffer, so the
    sender never awaits a syscall per chunk.
  - `transfer_host.dart` / `transfer_client.dart`: handshake, manifest, file
    selection, then a single ordered stream of file bytes.
- `lib/services/discovery_service.dart` — the host broadcasts a session beacon
  on UDP `:47810`; the receiver lists whatever answers. Beacons leave through
  the hotspot interface (bound to the AP address) and are refreshed every 2s.
- `lib/state/` — `SendController` / `ReceiveController` own the hotspot, the
  socket server/client, aggregate progress, smoothed speed and history records.
- `lib/ui/` — Material 3 UI: content sits on the bare page (pure white, or
  `#1C1C1C` in dark), neutral greys, one `#1E90FF` accent. Grouped sections get
  a soft neutral fill rather than a bordered card, and icons come from Lucide at
  2px stroke via `lib/theme/app_icons.dart`.
- `lib/theme/` — colours, type scale and the icon map, so the palette and the
  icon stroke are each defined in one place.

### Protocol

1. Client → host `HELLO {v, name, platform}`.
2. Host → client `SESSION {v, name, files[], totalBytes}`.
3. Client → host `ACCEPT {ids[]}` (a subset is fine).
4. Per file: host sends `FILE_HEADER`, then `DATA` frames of 512 KiB, then
   `FILE_END`. The receiver writes sequentially and verifies the byte count.
5. Host sends `TRANSFER_END`; receiver answers `ACK_ALL` and the host closes.

TCP already guarantees ordering and delivery, so the protocol deliberately has
no per-chunk acknowledgement — that is what keeps the link saturated.

## Running

```bash
flutter pub get
flutter run -d <device>          # android / linux / windows / macos
flutter build apk --release      # or build linux / windows / macos
```

Two devices: on one press **Send**, pick files, and scan the QR code it shows
with the other device (**Receive** → *Scan pairing code*). The code carries the
hotspot name, password and the sender's address, so the receiver joins and
connects in one step.

No camera (Windows or Linux receivers, or a code sent through a chat app)? Tap
*Copy code* on the sender and *Enter code* on the receiver, join the hotspot from
the system Wi-Fi menu, or use *Connect by address*.

Received files go to `Downloads/Free Send` on desktop and to the app's external
files directory on Android (changeable in Settings).

## Updating

The app can check GitLab Releases for a newer build and install it.

- **Settings → Updates → Check automatically** turns on a silent check each
  launch. A failure or an up-to-date app stays quiet.
- **Check for updates** always reports the outcome.
- When a release is found, a sheet shows the release notes and the download
  size. **Download update** pulls the asset, then **Install and restart** hands
  it to the OS installer and exits the app.

Releases are matched to the platform by a name suffix on the release asset
(`android`, `linux`, `windows`, `macos`), so one release can carry all four
builds.

Android releases carry three assets, and the app picks the one for its own ABI:

| Asset | Contents |
| --- | --- |
| `Free Send for Android (32-bit)` | armeabi-v7a |
| `Free Send for Android (64-bit)` | arm64-v8a |
| `Free Send for Android` | universal: armeabi-v7a, arm64-v8a and x86_64 |

The ABI is read from the device, so a 64-bit phone downloads the 26 MB build
instead of the 69 MB universal one. x86_64 (emulators) has no split and falls
back to the universal APK.

Android requires the user to grant *install unknown apps* to Free Send; the
install bridge checks for it and points at the system page when it is missing.
Every platform must be signed with the same key as the installed copy or the
installer refuses the update.

## Releasing

Create the release first, then let the pipeline attach the binary to it.

1. **Make the release** in GitLab: Deploy → Releases → New release, pick a tag
   (or type `v1.2.3` to create it), write the release notes, and save. Creating
   the tag is what triggers the pipeline.
2. The `release:publish` job builds the APKs, uploads them, and **attaches
   them to that release** as "Free Send for Android (32-bit)",
   "(64-bit)" and the universal build. Your release notes are left alone.
3. If a tag has no release at all, the job creates one for you, using the commit
   log since the previous tag as the notes.

The build job builds only the ABI splits on `main` to keep a push cheap, and
adds the universal APK on tags.

Two things must be configured once:

1. **`RELEASE_TOKEN`** — a project access token with the `api` scope, set as a
   CI/CD variable (Settings → CI/CD → Variables). Creating a release in the UI
   does not remove the need for this: the job still has to upload the APK and
   attach it, and `CI_JOB_TOKEN` cannot do that. Mark the variable **masked**.

   Also check **Protect variable**. A protected variable only reaches pipelines
   on protected branches or tags. If you leave it off, every pipeline can see
   it. If you turn it on, you must also protect your release tags
   (Settings → Repository → Protected tags, rule `v*`) or the tag pipeline
   will not receive the token and the job will fail with a 401.

2. **A signing keystore** — one stable key, or Android refuses to install an
   update over an existing copy. Locally, create `android/key.properties`
   (gitignored):

   ```
   STORE_FILE=/absolute/path/to/freesend.keystore
   STORE_PASSWORD=...
   KEY_ALIAS=freesend
   KEY_PASSWORD=...
   ```

   Generate the keystore once and keep it somewhere safe; losing it means no
   further updates to installed copies:

   ```bash
   keytool -genkeypair -v -keystore ~/freesend.keystore \
     -alias freesend -keyalg RSA -keysize 4096 -validity 10000
   ```

   For CI, add the same key as four CI/CD variables and the pipeline writes
   `key.properties` itself:

   | Variable | Value |
   | --- | --- |
   | `SIGNING_KEYSTORE_BASE64` | `base64 -w0 ~/freesend.keystore` |
   | `SIGNING_STORE_PASSWORD` | keystore password |
   | `SIGNING_KEY_ALIAS` | `freesend` |
   | `SIGNING_KEY_PASSWORD` | key password |

   Without these the build falls back to debug signing, which is fine for
   testing but will not update a properly signed release.

## Tests

```bash
flutter test
```

- `test/transfer_test.dart` drives the real socket protocol on localhost:
  multi-file transfer with byte-for-byte verification, subset selection, frame
  reassembly across arbitrary TCP boundaries, and a peer that disconnects
  mid-transfer (must surface an error, not hang).
- `test/pairing_test.dart` round-trips the pairing payload (including awkward
  SSIDs and passwords), and checks that foreign QRs, unknown versions, out-of-
  range ports and hostnames are refused.
- `test/ui_render_test.dart` renders the actual screens at phone size and fails
  on layout overflow or missing widgets; it also writes PNGs to `artifacts/`
  for visual review. It covers the update sheet end to end against a stubbed
  release API.
- `test/update_test.dart` checks release parsing, platform asset selection,
  version comparison, download progress and partial-file cleanup.

## Known limitations

- Hotspots created by `LocalOnlyHotspot` have no internet, by design. Expect the
  OS to label the connection "no internet".
- Android randomises hotspot names on some versions; always read the name from
  the sending device's screen.
- Camera scanning needs the `mobile_scanner` plugin, which has no Windows or
  Linux implementation; those receivers type or paste the code instead.
- The pairing code is not authenticated: someone on the same hotspot could read
  it off the sender's screen. It only grants access to the files being shared in
  that session.
- Transfers resume from scratch if the link drops — there is no offset/resume
  negotiation yet.
- Android's hotspot password is generated by the OS and cannot be chosen.
