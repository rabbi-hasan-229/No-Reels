package com.nodoom.nodoom

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import java.util.ArrayDeque
import java.util.Locale

/**
 * Scrolless-grade surgical short-form feed scanner.
 *
 * Detects ONLY short-form video feeds (YouTube Shorts, Instagram Reels, Facebook Reels,
 * TikTok video feed) without false-triggering on Home feeds, DMs, Profile, or Search.
 * Also supports Scrolless's DM video exemption rules and bounded video player cover for TikTok.
 */
object FeedScanner {

    enum class BlockStrategy {
        NAVIGATE_BACK,
        REDIRECT_TAB,
        COVER_VIDEO_REGION
    }

    data class DetectionResult(
        val appId: String,
        val packageName: String,
        val inShortFormFeed: Boolean,
        val dmExempted: Boolean,
        val strategy: BlockStrategy,
        /** Non-null for COVER_VIDEO_REGION. */
        val coverBoundsInScreen: Rect? = null,
        val coverBoundsInWindow: Rect? = null,
        /** Non-null for REDIRECT_TAB (TikTok Home -> Friends/Inbox native tab switch). */
        val redirectTargetNode: AccessibilityNodeInfo? = null,
        val redirectTapBounds: Rect? = null,
        val windowId: Int = -1
    )

    private val YOUTUBE_PKGS = setOf(
        "com.google.android.youtube",
        "com.google.android.apps.youtube.kids",
        "app.revanced.android.youtube",
        "app.morphe.android.youtube",
        "app.rvx.android.youtube",
        "com.vanced.android.youtube"
    )

    private val INSTAGRAM_PKGS = setOf(
        "com.instagram.android",
        "com.instagram.lite"
    )

    private val FACEBOOK_PKGS = setOf(
        "com.facebook.katana",
        "com.facebook.lite"
    )

    private val TIKTOK_PKGS = setOf(
        "com.zhiliaoapp.musically",
        "com.ss.android.ugc.trill",
        "com.ss.android.ugc.aweme",
        "com.zhiliaoapp.musically.go"
    )

    private val YOUTUBE_SHORTS_IDS = listOf(
        "reel_player_page_container",
        "reel_recycler",
        "shorts_container",
        "reel_player_page_view",
        "reel_player",
        "shorts_video_player",
        "reel_watch_fragment"
    )

    private val IG_REELS_IDS = listOf(
        "clips_viewer_view_pager",
        "clips_video_container",
        "clips_item_container",
        "clips_swipe_refresh_container",
        "clips_root_container"
    )

    private val IG_DM_REQUIRED_IDS = listOf(
        "sender_username_or_fullname",
        "sender_timestamp",
        "reply_bar_edittext"
    )

    private val TIKTOK_DM_REPLY_PREFIXES = listOf(
        "reply to ", "message ", "send a message", "send message", "write a message"
    )

    fun resolveAppId(pkg: String): String? = when {
        pkg in YOUTUBE_PKGS || (pkg.endsWith(".android.youtube") && !pkg.contains("music")) -> "youtube"
        pkg in INSTAGRAM_PKGS -> "instagram"
        pkg in FACEBOOK_PKGS -> "facebook"
        pkg in TIKTOK_PKGS -> "tiktok"
        else -> null
    }

    fun scan(
        root: AccessibilityNodeInfo,
        pkg: String,
        screenW: Int,
        screenH: Int,
        allowDmReels: Boolean,
        activeCoverScreenBounds: Rect? = null
    ): DetectionResult? {
        val appId = resolveAppId(pkg) ?: return null
        return when (appId) {
            "youtube" -> scanYouTube(root, pkg)
            "instagram" -> scanInstagram(root, pkg, allowDmReels)
            "facebook" -> scanFacebook(root, pkg, screenW, screenH)
            "tiktok" -> scanTikTok(root, pkg, screenW, screenH, allowDmReels, activeCoverScreenBounds)
            else -> null
        }
    }

    private fun scanYouTube(root: AccessibilityNodeInfo, pkg: String): DetectionResult {
        // 1. Direct Shorts player container IDs (never matches shorts_shelf on Home feed)
        val hasShortsId = YOUTUBE_SHORTS_IDS.any { id ->
            hasVisibleId(root, "$pkg:id/$id")
        }
        // 2. Or bottom navigation "Shorts" tab selected while not on Home/Subscriptions
        val shortsTabSelected = try {
            root.findAccessibilityNodeInfosByText("Shorts")
                ?.any { isVisible(it) && (it.isSelected || it.parent?.isSelected == true) } == true
        } catch (_: Exception) {
            false
        }
        return DetectionResult(
            appId = "youtube",
            packageName = pkg,
            inShortFormFeed = hasShortsId || shortsTabSelected,
            dmExempted = false,
            strategy = BlockStrategy.NAVIGATE_BACK
        )
    }

