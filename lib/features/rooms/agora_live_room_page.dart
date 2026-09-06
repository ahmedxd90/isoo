import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/data/saki_service.dart';
import 'pk_battle_page.dart';
import 'room_gifts_sheet.dart';

class AgoraLiveRoomPage extends StatefulWidget {
  const AgoraLiveRoomPage({
    super.key,
    required this.roomId,
    required this.channelName,
    required this.title,
    this.isHost = false,
  });
  final String roomId;
  final String channelName;
  final String title;
  final bool isHost;
  @override
  State<AgoraLiveRoomPage> createState() => _AgoraLiveRoomPageState();
}

class _AgoraLiveRoomPageState extends State<AgoraLiveRoomPage> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _joined = false;
  bool _muted = false;
  bool _cameraOff = false;
  String? _error;
  final _comment = TextEditingController();

  int _numericUid(String value) =>
      int.parse((value.replaceAll('-', '').substring(0, 8)), radix: 16) &
      0x7fffffff;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await SakiService.instance.joinRoom(widget.roomId);
      final permissions = await [
        Permission.microphone,
        Permission.camera,
      ].request();
      if (!permissions[Permission.microphone]!.isGranted ||
          !permissions[Permission.camera]!.isGranted) {
        throw Exception('يجب السماح بالكاميرا والميكروفون للبث المباشر.');
      }
      final uid = _numericUid(SakiService.instance.uid);
      final response = await SakiService.instance.client.functions.invoke(
        'agora-token',
        body: {'channelName': widget.channelName, 'uid': uid},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final appId = data['appId'] as String?;
      final token = data['token'] as String?;
      if (appId == null || token == null || appId.isEmpty || token.isEmpty)
        throw Exception('تعذر الحصول على رمز البث من الخادم.');
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, __) {
            if (mounted) setState(() => _joined = true);
          },
          onUserJoined: (_, uid, __) {
            if (mounted) setState(() => _remoteUid = uid);
          },
          onUserOffline: (_, uid, __) {
            if (mounted && _remoteUid == uid) setState(() => _remoteUid = null);
          },
          onTokenPrivilegeWillExpire: (_, __) => _renewToken(),
          onError: (code, message) {
            if (mounted) setState(() => _error = 'Agora: $code $message');
          },
        ),
      );
      await engine.enableVideo();
      await engine.startPreview();
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _renewToken() async {
    final response = await SakiService.instance.client.functions.invoke(
      'agora-token',
      body: {
        'channelName': widget.channelName,
        'uid': _numericUid(SakiService.instance.uid),
      },
    );
    final token =
        (Map<String, dynamic>.from(response.data as Map))['token'] as String?;
    if (token != null) await _engine?.renewToken(token);
  }

  Future<void> _leave() async {
    await _engine?.stopPreview();
    await _engine?.leaveChannel();
    await _engine?.release();
    await SakiService.instance.leaveRoom(widget.roomId);
    if (widget.isHost) {
      await SakiService.instance.endLiveBroadcast(widget.channelName);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showGifts() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomGiftsSheet(
        service: SakiService.instance,
        roomId: widget.roomId,
        onSent: (recipientId, gift, flyingBanner) async {
          await SakiService.instance.sendRoomGift(
            roomId: widget.roomId,
            recipientId: recipientId,
            giftId: gift['id'] as String,
          );
          await SakiService.instance.sendRoomMessage(
            widget.roomId,
            'أرسل هدية ${gift['name'] ?? 'هدية'}',
            type: 'gift',
            payload: {
              'gift_id': gift['id'],
              'icon': gift['icon'],
              'thumbnail_url': gift['icon'],
              'name': gift['name'],
              'media_url': gift['media_url'],
              'media_type': gift['media_type'],
              'recipient_id': recipientId,
              'flying_banner': flyingBanner,
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _comment.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    _comment.clear();
    await SakiService.instance.sendRoomMessage(widget.roomId, text);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111827),
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: _engine == null
                ? const SizedBox.shrink()
                : AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine!,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  ),
          ),
          if (_remoteUid != null && _engine != null)
            Positioned(
              top: 72,
              right: 16,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                IconButton(
                  onPressed: _leave,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PkBattlePage(
                        roomId: widget.roomId,
                        channelName: widget.channelName,
                        title: widget.title,
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.amberAccent,
                  ),
                ),
                IconButton(
                  onPressed: _showGifts,
                  icon: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.pinkAccent,
                  ),
                ),
                const Chip(
                  label: Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  backgroundColor: Colors.redAccent,
                ),
              ],
            ),
          ),
          if (!_joined && _error == null)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_error != null)
            Center(
              child: Container(
                margin: const EdgeInsets.all(22),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _start();
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 86,
            child: Column(
              children: [
                SizedBox(
                  height: 110,
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SakiService.instance.roomMessagesStream(
                      widget.roomId,
                    ),
                    builder: (_, snapshot) {
                      final rows =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      final visible = rows.length > 5
                          ? rows.sublist(rows.length - 5)
                          : rows;
                      return ListView.builder(
                        reverse: true,
                        itemCount: visible.length,
                        itemBuilder: (_, index) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              visible[visible.length - index - 1]['body']
                                      as String? ??
                                  '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _comment,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'اكتب تعليقًا...',
                          hintStyle: const TextStyle(color: Colors.white60),
                          filled: true,
                          fillColor: Colors.black54,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendComment,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 22,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: () async {
                    _muted = !_muted;
                    await _engine?.muteLocalAudioStream(_muted);
                    if (mounted) setState(() {});
                  },
                  icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                ),
                const SizedBox(width: 18),
                IconButton.filled(
                  onPressed: () async {
                    _cameraOff = !_cameraOff;
                    await _engine?.muteLocalVideoStream(_cameraOff);
                    if (mounted) setState(() {});
                  },
                  icon: Icon(_cameraOff ? Icons.videocam_off : Icons.videocam),
                ),
                const SizedBox(width: 18),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: _leave,
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
