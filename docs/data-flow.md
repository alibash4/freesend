# FreeSend data flow — full design

Status: proposal for review. No code has been written against it.
Scope: Android, Windows, Linux, macOS. iOS is a future delta (F1) and is not
designed for here.

--------------------------------------------------------------------------------
1. Frozen rules
--------------------------------------------------------------------------------

R1  The sender owns the radar and hunts.
R2  The receiver is the target.
R3  Phone -> phone: the receiver displays the QR, the sender scans it.
R4  Mixed phone/desktop: the desktop displays the QR, the mobile scans it.
    This holds in both directions, including desktop -> phone.
R5  Desktop -> desktop: no camera anywhere, so no QR. Radar only.
R6  Displaying a QR needs only a screen. Scanning needs a camera
    (Android, macOS only).
R7  A radar tap and a QR scan produce the identical authorization request on
    the receiver.
R8  Every device authorizes individually. No bytes move until that device
    accepts.
R9  The send control is a bottom sheet on mobile and a centered modal on
    desktop. Entries: Share to nearby / Scan a QR code / Send to a group.
R10 "Scan a QR code" is hidden on every desktop, including macOS, because the
    desktop shell never offers camera scanning. Desktops show two entries.

Derived invariants:

I1  The device displaying the QR hosts the link. A QR carries the host's
    credentials, so hosting and displaying are the same act.
    phone->phone      receiver displays -> receiver hosts
    phone<->desktop   desktop displays   -> desktop hosts (both directions)
    desktop->desktop  no QR             -> existing network, sender dials
I2  Whoever scans, dials. The mobile always scans, so the mobile always opens
    the TCP connection; in desktop->phone the receiver initiates and the sender
    waits.
I3  A device advertises on the radar only while its Receive screen is open.
    Radar contents = devices currently waiting in Receive. Nothing else appears.

--------------------------------------------------------------------------------
2. Platform capability table
--------------------------------------------------------------------------------

                 host hotspot   join hotspot   camera scanner
Android          yes            yes           yes
Linux            yes            yes           no
macOS            no             yes           yes (scanner only, see R10)
Windows          no             no            no

Consequences used throughout:

C1  Windows can neither create nor join a hotspot programmatically. Its only
    transport is an existing network. If another device hosts a hotspot, the
    Windows user joins it from the OS Wi-Fi menu.
C2  On desktop->desktop there is no QR (R5), so both devices must already share
    a network. The app cannot manufacture a link for them.
C3  A desktop never gets the camera entry (R10), even macOS.
C4  Linux has no camera, so a Linux sender cannot scan; Linux receivers display
    QR codes for phones to scan.

--------------------------------------------------------------------------------
3. Chain scenarios
--------------------------------------------------------------------------------

Notation: S = sender, R = receiver, H = who hosts, D = who dials, QR = who
displays it.

A. Android phone -> Android phone
   H = R (receiver). QR = R. Sender scans. D = S.
   Both on the sender's or receiver's hotspot depending on I1: receiver hosts,
   so receiver's hotspot name/password/address go in the QR.
   Permissions: nearby devices on the sender; receive-side grants on R.

B. Android phone -> Windows desktop
   H = R (desktop). QR = R (desktop shows it). Sender scans. D = S.
   Windows cannot host a hotspot (C1), so the desktop uses its current network
   and says so. The phone connects over that network; if the network isolates
   clients, this fails and the copy says why.
   Note: the desktop is hosting here in the sense of I1 (it displays and
   listens), but the link is a pre-existing network, not a created hotspot.

C. Android phone -> macOS desktop
   Same as B, except macOS is a valid hotspot host when it matters; in mixed
   pairs the desktop displays regardless.

D. Windows desktop -> Android phone
   H = S (desktop, because it displays). QR = S (desktop shows it). Receiver
   scans. D = R.
   The phone scans the desktop's QR, joins/dials, and the receiver is the one
   who initiates. Sender sits in "waiting". Accepted per A3 discussion:
   acceptable until a real problem appears.

E. macOS desktop -> Android phone
   Identical to D. The desktop displays and hosts.

