import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/data/saki_service.dart';

class AgoraAudioRoomPage extends StatefulWidget {
  const AgoraAudioRoomPage({super.key, required this.roomName, required this.title});

  final String roomName;
  final String title;

  @override
  State<AgoraAudioRoomPage> createState() => _AgoraAudioRoomPageState();
}

class _AgoraAudioRoomPageState extends State<AgoraAudioRoomPage> {
  RtcEngine? _engine;
  final Set<int> _remoteUsers = <int>{};
  bool _joining = true;
  bool _joined = false;
  bool _muted = false;
  String? _error;
  int? _uid;

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  int _numericUid(String value) {
    final compact = value.replaceAll('-', '');
    final prefix = compact.length > 8 ? compact.substring(0, 8) : compact;
    return int.parse(prefix, radix: 16) & 0x7fffffff;
  }

  Future<void> _joinRoom() async {
    try {
      final microphone = await Permission.microphone.request();
      if (!microphone.isGranted) {
        throw Exception('يجب السماح باستخدام الميكروفون للانضمام إلى الغرفة.');
      }

      final uid = _numericUid(SakiService.instance.uid);
      final response = await SakiService.instance.client.functions.invoke(
        'agora-token',
        body: {'channelName': widget.roomName, 'uid': uid},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final appId = data['appId'] as String?;
      final token = data['token'] as String?;
      if (appId == null || token == null || appId.isEmpty || token.isEmpty) {
        throw Exception('تعذر الحصول على رمز Agora من الخادم.');
      }

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
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _joined = true;
              _joining = false;
              _uid = connection.localUid;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (mounted) setState(() => _remoteUsers.add(remoteUid));
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (mounted) setState(() => _remoteUsers.remove(remoteUid));
          },
          onError: (errorCode, message) {
            if (mounted) setState(() => _error = 'Agora: $errorCode $message');
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            _refreshToken();
          },
        ),
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.enableAudio();
      await engine.joinChannel(
        token: token,
        channelId: widget.roomName,
        uid: uid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _joining = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _refreshToken() async {
    final uid = _uid ?? _numericUid(SakiService.instance.uid);
    final response = await SakiService.instance.client.functions.invoke(
      'agora-token',
      body: {'channelName': widget.roomName, 'uid': uid},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token'] as String?;
    if (token != null) await _engine?.renewToken(token);
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    await _engine?.muteLocalAudioStream(next);
    if (mounted) setState(() => _muted = next);
  }

  Future<void> _leave() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _leave, icon: const Icon(Icons.close_rounded)),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 74, color: Colors.cyan),
              const SizedBox(height: 20),
              Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              if (_joining) const CircularProgressIndicator(),
              if (_joined) ...[
                Text('أنت داخل الغرفة • ${_remoteUsers.length} متصل آخر'),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: _toggleMute,
                      icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                    ),
                    const SizedBox(width: 18),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _leave,
                      icon: const Icon(Icons.call_end),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: () { setState(() { _error = null; _joining = true; }); _joinRoom(); }, child: const Text('إعادة المحاولة')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
