import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

import '../../core/data/saki_service.dart';

Widget zegoLiveStreamingPageFor(Map<String, dynamic> room) {
  final roomId = room['room_id']?.toString().trim() ?? '';
  if (roomId.isEmpty) {
    return const Scaffold(body: Center(child: Text('معرف البث غير متوفر')));
  }
  final profile = Map<String, dynamic>.from(
    room['profiles'] as Map? ?? const {},
  );
  final name =
      profile['username']?.toString() ??
      SakiService.instance.currentUser?.email?.split('@').first ??
      'مستخدم SAKI';
  return ZegoLiveStreamingPage(room: room, roomId: roomId, userName: name);
}

class ZegoLiveStreamingPage extends StatefulWidget {
  const ZegoLiveStreamingPage({
    super.key,
    required this.room,
    required this.roomId,
    required this.userName,
  });
  final Map<String, dynamic> room;
  final String roomId;
  final String userName;

  @override
  State<ZegoLiveStreamingPage> createState() => _ZegoLiveStreamingPageState();
}

class _ZegoLiveStreamingPageState extends State<ZegoLiveStreamingPage> {
  late final Future<Map<String, dynamic>> _token;
  final service = SakiService.instance;

  bool get isOwner => widget.room['owner_id']?.toString() == service.uid;
  String get dbRoomId => widget.room['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _token = _loadToken();
  }

  Future<Map<String, dynamic>> _loadToken() async {
    if (service.client.auth.currentSession == null) {
      throw const AuthException('يرجى تسجيل الدخول أولًا');
    }
    if (dbRoomId.isNotEmpty) await service.joinRoom(dbRoomId);
    return service.zegoRoomToken(widget.roomId, userName: widget.userName);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _token,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('البث المباشر')),
              body: Center(child: Text('تعذر تشغيل البث: ${snapshot.error}')),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = snapshot.data!;
          final config = isOwner
              ? ZegoUIKitPrebuiltLiveStreamingConfig.host()
              : ZegoUIKitPrebuiltLiveStreamingConfig.audience();
          config.turnOnCameraWhenJoining = isOwner;
          config.turnOnMicrophoneWhenJoining = isOwner;
          config.inRoomMessage.visible = true;
          config.inRoomMessage.showName = true;
          return Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                ZegoUIKitPrebuiltLiveStreaming(
                  appID: (data['appId'] as num).toInt(),
                  token: data['token'].toString(),
                  userID: _safe(data['userId']?.toString() ?? 'user'),
                  userName: data['userName']?.toString() ?? widget.userName,
                  liveID: data['roomId']?.toString() ?? widget.roomId,
                  config: config,
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 12,
                  child: _LiveHeader(room: widget.room, isOwner: isOwner),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _safe(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
}

class _LiveHeader extends StatelessWidget {
  const _LiveHeader({required this.room, required this.isOwner});
  final Map<String, dynamic> room;
  final bool isOwner;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          room['name']?.toString() ?? 'بث مباشر',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'room_id: ${room['room_id'] ?? ''}',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        if (isOwner)
          const Text(
            'أنت المالك',
            style: TextStyle(color: Color(0xFFFFD166), fontSize: 10),
          ),
      ],
    ),
  );
}
