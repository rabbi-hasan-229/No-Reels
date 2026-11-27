# Security Policy

## 100% Offline Threat Model

**No-Reels** is engineered with a strict zero-network security boundary:
- **Zero Network Surface:** `android.permission.INTERNET` is not requested in [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml). The app cannot make HTTP requests, open sockets, or communicate with any external server or backend.
- **Transient In-Memory Accessibility Inspection:** `NoDoomAccessibilityService` inspects window node metadata (`viewIdResourceName`, bounds, and visible creator/caption hashes) strictly in volatile RAM to detect short-form video feeds and deduplicate video counts. No text, credentials, messages, or personal content is ever logged or written to disk.
- **Sandboxed Local Preferences:** Only aggregate daily integers (video counts, duration seconds, and user settings) are saved in Android's private app-sandboxed `SharedPreferences`.

## Supported Versions

| Version | Supported |
| :--- | :--- |
| `1.2.x` | :white_check_mark: Supported |
| `< 1.2.0` | :x: Unsupported |

## Reporting a Vulnerability

If you discover a security or privacy issue (for example, a bypass in `NoDoomAccessibilityService` or `NoDoomDeviceAdminReceiver`), please open a GitHub issue with the `[SECURITY]` prefix or contact the repository maintainer directly.
