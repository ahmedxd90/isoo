import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

/// واجهة الغرفة الأصلية في Flutter/Dart.
/// لا تستخدم WebView أو HTML أو JavaScript؛ كل التحديثات تأتي من Streams الحالية.
class NativeRoomView extends StatefulWidget {
  const NativeRoomView({
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
  State<NativeRoomView> createState() => _NativeRoomViewState();
}

class _NativeRoomViewState extends State<NativeRoomView> {
  final ScrollController _chatScroll = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  int _previousMessageCount = 0;

  @override
  void dispose() {
    _chatScroll.dispose();
    super.dispose();
  }

  String _number(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    if (n >= 1000000000000) return '${(n / 1000000000000).toStringAsFixed(1)}T';
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }

  Color _vipColor(Map<String, dynamic> profile) {
    final level = activeVipLevel(profile);
    return vipAccent(level);
  }

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double radius = 18,
    Color color = const Color(0x73000000),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: .14)),
        ),
        child: child,
      ),
    );
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white70,
    String? tooltip,
  }) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: _glass(
          radius: 18,
          color: const Color(0x59000000),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _header(List<Map<String, dynamic>> members) {
    final room = widget.room;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 2),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onRoomInfo,
                    child: _glass(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        5,
                        5,
                        12,
                        5,
                      ),
                      radius: 25,
                      child: Row(
                        children: [
                          SakiAvatar(
                            url: room['image_url']?.toString(),
                            label: room['name']?.toString(),
                            radius: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  room['name']?.toString() ?? 'غرفة SAKI',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'ID: ${room['room_id'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _circleButton(Icons.more_horiz_rounded, widget.onMenu),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: widget.onGiftRanking,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFC857),
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _number(room['gold_total'] ?? 0),
                        style: const TextStyle(
                          color: Color(0xFFFFD166),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onOnline,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 86,
                        height: 24,
                        child: Stack(
                          textDirection: TextDirection.rtl,
                          children: members
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                                final p = entry.value;
                                return PositionedDirectional(
                                  end: entry.key * 15,
                                  child: GestureDetector(
                                    onTap: () => widget.onUserTap(
                                      p['id']?.toString() ?? '',
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                      child: SakiAvatar(
                                        url: p['avatar_url']?.toString(),
                                        label: p['username']?.toString(),
                                        radius: 10,
                                        profile: p,
                                      ),
                                    ),
                                  ),
                                );
                              })
                              .toList(),
                        ),
                      ),
                      _glass(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        radius: 20,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.groups_rounded,
                              color: Color(0xFF34D399),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${members.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _seats(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> locks,
  ) {
    final count = (widget.room['seat_count'] as num?)?.toInt() ?? 10;
    final byNo = <int, Map<String, dynamic>>{};
    for (final row in rows) {
      final no = (row['seat_no'] as num?)?.toInt();
      if (no != null) byNo[no] = row;
    }
    final locked = locks
        .map((r) => (r['seat_no'] as num?)?.toInt())
        .whereType<int>()
        .toSet();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisExtent: 74,
          crossAxisSpacing: 5,
        ),
        itemBuilder: (_, index) {
          final no = index + 1;
          final row = byNo[no];
          final profile = row?['profiles'] is Map
              ? Map<String, dynamic>.from(row!['profiles'] as Map)
              : <String, dynamic>{};
          final occupied = row != null && row['user_id'] != null;
          final vip = activeVipLevel(profile);
          final accent = vipAccent(vip);
          final emoji = widget.room['seatEmojis'] is Map
              ? (widget.room['seatEmojis'] as Map)[row?['user_id']?.toString()]
              : null;
          final emojiUrl = emoji is Map
              ? (emoji['media_url'] ?? emoji['gif_url'] ?? emoji['asset_path'])
                    ?.toString()
              : emoji?.toString();
          return GestureDetector(
            onTap: () =>
                widget.onSeatTap({'seat': no, 'user_id': row?['user_id']}),
            child: Column(
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .13),
                          border: Border.all(
                            color: occupied
                                ? accent
                                : (locked.contains(no)
                                      ? Colors.redAccent
                                      : Colors.white38),
                            width: occupied ? 2 : 1,
                          ),
                          boxShadow: occupied && row?['is_speaking'] == true
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(
                                      alpha: .8,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: occupied
                            ? SakiAvatar(
                                url: profile['avatar_url']?.toString(),
                                label: profile['username']?.toString(),
                                radius: 20,
                                profile: profile,
                              )
                            : Icon(
                                locked.contains(no)
                                    ? Icons.lock_rounded
                                    : Icons.event_seat_rounded,
                                color: locked.contains(no)
                                    ? Colors.redAccent
                                    : Colors.white70,
                                size: 18,
                              ),
                      ),
                      if (emojiUrl != null && emojiUrl.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: emojiUrl.startsWith('assets/')
                                ? Image.asset(emojiUrl, fit: BoxFit.contain)
                                : Image.network(emojiUrl, fit: BoxFit.contain),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  occupied
                      ? (profile['username'] ??
                                profile['display_name'] ??
                                'عضو')
                            .toString()
                      : (locked.contains(no) ? 'مقفل' : '$no'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: occupied ? accent : Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _message(Map<String, dynamic> row) {
    final profile = row['profiles'] is Map
        ? Map<String, dynamic>.from(row['profiles'] as Map)
        : <String, dynamic>{};
    final vip = activeVipLevel(profile);
    final type =
        row['message_type']?.toString() ?? row['type']?.toString() ?? 'chat';
    final payload = row['payload'] is Map
        ? Map<String, dynamic>.from(row['payload'] as Map)
        : <String, dynamic>{};
    final body = row['body']?.toString() ?? '';
    final image =
        payload['image_url']?.toString() ??
        payload['thumbnail_url']?.toString();
    final gift = type == 'gift' || type == 'luck_multiplier';
    final id = profile['id']?.toString();
    final name = profile['username']?.toString() ?? 'عضو';
    return GestureDetector(
      onTap: id == null || id.isEmpty ? null : () => widget.onUserTap(id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SakiAvatar(
                  url: profile['avatar_url']?.toString(),
                  label: name,
                  radius: 12,
                  profile: profile,
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .42),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: vipAccent(vip),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'VIP$vip · LV${profile['wealth_level'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: vip > 0
                      ? (vipNameGradients[vip] ??
                            [Colors.black54, Colors.black38])
                      : [Colors.black54, Colors.black38],
                ),
                borderRadius: const BorderRadiusDirectional.only(
                  topEnd: Radius.circular(4),
                  topStart: Radius.circular(16),
                  bottomEnd: Radius.circular(16),
                  bottomStart: Radius.circular(16),
                ),
                border: Border.all(
                  color: vip > 0
                      ? vipAccent(vip).withValues(alpha: .5)
                      : Colors.white12,
                ),
              ),
              child: type == 'image' && image != null
                  ? Image.network(
                      image,
                      width: 150,
                      height: 100,
                      fit: BoxFit.contain,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            body,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ),
                        if (gift) ...[
                          const SizedBox(width: 7),
                          Text(
                            payload['icon']?.toString() ?? '🎁',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar() {
    final micMuted = widget.room['micMuted'] == true;
    final speakerMuted = widget.room['speakerMuted'] == true;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xE6000000)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onComposer,
                child: _glass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  radius: 22,
                  child: const Text(
                    'أدخل رسالة',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            _circleButton(Icons.emoji_emotions_outlined, widget.onEmoji),
            const SizedBox(width: 5),
            _circleButton(Icons.sports_esports_rounded, widget.onGames),
            const SizedBox(width: 5),
            _circleButton(
              speakerMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              widget.onSpeaker,
              color: speakerMuted ? Colors.redAccent : Colors.white70,
            ),
            const SizedBox(width: 5),
            _circleButton(
              micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              widget.onMic,
              color: micMuted ? Colors.redAccent : Colors.white70,
            ),
            const SizedBox(width: 5),
            _circleButton(Icons.apps_rounded, widget.onApps),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: widget.onGift,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF43F5E), Color(0xFFF59E0B)],
                  ),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _room(
    List<Map<String, dynamic>> seats,
    List<Map<String, dynamic>> locks,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> members,
  ) {
    final background = widget.room['background_url']?.toString();
    if (_previousMessageCount != messages.length) {
      _messages = messages;
      _previousMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _chatScroll.hasClients)
          _chatScroll.animateTo(
            _chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
      });
    }
    return WillPopScope(
      onWillPop: () async {
        widget.onExit();
        return false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (background != null && background.isNotEmpty)
            Image.network(
              background,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: const Color(0xFF0D0E12)),
            )
          else
            Container(color: const Color(0xFF0D0E12)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x99000000),
                  Color(0xF0000000),
                ],
              ),
            ),
          ),
          Column(
            children: [
              _header(members),
              _seats(seats, locks),
              Expanded(
                child: ListView.builder(
                  controller: _chatScroll,
                  padding: const EdgeInsets.only(top: 5, bottom: 10),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _message(_messages[i]),
                ),
              ),
              _toolbar(),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.seatStream,
      builder: (_, seats) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: widget.lockStream,
        builder: (_, locks) => StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.messageStream,
          builder: (_, messages) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.membersStream,
            builder: (_, members) => _room(
              seats.data ?? const [],
              locks.data ?? const [],
              messages.data ?? const [],
              members.data ?? const [],
            ),
          ),
        ),
      ),
    );
  }
}