    private fun scanInstagram(
        root: AccessibilityNodeInfo,
        pkg: String,
        allowDmReels: Boolean
    ): DetectionResult {
        if (pkg == "com.instagram.lite") {
            val inLiteReels = detectInstagramLiteReels(root, pkg)
            return DetectionResult(
                appId = "instagram",
                packageName = pkg,
                inShortFormFeed = inLiteReels,
                dmExempted = false,
                strategy = BlockStrategy.NAVIGATE_BACK
            )
        }

        val inReels = IG_REELS_IDS.any { id -> hasVisibleId(root, "$pkg:id/$id") }
        if (!inReels) {
            return DetectionResult("instagram", pkg, false, false, BlockStrategy.NAVIGATE_BACK)
        }

        // Scrolless DM Exemption Rule: all 3 sender/reply views visible & no "suggested_title"
        val isDmReel = allowDmReels &&
            !hasVisibleId(root, "$pkg:id/suggested_title") &&
            IG_DM_REQUIRED_IDS.all { id -> hasVisibleId(root, "$pkg:id/$id") }

        return DetectionResult(
            appId = "instagram",
            packageName = pkg,
            inShortFormFeed = true,
            dmExempted = isDmReel,
            strategy = BlockStrategy.NAVIGATE_BACK
        )
    }

    /**
     * Scrolless Instagram Lite structural rule:
     * Scrollable RecyclerView starting at the top of main_layout containing video_view.
     */
    private fun detectInstagramLiteReels(root: AccessibilityNodeInfo, pkg: String): Boolean {
        val mainTop = findFirstVisibleNode(root, "$pkg:id/main_layout")?.let {
            Rect().also(it::getBoundsInScreen).top
        } ?: return false
        val videos = safeFindById(root, "$pkg:id/video_view").filter(::isVisible)
        for (video in videos) {
            var p = video.parent
            while (p != null) {
                if (p.className?.toString() == "androidx.recyclerview.widget.RecyclerView" &&
                    p.isScrollable && isVisible(p)
                ) {
                    val r = Rect().also(p::getBoundsInScreen)
                    if (r.top <= mainTop) return true
                }
                p = p.parent
            }
        }
        return false
    }

