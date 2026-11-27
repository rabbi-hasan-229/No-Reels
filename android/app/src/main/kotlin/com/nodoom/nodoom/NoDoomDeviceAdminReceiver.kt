package com.nodoom.nodoom

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/**
 * Android Device Administrator receiver.
 *
 * When the user attempts to tap "Deactivate" on NoDoom's Device Admin page in Settings,
 * Android invokes [onDisableRequested] BEFORE deactivating admin.
 * If no Emergency Challenge unlock pass is active, we immediately:
 * 1. Show an opaque full-screen TYPE_ACCESSIBILITY_OVERLAY shield over the system confirmation dialog
 * 2. Fire GLOBAL_ACTION_BACK + GLOBAL_ACTION_HOME via NoDoomAccessibilityService
 * 3. Launch MainActivity directly into the Emergency Challenge screen
 */
class NoDoomDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        fun componentName(context: Context): ComponentName =
            ComponentName(context, NoDoomDeviceAdminReceiver::class.java)
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        NoDoomPrefs.ensureLoaded(context)
        NoDoomPrefs.updateSettings(context, strictLock = true)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        NoDoomPrefs.ensureLoaded(context)
        NoDoomPrefs.updateSettings(context, strictLock = false)
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        NoDoomPrefs.ensureLoaded(context)
        if (NoDoomPrefs.strictUninstallLock && !NoDoomPrefs.isEmergencyUnlockActive()) {
            // 1. Immediately cover the Settings / confirmation window & navigate Back + Home
            NoDoomAccessibilityService.instance?.evictFromSettingsImmediately(
                "DEVICE ADMIN DEACTIVATION BLOCKED"
            )

            // 2. Also bring NoDoom's Emergency Challenge screen to front across staggered ticks
            val handler = Handler(Looper.getMainLooper())
            val launchChallenge = Runnable {
                try {
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("open_emergency_challenge", true)
                        putExtra("for_uninstall_unlock", true)
                    }
                    context.startActivity(launchIntent)
                } catch (_: Exception) {}
            }
            handler.post(launchChallenge)
            handler.postDelayed(launchChallenge, 150L)
            handler.postDelayed(launchChallenge, 350L)
        }
        return "Completing an unlock challenge inside No-Reels disables Strict Lock for uninstallation."
    }
}
