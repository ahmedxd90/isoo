import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'room_background_bridge.dart';

class RoomSessionController extends ChangeNotifier {
  RoomSessionController._();
  static final RoomSessionController instance = RoomSessionController._();

  Map<String, dynamic>? room;
  String? roomId;
  RtcEngine? engine;
  bool isOnSeat = false;
  bool micMuted = true;
  int remoteUsers = 0;
  AudioPlayer? musicPlayer;
  bool bubbleVisible = false;
  bool overlayEligible = false;
  Future<void> Function()? onExitRequested;

  bool get isActive => room != null && engine != null;

  void activate({
    required Map<String, dynamic> room,
    required RtcEngine engine,
    required bool isOnSeat,
    required bool micMuted,
    required int remoteUsers,
    AudioPlayer? musicPlayer,
    Future<void> Function()? onExitRequested,
  }) {
    this.room = Map<String, dynamic>.from(room);
    roomId = room['id']?.toString() ?? room['room_id']?.toString();
    this.engine = engine;
    this.isOnSeat = isOnSeat;
    this.micMuted = micMuted;
    this.remoteUsers = remoteUsers;
    this.musicPlayer = musicPlayer;
    this.onExitRequested = onExitRequested;
    overlayEligible = true;
    bubbleVisible = false;
    notifyListeners();
  }

  void minimize({
    required Map<String, dynamic> room,
    required RtcEngine engine,
    required bool isOnSeat,
    required bool micMuted,
    required int remoteUsers,
    AudioPlayer? musicPlayer,
    Future<void> Function()? onExitRequested,
  }) {
    this.room = Map<String, dynamic>.from(room);
    roomId = room['id']?.toString() ?? room['room_id']?.toString();
    this.engine = engine;
    this.isOnSeat = isOnSeat;
    this.micMuted = micMuted;
    this.remoteUsers = remoteUsers;
    this.musicPlayer = musicPlayer;
    this.onExitRequested = onExitRequested;
    overlayEligible = true;
    bubbleVisible = true;
    notifyListeners();
  }

  void updateVoiceState({bool? isOnSeat, bool? micMuted, int? remoteUsers}) {
    if (isOnSeat != null) this.isOnSeat = isOnSeat;
    if (micMuted != null) this.micMuted = micMuted;
    if (remoteUsers != null) this.remoteUsers = remoteUsers;
    notifyListeners();
  }

  void hideBubble() {
    bubbleVisible = false;
    notifyListeners();
  }

  bool isSameRoom(String id) {
    if (roomId == id) return true;
    final current = room;
    if (current == null) return false;
    return current['id']?.toString() == id ||
        current['room_id']?.toString() == id;
  }

  Future<void> setOverlayVisible(bool visible) async {
    final currentRoom = room;
    final currentRoomId = roomId;
    if (!overlayEligible || currentRoom == null || currentRoomId == null) return;
    await RoomBackgroundBridge.setOverlayVisible(
      visible: visible,
      roomId: currentRoomId,
      roomName: currentRoom['name']?.toString() ?? 'غرفة SAKI',
      imageUrl: currentRoom['image_url']?.toString(),
    );
  }

  RtcEngine? takeEngine() {
    final value = engine;
    engine = null;
    room = null;
    roomId = null;
    onExitRequested = null;
    overlayEligible = false;
    bubbleVisible = false;
    notifyListeners();
    return value;
  }

  Future<void> close() async {
    await RoomBackgroundBridge.stop();
    final value = engine;
    final player = musicPlayer;
    engine = null;
    musicPlayer = null;
    room = null;
    roomId = null;
    onExitRequested = null;
    overlayEligible = false;
    bubbleVisible = false;
    if (value != null) {
      await value.leaveChannel();
      await value.release();
    }
    await player?.dispose();
    notifyListeners();
  }
}
