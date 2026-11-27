package com.nodoom.nodoom

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * Zero-database, flat SharedPreferences storage with in-memory static state
 * so AccessibilityService callbacks never block on disk I/O.
 */
object NoDoomPrefs {
    private const val PREFS_NAME = "NoDoomPrefs"
    private const val KEY_DATE = "today_date"
    private const val KEY_TODAY_REELS = "today_reels"
    private const val KEY_TODAY_REELS_SEC = "today_reels_sec"
    private const val KEY_RECENT_HASHES = "recent_hashes"
    private const val KEY_ALLOW_DM = "allow_dm_reels"
    private const val KEY_STATUS_BAR_MODE = "status_bar_mode" // PERMANENT, FEED_ONLY, OFF
    private const val KEY_STATUS_BAR_NOTIF = "status_bar_notif"
    private const val KEY_STRICT_LOCK = "strict_uninstall_lock"
    private const val KEY_EMERGENCY_UNTIL = "emergency_unlock_until_ms"
    private const val KEY_WALK_TARGET_STEPS = "walk_target_steps"
    private const val KEY_LIGHT_MODE = "light_mode"
    private const val KEY_THEME_ID = "app_theme_id"
    private const val KEY_FONT_FAMILY = "app_font_family"
    private const val KEY_TITLE_SIZE = "card_title_size"
    private const val KEY_BODY_SIZE = "card_body_size"
    private const val KEY_UI_SCALE = "ui_text_scale"
    private const val KEY_IS_GRID = "is_grid_view"
    private const val KEY_RULES_JSON = "app_rules_json"
    private const val KEY_APP_USAGE_JSON = "app_usage_json"
    private const val KEY_APP_REELS_SEC_JSON = "app_reels_sec_json"
    private const val KEY_APP_REELS_COUNT_JSON = "app_reels_count_json"
    private const val KEY_DAILY_HISTORY_JSON = "daily_history_json"
    private const val KEY_LIFETIME_REELS = "lifetime_reels_count"
    private const val KEY_LIFETIME_REELS_SEC = "lifetime_reels_sec"
    private const val KEY_LIFETIME_BLOCKED = "lifetime_blocked_count"
    private const val KEY_LIFETIME_SAVED_SEC = "lifetime_saved_sec"
    private const val AVG_REEL_DURATION_SEC = 30

    enum class StatusBarMode { PERMANENT, FEED_ONLY, OFF }

    data class DailyStat(
        val date: String,
        val reelsCount: Int,
        val reelsSec: Int
    )

    data class AppRule(
        val appId: String, // "youtube", "instagram", "facebook", "tiktok"
        val name: String,
        val blockReels: Boolean = true,
        /** 0 = instant reel block; >0 = allowed reel seconds per day before blocking */
        val dailyReelLimitSec: Int = 0,
        /** 0 = no count cap (uses time cap); >0 = block reels after N videos */
        val dailyReelCountLimit: Int = 0,
        val blockWholeApp: Boolean = false,
        /** 0 = instant whole-app block (if blockWholeApp=true); >0 = allowed whole-app seconds per day */
        val dailyAppLimitSec: Int = 1800
    )

    @Volatile var initialized = false
    @Volatile var todayDate: String = ""
    @Volatile var todayReelsCount: Int = 0
    @Volatile var todayReelsSec: Int = 0
    @Volatile var lifetimeReelsCount: Int = 0
    @Volatile var lifetimeReelsSec: Int = 0
    @Volatile var lifetimeBlockedCount: Int = 0
    @Volatile var lifetimeSavedSec: Int = 0
    @Volatile private var lastBlockedRecordedAtMs: Long = 0L
    @Volatile var allowDmReels: Boolean = true
    @Volatile var statusBarMode: StatusBarMode = StatusBarMode.PERMANENT
    @Volatile var statusBarNotification: Boolean = true
    /**
     * Defaults to false on a fresh install for Google Play Store policy compliance;
     * automatically turns true as soon as the user enables Device Admin or toggles Strict Lock ON.
     */
    @Volatile var strictUninstallLock: Boolean = false
    @Volatile var emergencyUnlockUntilMs: Long = 0L
    @Volatile var walkTargetSteps: Int = 200
    @Volatile var lightMode: Boolean = true
    @Volatile var themeId: String = "pure_light"
    @Volatile var fontFamily: String = "plus_jakarta_sans"
    @Volatile var cardTitleSize: Float = 20.0f
    @Volatile var cardBodySize: Float = 14.0f
    @Volatile var uiTextScale: Float = 1.0f
    @Volatile var isGridView: Boolean = false

