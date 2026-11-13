# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

People moving files between their own devices, or to someone standing nearby,
when the internet, a cloud account, or a cable is unavailable or unwanted.
Primary surfaces are Android phones and iPhones, plus Windows, Linux, and macOS
desktops.

## Product Purpose

FreeSend moves files directly between devices over a local link. It exists so
a transfer does not depend on an account, an upload, a subscription, or a
content feed. Success is a predictable, resumable transfer that arrives intact
and works the same way on every supported platform.

## Positioning

Direct local transfer with no cloud and no account: the sender hosts, the
receiver connects, and the bytes never leave the local link. The product is a
utility, not a media app. It must not grow an app cleaner, ad surface, content
feed, game, or remote-control suite to look like a super-app.

## Operating Context

Used at home, in an office, or while travelling: a phone and a laptop on the
same hotspot, a group of phones around a table, or two desktops on the same
Wi-Fi. Transfers are often large (video, app bundles, project folders) and are
expected to survive a backgrounded app, a locked screen, or a brief Wi-Fi
blip. The Windows and Linux desktop app can run in the tray; macOS uses the
Dock.

## Capabilities and Constraints

Confirmed product facts:

- Android, Windows, Linux, and macOS. The iOS target was dropped; Apple does
  not allow an app to create a hotspot and the platform was removed from the
  build.
- Current baseline is one sender to multiple receivers, files and folders, over a
  TCP session found by UDP beacons or a pairing code. Protocol v3 adds folder
  paths, SHA-256 verification, sender-side pause/resume, reconnect/resume,
  per-file retry, X25519 + AES-256-GCM encryption, and pinned device identities.
  A v1/v2 plaintext fallback remains for older peers.
- Hotspot creation is native on Android and Linux; Windows and macOS use the
  network the user selects, with system guidance.
- History is local-only and capped.

Implemented in the fully-fledged pass:

- Core transfer hardening: folder picks, pause/resume, reconnect/resume with a
  recovery sidecar, per-file retry, Android foreground-service background
  transfers, per-file status, and SHA-256 verification.
- Group sharing: one sender streaming to multiple receivers in one session.
- Media and file browser: photos, videos, audio, documents, installed app
  bundles, recents, search, and Android Storage Access Framework folders.
- Encryption and trusted devices: X25519 key exchange, AES-256-GCM frames,
  Ed25519 device signatures, and trust-on-first-use pinning.
- App/APK sharing on Android: list installed apps, extract the APK, send it,
  and offer the install flow on the receiver.

Explicitly out of scope:

- Clipboard/text and browser-based receive are not part of this pass.
- No app cleaner, ads, content feed, games, or remote-control suite.
- No cloud sync or account system.

Resolved implementation decisions:

- Protocol v3 is the current wire format; v1/v2 peers fall back to plaintext.
- Encryption uses `cryptography` (X25519, HKDF-SHA256, AES-256-GCM, Ed25519).
- Android folders granted through the Storage Access Framework are copied into
  the app cache by `SafBridge.kt`; a foreground service with a data-sync type
  keeps transfers alive in the background.
- Group sessions show each receiver as a peer row with per-receiver progress.

## Brand Commitments

Name: FreeSend. Promise: direct transfer, no cloud. The current restrained
accent-and-neutral visual system stays the baseline; the user chose features
first, so this pass does not replace the visual world.

## Evidence on Hand

Working Flutter app in this repository with send/receive controllers, hotspot
services, UDP discovery, a framed TCP protocol, local history, settings, and
tests. Protocol v3 supports multi-receiver sessions, folder-shaped writes,
SHA-256 checks, sender/receiver pause, reconnect/resume, per-file retry,
encryption, pinned identities, an Android foreground service, a media browser,
and app/APK sharing. The Android debug APK builds against Flutter 3.50 / Gradle
9.5 / AGP 9.3.1.

## Product Principles

1. Direct and local: no upload, no account, no cloud dependency.
2. Transfer truth first: show real progress, speed, ETA, and per-file state.
3. Recover, do not restart: pause, resume, retry, and keep going in the
   background when the platform allows it.
4. One product across platforms: the same transfer model and vocabulary on a
   phone and a desktop.
5. Utility discipline: every added capability must make a transfer more
   capable, not turn the app into a content or cleaning suite.