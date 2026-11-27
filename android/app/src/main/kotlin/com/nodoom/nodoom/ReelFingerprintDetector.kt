package com.nodoom.nodoom

import android.graphics.Rect
import android.view.accessibility.AccessibilityNodeInfo
import java.security.MessageDigest
import java.util.ArrayDeque
import java.util.Locale

/**
 * AntiDoom-grade distinct short-form video fingerprint detector.
 *
 * Builds a privacy-preserving 6-byte SHA-256 fingerprint ("creatorHash|captionHash")
 * from the visible reel/short on screen so that:
 * - Bounced swipes and fling animations don't double-count
 * - Scrolling in the comment sheet pauses counting
 * - Revisiting an already watched video (last 40) doesn't increment the count
 * - Auto-advanced videos still count once settled for >= 750ms
 */
object ReelFingerprintDetector {

    sealed class Outcome {
        data object Paused : Outcome()
        data object NoKey : Outcome()
        data class Reel(val key: String) : Outcome()
    }

    private const val MAX_NODES = 420
    private const val PART_LEN = 40
    private const val MIN_CAPTION_LEN = 12

    private val HANDLE_REGEX = Regex("""(?<![\p{L}\p{N}_.])@[\p{L}\p{N}_.\-]{2,30}""")
    private val REEL_BY_REGEX = Regex("""(?i)\breel (?:by|oleh|dari) ([\p{L}\p{N}_.]{2,30}?)\.?(?:\s|$)""")
    private val FB_CREATOR_REGEX = listOf(
        Regex("""^View (.+?)['’]s reels?$""", RegexOption.IGNORE_CASE),
        Regex("""^Follow (.+)$""", RegexOption.IGNORE_CASE)
    )
    private val NUMBER_REGEX = Regex("""\d[\d.,:]*\s*[KkMmBb]?""")
    private val LETTER_REGEX = Regex("""\p{L}""")

    private val UI_CHROME_LABELS = setOf(
        "home", "shorts", "reels", "reel", "search", "create", "you", "library",
        "subscriptions", "inbox", "profile", "friends", "for you", "following",
        "explore", "live", "camera", "more", "more options", "back", "close",
        "pause", "play", "mute", "unmute", "video progress", "sponsored", "ad",
        "follow", "subscribe", "subscribed", "like", "comment", "share", "remix",
        "send", "save", "original audio", "notifications", "messages", "watch",
        "menu", "view product", "show more", "please wait", "more actions",
        "skip video", "video unavailable", "see translation", "previous video",
        "next video", "earns commission", "products", "paid partnership"
    )

    private val ACTION_PREFIXES = listOf(
        "like", "unlike", "dislike", "comment", "view comment", "share", "remix",
        "subscribe", "unsubscribe", "follow", "save", "send", "sound", "audio",
        "more actions", "go to channel", "add to", "mute", "unmute", "view ",
        "see more", "go to", "open ", "visit", "original sound", "original audio",
        "reel by", "sponsored reel", "reposted", "liked by", "double tap",
        "suggested", "reshare", "shared by", "turn sound", "profile picture"
    )

    private val PROGRESS_MARKERS = listOf(
        " seconds of ", " second of ", " minutes of ", " minute of "
    )

    fun detect(
        root: AccessibilityNodeInfo,
        appId: String,
        pkg: String,
        screenW: Int,
        screenH: Int
    ): Outcome {
        if (isCommentsOrSheetOpen(root, appId, pkg)) return Outcome.Paused

        if (appId == "tiktok") {
            return detectTikTok(root, pkg, screenW, screenH)
        }

        val scope = findFeedScope(root, appId, pkg) ?: root
        return scanGeneric(scope, screenW, screenH)
    }

