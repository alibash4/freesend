# FreeSend data flow — manual QA checklist

Phase 6 deliverable. Run on real devices; the automated suite covers the
mechanisms, not the radios or the OS prompts.

## Before you start
- Note the app version and the two device platforms for each pass.
- A running second instance of FreeSend on the same machine answers discovery
  packets; quit it before testing locally (tests use their own port).
- Check `adb logcat` / Console for hotspot errors on Android.

## Window and shell
- [ ] Desktop opens at 900x625, centered, every launch.
- [ ] It cannot be resized smaller than 900x625.
- [ ] Restoring from the tray brings the same window back without shrinking.
- [ ] Send control is a bottom sheet on Android/iOS-sized screens and a
      centered dialog on desktop; Close and Escape dismiss the dialog.

## Pairing rules per platform pair
- [ ] Android phone -> Android phone: receiver shows QR, sender scans, sender
      joins the receiver's hotspot in-app, receiver gets the accept modal.
- [ ] Android phone -> Linux/macOS desktop: phone hosts, desktop joins in-app,
      desktop gets the accept modal.
- [ ] Android phone -> Windows desktop: desktop is told to join manually from
      the Wi-Fi flyout, then the transfer continues in-app. If both are already
      on one Wi-Fi, local-Wi-Fi mode is used instead (Windows shows its code).
- [ ] Linux/macOS desktop -> Android phone: phone hosts, desktop joins in-app,
      phone gets the accept modal after the sender taps.
- [ ] Desktop -> desktop: no QR anywhere; the inline "nothing to scan" copy
      shows; radar or typed code connects.

## Consent
- [ ] Nothing transfers before Accept; Decline leaves the sender on
      "Declined" with Try again.
- [ ] A pending request does not expire while the peer is there.
- [ ] Sender disappearing closes the receiver modal with
      "Sender has gone offline".
- [ ] Group: each receiver answers separately; one holdout does not block the
      others.

## Discovery and fallback
- [ ] Radar lists only devices sitting in Receive; leaving Receive removes the
      blip within a few seconds.
- [ ] Desktop "Unable to connect? Use local Wi-Fi network" reveals an address
      QR that a phone can scan; toggling back returns to the join prompt.
- [ ] QR staleness: kill the receiver after scanning; the sender must fall back
      to the signal filtered by instance id and report unreachable rather than
      hang.
- [ ] Client-isolated network: both paths fail and the copy says the network
      blocks device-to-device traffic.

## Hotspot resilience (the riskiest part)
- [ ] Android keeps the hotspot alive with the screen off and the app
      backgrounded; a lock screen mid-transfer must not kill it.
- [ ] If the hotspot dies, the error names the hotspot specifically.
- [ ] Brief Wi-Fi drops resume instead of restarting (recovery sidecar).
- [ ] Windows: joining the hotspot drops the laptop's previous Wi-Fi; say so
      before it happens, and never claim internet over a local-only hotspot.

## Copy review
- [ ] No "ready" wording anywhere; the radar empty state tells the user to open
      Receive on the other device.
- [ ] Scan entry absent on every desktop including macOS.
- [ ] Declined / unreachable / offline read as states, not as error dialogs.
