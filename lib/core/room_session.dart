import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

class RoomSessionController extends ChangeNotifier {
  RoomSessionController._();

  static final RoomSessionController instance = RoomSessionController._();

  Map<String, dynamic>? room;
  String? roomId;
  RtcEngine? engine;
  bool isOnSeat = false;
  bool micMuted = true;
  int remoteUsers = 0;

  bool get isActive => room != null && engine != null;

  void minimize({
    required Map<String, dynamic> room,
    required RtcEngine engine,
    required bool isOnSeat,
    required bool micMuted,
    required int remoteUsers,
  }) {
    this.room = Map<String, dynamic>.from(room);
    roomId = room['id']?.toString() ?? room['room_id']?.toString();
    this.engine = engine;
    this.isOnSeat = isOnSeat;
    this.micMuted = micMuted;
    this.remoteUsers = remoteUsers;
    notifyListeners();
  }

  void updateVoiceState({bool? isOnSeat, bool? micMuted, int? remoteUsers}) {
    if (isOnSeat != null) this.isOnSeat = isOnSeat;
    if (micMuted != null) this.micMuted = micMuted;
    if (remoteUsers != null) this.remoteUsers = remoteUsers;
    notifyListeners();
  }

  void clearBubble() {
    room = null;
    notifyListeners();
  }

  bool isSameRoom(String id) => roomId == id;

  RtcEngine? takeEngine() {
    final value = engine;
    engine = null;
    room = null;
    roomId = null;
    notifyListeners();
    return value;
  }

  Future<void> close() async {
    final value = engine;
    engine = null;
    room = null;
    roomId = null;
    if (value != null) {
      await value.leaveChannel();
      await value.release();
    }
    notifyListeners();
  }
}
