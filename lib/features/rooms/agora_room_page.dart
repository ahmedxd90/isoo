import 'package:flutter/material.dart';

import 'rooms_page.dart';

/// Entry point for opening a SAKI room from profile banners and deep links.
/// Room audio is provided by the Agora-backed room screen.
Widget agoraRoomPageFor(Map<String, dynamic> room) {
  final nested = room['rooms'];
  final record = Map<String, dynamic>.from(nested is Map ? nested : room);
  if (record['id'] == null) {
    return const Scaffold(body: Center(child: Text('معرف الغرفة غير متوفر')));
  }
  return RoomDetailPage(room: record);
}
