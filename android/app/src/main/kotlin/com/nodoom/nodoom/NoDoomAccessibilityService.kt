package com.nodoom.nodoom

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.ArrayDeque
import java.util.Locale

class NoDoomAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: NoDoomAccessibilityService? = null
            private set

        private const val DWELL_MS = 750L
        private const val SCAN_THROTTLE_MS = 80L
        private const val BACK_COOLDOWN_MS = 350L
        private const val GESTURE_GAP_MS = 500L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val powerManager by lazy { getSystemService(Context.POWER_SERVICE) as PowerManager }

    private var currentForegroundPkg: String? = null
    private var currentAppId: String? = null
    private var currentInShortFormFeed: Boolean = false
    private var currentDmExempted: Boolean = false

    // Fingerprint dwell state (isolated from scanRunnable so 750ms dwell never blocks feed detection)
    private var observedKey: String? = null
    private var observedSince: Long = 0L
    private var lastCountedKey: String? = null
    private var lastCountedAt: Long = 0L
    private var lastVerticalScrollAt: Long = 0L
    private var lastScrollEventTime: Long = 0L
    private var gestureCounted: Boolean = false
    private val fingerprintActiveApps = HashSet<String>()

    private var lastBackActionAt: Long = 0L
    private var lastScanExecutedAt: Long = 0L
    private var scanScheduled: Boolean = false

    private val scanRunnable = Runnable {
        scanScheduled = false
        lastScanExecutedAt = System.currentTimeMillis()
        performScreenScan()
    }

    private val dwellRunnable = Runnable {
        performScreenScan()
    }

    /** 1-second active usage ticker for accurate duration tracking and limit enforcement. */
    private val usageTickRunnable = object : Runnable {
        override fun run() {
            if (!powerManager.isInteractive) {
                OverlayController.hideVideoRegionCover()
                OverlayController.hideFullAppBlock()
                return
            }
            val appId = currentAppId
            if (appId != null) {
                val isCovered = OverlayController.activeCoverBounds() != null
                val countingFeedTime = currentInShortFormFeed && !isCovered
                NoDoomPrefs.addUsageSeconds(
                    context = applicationContext,
                    appId = appId,
                    inReelsFeed = countingFeedTime,
                    deltaSec = 1
                )
                OverlayController.updateStatusBarIndicator(currentInShortFormFeed)
                NoDoomForegroundService.updateNotificationIfRunning(applicationContext)

                enforceLimitsIfNeeded(appId)
                handler.postDelayed(this, 1000L)
            }
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    handler.removeCallbacks(usageTickRunnable)
                    OverlayController.hideVideoRegionCover()
                    OverlayController.hideFullAppBlock()
                    OverlayController.hideStrictProtectionShield()
                }
                Intent.ACTION_USER_PRESENT -> {
                    OverlayController.updateStatusBarIndicator(currentInShortFormFeed)
                    requestScan(250L)
                }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        NoDoomPrefs.ensureLoaded(applicationContext)
        lastCountedKey = NoDoomPrefs.recentHashes.lastOrNull()

        try {
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(Intent.ACTION_USER_PRESENT)
            }
            registerReceiver(screenReceiver, filter)
        } catch (_: Exception) {}

        OverlayController.updateStatusBarIndicator(false)
        if (NoDoomPrefs.statusBarNotification) {
            NoDoomForegroundService.startOrUpdate(applicationContext)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null || !powerManager.isInteractive) return
        val pkg = event.packageName?.toString() ?: return

        // Ignore our own overlay/app events
        if (pkg == packageName) return

        NoDoomPrefs.ensureLoaded(applicationContext)

        // 1. Multi-Window Self-Defense Guard: blocks Device Admin deactivation,
        //    Accessibility deactivation, App Info Force Stop, and Package Uninstaller.
        if (NoDoomPrefs.strictUninstallLock && !NoDoomPrefs.isEmergencyUnlockActive()) {
            val threatReason = detectSelfDefenseThreat(event, pkg)
            if (threatReason != null) {
                evictFromSettingsImmediately(threatReason)
                return
            }
        }

        val appId = FeedScanner.resolveAppId(pkg)
        if (appId != null) {
            OverlayController.hideStrictProtectionShield()
            if (currentForegroundPkg != pkg) {
                currentForegroundPkg = pkg
                currentAppId = appId
                currentInShortFormFeed = false
                OverlayController.hideFullAppBlock()
                OverlayController.hideVideoRegionCover()
                startUsageTicker()
                // Schedule quick follow-up scans on app launch so TikTok's Home tab is redirected
                // the instant its bottom navigation bar finishes inflating.
                if (appId == "tiktok") {
                    handler.postDelayed({ if (currentAppId == "tiktok") performScreenScan() }, 100L)
                    handler.postDelayed({ if (currentAppId == "tiktok") performScreenScan() }, 260L)
                }
            }

            if (event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED) {
                handleViewScrolled(appId, pkg, event)
            }

            val urgentEvent = event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
                event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED ||
                event.eventType == AccessibilityEvent.TYPE_VIEW_SELECTED ||
                (!currentInShortFormFeed && NoDoomPrefs.shouldBlockReels(appId))
            requestScan(if (urgentEvent) 0L else SCAN_THROTTLE_MS)
        } else if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (!isKeyboardOrAutofillPackage(pkg)) {
                OverlayController.hideVideoRegionCover()
                if (!isProtectedSystemPackage(pkg)) {
                    OverlayController.hideStrictProtectionShield()
                }
                if (currentAppId != null && pkg != "com.android.systemui") {
                    currentForegroundPkg = null
                    currentAppId = null
                    currentInShortFormFeed = false
                    currentDmExempted = false
                    handler.removeCallbacks(usageTickRunnable)
                    OverlayController.hideFullAppBlock()
                    OverlayController.updateStatusBarIndicator(false)
                }
            }
        }
    }

    /**
     * Immediately covers Settings / PackageInstaller with an opaque touch-blocking overlay
     * and navigates Back + Home so the user cannot tap "Deactivate", "OK", or "Uninstall".
     */
    fun evictFromSettingsImmediately(reason: String) {
        OverlayController.showStrictProtectionShield(reason)
        performGlobalAction(GLOBAL_ACTION_BACK)
        performGlobalAction(GLOBAL_ACTION_HOME)
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
        }, 180L)
    }

    private fun startUsageTicker() {
        handler.removeCallbacks(usageTickRunnable)
        handler.postDelayed(usageTickRunnable, 1000L)
    }

    private fun requestScan(delayMs: Long = SCAN_THROTTLE_MS) {
        val now = System.currentTimeMillis()
        // Leading-edge execution: if enough time elapsed since last scan (or urgent 0ms request),
        // run immediately on this frame without waiting in the message queue.
        if (delayMs == 0L || now - lastScanExecutedAt >= SCAN_THROTTLE_MS) {
            if (scanScheduled) {
                handler.removeCallbacks(scanRunnable)
                scanScheduled = false
            }
            lastScanExecutedAt = now
            performScreenScan()
            return
        }
        if (scanScheduled) return
        scanScheduled = true
        val remaining = (SCAN_THROTTLE_MS - (now - lastScanExecutedAt)).coerceAtLeast(16L)
        handler.postDelayed(scanRunnable, minOf(delayMs, remaining))
    }

    private fun scheduleDwellRecheck(delayMs: Long) {
        handler.removeCallbacks(dwellRunnable)
        handler.postDelayed(dwellRunnable, delayMs)
    }

    private fun findTargetRoot(pkg: String): AccessibilityNodeInfo? = try {
        rootInActiveWindow?.takeIf { it.packageName?.toString() == pkg }
            ?: windows.firstNotNullOfOrNull { w ->
                w.root?.takeIf { it.packageName?.toString() == pkg }
            }
    } catch (_: Exception) {
        null
    }

    private fun performScreenScan() {
        val pkg = currentForegroundPkg ?: return
        val appId = currentAppId ?: return
        val root = findTargetRoot(pkg) ?: return

        // 1. Check Whole-App Blocking first
        if (NoDoomPrefs.shouldBlockWholeApp(appId)) {
            val rule = NoDoomPrefs.rules[appId]
            val limitMin = (rule?.dailyAppLimitSec ?: 0) / 60
            OverlayController.showFullAppBlock(
                appName = rule?.name ?: appId.replaceFirstChar { it.uppercase() },
                reason = "DAILY APP LIMIT (${limitMin}M) REACHED"
            )
            return
        } else {
            OverlayController.hideFullAppBlock()
        }

        // 2. Scan for short-form video feed (Shorts / Reels / TikTok Home)
        val dm = resources.displayMetrics
        val detection = FeedScanner.scan(
            root = root,
            pkg = pkg,
            screenW = dm.widthPixels,
            screenH = dm.heightPixels,
            allowDmReels = NoDoomPrefs.allowDmReels,
            activeCoverScreenBounds = OverlayController.activeCoverBounds()
        ) ?: return

        val wasInFeed = currentInShortFormFeed
        currentInShortFormFeed = detection.inShortFormFeed
        currentDmExempted = detection.dmExempted

        if (currentInShortFormFeed != wasInFeed) {
            OverlayController.updateStatusBarIndicator(currentInShortFormFeed)
        }

        if (!detection.inShortFormFeed) {
            observedKey = null
            OverlayController.hideVideoRegionCover()
            return
        }

        // 3. If Reels blocking is triggered & not DM-exempted, enforce block immediately
        if (!detection.dmExempted && NoDoomPrefs.shouldBlockReels(appId)) {
            enforceShortFormBlock(detection)
            return
        } else {
            OverlayController.hideVideoRegionCover()
        }

        // 4. Otherwise, fingerprint the visible video for accurate distinct-video counting
        evaluateVideoFingerprint(root, appId, pkg, dm.widthPixels, dm.heightPixels)
    }

    private fun enforceLimitsIfNeeded(appId: String) {
        if (NoDoomPrefs.shouldBlockWholeApp(appId)) {
            val rule = NoDoomPrefs.rules[appId]
            val limitMin = (rule?.dailyAppLimitSec ?: 0) / 60
            OverlayController.showFullAppBlock(
                appName = rule?.name ?: appId,
                reason = "DAILY APP LIMIT (${limitMin}M) REACHED"
            )
            return
        }
        if (currentInShortFormFeed && !currentDmExempted && NoDoomPrefs.shouldBlockReels(appId)) {
            requestScan(0L)
        }
    }

    private fun enforceShortFormBlock(detection: FeedScanner.DetectionResult) {
        val now = System.currentTimeMillis()
        when (detection.strategy) {
            FeedScanner.BlockStrategy.NAVIGATE_BACK -> {
                if (now - lastBackActionAt >= BACK_COOLDOWN_MS) {
                    lastBackActionAt = now
                    NoDoomPrefs.recordBlockedReel(applicationContext)
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
            }
            FeedScanner.BlockStrategy.REDIRECT_TAB -> {
                if (now - lastBackActionAt >= BACK_COOLDOWN_MS) {
                    lastBackActionAt = now
                    NoDoomPrefs.recordBlockedReel(applicationContext)
                    val clicked = clickTabNodeOrParent(detection.redirectTargetNode)
                    if (!clicked && detection.redirectTapBounds != null) {
                        tapBoundsViaGesture(detection.redirectTapBounds)
                    } else if (detection.redirectTapBounds != null) {
                        // Verify 160ms later: if TikTok's custom tab view ignored ACTION_CLICK, fire gesture tap
                        val fallbackBounds = Rect(detection.redirectTapBounds)
                        handler.postDelayed({
                            if (currentAppId == "tiktok") {
                                val r = findTargetRoot(detection.packageName)
                                if (r != null) {
                                    val dm = resources.displayMetrics
                                    val recheck = FeedScanner.scan(
                                        r,
                                        detection.packageName,
                                        dm.widthPixels,
                                        dm.heightPixels,
                                        NoDoomPrefs.allowDmReels
                                    )
                                    if (recheck?.inShortFormFeed == true &&
                                        recheck.strategy == FeedScanner.BlockStrategy.REDIRECT_TAB
                                    ) {
                                        tapBoundsViaGesture(fallbackBounds)
                                    }
                                }
                            }
                        }, 160L)
                    }
                }
            }
            FeedScanner.BlockStrategy.COVER_VIDEO_REGION -> {
                val bounds = detection.coverBoundsInScreen
                if (bounds != null) {
                    val wasCovered = OverlayController.activeCoverBounds() != null
                    val appName = NoDoomPrefs.rules[detection.appId]?.name ?: "TikTok"
                    OverlayController.showVideoRegionCover(bounds, appName)
                    if (!wasCovered) {
                        NoDoomPrefs.recordBlockedReel(applicationContext)
                    }
                }
            }
        }
    }

    private fun clickTabNodeOrParent(node: AccessibilityNodeInfo?): Boolean {
        var cur = node
        var depth = 0
        while (cur != null && depth < 4) {
            if (cur.isClickable && cur.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
            cur = cur.parent
            depth++
        }
        return node?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true
    }

    private fun tapBoundsViaGesture(bounds: Rect) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return
        val cx = bounds.exactCenterX()
        val cy = bounds.exactCenterY()
        if (cx <= 0f || cy <= 0f) return
        try {
            val path = Path().apply { moveTo(cx, cy) }
            val stroke = GestureDescription.StrokeDescription(path, 0L, 25L)
            val gesture = GestureDescription.Builder().addStroke(stroke).build()
            dispatchGesture(gesture, null, null)
        } catch (_: Exception) {}
    }

    private fun evaluateVideoFingerprint(
        root: AccessibilityNodeInfo,
        appId: String,
        pkg: String,
        screenW: Int,
        screenH: Int
    ) {
        val outcome = ReelFingerprintDetector.detect(root, appId, pkg, screenW, screenH)
        val reel = outcome as? ReelFingerprintDetector.Outcome.Reel ?: return
        val key = reel.key
        fingerprintActiveApps.add(pkg)

        val now = System.currentTimeMillis()
        if (key != observedKey) {
            observedKey = key
            observedSince = now
            scheduleDwellRecheck(DWELL_MS + 40L)
            return
        }
        if (now - observedSince < DWELL_MS) {
            scheduleDwellRecheck(DWELL_MS - (now - observedSince) + 40L)
            return
        }

        val last = lastCountedKey
        if (last != null && ReelFingerprintDetector.sameReel(last, key)) {
            lastCountedKey = key
            return
        }
        if (last != null && lastCountedAt != 0L && lastVerticalScrollAt <= lastCountedAt &&
            ReelFingerprintDetector.sharesPart(last, key)
        ) {
            lastCountedKey = key
            return
        }
        if (NoDoomPrefs.recentHashes.any { ReelFingerprintDetector.sameReel(it, key) }) {
            lastCountedKey = key
            return
        }

        lastCountedKey = key
        lastCountedAt = now
        recordCountedVideo(appId, key)
    }

    private fun handleViewScrolled(appId: String, pkg: String, event: AccessibilityEvent) {
        if (!currentInShortFormFeed) return
        if (isHorizontalScroll(event)) return

        val now = System.currentTimeMillis()
        lastVerticalScrollAt = now

        if (pkg in fingerprintActiveApps) {
            requestScan(SCAN_THROTTLE_MS)
            return
        }

        val srcId = event.source?.viewIdResourceName?.lowercase(Locale.ROOT) ?: ""
        if (srcId.contains("comment") || srcId.contains("chat") || srcId.contains("direct")) return

        if (now - lastScrollEventTime > GESTURE_GAP_MS) {
            gestureCounted = false
        }
        lastScrollEventTime = now
        if (gestureCounted) return
        gestureCounted = true

        recordCountedVideo(appId, "swipe_${now / 1000}")
    }

    private fun recordCountedVideo(appId: String, hashKey: String) {
        NoDoomPrefs.recordNewReel(applicationContext, appId, hashKey)
        OverlayController.updateStatusBarIndicator(currentInShortFormFeed)
        NoDoomForegroundService.updateNotificationIfRunning(applicationContext)

        if (!currentDmExempted && NoDoomPrefs.shouldBlockReels(appId)) {
            requestScan(0L)
        }
    }

    private fun isHorizontalScroll(event: AccessibilityEvent): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val dx = kotlin.math.abs(event.scrollDeltaX)
        val dy = kotlin.math.abs(event.scrollDeltaY)
        return dx > 40 && dx > dy * 2
    }

    // ---------------- Multi-Window Self-Defense Guard ----------------

    private fun isProtectedSystemPackage(pkg: String): Boolean {
        val lower = pkg.lowercase(Locale.ROOT)
        return lower.contains("settings") ||
            lower.contains("packageinstaller") ||
            lower.contains("permissioncontroller") ||
            lower.contains("securitycenter") ||
            lower.contains("appdetail") ||
            lower.contains("accessibility")
    }

    private fun detectSelfDefenseThreat(event: AccessibilityEvent, pkg: String): String? {
        val lowerPkg = pkg.lowercase(Locale.ROOT)
        val cls = event.className?.toString()?.lowercase(Locale.ROOT) ?: ""
        val evText = event.text.joinToString(" ").lowercase(Locale.ROOT)

        // Collect all visible roots across ALL windows (so popup dialogs + background activities are both checked)
        val roots = ArrayList<AccessibilityNodeInfo>()
        try {
            rootInActiveWindow?.let(roots::add)
            for (w in windows) {
                w.root?.let { r -> if (r !in roots) roots.add(r) }
            }
        } catch (_: Exception) {}

        var mentionsApp = evText.contains("no-reels") || evText.contains("noreels") ||
            evText.contains("nodoom") || evText.contains("com.nodoom")
        var mentionsAdminDeactivate = cls.contains("deviceadminadd") ||
            evText.contains("deactivate this device admin") ||
            evText.contains("remove active admin")
        var mentionsUninstallOrStop = cls.contains("uninstaller") ||
            cls.contains("uninstallappprogress")
        var mentionsAccessibilityToggle = false

        val adminKeywords = listOf(
            "deactivate this device admin",
            "deactivate",
            "device admin app",
            "remove active admin",
            "disable admin",
            "no-reels uninstall lock",
            "nodoom uninstall lock"
        )
        val appInfoDangerKeywords = listOf(
            "uninstall",
            "force stop",
            "clear storage",
            "clear data",
            "delete app"
        )
        val accessibilityDangerKeywords = listOf(
            "no-reels guard",
            "use no-reels",
            "stop no-reels",
            "turn off no-reels",
            "nodoom reel & app guard",
            "use nodoom",
            "stop nodoom",
            "turn off nodoom"
        )

        val isProtectedPkg = isProtectedSystemPackage(lowerPkg)
        val isLauncherPkg = lowerPkg.contains("launcher") || lowerPkg.contains("home")

        if (!isProtectedPkg && !isLauncherPkg) return null

        for (root in roots) {
            val queue = ArrayDeque<AccessibilityNodeInfo>()
            queue.add(root)
            var visited = 0
            while (queue.isNotEmpty() && visited < 260) {
                val node = queue.poll() ?: break
                visited++
                if (!node.isVisibleToUser) continue

                val resId = node.viewIdResourceName?.lowercase(Locale.ROOT) ?: ""
                if (resId.contains("action_button") && cls.contains("deviceadmin")) {
                    mentionsAdminDeactivate = true
                }

                for (raw in listOf(node.text, node.contentDescription)) {
                    val t = raw?.toString()?.lowercase(Locale.ROOT)?.trim() ?: continue
                    if (t.isEmpty()) continue
                    if (t.contains("no-reels") || t.contains("noreels") ||
                        t.contains("nodoom") || t.contains("com.nodoom")
                    ) {
                        mentionsApp = true
                    }
                    if (adminKeywords.any { t.contains(it) }) {
                        mentionsAdminDeactivate = true
                    }
                    if (appInfoDangerKeywords.any {
                            t == it || t.contains("uninstall no-reels") ||
                                t.contains("uninstall nodoom") || t.contains("force stop")
                        }
                    ) {
                        mentionsUninstallOrStop = true
                    }
                    if (accessibilityDangerKeywords.any { t.contains(it) }) {
                        mentionsAccessibilityToggle = true
                    }
                }
                for (i in 0 until node.childCount) {
                    node.getChild(i)?.let(queue::add)
                }
            }
        }

        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? android.app.admin.DevicePolicyManager
        val isAdminAlreadyActive = dpm?.isAdminActive(
            NoDoomDeviceAdminReceiver.componentName(applicationContext)
        ) == true

        // Never block the DeviceAdminAdd screen when the user is activating Device Admin for the first time
        if (!isAdminAlreadyActive && cls.contains("deviceadminadd")) {
            return null
        }

        if (isProtectedPkg && mentionsApp) {
            if (mentionsAdminDeactivate && isAdminAlreadyActive) {
                return "DEVICE ADMIN DEACTIVATION BLOCKED"
            }
            if (mentionsUninstallOrStop) {
                return "UNINSTALL & FORCE STOP BLOCKED"
            }
            if (mentionsAccessibilityToggle) {
                return "ACCESSIBILITY GUARD LOCKED"
            }
            if (lowerPkg.contains("packageinstaller")) {
                return "PACKAGE UNINSTALLER BLOCKED"
            }
        }

        // Also catch DeviceAdmin deactivation confirmation dialog even if the dialog window omits the app name
        if (isProtectedPkg && isAdminAlreadyActive &&
            (cls.contains("deviceadminadd") || evText.contains("strict lock active"))
        ) {
            return "DEVICE ADMIN DEACTIVATION BLOCKED"
        }

        // Catch Launcher long-press popup showing "No-Reels" + "Uninstall"
        if (isLauncherPkg && mentionsApp && mentionsUninstallOrStop) {
            return "LAUNCHER UNINSTALL BLOCKED"
        }

        return null
    }

    private fun isKeyboardOrAutofillPackage(pkg: String): Boolean {
        val lower = pkg.lowercase(Locale.ROOT)
        return lower == "android" ||
            lower.contains("inputmethod") ||
            lower.contains("keyboard") ||
            lower.contains("ime") ||
            lower.contains("autofill")
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        OverlayController.clearAll()
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}
        instance = null
    }
}
