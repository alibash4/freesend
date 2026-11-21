# FreeSend

<p align="center">
  <img src="docs/alpha-banner.svg" alt="Alpha" width="100%">
</p>

Free, open-source file transfer between two devices: no cloud, no account,
no upload limits, no per-file size ceiling. Built in Flutter for Android,
Windows, Linux and macOS.

The transport is a raw TCP socket with framed 512 KiB chunks — files stream
to disk as they arrive, never re-encoded, compressed or staged.

```
sender                                            receiver
──────                                            ────────
LocalOnlyHotspot  ─────── WPA2 hotspot ───────▶   joins the hotspot
TCP :47811 (ServerSocket)                         TCP :47811 (client)
broadcast beacons :47810  ───── UDP ─────────▶    session list
streams frames of file bytes  ──── Wi-Fi ────▶    writes straight to disk
```

## Platform support

| Capability                             | Android | Linux | Windows | macOS |
| -------------------------------------- | ------- | ----- | ------- | ----- |
| Host a session and send files          | ✅      | ✅    | ✅      | ✅    |
| Create the hotspot from inside the app | ✅      | ✅ (NetworkManager) | manual (OS hotspot) | manual (OS Internet Sharing) |
| Join a hotspot from inside the app     | ✅      | ✅    | manual (Wi-Fi settings) | ✅ (`networksetup`) |
| Receive files                          | ✅      | ✅    | ✅      | ✅    |
| Scan a pairing QR code with the camera | ✅      | —     | —       | ✅    |
| System tray icon                       | —       | ✅    | ✅      | —     |

- Minimum Android is 8.0 (API 26).
- Windows and macOS cannot create hotspots programmatically, so the app
  shares over the current network and points you at the system hotspot
  settings for the fastest link.
- Windows and Linux show a tray icon while running (GNOME needs the
  AppIndicator extension); Linux needs `libayatana-appindicator3` at build
  and run time. macOS uses the Dock normally.
- iOS is not supported: Apple does not allow apps to create hotspots.

## How it works

- `lib/services/hotspot/` — platform hotspot control. Android goes through a
  `MethodChannel` to `HotspotBridge.kt` (`LocalOnlyHotspot` to host,
  `WifiNetworkSpecifier` to join); Linux shells out to `nmcli`; macOS joins
  with `networksetup`; Windows falls back to guided steps.
- `lib/services/transfer/` — the wire protocol and both endpoints:
  `[type:u8][length:u32][payload]` frames, JSON for control and raw bytes for
  file data, a 4 MiB write buffer so the sender never awaits per chunk.
- `lib/services/discovery_service.dart` — the host broadcasts a session
  beacon on UDP `:47810`; receivers list whatever answers.
- `lib/state/` — `SendController` / `ReceiveController` own the hotspot,
  sockets, aggregate progress, speed and history.
- `lib/ui/` and `lib/theme/` — Material 3 UI; colours, type scale and the
  UIcons map are each defined in one place.

### Protocol

Frames are `[type:u8][length:u32][payload]`; control frames carry JSON and
data frames carry raw bytes.

1. Client → host `hello` — protocol version, device name, platform, an
   ephemeral X25519 public key and a salt.
2. Host → client `helloAck` — its ephemeral key plus an Ed25519 signature
   over that key, the salt and the host's instance id. The receiver pins the
   sender on first contact and refuses a later change.
3. Both sides derive the same key (X25519, then HKDF-SHA256) and switch to
   AES-256-GCM. Every frame after this travels in a `secure` envelope.
4. Host → client `session` — the manifest: file ids, names, sizes and
   folder layout.
5. Client → host `accept` — the selected ids, plus resume offsets from an
   earlier partial attempt.
6. Per file: `fileHeader`, `data` frames of 512 KiB, then `fileEnd` carrying
   the SHA-256 of the whole file. The receiver answers `ackFile`.
7. Host → client `transferEnd`; the receiver answers `ackAll` and the host
   closes.

TCP already guarantees ordering and delivery, so the protocol deliberately
has no per-chunk acknowledgement — that is what keeps the link saturated.
Either side can pause: the sender stops reading, and the receiver stops
draining the socket so TCP backpressure does the work.

## Running

```bash
flutter pub get
flutter run -d <device>          # android / linux / windows / macos
flutter build apk --release      # or build linux / windows / macos
```

Two devices: on one press **Send**, pick files, and scan the QR code it
shows with the other device (**Receive** → *Scan pairing code*). The code
carries the hotspot name, password and the sender's address, so the
receiver joins and connects in one step.

No camera (Windows or Linux receivers, or a code sent through a chat app)?
Tap *Copy code* on the sender and *Enter code* on the receiver, join the
hotspot from the system Wi-Fi menu, or use *Connect by address*.

Received files go to `Downloads/FreeSend` on desktop and to the app's
external files directory on Android (changeable in Settings).

## Updating

The app checks GitLab Releases for a newer build and can download and
install it — see **Settings → Updates**. Release and CI setup for
maintainers is in [CONTRIBUTING.md](CONTRIBUTING.md).

## Tests

```bash
flutter test
```

- `test/transfer_test.dart` drives the real socket protocol on localhost:
  multi-file transfer with byte-for-byte verification, subset selection,
  frame reassembly across arbitrary TCP boundaries, and a peer that
  disconnects mid-transfer.
- `test/pairing_test.dart` round-trips the pairing payload and checks that
  foreign QRs, unknown versions, out-of-range ports and hostnames are
  refused.
- `test/ui_render_test.dart` renders the actual screens at phone size and
  fails on layout overflow; it also writes PNGs to `artifacts/` for visual
  review.
- `test/update_test.dart` checks release parsing, platform asset selection,
  version comparison, download progress and partial-file cleanup.

## License

FreeSend is free software under the GNU Affero General Public License v3 —
see [LICENSE](LICENSE).
