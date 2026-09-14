import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

import '../../core/data/saki_service.dart';

class ZegoLiveAudioRoomPage extends StatefulWidget {
  const ZegoLiveAudioRoomPage({
    super.key,
    required this.roomId,
    required this.userName,
  });

  final String roomId;
  final String userName;

  @override
  State<ZegoLiveAudioRoomPage> createState() => _ZegoLiveAudioRoomPageState();
}

class _ZegoLiveAudioRoomPageState extends State<ZegoLiveAudioRoomPage> {
  late final Future<Map<String, dynamic>> _tokenFuture;

  @override
  void initState() {
    super.initState();
    _tokenFuture = _loadRoomCredentials();
  }

  Future<Map<String, dynamic>> _loadRoomCredentials() async {
    final client = SakiService.instance.client;
    // Do not render seat controls until Supabase has a valid identity.
    if (client.auth.currentSession == null || client.auth.currentUser == null) {
      throw const AuthException(
        'انتهت جلسة تسجيل الدخول. يرجى تسجيل الدخول مرة أخرى.',
      );
    }
    return SakiService.instance.zegoRoomToken(
      widget.roomId,
      userName: widget.userName,
    );
  }

  String _safeZegoUserId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _tokenFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('الغرفة الصوتية')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'تعذر الدخول إلى الغرفة: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final userId = _safeZegoUserId(data['userId']?.toString() ?? 'user');
        final isOwner = data['isOwner'] == true;
        final config = isOwner
            ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
            : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();

        return SafeArea(
          child: ZegoUIKitPrebuiltLiveAudioRoom(
            appID: (data['appId'] as num).toInt(),
            token: data['token'].toString(),
            userID: userId,
            userName: data['userName']?.toString() ?? widget.userName,
            roomID: data['roomId'].toString(),
            config: config,
            events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
              onError: (error) {
                debugPrint(
                  'ZEGOCLOUD error ${error.code} in ${error.method}: ${error.message}',
                );
              },
              seat: ZegoLiveAudioRoomSeatEvents(
                audience: ZegoLiveAudioRoomSeatAudienceEvents(
                  onTakingFailed: () => debugPrint(
                    'ZEGOCLOUD audience seat request failed: room/user not ready',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
