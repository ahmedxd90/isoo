import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/widgets/vip_identity.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

class RoomGlobalGiftBanner extends StatefulWidget {
  const RoomGlobalGiftBanner({
    super.key,
    required this.onOpenRoom,
    this.hidden,
  });
  final Future<void> Function(Map<String, dynamic> room) onOpenRoom;
  final bool? hidden;
  @override
  State<RoomGlobalGiftBanner> createState() => _RoomGlobalGiftBannerState();
}

class _RoomGlobalGiftBannerState extends State<RoomGlobalGiftBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4400),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _event = null);
        }
      });
  Map<String, dynamic>? _event;
  String? _shownId;
  Timer? _queue;
  bool _loading = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted)
        setState(
          () => _hidden = prefs.getBool('saki_hide_gift_banners') ?? false,
        );
    });
  }

  @override
  void dispose() {
    _queue?.cancel();
    _animation.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _load(Map<String, dynamic> row) async {
    final sender = await SakiService.instance.userProfile(
      row['sender_id'].toString(),
    );
    final recipient = await SakiService.instance.userProfile(
      row['recipient_id'].toString(),
    );
    final roomId = row['room_id']?.toString();
    final room = roomId == null
        ? null
        : await SakiService.instance.roomById(roomId);
    final catalog = await SakiService.instance.roomGiftCatalog();
    final gift = catalog.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id']?.toString() == row['gift_id']?.toString(),
      orElse: () => null,
    );
    return {
      'row': row,
      'sender': sender ?? <String, dynamic>{},
      'recipient': recipient ?? <String, dynamic>{},
      'gift': gift ?? <String, dynamic>{'name': 'هدية', 'icon': '🎁'},
      'room': room ?? <String, dynamic>{'id': roomId, 'name': 'غرفة SAKI'},
    };
  }

  String _name(Map<String, dynamic> p) =>
      (p['display_name'] ?? p['username'] ?? 'مستخدم').toString();

  Future<void> _next(Map<String, dynamic> row) async {
    final id = row['id']?.toString();
    if (id == null || id == _shownId || _loading) return;
    _shownId = id;
    _loading = true;
    _animation.stop();
    _animation.reset();
    try {
      final loaded = await _load(row);
      if (mounted && loaded != null && id == _shownId) {
        setState(() => _event = loaded);
        _animation.forward();
      }
    } finally {
      _loading = false;
    }
  }

  Widget _gift(Map<String, dynamic> gift) {
    final src = (gift['media_url'] ?? gift['icon'])?.toString() ?? '';
    if (src.startsWith('http')) {
      return Image.network(
        src,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Text('🎁', style: TextStyle(fontSize: 26)),
      );
    }
    if (src.startsWith('assets/')) {
      return Image.asset(src, width: 38, height: 38, fit: BoxFit.cover);
    }
    return Text(src.isEmpty ? '🎁' : src, style: const TextStyle(fontSize: 26));
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: SakiService.instance.giftAnnouncementsStream(),
    builder: (_, snap) {
      final rows = (snap.data ?? const [])
          .where((r) => ((r['total_price'] as num?)?.toInt() ?? 0) >= 1000000)
          .toList();
      if (widget.hidden ?? _hidden) return const SizedBox.shrink();
      if (rows.isNotEmpty) {
        _queue ??= Timer(const Duration(milliseconds: 1), () {
          _queue = null;
          _next(rows.first);
        });
      }
      final event = _event;
      if (event == null) return const SizedBox.shrink();
      final row = Map<String, dynamic>.from(event['row'] as Map);
      final sender = Map<String, dynamic>.from(event['sender'] ?? {});
      final recipient = Map<String, dynamic>.from(event['recipient'] ?? {});
      final gift = Map<String, dynamic>.from(event['gift'] ?? {});
      final room = Map<String, dynamic>.from(event['room'] ?? {});
      final senderVip = activeVipLevel(sender);
      final vipColors =
          vipNameGradients[senderVip] ??
          const [Color(0xFF4B5563), Color(0xFF111827), Color(0xFF6B7280)];
      final sentLuckCount = event['sent_luck_count'] as int? ?? 0;
      return Positioned(
        top: 72,
        right: 10,
        width: 340,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: GestureDetector(
            onTap: () async {
              final go = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('الانتقال إلى الغرفة؟'),
                  content: Text(
                    'هل تريد الانتقال إلى ${room['name'] ?? 'الغرفة'} التي أُرسلت فيها الهدية؟',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('انتقال'),
                    ),
                  ],
                ),
              );
              if (go == true && mounted) await widget.onOpenRoom(room);
            },
            child: AnimatedBuilder(
              animation: _animation,
              builder: (_, child) {
                final t = _animation.value;
                final double x = t < .16
                    ? -1 + t / .16
                    : t > .84
                    ? (t - .84) / .16
                    : 0;
                return FractionalTranslation(
                  translation: Offset(x, 0),
                  child: child,
                );
              },
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: vipColors,
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFFD76A),
                      width: 1.4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SakiAvatar(
                        url: sender['avatar_url'] as String?,
                        label: _name(sender),
                        radius: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _name(sender),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        ' أرسل هدية إلى ${_name(recipient)} ',
                        style: const TextStyle(
                          color: Color(0xFFFFD76A),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _gift(gift),
                      ),
                      const SizedBox(width: 5),
                      SakiAvatar(
                        url: recipient['avatar_url'] as String?,
                        label: _name(recipient),
                        radius: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _name(recipient),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${gift['name'] ?? 'هدية'} · ${row['total_price']} ذهب',
                            style: const TextStyle(
                              color: Color(0xFFFFE6A0),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            room['name']?.toString() ?? 'غرفة',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                          if (row['event_type'] == 'luck_multiplier')
                            Text(
                              'أرسل هدايا حظ: $sentLuckCount مرة',
                              style: const TextStyle(
                                color: Color(0xFFFFD76A),
                                fontSize: 8,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
