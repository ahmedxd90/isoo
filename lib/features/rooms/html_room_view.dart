import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HtmlRoomView extends StatefulWidget {
  const HtmlRoomView({
    super.key,
    required this.room,
    required this.seatStream,
    required this.lockStream,
    required this.messageStream,
    required this.onSeatTap,
    required this.onMessage,
    required this.onMic,
    required this.onSpeaker,
    required this.onGift,
    required this.onMenu,
    required this.onExit,
  });

  final Map<String, dynamic> room;
  final Stream<List<Map<String, dynamic>>> seatStream;
  final Stream<List<Map<String, dynamic>>> lockStream;
  final Stream<List<Map<String, dynamic>>> messageStream;
  final ValueChanged<Map<String, dynamic>> onSeatTap;
  final ValueChanged<String> onMessage;
  final VoidCallback onMic;
  final VoidCallback onSpeaker;
  final VoidCallback onGift;
  final VoidCallback onMenu;
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
            case 'mic':
              widget.onMic();
            case 'speaker':
              widget.onSpeaker();
            case 'gift':
              widget.onGift();
            case 'menu':
              widget.onMenu();
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

  Future<void> _run(String script) async {
    if (!_ready || !mounted) return;
    await _controller.runJavaScript(script);
  }

  void _sync() {
    if (!_ready) return;
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
          : const {};
      seats.add({
        'no': i,
        'locked': locked.contains(i),
        'userId': row?['user_id'],
        'speaking': row?['is_speaking'] == true,
        'name': map['username'] ?? map['display_name'] ?? 'عضو',
        'avatar': map['avatar_url'],
      });
    }
    final messages = _messages.map((row) {
      final profile = row['profiles'];
      final map = profile is Map
          ? Map<String, dynamic>.from(profile)
          : const {};
      return {'name': map['username'] ?? 'عضو', 'body': row['body'] ?? ''};
    }).toList();
    final data = {
      'title': widget.room['name'] ?? 'غرفة SAKI',
      'roomNumber': widget.room['room_id'] ?? '',
      'hostAvatar': widget.room['image_url'],
      'onlineCount': 0,
      'seats': seats,
    };
    _run(
      'renderRoomData(${jsonEncode(data)});renderRoomMessages(${jsonEncode(messages)});',
    );
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
                WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
                return WillPopScope(
                  onWillPop: () async {
                    widget.onExit();
                    return false;
                  },
                  child: WebViewWidget(controller: _controller),
                );
              },
            );
          },
        );
      },
    );
  }
}
