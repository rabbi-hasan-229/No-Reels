package com.nodoom.nodoom

import android.accessibilityservice.AccessibilityService
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Nothing-Design styled native Accessibility overlays:
 * 1. Status-bar micro-indicator ("14R · 08M") in the top status bar strip.
 * 2. Bounded video-region cover for TikTok (covers ONLY player_view so bottom tabs,
 *    Inbox, and Profile stay usable).
 * 3. Full-app block overlay when whole-app daily usage limit is exhausted.
 * 4. Strict Protection Shield overlay that immediately covers Settings / Device Admin /
 *    Package Installer whenever an unauthorized deactivation or uninstall is attempted.
 */
object OverlayController {

    private val mainHandler = Handler(Looper.getMainLooper())

    private var videoCoverView: View? = null
    private var currentCoverBounds: Rect? = null

    private var fullAppBlockView: View? = null
    private var strictShieldView: View? = null

    private fun runOnMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else mainHandler.post(block)
    }

    private fun svc(): AccessibilityService? = NoDoomAccessibilityService.instance

    private fun wm(service: AccessibilityService): WindowManager? =
        service.getSystemService(Context.WINDOW_SERVICE) as? WindowManager

    fun activeCoverBounds(): Rect? = currentCoverBounds?.let { Rect(it) }

    // ---------------- 1. Notification Bar Counter Sync (No Top Screen Overlay) ----------------

    fun updateStatusBarIndicator(inMonitoredFeed: Boolean) {
        runOnMain {
            val service = svc() ?: return@runOnMain
            NoDoomForegroundService.syncWithFeedState(service.applicationContext, inMonitoredFeed)
        }
    }

    fun removeStatusBarIndicator() {
        runOnMain {
            val service = svc() ?: return@runOnMain
            NoDoomForegroundService.stop(service.applicationContext)
        }
    }

    // ---------------- 2. Bounded Video Region Cover (TikTok) ----------------

    @SuppressLint("RtlHardcoded")
    fun showVideoRegionCover(boundsInScreen: Rect, appName: String) {
        runOnMain {
            val service = svc() ?: return@runOnMain
            val windowManager = wm(service) ?: return@runOnMain
            if (boundsInScreen.width() <= 0 || boundsInScreen.height() <= 0) return@runOnMain

            val params = WindowManager.LayoutParams(
                boundsInScreen.width(),
                boundsInScreen.height(),
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.OPAQUE
            ).apply {
                gravity = Gravity.TOP or Gravity.LEFT
                x = boundsInScreen.left
                y = boundsInScreen.top
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setFitInsetsTypes(0)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    layoutInDisplayCutoutMode =
                        WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }
            }

            val existing = videoCoverView
            if (existing != null) {
                val cur = currentCoverBounds
                val significantChange = cur == null ||
                    kotlin.math.abs(cur.top - boundsInScreen.top) > 18 ||
                    kotlin.math.abs(cur.bottom - boundsInScreen.bottom) > 18 ||
                    kotlin.math.abs(cur.width() - boundsInScreen.width()) > 18
                if (significantChange) {
                    try {
                        windowManager.updateViewLayout(existing, params)
                        currentCoverBounds = Rect(boundsInScreen)
                    } catch (_: Exception) {}
                }
                return@runOnMain
            }

            val view = buildNothingInstrumentOverlay(
                service = service,
                signalTag = "FEED INTERCEPT // ${appName.uppercase()}",
                heroValue = NoDoomPrefs.formatCompactStatus().uppercase(),
                headline = "${appName.uppercase()} VIDEOS LOCKED",
                caption = "INBOX, PROFILE & NAVIGATION REMAIN ACTIVE BELOW",
                showHomeButton = false,
                onDismissSelf = { hideVideoRegionCover() }
            )

            try {
                windowManager.addView(view, params)
                videoCoverView = view
                currentCoverBounds = Rect(boundsInScreen)
            } catch (_: Exception) {}
        }
    }

    fun hideVideoRegionCover() {
        runOnMain {
            val v = videoCoverView ?: return@runOnMain
            try {
                svc()?.let { wm(it)?.removeViewImmediate(v) }
            } catch (_: Exception) {}
            videoCoverView = null
            currentCoverBounds = null
        }
    }

    // ---------------- 3. Full-App Block Overlay ----------------

    fun showFullAppBlock(appName: String, reason: String) {
        runOnMain {
            if (fullAppBlockView != null) return@runOnMain
            val service = svc() ?: return@runOnMain
            val windowManager = wm(service) ?: return@runOnMain

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.OPAQUE
            ).apply {
                gravity = Gravity.CENTER
            }

            val view = buildNothingInstrumentOverlay(
                service = service,
                signalTag = "QUOTA EXHAUSTED // ${appName.uppercase()}",
                heroValue = NoDoomPrefs.formatCompactStatus().uppercase(),
                headline = "${appName.uppercase()} LOCKED",
                caption = reason.uppercase(),
                showHomeButton = true,
                onDismissSelf = { hideFullAppBlock() }
            )

            try {
                windowManager.addView(view, params)
                fullAppBlockView = view
            } catch (_: Exception) {}
        }
    }

    fun hideFullAppBlock() {
        runOnMain {
            val v = fullAppBlockView ?: return@runOnMain
            try {
                svc()?.let { wm(it)?.removeViewImmediate(v) }
            } catch (_: Exception) {}
            fullAppBlockView = null
        }
    }

    // ---------------- 4. Strict Protection Shield (Minimal Floating Card Only) ----------------

    fun showStrictProtectionShield(reason: String) {
        runOnMain {
            if (strictShieldView != null) return@runOnMain
            val service = svc() ?: return@runOnMain
            val windowManager = wm(service) ?: return@runOnMain

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            val view = buildMinimalStrictShieldCard(
                service = service,
                onDismissSelf = { hideStrictProtectionShield() }
            )

            try {
                windowManager.addView(view, params)
                strictShieldView = view
            } catch (_: Exception) {}
        }
    }

    private fun buildMinimalStrictShieldCard(
        service: AccessibilityService,
        onDismissSelf: () -> Unit
    ): View {
        val density = service.resources.displayMetrics.density
        fun dp(v: Int): Int = (v * density).toInt()

        val root = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.TRANSPARENT)
            setPadding(dp(20), dp(12), dp(20), dp(12))
        }

        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(dp(296), LinearLayout.LayoutParams.WRAP_CONTENT)
            setPadding(dp(20), dp(18), dp(20), dp(18))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#121215"))
                cornerRadius = dp(24).toFloat()
                setStroke(1, Color.parseColor("#2C2C32"))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = dp(16).toFloat()
            }
            isClickable = true
        }

        // Header Row: Glowing Red Status Dot + Title
        val headerRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val dotBadge = android.widget.FrameLayout(service).apply {
            layoutParams = LinearLayout.LayoutParams(dp(28), dp(28)).apply {
                marginEnd = dp(10)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#26FF453A"))
            }
        }
        val dotCore = View(service).apply {
            layoutParams = android.widget.FrameLayout.LayoutParams(dp(10), dp(10), Gravity.CENTER)
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#FF453A"))
            }
        }
        dotBadge.addView(dotCore)

        val titleView = TextView(service).apply {
            text = "No-Reels Locked"
            setTextColor(Color.parseColor("#FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
        }

        headerRow.addView(dotBadge)
        headerRow.addView(titleView)

        val subtitleView = TextView(service).apply {
            text = "Complete a quick challenge to unlock protection."
            setTextColor(Color.parseColor("#A1A1AA"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setLineSpacing(0f, 1.3f)
            setPadding(0, dp(10), 0, dp(16))
        }

        // Side-by-side compact action buttons
        val btnRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        val dismissBtn = Button(service).apply {
            text = "Dismiss"
            isAllCaps = false
            setTextColor(Color.parseColor("#E4E4E7"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            stateListAnimator = null
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#1F1F25"))
                cornerRadius = dp(999).toFloat()
                setStroke(1, Color.parseColor("#2E2E36"))
            }
            layoutParams = LinearLayout.LayoutParams(0, dp(40), 1f).apply {
                marginEnd = dp(8)
            }
            setOnClickListener {
                onDismissSelf()
            }
        }

        val unlockBtn = Button(service).apply {
            text = "Unlock"
            isAllCaps = false
            setTextColor(Color.parseColor("#09090B"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = Typeface.create("sans-serif", Typeface.BOLD)
            stateListAnimator = null
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#FFFFFF"))
                cornerRadius = dp(999).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(0, dp(40), 1f)
            setOnClickListener {
                onDismissSelf()
                try {
                    val intent = Intent(service, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("open_emergency_challenge", true)
                        putExtra("for_uninstall_unlock", true)
                    }
                    service.startActivity(intent)
                } catch (_: Exception) {}
            }
        }

        btnRow.addView(dismissBtn)
        btnRow.addView(unlockBtn)

        card.addView(headerRow)
        card.addView(subtitleView)
        card.addView(btnRow)
        root.addView(card)
        return root
    }

    fun hideStrictProtectionShield() {
        runOnMain {
            val v = strictShieldView ?: return@runOnMain
            try {
                svc()?.let { wm(it)?.removeViewImmediate(v) }
            } catch (_: Exception) {}
            strictShieldView = null
        }
    }

    fun clearAll() {
        removeStatusBarIndicator()
        hideVideoRegionCover()
        hideFullAppBlock()
        hideStrictProtectionShield()
    }

    // ---------------- Nothing Design Instrument Overlay Builder ----------------

    private fun buildNothingInstrumentOverlay(
        service: AccessibilityService,
        signalTag: String,
        heroValue: String,
        headline: String,
        caption: String,
        showHomeButton: Boolean,
        forUninstallChallenge: Boolean = false,
        transparentBackdrop: Boolean = false,
        onDismissSelf: () -> Unit
    ): View {
        val density = service.resources.displayMetrics.density
        fun dp(v: Int): Int = (v * density).toInt()

        val root = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(
                if (transparentBackdrop) Color.TRANSPARENT else Color.parseColor("#000000")
            )
            setPadding(dp(24), dp(16), dp(24), dp(16))
            isClickable = !transparentBackdrop
        }

        val card = LinearLayout(service).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(22), dp(24), dp(22))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#141416"))
                cornerRadius = dp(18).toFloat()
                setStroke(dp(1), Color.parseColor("#38383C"))
            }
            elevation = dp(12).toFloat()
            isClickable = true
        }

        // Top Signal Row: Red Accent Dot + Space Mono ALL CAPS tag
        val topRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val redDot = View(service).apply {
            layoutParams = LinearLayout.LayoutParams(dp(8), dp(8)).apply {
                marginEnd = dp(8)
            }
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#D71921"))
            }
        }
        val tagView = TextView(service).apply {
            text = signalTag
            setTextColor(Color.parseColor("#999999"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            letterSpacing = 0.08f
        }
        topRow.addView(redDot)
        topRow.addView(tagView)

        // Hero Metric (Primary Layer)
        val heroView = TextView(service).apply {
            text = heroValue
            setTextColor(Color.parseColor("#FFFFFF"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 38f)
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = -0.02f
            setPadding(0, dp(16), 0, dp(4))
        }

        // Segmented Instrument Bar (12 discrete square blocks, Nothing signature)
        val segRow = LinearLayout(service).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(8), 0, dp(16))
        }
        for (i in 0 until 12) {
            val seg = View(service).apply {
                layoutParams = LinearLayout.LayoutParams(0, dp(6), 1f).apply {
                    if (i < 11) marginEnd = dp(2)
                }
                setBackgroundColor(Color.parseColor("#D71921"))
            }
            segRow.addView(seg)
        }

        // Secondary Layer: Headline
        val headlineView = TextView(service).apply {
            text = headline
            setTextColor(Color.parseColor("#E8E8E8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, dp(6))
        }

        // Tertiary Layer: Caption
        val captionView = TextView(service).apply {
            text = caption
            setTextColor(Color.parseColor("#999999"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            letterSpacing = 0.04f
            setLineSpacing(0f, 1.35f)
            setPadding(0, 0, 0, dp(24))
        }

        card.addView(topRow)
        card.addView(heroView)
        card.addView(segRow)
        card.addView(headlineView)
        card.addView(captionView)

        if (showHomeButton) {
            // Primary Pill Button (999px radius, #FFFFFF bg, #000000 text)
            val homeBtn = Button(service).apply {
                text = if (transparentBackdrop) "DISMISS CARD" else "EXIT TO HOME"
                isAllCaps = true
                setTextColor(Color.parseColor("#000000"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
                letterSpacing = 0.06f
                stateListAnimator = null
                background = GradientDrawable().apply {
                    setColor(Color.parseColor("#FFFFFF"))
                    cornerRadius = dp(999).toFloat()
                }
                layoutParams = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    dp(44)
                ).apply { bottomMargin = dp(10) }
                setOnClickListener {
                    onDismissSelf()
                    if (!transparentBackdrop) {
                        service.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME)
                    }
                }
            }
            card.addView(homeBtn)
        }

        // Secondary Pill Button (transparent, 1px solid #333333, 999px radius)
        val unlockBtn = Button(service).apply {
            text = "[ EMERGENCY CHALLENGE ]"
            isAllCaps = true
            setTextColor(Color.parseColor("#E8E8E8"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            letterSpacing = 0.06f
            stateListAnimator = null
            background = GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(999).toFloat()
                setStroke(1, Color.parseColor("#333333"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(44)
            )
            setOnClickListener {
                onDismissSelf()
                try {
                    val intent = Intent(service, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra("open_emergency_challenge", true)
                        putExtra("for_uninstall_unlock", forUninstallChallenge)
                    }
                    service.startActivity(intent)
                } catch (_: Exception) {}
            }
        }
        card.addView(unlockBtn)
        root.addView(card)
        return root
    }
}
