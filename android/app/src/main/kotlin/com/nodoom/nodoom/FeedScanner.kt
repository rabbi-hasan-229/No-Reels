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
        COVER_VIDEO_REGION
    }

    data class DetectionResult(
        val appId: String,
        val packageName: String,
        val inShortFormFeed: Boolean,
        val dmExempted: Boolean,
        val strategy: BlockStrategy,
        /** Non-null for COVER_VIDEO_REGION (TikTok player_view / view_rootview bounds). */
        val coverBoundsInScreen: Rect? = null,
        val coverBoundsInWindow: Rect? = null,
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

    /**
     * Fast, zero-flicker TikTok video feed detector & bounded player cover calculator:
     *
     * 1. Detects TikTok's video player & main feed immediately (0ms) via view IDs,
     *    top feed tabs ("For You", "Following"), selected bottom tabs ("Home", "Friends"),
     *    or full-screen video containers — even before player_view finishes buffering.
     * 2. When our opaque video cover is already on screen (activeCoverScreenBounds != null),
     *    Android marks nodes behind the cover as isVisibleToUser = false. We therefore inspect
     *    covered player nodes regardless of isVisibleToUser and keep the cover rock-solid
     *    until the user explicitly navigates to Inbox, Profile, Settings, or an exempted DM.
     * 3. Always leaves the bottom navigation bar (~9% of screen height) uncovered so Inbox
     *    and Profile remain clickable at all times.
     */
    private fun scanTikTok(
        root: AccessibilityNodeInfo,
        pkg: String,
        screenW: Int,
        screenH: Int,
        allowDmReels: Boolean,
        activeCoverScreenBounds: Rect?
    ): DetectionResult {
        val rootRect = Rect().also(root::getBoundsInScreen)
        val totalW = if (screenW > 0) screenW else rootRect.width().coerceAtLeast(1080)
        val totalH = if (screenH > 0) screenH else rootRect.height().coerceAtLeast(2200)
        val defaultNavReserve = (totalH * 0.088f).toInt()
        val defaultCoverBottom = (totalH - defaultNavReserve).coerceAtLeast(400)
        val isCoverCurrentlyActive = activeCoverScreenBounds != null

        val playerCandidateIds = listOf(
            "$pkg:id/player_view",
            "$pkg:id/simplayer_api_player_view",
            "$pkg:id/view_rootview",
            "$pkg:id/viewpager",
            "$pkg:id/feed_viewpager",
            "$pkg:id/video_view"
        )

        var foundPlayerNode: AccessibilityNodeInfo? = null
        val nodeRect = Rect()

        for (fullId in playerCandidateIds) {
            val nodes = safeFindById(root, fullId)
            for (n in nodes) {
                n.getBoundsInScreen(nodeRect)
                if (nodeRect.width() < totalW * 0.7f || nodeRect.height() < totalH * 0.5f) continue
                // If our cover is active, Android marks the underlying player as not visibleToUser;
                // accept it anyway so the cover never flickers off on content change events!
                if (!n.isVisibleToUser && !isCoverCurrentlyActive) continue
                foundPlayerNode = n
                break
            }
            if (foundPlayerNode != null) break
        }

        // Single fast BFS pass to inspect bottom navigation tabs, top feed tabs,
        // non-video screens (Inbox / Profile / Settings), and DM reply bars.
        var homeOrFriendsTabSelected = false
        var inboxOrProfileTabSelected = false
        var hasTopFeedIndicators = false
        var hasInboxOrProfileScreenMarkers = false
        var hasFullScreenVideoSurface = false
        var hasDmReplyBar = false
        var detectedBottomNavTop = totalH

        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0

        while (queue.isNotEmpty() && visited < 260) {
            val node = queue.poll() ?: break
            visited++
            node.getBoundsInScreen(nodeRect)
            if (nodeRect.width() <= 0 || nodeRect.height() <= 0) continue

            val cls = node.className?.toString() ?: ""
            // Detect full-screen video surface/pager even on obfuscated TikTok builds
            if ((cls.contains("ViewPager") ||
                    cls == "android.view.SurfaceView" ||
                    cls == "android.view.TextureView") &&
                nodeRect.width() >= totalW * 0.85f &&
                nodeRect.height() >= totalH * 0.68f &&
                (node.isVisibleToUser || isCoverCurrentlyActive)
            ) {
                hasFullScreenVideoSurface = true
            }

            val rawLabel = (node.text ?: node.contentDescription)?.toString()?.trim() ?: ""
            val label = rawLabel.lowercase(Locale.ROOT)

            if (label.isNotEmpty()) {
                // 1. Check bottom navigation bar tabs (located in bottom 14% of screen, always uncovered)
                if (nodeRect.top >= (totalH * 0.85f).toInt() && nodeRect.bottom <= totalH + 20) {
                    val isTabSelected = node.isSelected ||
                        node.parent?.isSelected == true ||
                        node.parent?.parent?.isSelected == true

                    if (label == "home" || label == "friends" || label == "for you") {
                        if (nodeRect.top in (totalH * 0.86f).toInt()..(totalH * 0.96f).toInt()) {
                            detectedBottomNavTop = minOf(detectedBottomNavTop, nodeRect.top)
                        }
                        if (isTabSelected) homeOrFriendsTabSelected = true
                    } else if (label == "inbox" || label == "profile" || label == "me") {
                        if (nodeRect.top in (totalH * 0.86f).toInt()..(totalH * 0.96f).toInt()) {
                            detectedBottomNavTop = minOf(detectedBottomNavTop, nodeRect.top)
                        }
                        if (isTabSelected) inboxOrProfileTabSelected = true
                    }
                }

                // 2. Check top feed tabs ("For You", "Following", "STEM", "Explore")
                if (nodeRect.top <= (totalH * 0.16f).toInt() &&
                    (label == "for you" || label == "following" || label == "stem")
                ) {
                    hasTopFeedIndicators = true
                }

                // 3. Check unmistakable Inbox / Profile / Settings screen headers
                if (nodeRect.top <= (totalH * 0.45f).toInt()) {
                    if (label == "all activity" ||
                        label == "new followers" ||
                        label == "system notifications" ||
                        label == "edit profile" ||
                        label == "share profile" ||
                        label == "add bio" ||
                        label == "settings and privacy"
                    ) {
                        hasInboxOrProfileScreenMarkers = true
                    }
                }

                // 4. Check DM video reply bar at the bottom of a friend-sent DM video
                if (node.isVisibleToUser &&
                    node.isEnabled &&
                    !node.isEditable &&
                    nodeRect.top >= (totalH * 0.80f).toInt() &&
                    TIKTOK_DM_REPLY_PREFIXES.any { label.startsWith(it) }
                ) {
                    hasDmReplyBar = true
                }
            }

            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }

        // If the user explicitly switched to the Inbox list or Profile screen (and hasn't opened
        // a full-screen video inside it), do NOT show the video cover.
        val onNonVideoTab = (inboxOrProfileTabSelected || hasInboxOrProfileScreenMarkers) &&
            !homeOrFriendsTabSelected &&
            !hasTopFeedIndicators

        if (onNonVideoTab) {
            return DetectionResult("tiktok", pkg, false, false, BlockStrategy.COVER_VIDEO_REGION)
        }

        val inVideoFeed = foundPlayerNode != null ||
            homeOrFriendsTabSelected ||
            hasTopFeedIndicators ||
            hasFullScreenVideoSurface ||
            isCoverCurrentlyActive

        if (!inVideoFeed) {
            return DetectionResult("tiktok", pkg, false, false, BlockStrategy.COVER_VIDEO_REGION)
        }

        val coverBottom = if (detectedBottomNavTop < totalH) {
            detectedBottomNavTop
        } else {
            defaultCoverBottom
        }

        val coverRect = Rect(0, 0, totalW, coverBottom)
        val isDmExempt = allowDmReels && hasDmReplyBar

        return DetectionResult(
            appId = "tiktok",
            packageName = pkg,
            inShortFormFeed = true,
            dmExempted = isDmExempt,
            strategy = BlockStrategy.COVER_VIDEO_REGION,
            coverBoundsInScreen = coverRect,
            coverBoundsInWindow = coverRect,
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