    val recentHashes = ArrayDeque<String>()
    val rules = LinkedHashMap<String, AppRule>()
    val appUsageSec = HashMap<String, Int>()
    val appReelsSec = HashMap<String, Int>()
    val appReelsCount = HashMap<String, Int>()
    val dailyHistory = LinkedHashMap<String, DailyStat>()

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun currentDateString(): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    private fun defaultRules(): LinkedHashMap<String, AppRule> = linkedMapOf(
        "youtube" to AppRule("youtube", "YouTube", blockReels = true, dailyReelLimitSec = 0, dailyReelCountLimit = 0, blockWholeApp = false, dailyAppLimitSec = 1800),
        "instagram" to AppRule("instagram", "Instagram", blockReels = true, dailyReelLimitSec = 0, dailyReelCountLimit = 0, blockWholeApp = false, dailyAppLimitSec = 1800),
        "facebook" to AppRule("facebook", "Facebook", blockReels = true, dailyReelLimitSec = 0, dailyReelCountLimit = 0, blockWholeApp = false, dailyAppLimitSec = 1800),
        "tiktok" to AppRule("tiktok", "TikTok", blockReels = true, dailyReelLimitSec = 0, dailyReelCountLimit = 0, blockWholeApp = false, dailyAppLimitSec = 1800),
    )

    @Synchronized
    fun ensureLoaded(context: Context) {
        if (!initialized) {
            load(context)
        } else {
            checkDayRollover(context)
        }
    }

    @Synchronized
    fun load(context: Context) {
        val p = prefs(context)
        val today = currentDateString()
        val storedDate = p.getString(KEY_DATE, "") ?: ""

        allowDmReels = p.getBoolean(KEY_ALLOW_DM, true)
        statusBarMode = try {
            StatusBarMode.valueOf(p.getString(KEY_STATUS_BAR_MODE, "PERMANENT") ?: "PERMANENT")
        } catch (_: Exception) {
            StatusBarMode.PERMANENT
        }
        statusBarNotification = p.getBoolean(KEY_STATUS_BAR_NOTIF, true)
        strictUninstallLock = p.getBoolean(KEY_STRICT_LOCK, false)
        emergencyUnlockUntilMs = p.getLong(KEY_EMERGENCY_UNTIL, 0L)
        walkTargetSteps = p.getInt(KEY_WALK_TARGET_STEPS, 200)
        lightMode = p.getBoolean(KEY_LIGHT_MODE, true)
        themeId = p.getString(KEY_THEME_ID, "pure_light") ?: "pure_light"
        fontFamily = p.getString(KEY_FONT_FAMILY, "plus_jakarta_sans") ?: "plus_jakarta_sans"
        cardTitleSize = p.getFloat(KEY_TITLE_SIZE, 20.0f)
        cardBodySize = p.getFloat(KEY_BODY_SIZE, 14.0f)
        uiTextScale = p.getFloat(KEY_UI_SCALE, 1.0f)
        isGridView = p.getBoolean(KEY_IS_GRID, false)

        rules.clear()
        rules.putAll(defaultRules())
        val rulesRaw = p.getString(KEY_RULES_JSON, null)
        if (!rulesRaw.isNullOrEmpty()) {
            try {
                val arr = JSONArray(rulesRaw)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val id = o.optString("appId")
                    val def = rules[id] ?: continue
                    rules[id] = AppRule(
                        appId = id,
                        name = def.name,
                        blockReels = o.optBoolean("blockReels", def.blockReels),
                        dailyReelLimitSec = o.optInt("dailyReelLimitSec", def.dailyReelLimitSec),
                        dailyReelCountLimit = o.optInt("dailyReelCountLimit", def.dailyReelCountLimit),
                        blockWholeApp = o.optBoolean("blockWholeApp", def.blockWholeApp),
                        dailyAppLimitSec = o.optInt("dailyAppLimitSec", def.dailyAppLimitSec)
                    )
                }
            } catch (_: Exception) {}
        }