    /**
     * Combines Scrolless 3-layer Facebook Reels detection + AntiDoom center-screen check:
     * 1. Legacy FbShortsComposerAttachmentComponentSpec descriptions
     * 2. Selected "Reels," tab or center-screen "Reels tab details"
     * 3. Locale-independent NodeStructure: scrollable RecyclerView (>=90%W, >=75%H)
     *    -> long-clickable Button (>=90%W, >=75%H) -> SurfaceView (>=90%W, >=75%H).
     */
    private fun scanFacebook(
        root: AccessibilityNodeInfo,
        pkg: String,
        screenW: Int,
        screenH: Int
    ): DetectionResult {
        if (pkg == "com.facebook.lite") {
            val inLiteVideo = hasVisibleId(root, "$pkg:id/video_view")
            return DetectionResult("facebook", pkg, inLiteVideo, false, BlockStrategy.NAVIGATE_BACK)
        }

        val rootRect = Rect().also(root::getBoundsInScreen)
        val totalW = if (screenW > 0) screenW else rootRect.width()
        val totalH = if (screenH > 0) screenH else rootRect.height()

        var foundFast = false
        val bigRecyclers = ArrayList<AccessibilityNodeInfo>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        val rect = Rect()

        while (queue.isNotEmpty() && visited < 320) {
            val node = queue.poll() ?: break
            visited++
            if (!node.isVisibleToUser) continue
            val desc = node.contentDescription?.toString()
            if (!desc.isNullOrEmpty()) {
                val lower = desc.lowercase(Locale.ROOT)
                if (lower == "fbshortscomposerattachmentcomponentspec_sticker" ||
                    lower == "fbshortscomposerattachmentcomponentspec_gif" ||
                    (node.isSelected && lower.startsWith("reels,"))
                ) {
                    foundFast = true
                    break
                }
                if (lower == "reels tab details" || lower == "detail tab reels" || lower == "detail reels") {
                    node.getBoundsInScreen(rect)
                    if (totalW <= 0 || rect.contains(totalW / 2, totalH / 2)) {
                        foundFast = true
                        break
                    }
                }
            }

            val cls = node.className?.toString() ?: ""
            if (cls == "androidx.recyclerview.widget.RecyclerView" && node.isScrollable) {
                node.getBoundsInScreen(rect)
                if (totalW > 0 && totalH > 0 &&
                    rect.width() >= totalW * 0.9f &&
                    rect.height() >= totalH * 0.75f
                ) {
                    bigRecyclers.add(node)
                }
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }

        val inFbReels = foundFast || bigRecyclers.any { rv ->
            hasFbReelsButtonAndSurface(rv, totalW, totalH)
        }

        return DetectionResult(
            appId = "facebook",
            packageName = pkg,
            inShortFormFeed = inFbReels,
            dmExempted = false,
            strategy = BlockStrategy.NAVIGATE_BACK
        )
    }

    private fun hasFbReelsButtonAndSurface(
        recycler: AccessibilityNodeInfo,
        totalW: Int,
        totalH: Int
    ): Boolean {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(recycler)
        var visited = 0
        val rect = Rect()
        while (queue.isNotEmpty() && visited < 120) {
            val node = queue.poll() ?: break
            visited++
            if (!node.isVisibleToUser) continue
            node.getBoundsInScreen(rect)
            // Prune entire subtree if this container is smaller than 75% screen dimensions
            if (rect.width() < totalW * 0.9f || rect.height() < totalH * 0.75f) continue
            if (node.className?.toString() == "android.widget.Button" && node.isLongClickable) {
                if (hasLargeSurfaceDescendant(node, totalW, totalH)) return true
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }
        return false
    }

    private fun hasLargeSurfaceDescendant(
        buttonNode: AccessibilityNodeInfo,
        totalW: Int,
        totalH: Int
    ): Boolean {
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(buttonNode)
        var visited = 0
        val rect = Rect()
        while (queue.isNotEmpty() && visited < 80) {
            val node = queue.poll() ?: break
            visited++
            if (isVisible(node, rect) &&
                node.className?.toString() == "android.view.SurfaceView" &&
                rect.width() >= totalW * 0.9f &&
                rect.height() >= totalH * 0.75f
            ) {
                return true
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }
        return false
    }

    private data class BottomTabInfo(
        val isSelected: Boolean,
        val clickableNode: AccessibilityNodeInfo?,
        val bounds: Rect
    )

    private fun findBottomTab(
        root: AccessibilityNodeInfo,
        tabText: String,
        totalW: Int,
        totalH: Int
    ): BottomTabInfo? {
        val bottomBarThreshold = (totalH * 0.85f).toInt()
        val matches = try {
            root.findAccessibilityNodeInfosByText(tabText) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }
        val rect = Rect()
        val ancRect = Rect()
        for (n in matches) {
            if (!n.isVisibleToUser) continue
            n.getBoundsInScreen(rect)
            if (rect.width() <= 0 || rect.height() <= 0) continue
            if (rect.top < bottomBarThreshold || rect.bottom > totalH + 30) continue
            val label = (n.text ?: n.contentDescription)?.toString()?.trim() ?: ""
            if (!label.equals(tabText, ignoreCase = true) &&
                !label.startsWith("$tabText,", ignoreCase = true) &&
                !label.startsWith("$tabText ", ignoreCase = true)
            ) {
                continue
            }

            var selected = n.isSelected
            var clickable: AccessibilityNodeInfo? = if (n.isClickable) n else null
            var bestBounds = Rect(rect)

            var cur = n.parent
            var depth = 0
            while (cur != null && depth < 4) {
                cur.getBoundsInScreen(ancRect)
                // Stop walking up once we hit the full-width bottom bar container
                if (ancRect.width() > (totalW * 0.36f).toInt()) break
                if (cur.isSelected) selected = true
                if (clickable == null && cur.isClickable) {
                    clickable = cur
                    bestBounds = Rect(ancRect)
                }
                cur = cur.parent
                depth++
            }
            return BottomTabInfo(
                isSelected = selected,
                clickableNode = clickable ?: n,
                bounds = bestBounds
            )
        }
        return null
    }

    /**
     * Native, zero-overlay TikTok detector:
     *
     * 1. No floating black WindowManager overlay — zero open/close lag and 100% native 120Hz animations!
     * 2. If the user is on "Friends", "Inbox", or "Profile", returns inShortFormFeed = false (allowed).
     * 3. If the user is on the "Home" screen ("For You" / "Following"), returns REDIRECT_TAB
     *    targeting the "Friends" tab (or "Inbox" / "Profile" fallback) so TikTok natively switches
     *    off the Home feed and pauses video/audio immediately.
     * 4. If the user opened a standalone full-screen video sub-page (e.g., from Search, where the
     *    bottom tab bar is hidden and it's not an exempted DM video), returns NAVIGATE_BACK.
     */
    private fun scanTikTok(
        root: AccessibilityNodeInfo,
        pkg: String,
        screenW: Int,
        screenH: Int,
        allowDmReels: Boolean,
        @Suppress("UNUSED_PARAMETER") activeCoverScreenBounds: Rect?
    ): DetectionResult {
        val totalW = if (screenW > 0) screenW else 1080
        val totalH = if (screenH > 0) screenH else 2200

        val friendsTab = findBottomTab(root, "Friends", totalW, totalH)
        val inboxTab = findBottomTab(root, "Inbox", totalW, totalH)
        val profileTab = findBottomTab(root, "Profile", totalW, totalH)
            ?: findBottomTab(root, "Me", totalW, totalH)
        val homeTab = findBottomTab(root, "Home", totalW, totalH)

        val hasBottomBar = homeTab != null || friendsTab != null || inboxTab != null || profileTab != null

        // 1. Friends, Inbox, and Profile tabs are explicitly allowed!
        if (friendsTab?.isSelected == true ||
            inboxTab?.isSelected == true ||
            profileTab?.isSelected == true
        ) {
            return DetectionResult("tiktok", pkg, false, false, BlockStrategy.NAVIGATE_BACK)
        }

        // 2. Check if we are on the TikTok Home screen ("Home" selected or "For You" visible at top)
        val hasForYouHeader = try {
            val forYou = root.findAccessibilityNodeInfosByText("For You") ?: emptyList()
            forYou.any { n ->
                n.isVisibleToUser &&
                    Rect().also(n::getBoundsInScreen).top in 1..(totalH * 0.20f).toInt()
            }
        } catch (_: Exception) {
            false
        }

        if (hasBottomBar) {
            val onHomeFeed = (homeTab?.isSelected == true) || hasForYouHeader
            if (!onHomeFeed) {
                return DetectionResult("tiktok", pkg, false, false, BlockStrategy.NAVIGATE_BACK)
            }

            // Redirect off Home onto Friends (first choice), or Inbox, or Profile!
            val targetTab = friendsTab ?: inboxTab ?: profileTab
            if (targetTab != null) {
                return DetectionResult(
                    appId = "tiktok",
                    packageName = pkg,
                    inShortFormFeed = true,
                    dmExempted = false,
                    strategy = BlockStrategy.REDIRECT_TAB,
                    redirectTargetNode = targetTab.clickableNode,
                    redirectTapBounds = targetTab.bounds,
                    windowId = root.windowId
                )
            }
        }

        // 3. No bottom bar visible: check if a standalone full-screen video player sub-page is open
        val hasStandaloneVideoPlayer = hasVisibleId(root, "$pkg:id/player_view") ||
            hasVisibleId(root, "$pkg:id/simplayer_api_player_view")

        if (!hasStandaloneVideoPlayer) {
            return DetectionResult("tiktok", pkg, false, false, BlockStrategy.NAVIGATE_BACK)
        }

        val isDmExempt = if (!allowDmReels) {
            false
        } else {
            try {
                val replyNodes = root.findAccessibilityNodeInfosByText("Reply to") ?: emptyList()
                replyNodes.any { n ->
                    n.isVisibleToUser && !n.isEditable &&
                        Rect().also(n::getBoundsInScreen).top >= (totalH * 0.78f).toInt()
                }
            } catch (_: Exception) {
                false
            }
        }

        return DetectionResult(
            appId = "tiktok",
            packageName = pkg,
            inShortFormFeed = true,
            dmExempted = isDmExempt,
            strategy = BlockStrategy.NAVIGATE_BACK,
            windowId = root.windowId
        )
    }

    private fun hasVisibleId(root: AccessibilityNodeInfo, fullId: String): Boolean =
        safeFindById(root, fullId).any(::isVisible)

    private fun findFirstVisibleNode(root: AccessibilityNodeInfo, fullId: String): AccessibilityNodeInfo? =
        safeFindById(root, fullId).firstOrNull(::isVisible)

    private fun safeFindById(root: AccessibilityNodeInfo, fullId: String): List<AccessibilityNodeInfo> =
        try {
            root.findAccessibilityNodeInfosByViewId(fullId) ?: emptyList()
        } catch (_: Exception) {
            emptyList()
        }

    private fun isVisible(node: AccessibilityNodeInfo, outRect: Rect = Rect()): Boolean {
        if (!node.isVisibleToUser) return false
        node.getBoundsInScreen(outRect)
        return outRect.width() > 0 && outRect.height() > 0
    }
}
