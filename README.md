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
  for visual review.

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
