import 'package:flutter/services.dart';

class RoomBackgroundBridge {
  RoomBackgroundBridge._();
  static const _channel = MethodChannel('saki/room_background');
  static Future<void> Function(Map<String, dynamic>)? _roomActionHandler;

  static void registerRoomActionHandler(
    Future<void> Function(Map<String, dynamic>) handler,
  ) {
    _roomActionHandler = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'roomAction' || call.arguments is! Map) return;
      await _roomActionHandler?.call(
        Map<String, dynamic>.from(call.arguments as Map),
      );
    });
  }

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

  static Future<void> setOverlayVisible({
    required bool visible,
    required String roomId,
    required String roomName,
    String? imageUrl,
  }) async {
    try {
      await _channel.invokeMethod<void>('setOverlayVisible', {
        'visible': visible,
        'roomId': roomId,
        'roomName': roomName,
        'imageUrl': imageUrl ?? '',
      });
    } on MissingPluginException {
      // Unsupported platforms keep the in-app bubble.
    } on PlatformException {
      // Overlay visibility is optional and must not interrupt the room.
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

  static Future<void> setPipEligible(bool eligible) async {
    try {
      await _channel.invokeMethod<void>('setPipEligible', {
        'eligible': eligible,
      });
    } on MissingPluginException {
      // Unsupported platforms simply keep the in-app mini room.
    } on PlatformException {
      // PiP is optional; never interrupt the room session.
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
