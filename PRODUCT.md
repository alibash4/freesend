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

Free Send moves files directly between devices over a local link. It exists so
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

- Android, iOS, Windows, Linux, and macOS. iOS cannot create a hotspot, so it
  joins the network the sender selects.
- Current baseline is one sender to multiple receivers, files and folders, over a
  TCP session found by UDP beacons or a pairing code. Protocol v2 adds folder
  paths, SHA-256 verification, sender-side pause/resume, and a v1 fallback.
- Hotspot creation is native on Android and Linux; Windows, macOS, and iOS use
  the network the user selects, with system guidance.
- History is local-only and capped.

Required for the fully-fledged pass, confirmed by the user:

- Core transfer hardening: folder picks, pause/resume, retry, background
  transfers, per-file status, and integrity verification.
- Group sharing: one sender streaming to multiple receivers in one session.
- Media and file browser: photos, videos, audio, documents, apps, and other
  files, with search and folder selection.
- Encryption and trusted devices: authenticated, encrypted local sessions with
  per-session trust.
- App/APK sharing on Android: list installed apps, extract the APK, send it,
  and offer the install flow on the receiver.

Explicitly out of scope:

- Clipboard/text and browser-based receive are not part of this pass.
- No app cleaner, ads, content feed, games, or remote-control suite.
- No cloud sync or account system.

Open decisions a builder must not invent:

- Protocol version 2 migration and backward compatibility.
- Encryption handshake and library choice.
- Android folder access and background-service implementation.
- How group sessions present multiple receivers and per-receiver progress.

## Brand Commitments

Name: Free Send. Promise: direct transfer, no cloud. The current restrained
accent-and-neutral visual system stays the baseline; the user chose features
first, so this pass does not replace the visual world.

## Evidence on Hand

Working Flutter app in this repository with send/receive controllers, hotspot
services, UDP discovery, a framed TCP protocol, local history, settings, and
tests. Protocol v2 supports multi-receiver sessions, folder-shaped writes,
SHA-256 checks, and sender-side pause/resume. Encryption/trusted devices and
Android app/APK sharing are not implemented.

## Product Principles

1. Direct and local: no upload, no account, no cloud dependency.
2. Transfer truth first: show real progress, speed, ETA, and per-file state.
3. Recover, do not restart: pause, resume, retry, and keep going in the
   background when the platform allows it.
4. One product across platforms: the same transfer model and vocabulary on a
   phone and a desktop.
5. Utility discipline: every added capability must make a transfer more
   capable, not turn the app into a content or cleaning suite.