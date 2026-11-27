package com.nodoom.nodoom

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "com.nodoom/engine"
    private var methodChannel: MethodChannel? = null
    private lateinit var stepCounterManager: StepCounterManager
    private var pendingOpenEmergencyChallenge = false
    private var pendingForUninstallUnlock = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NoDoomPrefs.ensureLoaded(applicationContext)
        stepCounterManager = StepCounterManager(applicationContext)
        ensureNotificationPermission()
        NoDoomForegroundService.startOrUpdate(applicationContext)
        if (intent?.getBooleanExtra("open_emergency_challenge", false) == true) {
            pendingOpenEmergencyChallenge = true
            pendingForUninstallUnlock = intent?.getBooleanExtra("for_uninstall_unlock", false) == true
        }
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    102
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("open_emergency_challenge", false)) {
            val forUninstall = intent.getBooleanExtra("for_uninstall_unlock", false)
            methodChannel?.invokeMethod("onOpenEmergencyChallenge", forUninstall)
        }
    }

    override fun onResume() {
        super.onResume()
        // Dismiss any leftover Settings shield once the user is back inside NoDoom
        OverlayController.hideStrictProtectionShield()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            NoDoomPrefs.ensureLoaded(applicationContext)
            when (call.method) {
                "getState" -> {
                    val consumeChallengeFlag = pendingOpenEmergencyChallenge
                    val consumeUninstallFlag = pendingForUninstallUnlock
                    pendingOpenEmergencyChallenge = false
                    pendingForUninstallUnlock = false
                    result.success(buildStateMap(consumeChallengeFlag, consumeUninstallFlag))
                }
                "updateRule" -> {
                    val appId = call.argument<String>("appId") ?: ""
                    val existing = NoDoomPrefs.rules[appId]
                    if (existing != null) {
                        NoDoomPrefs.rules[appId] = existing.copy(
                            blockReels = call.argument<Boolean>("blockReels") ?: existing.blockReels,
                            dailyReelLimitSec = call.argument<Int>("dailyReelLimitSec") ?: existing.dailyReelLimitSec,
                            dailyReelCountLimit = call.argument<Int>("dailyReelCountLimit") ?: existing.dailyReelCountLimit,
                            blockWholeApp = call.argument<Boolean>("blockWholeApp") ?: existing.blockWholeApp,
                            dailyAppLimitSec = call.argument<Int>("dailyAppLimitSec") ?: existing.dailyAppLimitSec
                        )
                        NoDoomPrefs.saveRules(applicationContext)
                    }
                    result.success(buildStateMap(false, false))
                }
                "updateSettings" -> {
                    val allowDm = call.argument<Boolean>("allowDmReels")
                    val barModeStr = call.argument<String>("statusBarMode")
                    val barMode = barModeStr?.let {
                        try { NoDoomPrefs.StatusBarMode.valueOf(it) } catch (_: Exception) { null }
                    }
                    val barNotif = call.argument<Boolean>("statusBarNotification")
                    val strictLock = call.argument<Boolean>("strictUninstallLock")
                    val walkSteps = call.argument<Int>("walkTargetSteps")
                    val isLightMode = call.argument<Boolean>("lightMode")
                    val newThemeId = call.argument<String>("themeId")
                    val newFontFamily = call.argument<String>("fontFamily")
                    val newTitleSize = call.argument<Double>("cardTitleSize")?.toFloat()
                    val newBodySize = call.argument<Double>("cardBodySize")?.toFloat()
                    val newUiScale = call.argument<Double>("uiTextScale")?.toFloat()
                    val newIsGrid = call.argument<Boolean>("isGridView")

                    NoDoomPrefs.updateSettings(
                        context = applicationContext,
                        allowDm = allowDm,
                        barMode = barMode,
                        barNotif = barNotif,
                        strictLock = strictLock,
                        walkSteps = walkSteps,
                        isLightMode = isLightMode,
                        newThemeId = newThemeId,
                        newFontFamily = newFontFamily,
                        newTitleSize = newTitleSize,
                        newBodySize = newBodySize,
                        newUiScale = newUiScale,
                        newIsGrid = newIsGrid
                    )
                    OverlayController.updateStatusBarIndicator(false)
                    NoDoomForegroundService.startOrUpdate(applicationContext)
                    result.success(buildStateMap(false, false))
                }
                "grantEmergencyUnlock" -> {
                    val minutes = call.argument<Int>("minutes") ?: 5
                    val deactivateAdmin = call.argument<Boolean>("deactivateAdmin") ?: false
                    NoDoomPrefs.grantEmergencyUnlock(applicationContext, minutes)
                    OverlayController.hideVideoRegionCover()
                    OverlayController.hideFullAppBlock()
                    OverlayController.hideStrictProtectionShield()
                    if (deactivateAdmin) {
                        NoDoomPrefs.updateSettings(applicationContext, strictLock = false)
                        removeDeviceAdmin()
                    }
                    result.success(buildStateMap(false, false))
                }
                "lockNow" -> {
                    NoDoomPrefs.revokeEmergencyUnlock(applicationContext)
                    NoDoomPrefs.updateSettings(applicationContext, strictLock = true)
                    result.success(buildStateMap(false, false))
                }
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }
                "requestDeviceAdmin" -> {
                    val comp = NoDoomDeviceAdminReceiver.componentName(applicationContext)
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                        putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, comp)
                        putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Protects No-Reels from impulsive uninstallation while Strict Lock is active."
                        )
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    } catch (_: Exception) {
                        startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                    }
                    result.success(true)
                }
                "startWalkSensor" -> {
                    ensureActivityRecognitionPermission()
                    val ok = stepCounterManager.start { steps ->
                        runOnUiThread {
                            methodChannel?.invokeMethod("onWalkStep", steps)
                        }
                    }
                    result.success(ok)
                }
                "stopWalkSensor" -> {
                    stepCounterManager.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun buildStateMap(
        openEmergencyChallenge: Boolean,
        forUninstallUnlock: Boolean
    ): Map<String, Any> {
        val rulesList = NoDoomPrefs.rules.values.map { r ->
            mapOf(
                "appId" to r.appId,
                "name" to r.name,
                "blockReels" to r.blockReels,
                "dailyReelLimitSec" to r.dailyReelLimitSec,
                "dailyReelCountLimit" to r.dailyReelCountLimit,
                "blockWholeApp" to r.blockWholeApp,
                "dailyAppLimitSec" to r.dailyAppLimitSec,
                "usedAppSec" to (NoDoomPrefs.appUsageSec[r.appId] ?: 0),
                "usedReelSec" to (NoDoomPrefs.appReelsSec[r.appId] ?: 0),
                "usedReelCount" to (NoDoomPrefs.appReelsCount[r.appId] ?: 0)
            )
        }
        return mapOf(
            "todayReelsCount" to NoDoomPrefs.todayReelsCount,
            "todayReelsSec" to NoDoomPrefs.todayReelsSec,
            "lifetimeReelsCount" to NoDoomPrefs.lifetimeReelsCount,
            "lifetimeReelsSec" to NoDoomPrefs.lifetimeReelsSec,
            "lifetimeBlockedCount" to NoDoomPrefs.lifetimeBlockedCount,
            "lifetimeSavedSec" to NoDoomPrefs.lifetimeSavedSec,
            "compactStatus" to NoDoomPrefs.formatCompactStatus(),
            "allowDmReels" to NoDoomPrefs.allowDmReels,
            "statusBarMode" to NoDoomPrefs.statusBarMode.name,
            "statusBarNotification" to NoDoomPrefs.statusBarNotification,
            "strictUninstallLock" to NoDoomPrefs.strictUninstallLock,
            "emergencyUnlockUntilMs" to NoDoomPrefs.emergencyUnlockUntilMs,
            "isEmergencyUnlockActive" to NoDoomPrefs.isEmergencyUnlockActive(),
            "walkTargetSteps" to NoDoomPrefs.walkTargetSteps,
            "lightMode" to NoDoomPrefs.lightMode,
            "themeId" to NoDoomPrefs.themeId,
            "fontFamily" to NoDoomPrefs.fontFamily,
            "cardTitleSize" to NoDoomPrefs.cardTitleSize.toDouble(),
            "cardBodySize" to NoDoomPrefs.cardBodySize.toDouble(),
            "uiTextScale" to NoDoomPrefs.uiTextScale.toDouble(),
            "isGridView" to NoDoomPrefs.isGridView,
            "isAccessibilityEnabled" to isAccessibilityServiceEnabled(),
            "isDeviceAdminEnabled" to isDeviceAdminActive(),
            "isBatteryUnrestricted" to isBatteryOptimizationIgnored(),
            "openEmergencyChallenge" to openEmergencyChallenge,
            "forUninstallUnlock" to forUninstallUnlock,
            "rules" to rulesList,
            "dailyHistory" to NoDoomPrefs.getLast7DaysHistory()
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        if (NoDoomAccessibilityService.instance != null) return true
        val enabled = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabled.contains("$packageName/${NoDoomAccessibilityService::class.java.name}") ||
            enabled.contains("$packageName/.NoDoomAccessibilityService")
    }

    private fun isDeviceAdminActive(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        return dpm.isAdminActive(NoDoomDeviceAdminReceiver.componentName(applicationContext))
    }

    private fun removeDeviceAdmin() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
            val comp = NoDoomDeviceAdminReceiver.componentName(applicationContext)
            if (dpm.isAdminActive(comp)) {
                dpm.removeActiveAdmin(comp)
            }
        } catch (_: Exception) {}
    }

    private fun isBatteryOptimizationIgnored(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pm.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun ensureActivityRecognitionPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                    201
                )
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    202
                )
            }
        }
    }

    override fun onDestroy() {
        stepCounterManager.stop()
        super.onDestroy()
    }
}
