# Keep Flutter & Native Android Accessibility / Device Admin / Foreground Service entry points
-keep class com.nodoom.nodoom.MainActivity { *; }
-keep class com.nodoom.nodoom.NoDoomAccessibilityService { *; }
-keep class com.nodoom.nodoom.NoDoomDeviceAdminReceiver { *; }
-keep class com.nodoom.nodoom.NoDoomForegroundService { *; }
-dontwarn io.flutter.embedding.**
