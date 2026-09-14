import 'dart:async';

import '../../shared/widgets/custom_toast.dart';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../messages/messages_page.dart';
import '../posts/posts_page.dart';
import '../profile/profile_page.dart';
import '../reels/reels_page.dart';
import '../rooms/rooms_page.dart';
import '../../core/data/saki_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  bool _dailyLoginChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showDailyLoginReward(),
    );
  }

  Future<void> _showDailyLoginReward() async {
    if (_dailyLoginChecked || !mounted) return;
    _dailyLoginChecked = true;
    try {
      final status = await SakiService.instance.dailyLoginStatus();
      if (!mounted || status['claimed'] == true) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _DailyLoginRewardDialog(),
      );
    } catch (_) {
      // The home screen remains usable if the optional reward request fails.
    }
  }

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
        children: [IndexedStack(index: _index, children: pages)],
      ),
      bottomNavigationBar: SakiHtmlBottomNav(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _DailyLoginRewardDialog extends StatefulWidget {
  const _DailyLoginRewardDialog();

  @override
  State<_DailyLoginRewardDialog> createState() =>
      _DailyLoginRewardDialogState();
}

class _DailyLoginRewardDialogState extends State<_DailyLoginRewardDialog> {
  bool _loading = false;

  Future<void> _claim() async {
    setState(() => _loading = true);
    try {
      final result = await SakiService.instance.claimDailyLogin();
      if (!mounted) return;
      final amount = (result['amount'] as num?)?.toInt() ?? 0;
      Navigator.of(context).pop();
      CustomToast.show(context, 'تم استلام مكافأة اليوم: $amount عملة ذهبية');
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        CustomToast.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 22),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 18,
                  left: 25,
                  child: Icon(
                    Icons.star_rounded,
                    color: Colors.white.withValues(alpha: .65),
                    size: 26,
                  ),
                ),
                Positioned(
                  bottom: 24,
                  right: 30,
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white.withValues(alpha: .6),
                    size: 24,
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              children: [
                const Text(
                  'مكافأة تسجيل الدخول اليومية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'سجّل دخولك كل يوم واحصل على مكافأتك الذهبية',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFF59E0B),
                        size: 28,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'مكافأة اليوم',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _loading ? null : _claim,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'استلام المكافأة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loading ? null : () => Navigator.pop(context),
                  child: const Text('لاحقاً'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
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
                                    ? const Color(0xFFFF6B35)
                                          .withValues(alpha: .12)
                                    : const Color(0xFF06B6D4)
                                          .withValues(alpha: .12))
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
