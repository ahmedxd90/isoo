package saki.chat.co

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.graphics.drawable.GradientDrawable
import androidx.core.app.NotificationCompat

class RoomOverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var bubble: View? = null
    private var bubbleImage: ImageView? = null
    private var roomId = ""
    private var roomName = "غرفة SAKI"
    private var imageUrl = ""

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, notification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        roomId = intent?.getStringExtra(EXTRA_ROOM_ID).orEmpty()
        roomName = intent?.getStringExtra(EXTRA_ROOM_NAME).orEmpty().ifBlank { "غرفة SAKI" }
        imageUrl = intent?.getStringExtra(EXTRA_IMAGE_URL).orEmpty()
        if (Settings.canDrawOverlays(this)) showBubble()
        if (imageUrl.isNotBlank()) loadBubbleImage()
        return START_REDELIVER_INTENT
    }

    private fun showBubble() {
        if (bubble != null) return
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val image = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_media_play)
            setColorFilter(Color.WHITE)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        val view = FrameLayout(this).apply {
            background = GradientDrawable().apply {
                setColor(Color.rgb(29, 36, 66))
                cornerRadius = 18f * resources.displayMetrics.density
                setStroke(
                    (1.2f * resources.displayMetrics.density).toInt(),
                    Color.rgb(124, 131, 255),
                )
            }
            elevation = 12f
            contentDescription = roomName
            addView(image, FrameLayout.LayoutParams(-1, -1))
            addView(WaveOverlayView(this@RoomOverlayService), FrameLayout.LayoutParams(-1, -1))
            val controls = LinearLayout(this@RoomOverlayService).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.argb(150, 10, 12, 28))
                addView(control("عودة") { openApp("return") })
                addView(control("خروج") { openApp("exit") })
            }
            addView(controls, FrameLayout.LayoutParams(-1, 28).apply {
                gravity = Gravity.BOTTOM
            })
        }
        bubbleImage = image
        val width = (94 * resources.displayMetrics.density).toInt()
        val height = (68 * resources.displayMetrics.density).toInt()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            WindowManager.LayoutParams.TYPE_PHONE
        }
        val params = WindowManager.LayoutParams(
            width,
            height,
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
                        bubbleImage?.clearColorFilter()
                        bubbleImage?.setImageBitmap(bitmap)
                    }
                }
            } catch (_: Exception) {
                // Keep the room icon fallback when the remote image is unavailable.
            }
        }.start()
    }

    private fun openApp() {
        openApp("return")
    }

    private fun openApp(action: String) {
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ROOM_ID, roomId)
            putExtra(EXTRA_ROOM_NAME, roomName)
            putExtra(EXTRA_IMAGE_URL, imageUrl)
            putExtra(EXTRA_ACTION, action)
        } ?: return
        startActivity(intent)
    }

    private fun control(label: String, action: () -> Unit): TextView = TextView(this).apply {
        text = label
        setTextColor(Color.WHITE)
        textSize = 10f
        gravity = Gravity.CENTER
        isClickable = true
        setPadding(10, 0, 10, 0)
        setOnClickListener { action() }
    }

    override fun onDestroy() {
        bubble?.let { windowManager?.removeView(it) }
        bubble = null
        bubbleImage = null
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

    private class WaveOverlayView(context: Context) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(103, 232, 249)
        }
        private var phase = 0f
        private val animator = android.animation.ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 900
            repeatCount = android.animation.ValueAnimator.INFINITE
            interpolator = LinearInterpolator()
            addUpdateListener {
                phase = it.animatedValue as Float
                invalidate()
            }
        }

        init {
            animator.start()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val heights = floatArrayOf(.25f, .52f, .38f, .64f, .30f)
            val base = height * .5f
            val start = width * .72f
            val gap = width * .045f
            for (i in heights.indices) {
                val p = (phase + i * .17f) % 1f
                val scale = .65f + .35f * ((if (p < .5f) p else 1f - p) * 2f)
                val barHeight = height * heights[i] * scale
                val x = start + i * gap
                canvas.drawRoundRect(
                    x,
                    base - barHeight / 2,
                    x + width * .035f,
                    base + barHeight / 2,
                    8f,
                    8f,
                    paint,
                )
            }
        }

        override fun onDetachedFromWindow() {
            animator.cancel()
            super.onDetachedFromWindow()
        }
    }

    companion object {
        private const val CHANNEL_ID = "saki_room_session"
        private const val NOTIFICATION_ID = 7102
        const val EXTRA_ROOM_NAME = "roomName"
        const val EXTRA_ROOM_ID = "roomId"
        const val EXTRA_IMAGE_URL = "imageUrl"
        const val EXTRA_ACTION = "roomAction"

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
