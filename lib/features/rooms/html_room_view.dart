import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/widgets/vip_identity.dart';

class HtmlRoomView extends StatefulWidget {
  const HtmlRoomView({
    super.key,
    required this.room,
    required this.seatStream,
    required this.lockStream,
    required this.messageStream,
    required this.membersStream,
    required this.onSeatTap,
    required this.onMessage,
    required this.onComposer,
    required this.onMic,
    required this.onSpeaker,
    required this.onEmoji,
    required this.onGift,
    required this.onGiftRanking,
    required this.onApps,
    required this.onGames,
    required this.onMenu,
    required this.onOnline,
    required this.onRoomInfo,
    required this.onUserTap,
    required this.onExit,
  });

  final Map<String, dynamic> room;
  final Stream<List<Map<String, dynamic>>> seatStream;
  final Stream<List<Map<String, dynamic>>> lockStream;
  final Stream<List<Map<String, dynamic>>> messageStream;
  final Stream<List<Map<String, dynamic>>> membersStream;
  final ValueChanged<Map<String, dynamic>> onSeatTap;
  final ValueChanged<String> onMessage;
  final VoidCallback onComposer;
  final VoidCallback onMic;
  final VoidCallback onSpeaker;
  final VoidCallback onEmoji;
  final VoidCallback onGift;
  final VoidCallback onGiftRanking;
  final VoidCallback onApps;
  final VoidCallback onGames;
  final VoidCallback onMenu;
  final VoidCallback onOnline;
  final VoidCallback onRoomInfo;
  final ValueChanged<String> onUserTap;
  final VoidCallback onExit;

  @override
  State<HtmlRoomView> createState() => _HtmlRoomViewState();
}

