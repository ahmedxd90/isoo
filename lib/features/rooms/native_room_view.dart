import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

/// واجهة الغرفة الأصلية في Flutter/Dart.
/// لا تستخدم WebView أو HTML أو JavaScript؛ كل التحديثات تأتي من Streams الحالية.
class NativeRoomView extends StatefulWidget {
  const NativeRoomView({
    super.key,
    required this.room,
    required this.seatStream,
    required this.specialSeatStream,
    required this.lockStream,
    required this.messageStream,
    required this.membersStream,
    required this.onSeatTap,
    required this.onSpecialSeatTap,
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
    this.seatKeys = const {},
    this.optimisticMessages = const [],
    this.chatClearedAt,
  });

  final Map<String, dynamic> room;
  final Stream<List<Map<String, dynamic>>> seatStream;
  final Stream<List<Map<String, dynamic>>> specialSeatStream;
  final Stream<List<Map<String, dynamic>>> lockStream;
  final Stream<List<Map<String, dynamic>>> messageStream;
  final Stream<List<Map<String, dynamic>>> membersStream;
  final ValueChanged<Map<String, dynamic>> onSeatTap;
  final ValueChanged<Map<String, dynamic>> onSpecialSeatTap;
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
  final Map<String, GlobalKey> seatKeys;
  final List<Map<String, dynamic>> optimisticMessages;
  final DateTime? chatClearedAt;

  @override
  State<NativeRoomView> createState() => _NativeRoomViewState();
}

class _SpeakingSeatOverlay extends StatefulWidget {
  const _SpeakingSeatOverlay({
    required this.speaking,
    required this.vipLevel,
    required this.color,
  });

  final bool speaking;
  final int vipLevel;
  final Color color;

  @override
  State<_SpeakingSeatOverlay> createState() => _SpeakingSeatOverlayState();
}

class _SpeakingSeatOverlayState extends State<_SpeakingSeatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.speaking) return const SizedBox.shrink();
    final colors = widget.vipLevel >= 4
        ? (vipNameGradients[widget.vipLevel] ?? [widget.color])
        : [const Color(0xFF34D399), const Color(0xFF67E8F9)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => CustomPaint(
        painter: _SpeakingRingsPainter(
          progress: _controller.value,
          colors: colors,
          premium: widget.vipLevel >= 4,
        ),
      ),
    );
  }
}

class _SpeakingRingsPainter extends CustomPainter {
  const _SpeakingRingsPainter({
    required this.progress,
    required this.colors,
    required this.premium,
  });

  final double progress;
  final List<Color> colors;
  final bool premium;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * .31;
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      final radius = base + phase * size.shortestSide * .23;
      final color = colors[i % colors.length].withValues(
        alpha: (1 - phase) * (premium ? .92 : .70),
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = premium ? 2.6 : 1.8
        ..color = color
        ..maskFilter = premium
            ? const MaskFilter.blur(BlurStyle.normal, 2)
            : null;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeakingRingsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _RoyalBridgeWave extends StatefulWidget {
  const _RoyalBridgeWave({required this.active});
  final bool active;

  @override
  State<_RoyalBridgeWave> createState() => _RoyalBridgeWaveState();
}

class _RoyalBridgeWaveState extends State<_RoyalBridgeWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(7, (index) {
        final wave = widget.active
            ? (0.35 +
                  .65 *
                      ((math.sin(_controller.value * math.pi * 2 + index) + 1) /
                          2))
            : .18;
        return Container(
          width: 3,
          height: 18 + wave * 42,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF3D81), Color(0xFF7C3AED), Color(0xFF22D3EE)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: widget.active
                ? const [BoxShadow(color: Color(0xFFB026FF), blurRadius: 8)]
                : null,
          ),
        );
      }),
    ),
  );
}

class _NativeRoomViewState extends State<NativeRoomView> {
  final ScrollController _chatScroll = ScrollController();
  List<Map<String, dynamic>> _messages = const [];
  String _previousMessageKey = '';

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

