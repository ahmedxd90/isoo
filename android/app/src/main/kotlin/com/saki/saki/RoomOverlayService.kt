package com.saki.saki

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import androidx.core.app.NotificationCompat

class RoomOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var bubble: ImageView? = null
    private var roomName = "غرفة SAKI"
    private var imageUrl = ""

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, notification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        roomName = intent?.getStringExtra(EXTRA_ROOM_NAME).orEmpty().ifBlank { "غرفة SAKI" }
        imageUrl = intent?.getStringExtra(EXTRA_IMAGE_URL).orEmpty()
        if (Settings.canDrawOverlays(this)) showBubble()
        if (imageUrl.isNotBlank()) loadBubbleImage()
        return START_STICKY
    }

    private fun showBubble() {
        if (bubble != null) return
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val view = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play)
            setColorFilter(Color.WHITE)
            setBackgroundColor(Color.rgb(101, 107, 249))
            elevation = 12f
            contentDescription = roomName
        }
        val size = (58 * resources.displayMetrics.density).toInt()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            size,
            size,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = 18
            y = 220
        }
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        view.setOnTouchListener { _, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    downY = event.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - downX).toInt()
                    val dy = (event.rawY - downY).toInt()
                    if (kotlin.math.abs(dx) > 8 || kotlin.math.abs(dy) > 8) moved = true
                    params.x = startX - dx
                    params.y = startY + dy
                    windowManager?.updateViewLayout(view, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) openApp()
                    true
                }
                else -> false
            }
        }
        bubble = view
        windowManager?.addView(view, params)
    }

    private fun loadBubbleImage() {
        Thread {
            try {
                val bitmap = java.net.URL(imageUrl).openStream().use { BitmapFactory.decodeStream(it) }
                if (bitmap != null) {
                    bubble?.post {
                        bubble?.clearColorFilter()
                        bubble?.setImageBitmap(bitmap)
                    }
                }
            } catch (_: Exception) {
                // Keep the room icon fallback when the remote image is unavailable.
            }
        }.start()
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        } ?: return
        startActivity(intent)
    }

    override fun onDestroy() {
        bubble?.let { windowManager?.removeView(it) }
        bubble = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(): Notification = NotificationCompat.Builder(this, CHANNEL_ID)
        .setSmallIcon(android.R.drawable.ic_media_play)
        .setContentTitle("$roomName نشطة")
        .setContentText("اضغط للعودة إلى الغرفة")
        .setOngoing(true)
        .setCategory(NotificationCompat.CATEGORY_CALL)
        .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "جلسة الغرفة", NotificationManager.IMPORTANCE_LOW),
        )
    }

    companion object {
        private const val CHANNEL_ID = "saki_room_session"
        private const val NOTIFICATION_ID = 7102
        const val EXTRA_ROOM_NAME = "roomName"
        const val EXTRA_ROOM_ID = "roomId"
        const val EXTRA_IMAGE_URL = "imageUrl"

        fun start(context: Context, roomId: String, roomName: String, imageUrl: String) {
            val intent = Intent(context, RoomOverlayService::class.java).apply {
                putExtra(EXTRA_ROOM_ID, roomId)
                putExtra(EXTRA_ROOM_NAME, roomName)
                putExtra(EXTRA_IMAGE_URL, imageUrl)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