class _HtmlRoomViewState extends State<HtmlRoomView> {
  late final WebViewController _controller;
  bool _ready = false;
  List<Map<String, dynamic>> _seats = const [];
  List<Map<String, dynamic>> _locks = const [];
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _members = const [];
  bool _syncQueued = false;
  Timer? _syncTimer;
  String? _lastFingerprint;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0E12))
      ..addJavaScriptChannel(
        'RoomBridge',
        onMessageReceived: (message) {
          final raw = jsonDecode(message.message);
          if (raw is! Map) return;
          final type = raw['type']?.toString();
          switch (type) {
            case 'ready':
              _ready = true;
              _sync();
            case 'seat':
              final seat = (raw['seat'] as num?)?.toInt();
              if (seat != null) {
                widget.onSeatTap({
                  'seat': seat,
                  'user_id': raw['occupiedUserId'],
                });
              }
            case 'message':
              final body = raw['body']?.toString().trim();
              if (body != null && body.isNotEmpty) widget.onMessage(body);
            case 'composer':
              widget.onComposer();
            case 'mic':
              widget.onMic();
            case 'speaker':
              widget.onSpeaker();
            case 'emoji':
              widget.onEmoji();
            case 'gift':
              widget.onGift();
            case 'giftRanking':
              widget.onGiftRanking();
            case 'apps':
              widget.onApps();
            case 'games':
              widget.onGames();
            case 'menu':
              widget.onMenu();
            case 'online':
              widget.onOnline();
            case 'roomInfo':
              widget.onRoomInfo();
            case 'user':
              final id = raw['userId']?.toString();
              if (id != null && id.isNotEmpty) widget.onUserTap(id);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('file://') ||
                request.url.startsWith('about:blank')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset('assets/rooms/room_html_template.html');
  }

  @override
  void didUpdateWidget(covariant HtmlRoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent mutates the shared seatEmojis map in place. Comparing the
    // map references therefore misses the update; always resync the HTML
    // seats when Flutter rebuilds this bridge.
    if (_ready) _sync();
  }

  Future<void> _run(String script) async {
    if (!_ready || !mounted) return;
    await _controller.runJavaScript(script);
  }

  void _sync() {
    if (!_ready || !mounted) return;
    // Coalesce bursts from Realtime into one WebView update.
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 70), () {
      if (!_ready || !mounted || _syncQueued) return;
      _syncQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncQueued = false;
        if (mounted) _syncNow();
      });
    });
  }

  void _syncNow() {
    if (!_ready) return;
    final fingerprint = [
      _seats.length,
      _seats
          .take(12)
          .map(
            (row) =>
                '${row['seat_no']}:${row['user_id']}:${row['is_speaking']}',
          )
          .join('|'),
      _locks.map((row) => row['seat_no']).join(','),
      _messages.length,
      _messages.isEmpty ? '' : _messages.last['id'],
      _members.length,
      _members.take(5).map((row) => row['id']).join(','),
      widget.room['micMuted'],
      widget.room['speakerMuted'],
      widget.room['gold_total'],
    ].join('¦');
    if (_lastFingerprint == fingerprint) return;
    _lastFingerprint = fingerprint;
    final seats = <Map<String, dynamic>>[];
    final byNo = <int, Map<String, dynamic>>{
      for (final row in _seats)
        if (row['seat_no'] is num) (row['seat_no'] as num).toInt(): row,
    };
    final locked = _locks
        .map((row) => (row['seat_no'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    final count = (widget.room['seat_count'] as num?)?.toInt() ?? 10;
    for (var i = 1; i <= count; i++) {
      final row = byNo[i];
      final profile = row?['profiles'];
      final map = profile is Map
          ? Map<String, dynamic>.from(profile)
          : <String, dynamic>{};
      final vip = activeVipLevel(map);
      seats.add({
        'no': i,
        'locked': locked.contains(i),
        'userId': row?['user_id'],
        'speaking': row?['is_speaking'] == true,
        'name': map['username'] ?? map['display_name'] ?? 'عضو',
        'avatar': map['avatar_url'],
        'vip': vip,
        'vipColors': _vipColors(vip),
        // room_html_template.html is loaded from assets/rooms/.
        'vip11SeatAsset': vip >= 11 ? 'royal_seat_vip11.png' : null,
        'emoji': _emojiSource(
          (widget.room['seatEmojis'] is Map)
              ? (widget.room['seatEmojis'] as Map)[row?['user_id']?.toString()]
              : null,
        ),
      });
    }
    final messages = _messages.map((row) {
      final profile = row['profiles'];
      final map = profile is Map
          ? Map<String, dynamic>.from(profile)
          : <String, dynamic>{};
      final vip = activeVipLevel(map);
      return {
        'id': map['id'],
        'messageId': row['id'],
        'created_at': row['created_at'],
        'name': map['username'] ?? 'عضو',
        'avatar': map['avatar_url'],
        'vip': vip,
        'vipColors': _vipColors(vip),
        'wealth': map['wealth_level'] ?? 0,
        'body': row['body'] ?? '',
        'type': row['message_type'] ?? row['type'] ?? 'chat',
        'payload': row['payload'] is Map ? row['payload'] : const {},
      };
    }).toList();
    final members = _members
        .take(5)
        .map((row) => {'id': row['id'], 'avatar': row['avatar_url']})
        .toList();
    final data = {
      'title': widget.room['name'] ?? 'غرفة SAKI',
      'roomNumber': widget.room['room_id'] ?? '',
      'hostAvatar': widget.room['image_url'],
      'backgroundUrl': widget.room['background_url'],
      'onlineCount': _members.length,
      'goldTotal': widget.room['gold_total'] ?? 0,
      'members': members,
      'seats': seats,
      'seatEmojis': widget.room['seatEmojis'] ?? const {},
      'micMuted': widget.room['micMuted'] == true,
      'speakerMuted': widget.room['speakerMuted'] == true,
    };
    _run(
      'renderRoomData(${jsonEncode(data)});renderRoomMessages(${jsonEncode(messages)});',
    );
  }

  String? _emojiSource(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      for (final key in const [
        'asset_path',
        'gif_url',
        'media_url',
        'thumbnail_url',
      ]) {
        final source = map[key]?.toString();
        if (source != null && source.isNotEmpty) {
          return source.startsWith('assets/rooms/')
              ? source.replaceFirst('assets/rooms/', '')
              : source;
        }
      }
    }
    return null;
  }

  List<String> _vipColors(int level) => (vipNameGradients[level] ?? const [])
      .map((color) => '#${color.toARGB32().toRadixString(16).substring(2)}')
      .toList();

  @override
  void dispose() {
    _syncTimer?.cancel();
    _controller.clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.seatStream,
      builder: (_, seatSnapshot) {
        _seats = seatSnapshot.data ?? const [];
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.lockStream,
          builder: (_, lockSnapshot) {
            _locks = lockSnapshot.data ?? const [];
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.messageStream,
              builder: (_, messageSnapshot) {
                _messages = messageSnapshot.data ?? const [];
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.membersStream,
                  builder: (_, memberSnapshot) {
                    _members = memberSnapshot.data ?? const [];
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => _sync(),
                    );
                    return SafeArea(
                      bottom: true,
                      maintainBottomViewPadding: true,
                      child: PopScope(
                        canPop: false,
                        onPopInvokedWithResult: (didPop, result) {
                          if (!didPop) {
                            widget.onExit();
                          }
                        },
                        child: WebViewWidget(controller: _controller),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