  Widget _royalSpecialSeats(List<Map<String, dynamic>> rows) {
    final speakingUserIds = (widget.room['speaking_user_ids'] is Iterable)
        ? (widget.room['speaking_user_ids'] as Iterable)
              .map((id) => id.toString())
              .toSet()
        : <String>{};
    final byKind = <String, Map<String, dynamic>>{
      for (final row in rows)
        if (row['seat_kind'] != null) row['seat_kind'].toString(): row,
    };

    Widget card(String kind, String asset, Color glow, String label) {
      final row = byKind[kind];
      final profile = row?['profiles'] is Map
          ? Map<String, dynamic>.from(row!['profiles'] as Map)
          : <String, dynamic>{};
      final occupied = row?['user_id'] != null;
      final userId = row?['user_id']?.toString();
      final speaking = row?['is_speaking'] == true ||
          (occupied && userId != null && speakingUserIds.contains(userId)) ||
          (occupied &&
              userId == widget.room['local_user_id']?.toString() &&
              widget.room['local_speaking'] == true);
      final vip = activeVipLevel(profile).clamp(0, 10);
      final name = (profile['username'] ?? profile['display_name'] ?? label).toString();
      return Expanded(
        child: GestureDetector(
          onTap: () => widget.onSpecialSeatTap({'seat_kind': kind, 'user_id': userId}),
          child: SizedBox(
            height: 116,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (speaking)
                        Positioned.fill(
                          child: _SpeakingSeatOverlay(
                            speaking: true,
                            vipLevel: vip,
                            color: glow,
                          ),
                        ),
                      Image.asset(asset, width: 100, height: 100, fit: BoxFit.contain),
                      if (occupied)
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [BoxShadow(color: glow.withValues(alpha: .5), blurRadius: 12)],
                          ),
                          child: SakiAvatar(
                            url: profile['avatar_url']?.toString(),
                            label: name,
                            radius: 26,
                            profile: profile,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  occupied ? name : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: occupied ? glow : Colors.white70, fontSize: 10, fontWeight: FontWeight.w900),
                ),
                if (occupied && vip > 0)
                  Text('VIP $vip', style: TextStyle(color: glow, fontSize: 8, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          card('host', 'assets/rooms/royal_seat_host.png', const Color(0xFFFF405C), 'المضيف'),
          const SizedBox(width: 8),
          card('legend', 'assets/rooms/royal_seat_legend.png', const Color(0xFFFFD166), 'الأسطورة'),
        ],
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
          mainAxisExtent: 80,
          crossAxisSpacing: 5,
        ),
        itemBuilder: (_, index) {
          final no = index + 1;
          final row = byNo[no];
          final profile = row?['profiles'] is Map
              ? Map<String, dynamic>.from(row!['profiles'] as Map)
              : <String, dynamic>{};
          final occupied = row != null && row['user_id'] != null;
          final userId = row?['user_id']?.toString();
          final seatKey = occupied && userId != null
              ? widget.seatKeys.putIfAbsent(userId, GlobalKey.new)
              : null;
          final sessionGold =
              (row?['session_gold_received'] as num?)?.toInt() ?? 0;
          final vip = activeVipLevel(profile);
          final isVip11Seat = occupied && vip >= 11;
          final ownerVip = widget.room['owner_vip_level'] is num
              ? (widget.room['owner_vip_level'] as num).toInt()
              : int.tryParse(
                      widget.room['owner_vip_level']?.toString() ?? '',
                    ) ??
                    0;
          final showVip11Design = ownerVip >= 11 || isVip11Seat;
          final localUserId = widget.room['local_user_id']?.toString();
          final localSpeaking = widget.room['local_speaking'] == true;
          final speakingUserIds = (widget.room['speaking_user_ids'] is Iterable)
              ? (widget.room['speaking_user_ids'] as Iterable)
                    .map((id) => id.toString())
                    .toSet()
              : <String>{};
          final speaking =
              row?['is_speaking'] == true ||
              (occupied && userId != null && speakingUserIds.contains(userId)) ||
              (occupied && userId == localUserId && localSpeaking);
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
                  width: 66,
                  height: 66,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      if (speaking)
                        Positioned.fill(
                          child: _SpeakingSeatOverlay(
                            speaking: true,
                            vipLevel: vip,
                            color: accent,
                          ),
                        ),
                      Container(
                        key: seatKey,
                        width: isVip11Seat ? 66 : 60,
                        height: isVip11Seat ? 66 : 60,
                        decoration: showVip11Design
                            ? null
                            : BoxDecoration(
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
                                boxShadow:
                                    occupied && row['is_speaking'] == true
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
                        child: showVip11Design
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.asset(
                                    'assets/rooms/royal_seat_vip11.png',
                                    fit: BoxFit.contain,
                                  ),
                                  if (occupied)
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: SakiAvatar(
                                        url: profile['avatar_url']?.toString(),
                                        label: profile['username']?.toString(),
                                        radius: 20,
                                        profile: profile,
                                      ),
                                    ),
                                ],
                              )
                            : occupied
                            ? SakiAvatar(
                                url: profile['avatar_url']?.toString(),
                                label: profile['username']?.toString(),
                                radius: 33,
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
                if (occupied)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x992563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '★ $sessionGold',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
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
    final rawBody = row['body']?.toString() ?? '';
    final body = rawBody.startsWith('http') ? 'أرسل هدية' : rawBody;
    final image =
        payload['image_url']?.toString() ??
        payload['thumbnail_url']?.toString();
    final gift = type == 'gift' || type == 'luck_multiplier';
    final id = profile['id']?.toString();
    final name = profile['username']?.toString() ?? 'عضو';
    Widget giftVisual() {
      final source =
          payload['thumbnail_asset_path']?.toString() ??
          payload['thumbnail_url']?.toString() ??
          payload['icon']?.toString();
      if (source != null && source.startsWith('assets/')) {
        return Image.asset(
          source,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Text('🎁', style: TextStyle(fontSize: 20)),
        );
      }
      if (source != null && source.startsWith('http')) {
        return Image.network(
          source,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Text('🎁', style: TextStyle(fontSize: 20)),
        );
      }
      return Text(
        source == null || source.isEmpty ? '🎁' : source,
        style: const TextStyle(fontSize: 20),
      );
    }

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
                    color: Colors.black.withValues(alpha: .40),
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
                color: Colors.black.withValues(alpha: .40),
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
                        if (gift) ...[const SizedBox(width: 7), giftVisual()],
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

  int _ownerVipLevel() {
    final raw = widget.room['owner_vip_level'];
    final level = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? 0;
    return level.clamp(0, 11);
  }

  Widget _room(
    List<Map<String, dynamic>> seats,
    List<Map<String, dynamic>> specialSeats,
    List<Map<String, dynamic>> locks,
    List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>> members,
  ) {
    final background = widget.room['background_url']?.toString();
    final visibleMessages = <String, Map<String, dynamic>>{};
    for (final message in messages) {
      final created = DateTime.tryParse(
        message['created_at']?.toString() ?? '',
      );
      if (widget.chatClearedAt != null &&
          created != null &&
          !created.isAfter(widget.chatClearedAt!)) {
        continue;
      }
      final id = message['id']?.toString() ?? message['message_id']?.toString();
      if (id != null) visibleMessages[id] = message;
    }
    bool sameMessage(Map<String, dynamic> a, Map<String, dynamic> b) {
      final aType = (a['message_type'] ?? a['type'] ?? 'chat').toString();
      final bType = (b['message_type'] ?? b['type'] ?? 'chat').toString();
      if (aType != bType ||
          a['sender_id']?.toString() != b['sender_id']?.toString() ||
          a['body']?.toString() != b['body']?.toString()) {
        return false;
      }
      final aTime = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bTime = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return aTime != null &&
          bTime != null &&
          aTime.difference(bTime).inSeconds.abs() <= 20;
    }

    for (final message in widget.optimisticMessages) {
      final id = message['id']?.toString();
      final alreadyConfirmed = messages.any((serverMessage) {
        final created = DateTime.tryParse(
          serverMessage['created_at']?.toString() ?? '',
        );
        return (created == null ||
                widget.chatClearedAt == null ||
                created.isAfter(widget.chatClearedAt!)) &&
            sameMessage(message, serverMessage);
      });
      if (id != null && !alreadyConfirmed) visibleMessages[id] = message;
    }
    final visible = visibleMessages.values.toList()
      ..sort(
        (a, b) =>
            (DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );
    final messageKey = visible.isEmpty
        ? ''
        : '${visible.length}:${visible.last['id'] ?? visible.last['message_id'] ?? visible.last['created_at'] ?? ''}:${widget.chatClearedAt?.millisecondsSinceEpoch ?? 0}';
    if (_previousMessageKey != messageKey) {
      _messages = visible;
      _previousMessageKey = messageKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _chatScroll.hasClients) {
          _chatScroll.animateTo(
            0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          widget.onExit();
        }
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
              if (_ownerVipLevel() >= 10) _royalSpecialSeats(specialSeats),
              _seats(seats, locks),
              Expanded(
                child: RepaintBoundary(
                  child: ListView.builder(
                    scrollCacheExtent: const ScrollCacheExtent.pixels(420),
                    controller: _chatScroll,
                    reverse: true,
                    padding: const EdgeInsets.only(top: 5, bottom: 10),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _messages.length,
                    itemBuilder: (_, i) =>
                        _message(_messages[_messages.length - 1 - i]),
                  ),
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
        stream: widget.specialSeatStream,
        builder: (_, specialSeats) => StreamBuilder<List<Map<String, dynamic>>>(
          stream: widget.lockStream,
          builder: (_, locks) => StreamBuilder<List<Map<String, dynamic>>>(
            stream: widget.messageStream,
            builder: (_, messages) => StreamBuilder<List<Map<String, dynamic>>>(
              stream: widget.membersStream,
              builder: (_, members) => DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: _room(
                  seats.data ?? const [],
                  specialSeats.data ?? const [],
                  locks.data ?? const [],
                  messages.data ?? const [],
                  members.data ?? const [],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
