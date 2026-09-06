import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../messages/messages_page.dart';
import '../posts/posts_page.dart';
import '../profile/profile_page.dart';
import '../reels/reels_page.dart';
import '../rooms/rooms_page.dart';
import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _navTeal = Color(0xFF2DD4BF);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  final _pages = const [
    PostsPage(),
    ReelsPage(),
    RoomsPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
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
    (FontAwesomeIcons.house, 'الرئيسية'),
    (FontAwesomeIcons.clapperboard, 'الريلز'),
    (FontAwesomeIcons.microphone, 'الغرف'),
    (FontAwesomeIcons.comments, 'الرسائل'),
    (FontAwesomeIcons.circleUser, 'أنا'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: const BoxDecoration(
        color: Color(0xF20B0F14),
        border: Border(top: BorderSide(color: Color(0xFF27303A))),
        boxShadow: [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 16,
            offset: Offset(0, -3),
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
                splashColor: _navTeal.withValues(alpha: .12),
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  transform: Matrix4.translationValues(0, active ? -2 : 0, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: active && index == 1 ? 34 : 30,
                        height: active && index == 1 ? 34 : 30,
                        decoration: BoxDecoration(
                          color: active && index == 1
                              ? _navTeal.withValues(alpha: .20)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: FaIcon(
                            item.$1,
                            color: active ? _navTeal : const Color(0xFF9CA3AF),
                            size: active ? 19 : 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.$2,
                        style: TextStyle(
                          color: active ? _navTeal : const Color(0xFF9CA3AF),
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
