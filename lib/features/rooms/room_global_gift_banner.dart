import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    with TickerProviderStateMixin {
  late final AnimationController _flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );
  late final AnimationController _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );
  late final AnimationController _coins = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );

  final Set<String> _seenAnnouncementIds = <String>{};
  final List<Map<String, dynamic>> _pendingRows = <Map<String, dynamic>>[];
  Map<String, dynamic>? _event;
  Timer? _queueTimer;
  bool _streamPrimed = false;
  bool _prefsReady = false;
  bool _loading = false;
  bool _hidden = false;

  bool get _isHidden => widget.hidden ?? _hidden;

  @override
  void initState() {
    super.initState();
    _flight.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() {
        _event = null;
        _coins.stop();
        _coins.reset();
      });
      _scheduleNext();
    });
    _shine.repeat();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final hidden = prefs.getBool('saki_hide_gift_banners') ?? false;
      setState(() {
        _hidden = hidden;
        _prefsReady = true;
        if (hidden) {
          _event = null;
          _pendingRows.clear();
        }
      });
      if (hidden) {
        _flight.stop();
      } else {
        _scheduleNext();
      }
    });
  }

  @override
  void didUpdateWidget(covariant RoomGlobalGiftBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isHidden) {
      _event = null;
      _pendingRows.clear();
      _flight.stop();
      _coins.stop();
      _coins.reset();
      _queueTimer?.cancel();
      _queueTimer = null;
    } else {
      _scheduleNext();
    }
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    _flight.dispose();
    _shine.dispose();
    _coins.dispose();
    super.dispose();
  }

  int _price(Map<String, dynamic> row) =>
      ((row['total_price'] ?? row['gift_price']) as num?)?.toInt() ?? 0;

  int _multiplier(Map<String, dynamic> row) {
    final value = row['multiplier'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _rewardGold(Map<String, dynamic> row) {
    final value = row['reward_gold'] ?? row['recipient_diamonds'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isFeaturedLuck(Map<String, dynamic> row) =>
      row['event_type']?.toString() == 'luck_multiplier' &&
      const {250, 500, 1000}.contains(_multiplier(row));

  void _ingest(List<Map<String, dynamic>> rows) {
    if (!_streamPrimed) {
      _streamPrimed = true;
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) _seenAnnouncementIds.add(id);
      }
      return;
    }

    final fresh = <Map<String, dynamic>>[];
    for (final row in rows) {
      final id = row['id']?.toString();
      if (id == null || id.isEmpty || !_seenAnnouncementIds.add(id)) continue;
      final price = _price(row);
      if (_isFeaturedLuck(row) || price >= 100000) fresh.add(row);
    }
    if (_seenAnnouncementIds.length > 500) {
      final currentIds = rows
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .toSet();
      _seenAnnouncementIds.removeWhere((id) => !currentIds.contains(id));
    }
    if (_isHidden || fresh.isEmpty) return;

    // Supabase returns newest first; show a burst of new events oldest first.
    _pendingRows.addAll(fresh.reversed);
    _scheduleNext();
  }

  void _scheduleNext() {
    if (!_prefsReady ||
        _isHidden ||
        _event != null ||
        _loading ||
        _pendingRows.isEmpty ||
        _queueTimer != null) {
      return;
    }
    _queueTimer = Timer(const Duration(milliseconds: 120), () {
      _queueTimer = null;
      if (!mounted || _isHidden || _event != null || _pendingRows.isEmpty) {
        return;
      }
      unawaited(_next(_pendingRows.removeAt(0)));
    });
  }

  Future<Map<String, dynamic>> _load(Map<String, dynamic> row) async {
    final senderId = row['sender_id']?.toString() ?? '';
    final recipientId = row['recipient_id']?.toString() ?? '';
    final roomId = row['room_id']?.toString();
    final results = await Future.wait<dynamic>([
      senderId.isEmpty
          ? Future<dynamic>.value(null)
          : SakiService.instance.userProfile(senderId),
      recipientId.isEmpty
          ? Future<dynamic>.value(null)
          : SakiService.instance.userProfile(recipientId),
      roomId == null
          ? Future<dynamic>.value(null)
          : SakiService.instance.roomById(roomId),
      SakiService.instance.roomGiftCatalog(),
    ]);

    final sender = results[0] is Map
        ? Map<String, dynamic>.from(results[0] as Map)
        : <String, dynamic>{};
    final recipient = results[1] is Map
        ? Map<String, dynamic>.from(results[1] as Map)
        : <String, dynamic>{};
    final room = results[2] is Map
        ? Map<String, dynamic>.from(results[2] as Map)
        : <String, dynamic>{'id': roomId, 'name': 'غرفة'};
    final catalog = List<Map<String, dynamic>>.from(results[3] as List);
    final giftId = row['gift_id']?.toString();
    Map<String, dynamic> gift = <String, dynamic>{};
    for (final item in catalog) {
      if (item['id']?.toString() == giftId) {
        gift = item;
        break;
      }
    }

    return {
      'row': row,
      'sender': sender,
      'recipient': recipient,
      'gift': gift,
      'room': room,
    };
  }

  Future<void> _next(Map<String, dynamic> row) async {
    if (_loading || _isHidden) return;
    _loading = true;
    _flight.stop();
    _flight.reset();
    try {
      final loaded = await _load(row);
      if (mounted && !_isHidden) {
        final eventRow = Map<String, dynamic>.from(loaded['row'] as Map);
        _coins.stop();
        _coins.reset();
        if (_isFeaturedLuck(eventRow)) _coins.repeat();
        setState(() => _event = loaded);
        _flight.forward();
      }
    } catch (_) {
      // A transient profile/catalog lookup failure should not block later events.
    } finally {
      _loading = false;
      if (mounted && _event == null) _scheduleNext();
    }
  }

  String _name(Map<String, dynamic> profile) {
    final displayName = profile['display_name']?.toString().trim();
    final username = profile['username']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (username != null && username.isNotEmpty) return username;
    return 'مستخدم';
  }

  String _formatGold(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  Widget _giftImage(Map<String, dynamic> gift) {
    final sources = [
      gift['thumbnail_url']?.toString(),
      gift['media_url']?.toString(),
      gift['icon']?.toString(),
    ].whereType<String>().where((source) => source.isNotEmpty).toList();
    for (final source in sources) {
      if (source.startsWith('http')) {
        return Image.network(
          source,
          width: 30,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _giftFallback(gift),
        );
      }
      if (source.startsWith('assets/')) {
        return Image.asset(
          source,
          width: 30,
          height: 30,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _giftFallback(gift),
        );
      }
      return Text(source, style: const TextStyle(fontSize: 22));
    }
    return _giftFallback(gift);
  }

  Widget _giftFallback(Map<String, dynamic> gift) {
    final icon = gift['icon']?.toString();
    if (icon != null && icon.isNotEmpty && !icon.startsWith('http')) {
      return Text(icon, style: const TextStyle(fontSize: 22));
    }
    return const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFFD66B));
  }

  Future<void> _openRoom(Map<String, dynamic> room) async {
    if (room['id'] == null || !mounted) return;
    // The page's room-opening callback owns the confirmation and navigation.
    await widget.onOpenRoom(room);
  }

  Widget _ribbon(Map<String, dynamic> event) {
    final row = Map<String, dynamic>.from(event['row'] as Map);
    final sender = Map<String, dynamic>.from(event['sender'] as Map);
    final recipient = Map<String, dynamic>.from(event['recipient'] as Map);
    final gift = Map<String, dynamic>.from(event['gift'] as Map);
    final room = Map<String, dynamic>.from(event['room'] as Map);
    final gold = _price(row);
    final featuredLuck = _isFeaturedLuck(row);
    final multiplier = _multiplier(row);
    final rewardGold = _rewardGold(row);
    final isMega = !featuredLuck && gold >= 1000000;
    final accent = featuredLuck
        ? const Color(0xFF8DEBFF)
        : isMega
        ? const Color(0xFFFFD66B)
        : const Color(0xFFFF777A);
    final base = featuredLuck
        ? const Color(0xFF073B73)
        : isMega
        ? const Color(0xFF442508)
        : const Color(0xFF5E0715);
    final image = featuredLuck
        ? 'assets/room_effects/luck_multiplier_blue.webp'
        : isMega
        ? 'assets/room_effects/gift_gold_ribbon.webp'
        : 'assets/room_effects/gift_red_ribbon.webp';
    final senderName = _name(sender);
    final recipientName = _name(recipient);
    final giftName = gift['name']?.toString().trim();
    final roomName = room['name']?.toString().trim();
    final headline = featuredLuck
        ? '$recipientName حصل على مضاعف ×$multiplier'
        : 'أرسل هدية';
    final details = featuredLuck
        ? 'ربح ${_formatGold(rewardGold)} ذهب · ${roomName ?? 'غرفة'}'
        : '${giftName == null || giftName.isEmpty ? 'هدية' : giftName} · ${_formatGold(gold)} ذهب · ${roomName ?? 'غرفة'}';

    return Semantics(
      button: true,
      label: featuredLuck
          ? '$headline من $senderName، ${_formatGold(rewardGold)} ذهب، ${roomName ?? 'غرفة'}'
          : '$senderName $headline إلى $recipientName، ${_formatGold(gold)} ذهب، ${roomName ?? 'غرفة'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => unawaited(_openRoom(room)),
          child: Container(
            width: math.min(420, MediaQuery.sizeOf(context).width - 20),
            height: 84,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accent.withValues(alpha: .92),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .23),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                ),
                const BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(image, fit: BoxFit.fill),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          base.withValues(alpha: .08),
                          base.withValues(alpha: .28),
                        ],
                        begin: AlignmentDirectional.topCenter,
                        end: AlignmentDirectional.bottomCenter,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _shine,
                    builder: (_, _) => Positioned.fill(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment(-1.25 + 2.5 * _shine.value, 0),
                          child: Transform.rotate(
                            angle: -.16,
                            child: Container(
                              width: 30,
                              height: 126,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    accent.withValues(alpha: .09),
                                    Colors.white.withValues(alpha: .3),
                                    accent.withValues(alpha: .06),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (featuredLuck) ..._fallingCoins(accent),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(80, 8, 15, 8),
                    child: Row(
                      children: [
                        SakiAvatar(
                          url: sender['avatar_url']?.toString(),
                          label: senderName,
                          radius: 16,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                featuredLuck
                                    ? headline
                                    : '$senderName · $headline',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      featuredLuck
                                          ? 'هدية من $senderName · إلى $recipientName'
                                          : 'إلى $recipientName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                details,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: .85),
                            ),
                          ),
                          child: _giftImage(gift),
                        ),
                        const SizedBox(width: 6),
                        SakiAvatar(
                          url: recipient['avatar_url']?.toString(),
                          label: recipientName,
                          radius: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fallingCoins(Color accent) => List.generate(4, (index) {
    return AnimatedBuilder(
      animation: _coins,
      builder: (_, _) {
        final progress = (_coins.value + index * .24) % 1;
        final sway = math.sin((progress * math.pi * 2) + index).toDouble() * 5;
        return Positioned(
          right: 76 + (index % 2) * 18 + sway,
          top: 3 + progress * 68,
          child: IgnorePointer(
            child: Opacity(
              opacity: .35 + .6 * (1 - progress),
              child: Transform.rotate(
                angle: progress * math.pi * 2,
                child: Icon(
                  Icons.monetization_on_rounded,
                  size: 11 + (index % 2) * 3,
                  color: index.isEven ? const Color(0xFFFFD65B) : accent,
                  shadows: const [
                    Shadow(color: Color(0xAAFFB300), blurRadius: 7),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  });

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<Map<String, dynamic>>>(
        stream: SakiService.instance.giftAnnouncementsStream(),
        builder: (_, snapshot) {
          if (snapshot.hasData) _ingest(snapshot.data!);
          if (_isHidden) return const SizedBox.shrink();
          final event = _event;
          if (event == null) return const SizedBox.shrink();

          return Positioned(
            top: 72,
            left: 8,
            right: 8,
            child: Center(
              child: AnimatedBuilder(
                animation: _flight,
                builder: (_, child) {
                  final t = _flight.value;
                  final x = t < .15
                      ? -1 + t / .15
                      : t > .85
                      ? (t - .85) / .15
                      : 0;
                  return FractionalTranslation(
                    translation: Offset(x.toDouble(), 0),
                    child: child,
                  );
                },
                child: _ribbon(event),
              ),
            ),
          );
        },
      );
}
