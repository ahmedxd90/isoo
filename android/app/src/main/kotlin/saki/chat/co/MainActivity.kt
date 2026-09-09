package saki.chat.co

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.app.PictureInPictureParams
import android.util.Rational
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "saki/room_background"
    private var pendingRoom: HashMap<String, String>? = null
    private var pipEligible = false

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipEligible && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        rememberPendingRoom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        rememberPendingRoom(intent)
    }

    private fun rememberPendingRoom(intent: Intent?) {
        val roomId = intent?.getStringExtra(RoomOverlayService.EXTRA_ROOM_ID).orEmpty()
        if (roomId.isBlank()) return
        pendingRoom = hashMapOf(
            "roomId" to roomId,
            "roomName" to intent?.getStringExtra(RoomOverlayService.EXTRA_ROOM_NAME).orEmpty(),
            "imageUrl" to intent?.getStringExtra(RoomOverlayService.EXTRA_IMAGE_URL).orEmpty(),
            "action" to intent?.getStringExtra(RoomOverlayService.EXTRA_ACTION).orEmpty(),
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val roomId = call.argument<String>("roomId").orEmpty()
                        val roomName = call.argument<String>("roomName").orEmpty()
                        val imageUrl = call.argument<String>("imageUrl").orEmpty()
                        if (roomId.isBlank()) {
                            result.error("invalid_room", "roomId is required", null)
                        } else {
                            RoomOverlayService.start(this, roomId, roomName, imageUrl)
                            if (!Settings.canDrawOverlays(this)) {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName"),
                                    ),
                                )
                            }
                            result.success(null)
                        }
                    }
                    "stop" -> {
                        stopService(Intent(this, RoomOverlayService::class.java))
                        result.success(null)
                    }
                    "requestOverlayPermission" -> {
                        if (!Settings.canDrawOverlays(this)) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                        result.success(null)
                    }
                    "setPipEligible" -> {
                        pipEligible = call.argument<Boolean>("eligible") == true
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            setPictureInPictureParams(
                                PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(16, 9))
                                    .setAutoEnterEnabled(pipEligible)
                                    .build()
                            )
                        }
                        result.success(null)
                    }
                    "consumePendingRoom" -> {
                        val value = pendingRoom
                        pendingRoom = null
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