        dailyHistory.clear()
        val historyRaw = p.getString(KEY_DAILY_HISTORY_JSON, null)
        if (!historyRaw.isNullOrEmpty()) {
            try {
                val arr = JSONArray(historyRaw)
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    val d = o.optString("date", "")
                    if (d.isNotEmpty()) {
                        dailyHistory[d] = DailyStat(
                            date = d,
                            reelsCount = o.optInt("reelsCount", 0),
                            reelsSec = o.optInt("reelsSec", 0)
                        )
                    }
                }
            } catch (_: Exception) {}
        }

        if (storedDate != today) {
            if (storedDate.isNotEmpty()) {
                val prevCount = p.getInt(KEY_TODAY_REELS, 0)
                val prevSec = p.getInt(KEY_TODAY_REELS_SEC, 0)
                dailyHistory[storedDate] = DailyStat(storedDate, prevCount, prevSec)
            }
            todayDate = today
            todayReelsCount = 0
            todayReelsSec = 0
            recentHashes.clear()
            appUsageSec.clear()
            appReelsSec.clear()
            appReelsCount.clear()
            dailyHistory[today] = DailyStat(today, 0, 0)
            p.edit()
                .putString(KEY_DATE, today)
                .putInt(KEY_TODAY_REELS, 0)
                .putInt(KEY_TODAY_REELS_SEC, 0)
                .putString(KEY_RECENT_HASHES, "[]")
                .putString(KEY_APP_USAGE_JSON, "{}")
                .putString(KEY_APP_REELS_SEC_JSON, "{}")
                .putString(KEY_APP_REELS_COUNT_JSON, "{}")
                .putString(KEY_DAILY_HISTORY_JSON, serializeDailyHistory())
                .apply()
        } else {
            todayDate = today
            todayReelsCount = p.getInt(KEY_TODAY_REELS, 0)
            todayReelsSec = p.getInt(KEY_TODAY_REELS_SEC, 0)
            dailyHistory[today] = DailyStat(today, todayReelsCount, todayReelsSec)
            recentHashes.clear()
            try {
                val arr = JSONArray(p.getString(KEY_RECENT_HASHES, "[]") ?: "[]")
                for (i in 0 until arr.length()) {
                    recentHashes.addLast(arr.getString(i))
                }
            } catch (_: Exception) {}
            appUsageSec.clear()
            try {
                val obj = JSONObject(p.getString(KEY_APP_USAGE_JSON, "{}") ?: "{}")
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    appUsageSec[k] = obj.optInt(k, 0)
                }
            } catch (_: Exception) {}
            appReelsSec.clear()
            try {
                val obj = JSONObject(p.getString(KEY_APP_REELS_SEC_JSON, "{}") ?: "{}")
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    appReelsSec[k] = obj.optInt(k, 0)
                }
            } catch (_: Exception) {}
            appReelsCount.clear()
            try {
                val obj = JSONObject(p.getString(KEY_APP_REELS_COUNT_JSON, "{}") ?: "{}")
                val keys = obj.keys()
                while (keys.hasNext()) {
                    val k = keys.next()
                    appReelsCount[k] = obj.optInt(k, 0)
                }
            } catch (_: Exception) {}
        }
        val historySumReels = dailyHistory.values.sumOf { it.reelsCount }
        val historySumSec = dailyHistory.values.sumOf { it.reelsSec }
        lifetimeReelsCount = maxOf(
            p.getInt(KEY_LIFETIME_REELS, 0),
            historySumReels,
            todayReelsCount
        )
        lifetimeReelsSec = maxOf(
            p.getInt(KEY_LIFETIME_REELS_SEC, 0),
            historySumSec,
            todayReelsSec
        )
        lifetimeBlockedCount = p.getInt(KEY_LIFETIME_BLOCKED, 0)
        lifetimeSavedSec = p.getInt(
            KEY_LIFETIME_SAVED_SEC,
            lifetimeBlockedCount * AVG_REEL_DURATION_SEC
        )
        initialized = true
    }

    private fun serializeDailyHistory(): String {
        val keys = dailyHistory.keys.sorted().takeLast(30)
        val arr = JSONArray()
        for (k in keys) {
            val st = dailyHistory[k] ?: continue
            arr.put(JSONObject().apply {
                put("date", st.date)
                put("reelsCount", st.reelsCount)
                put("reelsSec", st.reelsSec)
            })
        }
        return arr.toString()
    }

    @Synchronized
    fun getLast7DaysHistory(): List<Map<String, Any>> {
        val dateFmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val dayFmt = SimpleDateFormat("EEE", Locale.US)
        val list = ArrayList<Map<String, Any>>(7)
        for (offset in 6 downTo 0) {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, -offset)
            val dateStr = dateFmt.format(cal.time)
            val label = if (offset == 0) "Today" else dayFmt.format(cal.time)
            val stat = if (dateStr == todayDate) {
                DailyStat(todayDate, todayReelsCount, todayReelsSec)
            } else {
                dailyHistory[dateStr] ?: DailyStat(dateStr, 0, 0)
            }
            list.add(
                mapOf(
                    "date" to dateStr,
                    "dayLabel" to label,
                    "reelsCount" to stat.reelsCount,
                    "reelsSec" to stat.reelsSec
                )
            )
        }
        return list
    }

    @Synchronized
    fun checkDayRollover(context: Context) {
        val today = currentDateString()
        if (today != todayDate) {
            if (todayDate.isNotEmpty()) {
                dailyHistory[todayDate] = DailyStat(todayDate, todayReelsCount, todayReelsSec)
            }
            todayDate = today
            todayReelsCount = 0
            todayReelsSec = 0
            recentHashes.clear()
            appUsageSec.clear()
            appReelsSec.clear()
            appReelsCount.clear()
            dailyHistory[today] = DailyStat(today, 0, 0)
            prefs(context).edit()
                .putString(KEY_DATE, today)
                .putInt(KEY_TODAY_REELS, 0)
                .putInt(KEY_TODAY_REELS_SEC, 0)
                .putString(KEY_RECENT_HASHES, "[]")
                .putString(KEY_APP_USAGE_JSON, "{}")
                .putString(KEY_APP_REELS_SEC_JSON, "{}")
                .putString(KEY_APP_REELS_COUNT_JSON, "{}")
                .putString(KEY_DAILY_HISTORY_JSON, serializeDailyHistory())
                .apply()
        }
    }

    @Synchronized
    fun recordNewReel(context: Context, appId: String, hashKey: String): Int {
        checkDayRollover(context)
        todayReelsCount++
        lifetimeReelsCount++
        appReelsCount[appId] = (appReelsCount[appId] ?: 0) + 1
        dailyHistory[todayDate] = DailyStat(todayDate, todayReelsCount, todayReelsSec)
        recentHashes.addLast(hashKey)
        while (recentHashes.size > 40) recentHashes.removeFirst()

        val arr = JSONArray()
        recentHashes.forEach { arr.put(it) }
        val countObj = JSONObject()
        for ((k, v) in appReelsCount) countObj.put(k, v)

        prefs(context).edit()
            .putInt(KEY_TODAY_REELS, todayReelsCount)
            .putInt(KEY_LIFETIME_REELS, lifetimeReelsCount)
            .putString(KEY_RECENT_HASHES, arr.toString())
            .putString(KEY_APP_REELS_COUNT_JSON, countObj.toString())
            .putString(KEY_DAILY_HISTORY_JSON, serializeDailyHistory())
            .apply()
        return todayReelsCount
    }

    @Synchronized
    fun recordBlockedReel(context: Context) {
        val now = System.currentTimeMillis()
        // Debounce rapid consecutive scan ticks during a single block event (2.5s window)
        if (now - lastBlockedRecordedAtMs < 2500L) return
        lastBlockedRecordedAtMs = now
        checkDayRollover(context)
        lifetimeBlockedCount++
        lifetimeSavedSec += AVG_REEL_DURATION_SEC
        prefs(context).edit()
            .putInt(KEY_LIFETIME_BLOCKED, lifetimeBlockedCount)
            .putInt(KEY_LIFETIME_SAVED_SEC, lifetimeSavedSec)
            .apply()
    }

    @Synchronized
    fun addUsageSeconds(context: Context, appId: String, inReelsFeed: Boolean, deltaSec: Int) {
        if (deltaSec <= 0) return
        checkDayRollover(context)
        val nextAppSec = (appUsageSec[appId] ?: 0) + deltaSec
        appUsageSec[appId] = nextAppSec
        if (inReelsFeed) {
            todayReelsSec += deltaSec
            lifetimeReelsSec += deltaSec
            appReelsSec[appId] = (appReelsSec[appId] ?: 0) + deltaSec
            dailyHistory[todayDate] = DailyStat(todayDate, todayReelsCount, todayReelsSec)
        }
        val usageObj = JSONObject()
        for ((k, v) in appUsageSec) usageObj.put(k, v)
        val reelSecObj = JSONObject()
        for ((k, v) in appReelsSec) reelSecObj.put(k, v)

        prefs(context).edit()
            .putInt(KEY_TODAY_REELS_SEC, todayReelsSec)
            .putInt(KEY_LIFETIME_REELS_SEC, lifetimeReelsSec)
            .putString(KEY_APP_USAGE_JSON, usageObj.toString())
            .putString(KEY_APP_REELS_SEC_JSON, reelSecObj.toString())
            .putString(KEY_DAILY_HISTORY_JSON, serializeDailyHistory())
            .apply()
    }

    @Synchronized
    fun saveRules(context: Context) {
        val arr = JSONArray()
        for ((_, r) in rules) {
            arr.put(JSONObject().apply {
                put("appId", r.appId)
                put("blockReels", r.blockReels)
                put("dailyReelLimitSec", r.dailyReelLimitSec)
                put("dailyReelCountLimit", r.dailyReelCountLimit)
                put("blockWholeApp", r.blockWholeApp)
                put("dailyAppLimitSec", r.dailyAppLimitSec)
            })
        }
        prefs(context).edit().putString(KEY_RULES_JSON, arr.toString()).apply()
    }

    @Synchronized
    fun updateSettings(
        context: Context,
        allowDm: Boolean? = null,
        barMode: StatusBarMode? = null,
        barNotif: Boolean? = null,
        strictLock: Boolean? = null,
        walkSteps: Int? = null,
        isLightMode: Boolean? = null,
        newThemeId: String? = null,
        newFontFamily: String? = null,
        newTitleSize: Float? = null,
        newBodySize: Float? = null,
        newUiScale: Float? = null,
        newIsGrid: Boolean? = null
    ) {
        val ed = prefs(context).edit()
        if (allowDm != null) {
            allowDmReels = allowDm
            ed.putBoolean(KEY_ALLOW_DM, allowDm)
        }
        if (barMode != null) {
            statusBarMode = barMode
            ed.putString(KEY_STATUS_BAR_MODE, barMode.name)
        }
        if (barNotif != null) {
            statusBarNotification = barNotif
            ed.putBoolean(KEY_STATUS_BAR_NOTIF, barNotif)
        }
        if (strictLock != null) {
            strictUninstallLock = strictLock
            ed.putBoolean(KEY_STRICT_LOCK, strictLock)
        }
        if (walkSteps != null) {
            walkTargetSteps = walkSteps.coerceIn(50, 5000)
            ed.putInt(KEY_WALK_TARGET_STEPS, walkTargetSteps)
        }
        if (isLightMode != null) {
            lightMode = isLightMode
            ed.putBoolean(KEY_LIGHT_MODE, isLightMode)
        }
        if (newThemeId != null) {
            themeId = newThemeId
            ed.putString(KEY_THEME_ID, newThemeId)
        }
        if (newFontFamily != null) {
            fontFamily = newFontFamily
            ed.putString(KEY_FONT_FAMILY, newFontFamily)
        }
        if (newTitleSize != null) {
            cardTitleSize = newTitleSize.coerceIn(16f, 28f)
            ed.putFloat(KEY_TITLE_SIZE, cardTitleSize)
        }
        if (newBodySize != null) {
            cardBodySize = newBodySize.coerceIn(12f, 20f)
            ed.putFloat(KEY_BODY_SIZE, cardBodySize)
        }
        if (newUiScale != null) {
            uiTextScale = newUiScale.coerceIn(0.85f, 1.20f)
            ed.putFloat(KEY_UI_SCALE, uiTextScale)
        }
        if (newIsGrid != null) {
            isGridView = newIsGrid
            ed.putBoolean(KEY_IS_GRID, newIsGrid)
        }
        ed.apply()
    }

    @Synchronized
    fun grantEmergencyUnlock(context: Context, durationMinutes: Int): Long {
        val until = System.currentTimeMillis() + durationMinutes * 60_000L
        emergencyUnlockUntilMs = until
        prefs(context).edit().putLong(KEY_EMERGENCY_UNTIL, until).apply()
        return until
    }

    @Synchronized
    fun revokeEmergencyUnlock(context: Context) {
        emergencyUnlockUntilMs = 0L
        prefs(context).edit().putLong(KEY_EMERGENCY_UNTIL, 0L).apply()
    }

    fun isEmergencyUnlockActive(now: Long = System.currentTimeMillis()): Boolean =
        emergencyUnlockUntilMs > now

    fun shouldBlockWholeApp(appId: String, now: Long = System.currentTimeMillis()): Boolean {
        if (isEmergencyUnlockActive(now)) return false
        val rule = rules[appId] ?: return false
        if (!rule.blockWholeApp) return false
        val used = appUsageSec[appId] ?: 0
        return used >= rule.dailyAppLimitSec
    }

    fun shouldBlockReels(appId: String, now: Long = System.currentTimeMillis()): Boolean {
        if (isEmergencyUnlockActive(now)) return false
        val rule = rules[appId] ?: return false
        if (!rule.blockReels) return false
        val usedSec = appReelsSec[appId] ?: 0
        val usedCount = appReelsCount[appId] ?: 0
        val timeExceeded = usedSec >= rule.dailyReelLimitSec
        val countExceeded = rule.dailyReelCountLimit > 0 && usedCount >= rule.dailyReelCountLimit
        return timeExceeded || countExceeded
    }

    fun formatCompactStatus(): String {
        val mins = todayReelsSec / 60
        val secs = todayReelsSec % 60
        val timePart = if (mins > 0) "${mins}m" else "${secs}s"
        return "${todayReelsCount}r · $timePart"
    }
}