    private fun isCommentsOrSheetOpen(root: AccessibilityNodeInfo, appId: String, pkg: String): Boolean {
        val pauseIds = when (appId) {
            "youtube" -> listOf("$pkg:id/app_engagement_panel", "$pkg:id/design_bottom_sheet")
            "instagram" -> listOf("$pkg:id/layout_comment_thread_edittext", "$pkg:id/bottom_sheet_container")
            "tiktok" -> listOf("$pkg:id/comment_list", "$pkg:id/comment_container")
            else -> emptyList()
        }
        return pauseIds.any { id ->
            try {
                root.findAccessibilityNodeInfosByViewId(id)?.any { it.isVisibleToUser } == true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun findFeedScope(root: AccessibilityNodeInfo, appId: String, pkg: String): AccessibilityNodeInfo? {
        val ids = when (appId) {
            "youtube" -> listOf(
                "$pkg:id/reel_player_page_content",
                "$pkg:id/reel_player_page_container",
                "$pkg:id/reel_player_page_view"
            )
            "instagram" -> listOf("$pkg:id/clips_viewer_view_pager")
            else -> emptyList()
        }
        for (id in ids) {
            try {
                val found = root.findAccessibilityNodeInfosByViewId(id)?.firstOrNull { it.isVisibleToUser }
                if (found != null) return found
            } catch (_: Exception) {}
        }
        return null
    }

    private fun detectTikTok(
        root: AccessibilityNodeInfo,
        pkg: String,
        screenW: Int,
        screenH: Int
    ): Outcome {
        val bounds = Rect()
        val page = try {
            root.findAccessibilityNodeInfosByViewId("$pkg:id/view_rootview")?.firstOrNull { n ->
                if (!n.isVisibleToUser) return@firstOrNull false
                n.getBoundsInScreen(bounds)
                screenW <= 0 || bounds.contains(screenW / 2, screenH / 2)
            }
        } catch (_: Exception) {
            null
        } ?: root

        val creator = readFirstVisibleText(page, "$pkg:id/title")
            ?.let { "@" + it.lowercase(Locale.ROOT).replace(Regex("""\s+"""), "") }
        val caption = readFirstVisibleText(page, "$pkg:id/desc")?.let(::cleanCaption)
        if (creator == null && caption == null) {
            return scanGeneric(page, screenW, screenH)
        }
        val parts = listOfNotNull(creator, caption)
        return Outcome.Reel(parts.joinToString("|") { sha256Short(it) })
    }

    private fun readFirstVisibleText(scope: AccessibilityNodeInfo, fullId: String): String? =
        try {
            scope.findAccessibilityNodeInfosByViewId(fullId)
                ?.firstOrNull { it.isVisibleToUser }
                ?.let { (it.text ?: it.contentDescription)?.toString() }
                ?.replace('\n', ' ')
                ?.trim()
                ?.takeIf { it.isNotEmpty() }
        } catch (_: Exception) {
            null
        }

    private fun scanGeneric(scope: AccessibilityNodeInfo, screenW: Int, screenH: Int): Outcome {
        val screen = Rect(0, 0, screenW, screenH)
        var handle: String? = null
        val candidates = ArrayList<String>(4)
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(scope)
        val bounds = Rect()
        var visited = 0

        while (queue.isNotEmpty() && visited < MAX_NODES) {
            val node = queue.poll() ?: break
            visited++
            if (!node.isVisibleToUser) continue
            node.getBoundsInScreen(bounds)
            if (screenW > 0 && screenH > 0 && !screen.contains(bounds.centerX(), bounds.centerY())) {
                continue
            }

            for (raw in listOf(node.text, node.contentDescription)) {
                val text = raw?.toString()?.trim()?.replace('\n', ' ') ?: continue
                if (text.isEmpty()) continue
                if (handle == null) {
                    REEL_BY_REGEX.find(text)?.let {
                        handle = "@" + it.groupValues[1].trimEnd('.').lowercase(Locale.ROOT)
                    } ?: HANDLE_REGEX.find(text)?.let {
                        handle = it.value.trimEnd('.', '-').lowercase(Locale.ROOT)
                    } ?: FB_CREATOR_REGEX.firstNotNullOfOrNull { rx ->
                        rx.find(text)?.groupValues?.getOrNull(1)
                    }?.let {
                        handle = "@" + it.lowercase(Locale.ROOT).replace(Regex("""\s+"""), "")
                    }
                }
                if (candidates.size < 4) {
                    cleanCaption(text)?.let { if (it !in candidates) candidates.add(it) }
                }
            }
            if (handle != null && candidates.size >= 4) break
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let(queue::add)
            }
        }

        if (handle == null && candidates.isEmpty()) return Outcome.NoKey
        val bestCaption = candidates.maxByOrNull { it.length }
        val parts = if (handle != null) {
            listOfNotNull(handle, bestCaption)
        } else {
            candidates.sortedByDescending { it.length }.take(2)
        }
        return Outcome.Reel(parts.joinToString("|") { sha256Short(it) })
    }

    private fun cleanCaption(text: String): String? {
        val cut = text.split('…', '\u2026').first().replace("\u2060", "").lowercase(Locale.ROOT)
        if (PROGRESS_MARKERS.any { cut.contains(it) }) return null
        val norm = NUMBER_REGEX.replace(cut, "#").replace(Regex("""\s+"""), " ").trim()
        if (LETTER_REGEX.findAll(norm).count() < 3) return null
        if (norm.length < MIN_CAPTION_LEN || norm in UI_CHROME_LABELS) return null
        if (HANDLE_REGEX.containsMatchIn(norm) && norm.length < 60) return null
        if (norm.length < 160 && ACTION_PREFIXES.any { norm.startsWith(it) }) return null
        return norm.take(PART_LEN)
    }

    private fun sha256Short(input: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(input.toByteArray())
        return digest.take(6).joinToString("") { "%02x".format(it) }
    }

    fun sameReel(a: String, b: String): Boolean {
        if (a == b) return true
        val pa = a.split('|').toSet()
        val pb = b.split('|').toSet()
        return pa.containsAll(pb) || pb.containsAll(pa)
    }

    fun sharesPart(a: String, b: String): Boolean =
        a.split('|').toSet().intersect(b.split('|').toSet()).isNotEmpty()
}
