import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../messages/messages_page.dart';
import '../posts/posts_page.dart';
import '../profile/profile_page.dart';
import '../reels/reels_page.dart';
import '../rooms/rooms_page.dart';

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
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SakiHtmlBottomNav(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
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
