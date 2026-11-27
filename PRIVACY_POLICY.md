# Privacy Policy for No-Reels

**Effective Date:** November 27, 2026

**No-Reels** is an open-source, 100% offline Android application designed to help users block short-form video feeds (YouTube Shorts, Instagram Reels, Facebook Reels, and TikTok videos) and track daily short-form screen time.

## 1. Zero Data Collection & Zero Internet Access

- **No Internet Permission:** No-Reels does **not** request the `android.permission.INTERNET` permission in its Android Manifest. It is physically impossible for the app to transmit data to any remote server.
- **No Analytics, Ads, or Trackers:** No-Reels contains zero third-party analytics SDKs, crash reporters, advertising networks, or telemetry frameworks.
- **100% Local Storage:** All preferences and daily counters (reels count and active duration) are stored exclusively on your device inside Android's sandboxed `SharedPreferences` and reset automatically each day.

## 2. Accessibility Service API Disclosure (`BIND_ACCESSIBILITY_SERVICE`)

No-Reels uses the Android `AccessibilityService` API solely to provide its core user-initiated focus features:
1. **Short-Form Feed Detection:** Inspecting on-screen view resource IDs and structural layout containers inside supported social apps (**YouTube**, **Instagram**, **Facebook**, and **TikTok**) to detect when a short-form video feed is open and navigate back (or cover the video player region on TikTok) while leaving the rest of the app (DMs, search, subscriptions, profile) usable.
2. **Video Counting & Dynamic Island Overlay:** Detecting distinct short-form videos to increment your local daily counter and rendering the non-intrusive top Dynamic Island counter pill.
3. **Opt-In Focus Protection:** Protecting active focus rules when the user explicitly enables Strict Uninstall Lock.

**Accessibility Data Guarantee:** All window and node inspection occurs transiently in device memory (RAM). No-Reels never logs, saves, shares, or transmits any text, messages, passwords, or personal screen content.

## 3. Device Administrator Disclosure (`BIND_DEVICE_ADMIN`)

If you explicitly opt in to **Device Admin Lock** / **Strict Uninstall Lock**, No-Reels uses the Android `DeviceAdminReceiver` API solely to prevent impulsive uninstallation while your focus lock is active. You can disable Strict Uninstall Lock and uninstall the app at any time by completing an offline Emergency Unlock challenge (Physical Walk, Read Book, or Hard Math) inside the app.

## 4. Physical Activity Sensor (`ACTIVITY_RECOGNITION`)

No-Reels requests `android.permission.ACTIVITY_RECOGNITION` solely to count hardware pedometer steps when you choose the **Make a Walk** Emergency Unlock challenge. Step data is processed locally in real time and is never saved or transmitted.

## 5. Contact & Open-Source Verification

Because No-Reels is open source under the **PolyForm Noncommercial License 1.0.0**, anyone can audit the complete source code and verify that zero user data is collected or transmitted and that the app makes zero calls to any server or backend.