F. Android phone -> Linux desktop
   Same as B. Linux can host a hotspot, so if the desktop is the host the phone
   joins it; the desktop still only displays.

G. Linux desktop -> Android phone
   Same as D/E.

H. Desktop -> desktop (any combination)
   No QR (R5). Both on the same existing network, or one hosts a hotspot the
   other joins via OS settings (only possible when a Linux host is involved).
   Radar only, plus typed pairing code as the fallback.

I. Any -> any, group variant
   Sender opens "Send to a group". Radar multi-select. Per-device consent, per-
   device state. No QR at all (C1 of group decisions).

J. iOS (future)
   Deferred. iOS cannot create a hotspot, so it is always a receiver-displayer
   or an existing-network peer. Not designed now.

--------------------------------------------------------------------------------
4. Screen-by-screen
--------------------------------------------------------------------------------

4.1 Home (sender)
    Send button opens the drawer/modal with three entries (two on desktop):
      Share to nearby / Scan a QR code (mobile only) / Send to a group.
    Container: bottom sheet, opens at medium detent, drag to expand (mobile);
    centered modal, single column ~400px wide, Close + Escape (desktop).
    Choosing an entry does not start anything by itself; it enters the matching
    send mode described below.

4.2 Sender, hunting view
    - Status line: "Looking for a device to receive these."
    - Radar sweeping; blips appear for every device advertising (I3).
    - Empty radar copy: "Nobody is ready yet — on the other device, open
      FreeSend and tap Receive." (F2 consequence.)
    - Blip tap -> authorization request to that device. Blip becomes pending.
    - Under the radar, the link "Connect by scanning a QR code instead"
      (mobile only; hidden on desktop per R10).
    - Per-target state shown after the request: pending / accepted /
      declined / offline.
    - Declined -> inline "Declined" with Try again (B2).
    - Sender drops or receiver drops -> small modal "Sender has gone offline"
      on the remaining side (B3), on all platforms.
    - Pending never expires (B1). It stays until accept, decline, cancel, or
      the peer disappearing.

4.3 Sender, scanning view
    Camera full screen, reticle, caption. Reads a QR, extracts host/port/
    instance id/name, then behaves exactly like a radar tap (R7): same
    authorization request, same receiver modal.
    Error copy for a non-FreeSend code: "That code is not from FreeSend."
    Error copy for an unreachable address: "That device isn't reachable on this
    link. Make sure both devices are on the same network."

4.4 Receiver, presenting view
    On open, permissions gate (Android), then automatically: bring up the link
    and advertise (E1). Then render one of two states:
      (a) QR panel — shown when the counterpart could have a camera, i.e.
          whenever this device is the one that should display under I1/R3/R4.
          Contents: device name, large QR, "Scan this from the other device",
          Copy code text button.
      (b) No-camera panel — desktop->desktop, or any case where no camera exists
          on the other side. Inline copy, no modal, no dead QR frame:
          "This device has no camera to scan a code, so there's nothing to
          scan. The other device will find this one by name — keep both on the
          same network."
    Leaving Receive stops advertising and tears down the link.
    Receivers do not need a "ready" toggle; being in this screen is the state.

4.5 Receiver, authorization modal
    Title: "Accept files from <name>?"
    Body: "<count> files · <size>".
    Actions: Decline / Accept. Optional unchecked "Remember this device" (B4).
    No timeout on the request (B1); the modal stays until answered or the
    sender disappears (B3).
    Accept -> transfer starts. Decline -> sender sees declined.

4.6 Sender, group view
    Radar list with checkboxes. "Send to N devices". Each target shows
    pending / accepted / sending / failed independently; one holdout does not
    block the others. No QR in group mode.
    Same protocol consent path, once per device.

4.7 Transfer views
    Unchanged in substance: progress ring, per-file rows, speed/ETA, pause,
    resume, cancel, per-receiver progress in group mode.

--------------------------------------------------------------------------------
5. Protocol mapping
--------------------------------------------------------------------------------

