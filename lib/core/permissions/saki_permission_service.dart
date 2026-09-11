import 'dart:io';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../room_background_bridge.dart';

class SakiPermissionService {
  SakiPermissionService._();

  static const _firstLaunchKey = 'saki.first_launch_permissions_requested.v1';

  static Future<void> requestOnFirstLaunch() async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstLaunchKey) == true) return;

    // Let the splash/activity finish rendering before Android shows dialogs.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final permissions = <Permission>[
      Permission.camera,
      Permission.microphone,
      Permission.notification,
      Permission.bluetoothConnect,
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ];
    try {
      await permissions.request();
    } catch (_) {
      // Unsupported permissions on a specific Android version are skipped.
    }

    // Overlay permission is a system settings screen, not a runtime dialog.
    // It is required only for the floating room bubble.
    try {
      if (!await Permission.systemAlertWindow.isGranted) {
        await RoomBackgroundBridge.requestOverlayPermission();
      }
    } catch (_) {}

    await prefs.setBool(_firstLaunchKey, true);
  }
}
