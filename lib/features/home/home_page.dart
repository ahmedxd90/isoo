import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../messages/messages_page.dart';
import '../posts/posts_page.dart';
import '../profile/profile_page.dart';
import '../reels/reels_page.dart';
import '../rooms/rooms_page.dart';
import '../../core/data/saki_service.dart';
import '../../core/room_session.dart';
import '../../core/room_background_bridge.dart';
import '../../shared/widgets/saki_widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const RoomsPage(),
      const PostsPage(),
      ReelsPage(visible: _index == 2),
      const MessagesPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          const _GlobalGiftBanner(),
        ],
      ),
      bottomNavigationBar: SakiHtmlBottomNav(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class RoomMiniBubble extends StatefulWidget {
  const RoomMiniBubble({super.key});

  @override
  State<RoomMiniBubble> createState() => _RoomMiniBubbleState();
}

class _RoomMiniBubbleState extends State<RoomMiniBubble>
    with WidgetsBindingObserver {
  final _session = RoomSessionController.instance;
  Offset _dragOffset = Offset.zero;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNativeAction());
  }

  Future<void> _consumeNativeAction() async {
    final pending = await RoomBackgroundBridge.consumePendingRoom();
    if (!mounted || pending == null) return;
    final action = pending['action']?.toString();
    if (action == 'exit') {
      final callback = _session.onExitRequested;
      if (callback != null) await callback();
      return;
    }
    if (action == 'return') {
      final roomId = pending['roomId']?.toString() ?? '';
      final current = _session.room;
      if (current == null || !_session.isSameRoom(roomId) || _opening) return;
      _openRoom(current);
    }
  }

  Future<void> _openRoom(Map<String, dynamic> current) async {
    if (_opening || !mounted) return;
    setState(() => _opening = true);
    await _session.setOverlayVisible(false);
    if (!mounted) return;
    try {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) =>
              RoomDetailPage(room: Map<String, dynamic>.from(current)),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _session.setOverlayVisible(false);
      _consumeNativeAction();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _session.setOverlayVisible(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _session.room;
    if (!_session.bubbleVisible || room == null || _session.engine == null) {
      return const SizedBox.shrink();
    }
    final image = room['image_url']?.toString() ?? '';
    return Positioned(
      right: 16,
      bottom: 92,
      child: Transform.translate(
        offset: _dragOffset,
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() => _dragOffset += details.delta);
          },
          onTap: () => _openRoom(room),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF67E8F9), width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 14),
                  ],
                ),
                child: ClipOval(
                  child: image.isEmpty
                      ? const ColoredBox(
                          color: Color(0xFF343B79),
                          child: Icon(
                            Icons.meeting_room,
                            color: Colors.white,
                            size: 28,
                          ),
                        )
                      : Image.network(image, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -2,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D2442),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(7),
                    child: Icon(
                      Icons.keyboard_return_rounded,
                      color: Color(0xFF67E8F9),
                      size: 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalGiftBanner extends StatefulWidget {
  const _GlobalGiftBanner();
  @override
  State<_GlobalGiftBanner> createState() => _GlobalGiftBannerState();
}

class _GlobalGiftBannerState extends State<_GlobalGiftBanner> {
  String? _activeId;
  String? _shownId;
  Timer? _hideTimer;
  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _load(Map<String, dynamic> row) async {
    final sender = await SakiService.instance.client
        .from('profiles')
        .select('username,avatar_url')
        .eq('id', row['sender_id'])
        .maybeSingle();
    final recipient = await SakiService.instance.client
        .from('profiles')
        .select('username,avatar_url')
        .eq('id', row['recipient_id'])
        .maybeSingle();
    final gift = await SakiService.instance.client
        .from('room_gift_catalog')
        .select('name,icon')
        .eq('id', row['gift_id'])
        .maybeSingle();
    return {'sender': sender, 'recipient': recipient, 'gift': gift};
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<List<Map<String, dynamic>>>(
    stream: SakiService.instance.giftAnnouncementsStream(),
    builder: (_, snapshot) {
      final rows = (snapshot.data ?? const [])
          .where((r) => ((r['total_price'] as num?)?.toInt() ?? 0) >= 100000)
          .toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      final newestId = rows.first['id']?.toString();
      if (newestId != null && newestId != _shownId) {
        _shownId = newestId;
        _activeId = newestId;
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _activeId = null);
        });
      }
      if (_activeId != newestId) return const SizedBox.shrink();
      return Positioned(
        top: 72,
        left: 0,
        right: 0,
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _load(rows.first),
          builder: (_, data) {
            final info = data.data;
            if (info == null) return const SizedBox.shrink();
            final sender = Map<String, dynamic>.from(info['sender'] ?? {}),
                recipient = Map<String, dynamic>.from(info['recipient'] ?? {}),
                gift = Map<String, dynamic>.from(info['gift'] ?? {});
            return TweenAnimationBuilder<Offset>(
              tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
              duration: const Duration(milliseconds: 650),
              builder: (_, offset, child) =>
                  FractionalTranslation(translation: offset, child: child),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.amberAccent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SakiAvatar(
                        url: sender['avatar_url'] as String?,
                        label: sender['username'] as String?,
                        radius: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        sender['username'] as String? ?? 'مستخدم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        ' أرسل ',
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                      Text(
                        gift['icon'] as String? ?? '🎁',
                        style: const TextStyle(fontSize: 22),
                      ),
                      const Text(
                        ' إلى ',
                        style: TextStyle(color: Colors.amberAccent),
                      ),
                      SakiAvatar(
                        url: recipient['avatar_url'] as String?,
                        label: recipient['username'] as String?,
                        radius: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        recipient['username'] as String? ?? 'مستخدم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

class SakiHtmlBottomNav extends StatelessWidget {
  const SakiHtmlBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (
      'assets/trace_home/images/ic_main_default.png',
      'assets/trace_home/images/ic_main_selected.png',
      'الرئيسية',
    ),
    (
      'assets/trace_home/images/ic_feed_default.png',
      'assets/trace_home/images/ic_feed_selected.png',
      'اللحظات',
    ),
    (
      'assets/trace_home/images/activity_main_send_live.png',
      'assets/trace_home/images/activity_main_send_live.png',
      'الريلز',
    ),
    (
      'assets/trace_home/images/home_icon_message.png',
      'assets/trace_home/images/home_icon_message.png',
      'الرسائل',
    ),
    (
      'assets/trace_home/images/ic_profile_default.png',
      'assets/trace_home/images/ic_profile_default.png',
      'أنا',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          textDirection: TextDirection.rtl,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final active = selectedIndex == index;
            return Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                splashColor: const Color(0xFFFF6B35).withValues(alpha: .12),
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active ? 34 : 30,
                        height: active ? 34 : 30,
                        decoration: BoxDecoration(
                          color: active
                              ? (index.isEven
                                    ? const Color(0xFFFF6B35).withValues(alpha: .12)
                                    : const Color(0xFF06B6D4).withValues(alpha: .12))
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Image.asset(
                            active ? item.$2 : item.$1,
                            width: active ? 25 : 22,
                            height: active ? 25 : 22,
                            errorBuilder: (_, _, _) => FaIcon(
                              FontAwesomeIcons.circle,
                              color: active
                                  ? (index.isEven
                                        ? const Color(0xFFFF6B35)
                                        : const Color(0xFF06B6D4))
                                  : const Color(0xFF111827),
                              size: active ? 19 : 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: TextStyle(
                          color: active
                              ? (index.isEven
                                    ? const Color(0xFFFF6B35)
                                    : const Color(0xFF06B6D4))
                              : const Color(0xFF111827),
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w900
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