Existing frames: hello, session, accept, fileHeader, data, fileEnd,
transferEnd, ackFile, ackAll, error, cancel, pause, resume, fileStatus,
helloAck, helloConfirm, secure.

Changes:
P1  A sender's authorization request is explicit and precedes `session`.
    It carries sender name, file count, total size, and a request id.
P2  The receiver's accept is its own frame (the existing `accept` type),
    made mandatory: no fileHeader/data is sent before it arrives.
P3  Decline, cancel, and peer-offline are distinct outcomes the UI renders
    differently (B2/B3).
P4  Group = N independent request/accept exchanges on N channels; one
    failure does not abort the others.
P5  Trust-on-first-use: an accepted device with "Remember" stores the pinned
    identity (existing store) and skips the modal next time.
No new wire format beyond P1's request payload; the rest is sequencing.

QR payload (unchanged format, semantics now fixed):
  freesend://pair?v=1&ssid=<host>&pw=<password>&host=<ip>&port=<port>
          &name=<sender/receiver name>&pf=<platform>
The displayer's own credentials go in, because the displayer is the host (I1).
Non-literal IPs stay rejected for safety.
Direct-connect first (IP:port from the QR); on failure fall back to discovery
filtered by the instance id. No NAT traversal work is needed because every
scenario is on one local link.

--------------------------------------------------------------------------------
6. Failure and edge states
--------------------------------------------------------------------------------

E1  No camera (desktop)           entry hidden, not disabled (R10/D1).
E2  No hotspot capability          use existing network; say so; never offer
                                   "my hotspot".
E3  Windows joining a hotspot     app cannot do it; guide to OS Wi-Fi, then
                                   rely on discovery.
E4  Client isolation on the AP    discovery and direct connect both fail;
                                   copy: "This network blocks device-to-device
                                   traffic. Try a hotspot instead."
E5  Sender vanishes                receiver modal closes with
                                   "Sender has gone offline" (B3).
E6  Receiver never answers         pending stays; sender may cancel (B1).
E7  Receiver declines              inline declined + Try again (B2).
E8  Backgrounded / locked          Android foreground service keeps the
                                   transfer alive; consent already granted.
E9  QR stale / wrong interface     fall back to discovery by instance id;
                                   if still unreachable, E4-style copy.
E10 Resume after accept           partial files resume; unchanged behavior.

--------------------------------------------------------------------------------
7. Phases
--------------------------------------------------------------------------------

Phase 0  This document. Reviewed and approved before any code. Alone it ships
         nothing.

Phase 1  Foundation types: host/scanner/qr roles, per-peer auth state
         (pending/accepted/declined/offline), capability model.
         Pure Dart. Behavior unchanged. Analyze clean + tests green.

Phase 2  Protocol consent: P1-P5. Explicit request, mandatory accept, distinct
         decline/offline, N-way group consent, remember-device.
         Exit: tested; single-receiver verified on this machine.

Phase 3  Receiver screen: automatic link-up, QR vs no-camera state, inbound
         authorization modal. Sender untouched.
         Exit: receiver correct on all four platforms in tests.

Phase 4  Sender screen + radar ownership swap: radar to sender, blip tap issues
         request, scanning view, per-target states, receiver radar removed.
         Exit: real-device pass phone->phone and desktop->phone.

Phase 5  Drawer/modal container with entries, mobile sheet + desktop modal,
         desktop scan entry omitted. Group multi-select.
         Exit: all entries reachable; group works with mixed peers.

Phase 6  Platform gates, error copy, background/lock, QR staleness, resume
         after accept, desktop window 900x625 on launch. Manual QA checklist.
         Exit: failure paths tested per platform.

Phase 7  Ship: full suite, real-device matrix, artifacts for visual review.
         No commit without explicit approval at each phase boundary.

--------------------------------------------------------------------------------
8. Deliberately out of scope
--------------------------------------------------------------------------------

- Background advertising so idle devices appear on the radar (would need an
  always-on service; rejected with F2 as answered).
- Cross-network / relay / hole punching. All scenarios are one local link.
- iOS implementation.
- Rooms / shared-space group model. Chosen model is multi-recipient select.
