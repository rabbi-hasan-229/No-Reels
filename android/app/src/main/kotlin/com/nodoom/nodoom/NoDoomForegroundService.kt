package com.nodoom.nodoom

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder

/**
 * Lightweight foreground notification bar service that displays the live reels count
 * and time wasted directly in the Android status/notification bar (no screen overlay).
 */
class NoDoomForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "nodoom_status_bar"
        private const val NOTIF_ID = 1001
        @Volatile private var isRunning = false
        @Volatile private var lastInFeedState = false

        fun syncWithFeedState(context: Context, inMonitoredFeed: Boolean) {
            lastInFeedState = inMonitoredFeed
            startOrUpdate(context)
        }

        fun startOrUpdate(context: Context) {
            NoDoomPrefs.ensureLoaded(context)
            val shouldRun = when (NoDoomPrefs.statusBarMode) {
                NoDoomPrefs.StatusBarMode.PERMANENT -> true
                NoDoomPrefs.StatusBarMode.FEED_ONLY -> lastInFeedState
                NoDoomPrefs.StatusBarMode.OFF -> false
            }
            if (!shouldRun) {
                stop(context)
                return
            }
            if (isRunning) {
                updateNotificationIfRunning(context)
                return
            }
            val intent = Intent(context, NoDoomForegroundService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (_: Exception) {}
        }

        fun updateNotificationIfRunning(context: Context) {
            NoDoomPrefs.ensureLoaded(context)
            val shouldRun = when (NoDoomPrefs.statusBarMode) {
                NoDoomPrefs.StatusBarMode.PERMANENT -> true
                NoDoomPrefs.StatusBarMode.FEED_ONLY -> lastInFeedState
                NoDoomPrefs.StatusBarMode.OFF -> false
            }
            if (!shouldRun) {
                stop(context)
                return
            }
            if (!isRunning) {
                startOrUpdate(context)
                return
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            nm.notify(NOTIF_ID, buildNotification(context))
        }

        fun stop(context: Context) {
            try {
                context.stopService(Intent(context, NoDoomForegroundService::class.java))
            } catch (_: Exception) {}
        }

        private fun buildNotification(context: Context): Notification {
            NoDoomPrefs.ensureLoaded(context)
            val count = NoDoomPrefs.todayReelsCount
            val totalSec = NoDoomPrefs.todayReelsSec
            val mins = totalSec / 60
            val secs = totalSec % 60
            val timeFormatted = when {
                mins >= 60 -> "${mins / 60}h ${mins % 60}m"
                mins > 0 -> "${mins}m ${secs}s"
                else -> "${secs}s"
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )

            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, CHANNEL_ID)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }

            builder
                .setContentTitle("No-Reels · $count Reels · $timeFormatted")
                .setContentText("Today: $count reels watched · $timeFormatted time wasted")
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                builder.setSmallIcon(createCounterBadgeIcon(count))
            } else {
                builder.setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            }

            return builder.build()
        }

        /** Renders the live reel count directly as a crisp status-bar notification icon. */
        private fun createCounterBadgeIcon(count: Int): Icon {
            val size = 64
            val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)

            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                style = Paint.Style.STROKE
                strokeWidth = 4.5f
            }
            canvas.drawRoundRect(4f, 8f, 60f, 56f, 14f, 14f, bgPaint)

            val label = if (count > 99) "99+" else "${count}R"
            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textAlign = Paint.Align.CENTER
                typeface = Typeface.create("sans-serif", Typeface.BOLD)
                textSize = if (label.length >= 3) 22f else 26f
            }
            val yPos = (size / 2f) - ((textPaint.descent() + textPaint.ascent()) / 2f)
            canvas.drawText(label, size / 2f, yPos, textPaint)

            return Icon.createWithBitmap(bmp)
        }
    }

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isRunning = true
        createChannel()
        try {
            startForeground(NOTIF_ID, buildNotification(this))
        } catch (_: Exception) {}
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "No-Reels Notification Bar Counter",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live reels count and time wasted in the notification bar."
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
