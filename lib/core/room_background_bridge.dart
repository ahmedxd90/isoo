import 'package:flutter/services.dart';

class RoomBackgroundBridge {
  RoomBackgroundBridge._();
  static const _channel = MethodChannel('saki/room_background');

  static Future<void> start({
    required String roomId,
    required String roomName,
    String? imageUrl,
  }) async {
    try {
      await _channel.invokeMethod<void>('start', {
        'roomId': roomId,
        'roomName': roomName,
        'imageUrl': imageUrl ?? '',
      });
    } on MissingPluginException {
      // Android-only capability; the in-app bubble remains available elsewhere.
    } on PlatformException {
      // A missing overlay permission must not terminate the room session.
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException {
      // The native service is best-effort; the Dart session still closes safely.
    }
  }

  static Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod<void>('requestOverlayPermission');
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException {
      // The user can continue using the in-app bubble.
    }
  }

  static Future<Map<String, dynamic>?> consumePendingRoom() async {
    try {
      final value = await _channel.invokeMethod<dynamic>('consumePendingRoom');
      if (value is Map) return Map<String, dynamic>.from(value);
    } on MissingPluginException {
      // No-op on unsupported platforms.
    } on PlatformException {
      // A pending overlay room is optional; the home screen remains usable.
    }
    return null;
  }
}
