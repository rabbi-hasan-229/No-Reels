# Contributing to No-Reels

Thank you for contributing to **No-Reels**! Our goal is to keep the app fast, lightweight, 100% offline, and compatible with both open-source distributions (GitHub / F-Droid / IzzyOnDroid) and the Google Play Store.

## Core Principles

1. **100% Offline — Zero Network, Zero Server, Zero Telemetry:** Never add `android.permission.INTERNET`, backend calls, analytics SDKs, or external network dependencies.
2. **Non-Commercial License Compliance:** All contributions are licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE) and may not introduce commercial dependencies, ads, or monetization hooks.
3. **Zero Database Bloat:** Keep state persistence inside `NoDoomPrefs.kt` (flat `SharedPreferences` with in-memory static caching) so `AccessibilityService` callbacks never block on disk I/O.
4. **Surgical Blocking Only:** Detection rules in `FeedScanner.kt` must block only short-form video feeds (Shorts / Reels / TikTok player) while keeping DMs, messaging, subscriptions, and normal app navigation working.

## Project Structure

- `android/app/src/main/kotlin/com/nodoom/nodoom/`
  - `NoDoomAccessibilityService.kt`: Real-time event loop (`0ms` leading-edge scan, `750ms` decoupled fingerprint dwell timer, `350ms` back cooldown).
  - `FeedScanner.kt`: Surgical view-ID and structural layout detectors for YouTube, Instagram, Facebook, and TikTok.
  - `ReelFingerprintDetector.kt`: 6-byte SHA-256 `creator|caption` fingerprinting with comment-sheet pause detection.
  - `OverlayController.kt`: Camera-wrapping top Dynamic Island counter, TikTok bounded video player cover, Full-App Block screen, and minimal floating Strict Lock card.
  - `NoDoomPrefs.kt`: In-memory + `SharedPreferences` state store.
- `lib/`
  - `screens/home_screen.dart`: Main dashboard, daily exposure summary, and platform setup sheet.
  - `screens/settings_screen.dart`: Minimal settings with Google Play prominent disclosures.
  - `screens/emergency_challenge_screen.dart`: 3-method Emergency Unlock picker (`Make a Walk`, `Read Book`, `Hard Math` MCQ).

## Submitting a Pull Request

1. Run static analysis and unit tests:
   ```bash
   flutter analyze
   flutter test
   ```
2. Verify the Android build succeeds:
   ```bash
   flutter build apk --debug
   ```
3. Open a Pull Request describing the target app version tested if updating `FeedScanner.kt` detection rules.
