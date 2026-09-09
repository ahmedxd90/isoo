import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';
import '../../core/room_background_bridge.dart';
import '../../core/room_session.dart';
import '../search/search_page.dart';
import 'ranking_page.dart';
import 'room_settings_page.dart';
import 'room_gifts_sheet.dart';
import 'room_gift_ranking_sheet.dart';
import 'luck_bag_widgets.dart';
import '../profile/store_pages.dart';
import '../profile/user_profile_page.dart';
import '../profile/vip_widgets.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

const _roomPrimary = Color(0xFF656BF9);
const _roomSecondary = Color(0xFF8E91FF);
const _roomTrophyGold = Color(0xFFF3B83F);
const _roomTrendOrange = Color(0xFFFF6B35);
const _roomBg = Color(0xFFF7F7F7);
const _roomMuted = Color(0xFF9CA3AF);

class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});

  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _rooms = [];
  List<Map<String, dynamic>> _banners = [];
  Set<String> _followedRoomIds = <String>{};
  bool _loading = true;
  bool _followingOnly = false;
  String _country = 'الترند';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.rooms(),
        _service.followedRoomIds(),
      ]);
      final rooms = List<Map<String, dynamic>>.from(results[0] as List);
      List<Map<String, dynamic>> banners = [];
      try {
        banners = await _service.roomBanners();
      } catch (_) {
        // Banners are optional; never hide the real room list if they fail.
      }
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _followedRoomIds = Set<String>.from(results[1] as Set<String>);
          _banners = banners;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل الغرف من Supabase')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleRooms {
    return _rooms.where((room) {
      final country = (room['country'] as String? ?? '').toLowerCase();
      final matchesCountry =
          _country == 'الترند' || country.contains(_country.toLowerCase());
      final matchesFollowing =
          !_followingOnly || _followedRoomIds.contains(room['id']?.toString());
      return matchesCountry && matchesFollowing;
    }).toList();
  }

  List<String> get _availableCountries {
    final values = <String>{};
    for (final room in _rooms) {
      final value = (room['country'] as String? ?? '').trim();
      if (value.isNotEmpty && value != 'الكل' && value != 'ترند') {
        values.add(value);
      }
    }
    return values.toList()..sort();
  }

  Future<void> _search() async =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SearchPage()));

  Future<void> _create() async {
    await RoomSessionController.instance.close();
    final owned = await _service.myOwnedRoom();
    if (!mounted) return;
    if (owned != null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: owned)));
      return;
    }
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateRoomPage()),
    );
    if (!mounted || created == null) return;
    await _load();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: created)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _roomBg,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .95),
        surfaceTintColor: Colors.white,
        elevation: 2,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            _RoomHeaderTab(
              label: 'الكل',
              selected: !_followingOnly,
              onTap: () => setState(() {
                _followingOnly = false;
                _country = 'الترند';
              }),
            ),
            const SizedBox(width: 24),
            _RoomHeaderTab(
              label: 'متابعة',
              selected: _followingOnly,
              onTap: () => setState(() => _followingOnly = true),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 2),
            child: _AnimatedTrophyButton(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const RankingPage())),
            ),
          ),
          IconButton(
            onPressed: _search,
            icon: const FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 18,
              color: Color(0xFF374151),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16, start: 3),
            child: GestureDetector(
              onTap: _create,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_roomPrimary, _roomSecondary],
                  ),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.plus,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _roomPrimary))
          : RefreshIndicator(
              color: _roomPrimary,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  if (!_followingOnly && _banners.isNotEmpty)
                    SliverToBoxAdapter(
                      child: RoomBannerCarousel(banners: _banners),
                    ),
                  if (!_followingOnly)
                    SliverToBoxAdapter(
                      child: _TrendCountryBar(
                        countries: _availableCountries,
                        selected: _country,
                        onSelected: (value) => setState(() => _country = value),
                      ),
                    ),
                  if (_visibleRooms.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.mic_none_rounded,
                        title: 'لا توجد غرف الآن',
                        subtitle: 'أنشئ غرفة صوتية وابدأ الحوار.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
                      sliver: SliverList.builder(
                        itemCount: _visibleRooms.length,
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: HtmlRoomCard(
                            room: _visibleRooms[index],
                            rank: index + 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: _roomPrimary,
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),
    );
  }
}

class _RoomHeaderTab extends StatelessWidget {
  const _RoomHeaderTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? _roomPrimary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? const Color(0xFF111827) : _roomMuted,
          fontSize: selected ? 19 : 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _TrendCountryBar extends StatelessWidget {
  const _TrendCountryBar({
    required this.countries,
    required this.selected,
    required this.onSelected,
  });
  final List<String> countries;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 66,
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      scrollDirection: Axis.horizontal,
      itemCount: countries.length + 1,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _TrendPill(
            selected: selected == 'الترند',
            onTap: () => onSelected('الترند'),
            label: 'الترند',
            child: const _TrendFlame(),
          );
        }
        final country = countries[index - 1];
        return _TrendPill(
          selected: selected == country,
          onTap: () => onSelected(country),
          label: country,
          child: Text(
            _flagForCountry(country),
            style: const TextStyle(fontSize: 22),
          ),
        );
      },
    ),
  );
}

class _TrendPill extends StatelessWidget {
  const _TrendPill({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.label,
  });
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsetsDirectional.only(start: 9, end: 13),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFFFFF1EB), Color(0xFFFFD6C7)],
              )
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: selected ? _roomTrendOrange : const Color(0xFFE8EAF0),
          width: selected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? _roomTrendOrange.withValues(alpha: .18)
                : Colors.black.withValues(alpha: .05),
            blurRadius: selected ? 12 : 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFB83D18)
                  : const Color(0xFF374151),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (selected) ...[
            const SizedBox(width: 5),
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: _roomTrendOrange,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _TrendFlame extends StatefulWidget {
  const _TrendFlame();
  @override
  State<_TrendFlame> createState() => _TrendFlameState();
}

class _TrendFlameState extends State<_TrendFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, child) => Transform.translate(
      offset: Offset(0, -1.5 * _controller.value),
      child: Transform.rotate(
        angle: (_controller.value - .5) * .08,
        child: child,
      ),
    ),
    child: Image.asset(
      'assets/saki_trending_flame.png',
      width: 27,
      height: 27,
      fit: BoxFit.contain,
    ),
  );
}

String _flagForCountry(String country) {
  const flags = {
    'السعودية': '🇸🇦',
    'المغرب': '🇲🇦',
    'مصر': '🇪🇬',
    'الإمارات': '🇦🇪',
    'العراق': '🇮🇶',
    'الكويت': '🇰🇼',
    'قطر': '🇶🇦',
    'البحرين': '🇧🇭',
    'عمان': '🇴🇲',
    'الأردن': '🇯🇴',
    'لبنان': '🇱🇧',
    'سوريا': '🇸🇾',
    'اليمن': '🇾🇪',
    'الجزائر': '🇩🇿',
    'تونس': '🇹🇳',
    'ليبيا': '🇱🇾',
    'السودان': '🇸🇩',
    'فلسطين': '🇵🇸',
    'موريتانيا': '🇲🇷',
    'الصومال': '🇸🇴',
    'جيبوتي': '🇩🇯',
    'جزر القمر': '🇰🇲',
  };
  return flags[country] ?? '🌐';
}

class _AnimatedTrophyButton extends StatefulWidget {
  const _AnimatedTrophyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AnimatedTrophyButton> createState() => _AnimatedTrophyButtonState();
}

class _AnimatedTrophyButtonState extends State<_AnimatedTrophyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: widget.onTap,
    child: AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -1.5 * _controller.value),
        child: Transform.rotate(
          angle: (_controller.value - .5) * .10,
          child: child,
        ),
      ),
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _roomTrophyGold.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _roomTrophyGold.withValues(alpha: .35)),
        ),
        child: Image.asset(
          'assets/saki_leaderboard_trophy.png',
          width: 34,
          height: 34,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

class RoomBannerCarousel extends StatefulWidget {
  const RoomBannerCarousel({super.key, required this.banners});
  final List<Map<String, dynamic>> banners;

  @override
  State<RoomBannerCarousel> createState() => _RoomBannerCarouselState();
}

class _RoomBannerCarouselState extends State<RoomBannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  final _fallback = const [
    {
      'image': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=800&q=80',
      'title': 'مهرجان الصيف',
      'subtitle': 'جوائز كبرى بانتظارك',
    },
    {
      'image': 'https://images.unsplash.com/photo-1549490349-8643362247b5?auto=format&fit=crop&w=800&q=80',
      'title': 'تحدي المواهب',
      'subtitle': 'كن النجم الأول',
    },
    {
      'image': 'https://images.unsplash.com/photo-1516280440502-37f8e10bc2eb?auto=format&fit=crop&w=800&q=80',
      'title': 'صداقات جديدة',
      'subtitle': 'استكشف غرف الدردشة',
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final count = widget.banners.isEmpty
          ? _fallback.length
          : widget.banners.length;
      _index = (_index + 1) % count;
      _controller.animateToPage(
        _index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.banners.isEmpty ? _fallback : widget.banners;
    return SizedBox(
      height: 164,
      child: PageView.builder(
        controller: _controller,
        itemCount: data.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, index) {
          final item = data[index];
          final image = (item['image_url'] ?? item['image']) as String? ?? '';
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_roomPrimary, _roomSecondary],
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xAA111827), Colors.transparent],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    top: 34,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['title'] as String?) ?? 'غرف SAKI',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          (item['subtitle'] as String?) ?? 'اكتشف غرفًا جديدة',
                          style: const TextStyle(
                            color: Color(0xFFF9A8D4),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReferenceRoomCard extends StatelessWidget {
  const _ReferenceRoomCard({required this.room, required this.rank});
  final Map<String, dynamic> room;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final name = room['name'] as String? ?? 'غرفة SAKI';
    final image = room['image_url'] as String?;
    final country = room['country'] as String? ?? '';
    final members = room['_members_count'] as int? ?? 0;
    final description = (room['description'] as String?)?.trim();
    final official =
        room['is_official'] == true ||
        room['room_type']?.toString().toLowerCase() == 'official';
    final accent = rank == 1
        ? const Color(0xFFF59E0B)
        : rank == 2
        ? const Color(0xFF94A3B8)
        : rank == 3
        ? const Color(0xFFD97706)
        : const Color(0xFFE2E8F0);
    final badgeIcon = rank == 1
        ? FontAwesomeIcons.crown
        : rank == 2
        ? FontAwesomeIcons.award
        : FontAwesomeIcons.medal;

    Future<void> openRoom() async {
      final active = RoomSessionController.instance.room;
      if (active != null && active['id'] != room['id']) {
        await RoomSessionController.instance.close();
      }
      if (!context.mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)));
    }

    return GestureDetector(
      onTap: openRoom,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent, width: rank <= 3 ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: rank <= 3 ? .14 : .06),
              blurRadius: rank <= 3 ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: image == null || image.isEmpty
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_roomPrimary, _roomSecondary],
                              ),
                            ),
                            child: Icon(
                              Icons.mic_external_on_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          )
                        : Image.network(
                            image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_roomPrimary, _roomSecondary],
                                ),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .92),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _ReferenceWave(),
                          const Text(
                            'مباشر',
                            style: TextStyle(
                              color: Color(0xFFDB2777),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (official)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.verified_rounded,
                            color: Color(0xFF3B82F6),
                            size: 16,
                          ),
                        ),
                      if (country.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 3),
                          child: Text(
                            _flagForCountry(country),
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                    ],
                  ),
                  if (official)
                    Container(
                      margin: const EdgeInsets.only(top: 5, bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Text(
                        'غرفة رسمية',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  if (!official) const SizedBox(height: 8),
                  Text(
                    description == null || description.isEmpty
                        ? 'انضم الآن وشارك في الحوار الصوتي المباشر.'
                        : description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.only(top: 7),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Color(0xFF10B981),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$members',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (rank <= 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: rank == 1
                                    ? const [
                                        Color(0xFFFBBF24),
                                        Color(0xFFF59E0B),
                                      ]
                                    : rank == 2
                                    ? const [
                                        Color(0xFFE2E8F0),
                                        Color(0xFF94A3B8),
                                      ]
                                    : const [
                                        Color(0xFFD97706),
                                        Color(0xFFB45309),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FaIcon(
                                  badgeIcon,
                                  color: rank == 2
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TOP $rank',
                                  style: TextStyle(
                                    color: rank == 2
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceWave extends StatefulWidget {
  const _ReferenceWave();
  @override
  State<_ReferenceWave> createState() => _ReferenceWaveState();
}

class _ReferenceWaveState extends State<_ReferenceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, _) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final height = 3 + (index.isEven ? 7 : 12) * (0.35 + _controller.value);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFEC4899),
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    ),
  );
}

class HtmlRoomCard extends StatelessWidget {
  const HtmlRoomCard({super.key, required this.room, required this.rank});
  final Map<String, dynamic> room;
  final int rank;

  @override
  Widget build(BuildContext context) =>
      _ReferenceRoomCard(room: room, rank: rank);
}

class _RoomWave extends StatefulWidget {
  const _RoomWave();
  @override
  State<_RoomWave> createState() => _RoomWaveState();
}

class _RoomWaveState extends State<_RoomWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (index) {
            final height =
                6 + (index.isEven ? 10 : 6) * (0.4 + _controller.value);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: index == 1 ? _roomSecondary : const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key, required this.room});
  final Map<String, dynamic> room;
  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final _service = SakiService.instance;
  final _message = TextEditingController();
  final _messageFocus = FocusNode();
  late final String _roomId = widget.room['id'] as String;
  late final DateTime _roomOpenedAt = DateTime.now().toUtc();
  late final Stream<List<Map<String, dynamic>>> _seatStream;
  late final Stream<List<Map<String, dynamic>>> _roomSettingsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _roomSettingsSubscription;
  late final Stream<List<Map<String, dynamic>>> _messageStream;
  late final RealtimeChannel _roomChatChannel;
  DateTime? _chatClearedAt;
  bool _joined = false;
  bool _busy = false;
  bool _followed = false;
  RtcEngine? _engine;
  bool _isOnSeat = false;
  bool _micMuted = true;
  bool _listenMuted = false;
  bool _isComposing = false;
  String _micPermission = 'everyone';
  bool _isModerator = false;
  int _comboSeconds = 0;
  Timer? _comboTimer;
  String? _lastGiftRecipient;
  Map<String, dynamic>? _lastGift;
  final Set<int> _remoteUsers = <int>{};
  late int _liveSeatCount;
  String? _liveBackgroundUrl;
  Map<String, dynamic>? _activeGiftMessage;
  String? _shownGiftMessageId;
  List<Map<String, dynamic>> _roomMembers = [];
  Timer? _presenceTimer;
  final List<Map<String, dynamic>> _optimisticMessages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _roomMembersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _roomEmojiSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _luckBagSubscription;
  final Map<String, Timer> _roomEmojiTimers = {};
  final Map<String, Map<String, dynamic>> _activeSeatEmojis = {};
  final Map<String, GlobalKey> _seatKeys = {};
  List<Map<String, dynamic>> _roomEmojis = [];
  int _roomGoldTotal = 0;
  Map<String, dynamic>? _entranceProfile;
  Map<String, dynamic>? _entranceProduct;
  Timer? _entranceTimer;
  bool _membersInitialized = false;
  late AudioPlayer _musicPlayer;
  List<Map<String, dynamic>> _roomMusic = [];
  Map<String, dynamic>? _activeMusic;
  bool _musicPlaying = false;
  double _musicVolume = 1;
  double _musicDurationSeconds = 0;
  String? _musicOwnerId;
  Set<String> _previousSeatUserIds = <String>{};
  bool _seatStopPending = false;
  Timer? _seatTaskTimer;
  List<Map<String, dynamic>> _luckBags = [];
  Map<String, dynamic>? _newLuckBag;

  @override
  void initState() {
    super.initState();
    // Stop the external bubble only after this room page has actually started.
    RoomBackgroundBridge.stop();
    final session = RoomSessionController.instance;
    _musicPlayer = session.isSameRoom(_roomId)
        ? (session.musicPlayer ?? AudioPlayer())
        : AudioPlayer();
    _seatStream = _service.roomSeatsStream(_roomId);
    _roomSettingsStream = _service.roomSettingsStream(_roomId);
    _liveSeatCount = (widget.room['seat_count'] as num?)?.toInt() ?? 10;
    _liveBackgroundUrl = widget.room['background_url'] as String?;
    _micPermission = widget.room['mic_permission'] as String? ?? 'everyone';
    _roomSettingsSubscription = _roomSettingsStream.listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final updated = rows.first;
      setState(() {
        _liveSeatCount =
            (updated['seat_count'] as num?)?.toInt() ?? _liveSeatCount;
        _liveBackgroundUrl = updated['background_url'] as String?;
        _micPermission = updated['mic_permission'] as String? ?? _micPermission;
      });
    });
    _messageStream = _service.roomMessagesStream(_roomId, after: _roomOpenedAt);
    _service.roomEmojis().then((items) {
      if (mounted) setState(() => _roomEmojis = items);
    });
    _roomEmojiSubscription = _service.roomEmojiEventsStream(_roomId).listen((
      events,
    ) {
      if (events.isEmpty) return;
      final event = events.last;
      final userId = event['user_id']?.toString();
      final emojiId = event['emoji_id']?.toString();
      if (userId == null || emojiId == null) return;
      Map<String, dynamic>? emoji;
      for (final item in _roomEmojis) {
        if (item['id']?.toString() == emojiId) emoji = item;
      }
      if (emoji != null) {
        _activateSeatEmoji(userId, emoji);
        return;
      }
      _service.roomEmojis().then((items) {
        if (!mounted) return;
        final match = items.where((item) => item['id']?.toString() == emojiId);
        if (match.isNotEmpty) _activateSeatEmoji(userId, match.first);
      });
    });
    _roomChatChannel = _service.client.channel('room-chat:$_roomId')
      ..onBroadcast(
        event: 'clear',
        callback: (payload) {
          if (!mounted) return;
          final clearedAt = DateTime.tryParse(
            payload['clearedAt']?.toString() ?? '',
          );
          _applyChatClear(clearedAt ?? DateTime.now().toUtc());
        },
      )
      ..onBroadcast(
        event: 'music',
        callback: (payload) =>
            _handleMusicEvent(Map<String, dynamic>.from(payload as Map)),
      )
      ..subscribe();
    final existingEngine = RoomSessionController.instance.engine;
    final restoredSession =
        existingEngine != null &&
        RoomSessionController.instance.isSameRoom(_roomId);
    if (restoredSession) {
      _engine = existingEngine;
      final session = RoomSessionController.instance;
      _isOnSeat = session.isOnSeat;
      _micMuted = session.micMuted;
      RoomSessionController.instance.hideBubble();
    }
    _join();
    _loadRoomState();
    _loadRoomMusic();
    _roomMembersSubscription = _service.roomMembersStream(_roomId).listen((
      members,
    ) {
      if (!mounted) return;
      final previousIds = _roomMembers.map((m) => m['id']).toSet();
      final entrant = members
          .where((m) => _membersInitialized && !previousIds.contains(m['id']))
          .firstOrNull;
      setState(() {
        _roomMembers = members;
        _membersInitialized = true;
        if (entrant != null) {
          _entranceProfile = entrant;
          _entranceProduct = null;
        }
      });
      if (entrant != null) {
        _entranceTimer?.cancel();
        _service.equippedEntranceInRoom(_roomId, entrant['id'] as String).then((
          product,
        ) {
          if (!mounted) return;
          setState(() => _entranceProduct = product);
          if (product == null) {
            _entranceTimer?.cancel();
            _entranceTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) setState(() => _entranceProfile = null);
            });
          }
        });
      }
    });
    _service.roomMembers(_roomId).then((members) {
      if (mounted) setState(() => _roomMembers = members);
    });
    _luckBagSubscription = _service.roomLuckBagsStream(_roomId).listen((bags) {
      if (!mounted) return;
      setState(() => _luckBags = bags);
    });
    if (!restoredSession) _startRoomAudio();
  }

  int _numericUid(String value) {
    final compact = value.replaceAll('-', '');
    final prefix = compact.length > 8 ? compact.substring(0, 8) : compact;
    return int.parse(prefix, radix: 16) & 0x7fffffff;
  }

  void _applyChatClear(DateTime clearedAt) {
    if (!mounted) return;
    setState(() => _chatClearedAt = clearedAt.toUtc());
  }

  Future<void> _clearRoomChatForEveryone() async {
    await _service.clearRoomMessages(_roomId);
    final clearedAt = DateTime.now().toUtc();
    _applyChatClear(clearedAt);
    await _roomChatChannel.sendBroadcastMessage(
      event: 'clear',
      payload: {'roomId': _roomId, 'clearedAt': clearedAt.toIso8601String()},
    );
  }

  Future<void> _startRoomAudio() async {
    try {
      final uid = _numericUid(_service.uid);
      final response = await _service.client.functions.invoke(
        'agora-token',
        body: {'channelName': _roomId, 'uid': uid},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final appId = data['appId'] as String?;
      final token = data['token'] as String?;
      if (appId == null || token == null || appId.isEmpty || token.isEmpty) {
        return;
      }
      final engine = createAgoraRtcEngine();
      _engine = engine;
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (_, _) {},
          onUserJoined: (_, remoteUid, _) {
            if (mounted) setState(() => _remoteUsers.add(remoteUid));
            RoomSessionController.instance.updateVoiceState(
              remoteUsers: _remoteUsers.length,
            );
          },
          onUserOffline: (_, remoteUid, _) {
            if (mounted) setState(() => _remoteUsers.remove(remoteUid));
            RoomSessionController.instance.updateVoiceState(
              remoteUsers: _remoteUsers.length,
            );
          },
          onTokenPrivilegeWillExpire: (_, _) => _refreshRoomToken(),
        ),
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableAudio();
      await engine.joinChannel(
        token: token,
        channelId: _roomId,
        uid: uid,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ),
      );
      RoomSessionController.instance.activate(
        room: widget.room,
        engine: engine,
        isOnSeat: _isOnSeat,
        micMuted: _micMuted,
        remoteUsers: _remoteUsers.length,
        musicPlayer: _musicPlayer,
        onExitRequested: () async {
          await _service.leaveRoom(_roomId);
          await RoomSessionController.instance.close();
        },
      );
    } catch (_) {
      // Audio errors must not prevent the text room from loading.
    }
  }

  Future<void> _refreshRoomToken() async {
    final uid = _numericUid(_service.uid);
    final response = await _service.client.functions.invoke(
      'agora-token',
      body: {'channelName': _roomId, 'uid': uid},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token'] as String?;
    if (token != null) await _engine?.renewToken(token);
  }

  void _minimizeRoom() {
    final engine = _engine;
    if (engine == null) return;
    RoomSessionController.instance.minimize(
      room: widget.room,
      engine: engine,
      isOnSeat: _isOnSeat,
      micMuted: _micMuted,
      remoteUsers: _remoteUsers.length,
      musicPlayer: _musicPlayer,
      onExitRequested: () async {
        await _service.leaveRoom(_roomId);
        await RoomSessionController.instance.close();
      },
    );
    RoomBackgroundBridge.start(
      roomId: _roomId,
      roomName: widget.room['name']?.toString() ?? 'غرفة SAKI',
      imageUrl: widget.room['image_url']?.toString(),
    );
    // The in-app card is the only bubble while the app is visible. The
    // Android overlay is started by RoomMiniBubble only after the app pauses.
    _joined = false;
    Navigator.of(context).pop();
  }

  Future<void> _setSeatAudio(bool seated) async {
    _isOnSeat = seated;
    RoomSessionController.instance.updateVoiceState(isOnSeat: seated);
    await _syncMusicSeatAccess(seated);
    if (!seated) {
      _seatTaskTimer?.cancel();
      _seatTaskTimer = null;
      _micMuted = true;
      await _engine?.muteLocalAudioStream(true);
      await _engine?.setClientRole(role: ClientRoleType.clientRoleAudience);
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishMicrophoneTrack: false,
          autoSubscribeAudio: true,
        ),
      );
      if (mounted) setState(() {});
      return;
    }
    _seatTaskTimer?.cancel();
    _seatTaskTimer = Timer(const Duration(minutes: 5), () {
      _service
          .recordUserTask('seat_5_minutes')
          .catchError((_) => const <String, dynamic>{});
    });
    await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine?.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishMicrophoneTrack: false,
        autoSubscribeAudio: true,
      ),
    );
    await _engine?.muteLocalAudioStream(true);
    if (mounted) setState(() {});
  }

  Future<void> _toggleRoomMic() async {
    if (!_isOnSeat) {
      _messageSnack('يجب أن تجلس على مقعد قبل التحدث.');
      return;
    }
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      _messageSnack('اسمح باستخدام الميكروفون للتحدث.');
      return;
    }
    _micMuted = !_micMuted;
    RoomSessionController.instance.updateVoiceState(micMuted: _micMuted);
    await _engine?.updateChannelMediaOptions(
      ChannelMediaOptions(
        publishMicrophoneTrack: !_micMuted,
        autoSubscribeAudio: true,
      ),
    );
    await _engine?.muteLocalAudioStream(_micMuted);
    await _service.setRoomSpeaking(_roomId, !_micMuted);
    if (mounted) setState(() {});
  }

  Future<void> _toggleListenMute() async {
    final next = !_listenMuted;
    await _engine?.muteAllRemoteAudioStreams(next);
    if (mounted) setState(() => _listenMuted = next);
  }

  Future<void> _showGiftPanel() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomGiftsSheet(
        service: _service,
        roomId: _roomId,
        onSent: (recipientId, gift, flyingBanner) async {
          _lastGiftRecipient = recipientId;
          _lastGift = gift;
          final payload = <String, dynamic>{
            'gift_id': gift['id'],
            'icon': gift['icon'],
            'thumbnail_url': gift['icon'],
            'name': gift['name'],
            'media_url': gift['media_url'],
            'media_type': gift['media_type'],
            'category': gift['category'],
            'recipient_id': recipientId,
            'flying_banner': flyingBanner,
          };
          final optimistic = _queueOptimisticMessage(
            body: 'أرسل هدية ${gift['name'] ?? 'هدية'}',
            type: 'gift',
            payload: payload,
          );
          final giftRequest = _service.sendRoomGift(
            roomId: _roomId,
            recipientId: recipientId,
            giftId: gift['id'] as String,
          );
          final messageRequest = _service.sendRoomMessage(
            _roomId,
            'أرسل هدية ${gift['name'] ?? 'هدية'}',
            type: 'gift',
            payload: payload,
          );
          try {
            await Future.wait([giftRequest, messageRequest]);
          } catch (_) {
            _removeOptimisticMessage(optimistic);
            rethrow;
          }
        },
      ),
    );
    if (sent == true && _isLuckGift(_lastGift)) {
      _startGiftCombo();
    } else if (mounted) {
      _comboTimer?.cancel();
      setState(() => _comboSeconds = 0);
    }
  }

  bool _isLuckGift(Map<String, dynamic>? gift) {
    final category = gift?['category']?.toString().toLowerCase();
    return category == 'luck' || category == 'الحظ';
  }

  void _startGiftCombo() {
    _comboTimer?.cancel();
    setState(() => _comboSeconds = 10);
    _comboTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_comboSeconds <= 1) {
        timer.cancel();
        setState(() => _comboSeconds = 0);
      } else {
        setState(() => _comboSeconds--);
      }
    });
  }

  Future<void> _sendComboAgain() async {
    final recipient = _lastGiftRecipient;
    final gift = _lastGift;
    if (recipient == null || gift == null) return;
    if (!_isLuckGift(gift)) return;
    try {
      final payload = <String, dynamic>{
        'gift_id': gift['id'],
        'icon': gift['icon'],
        'thumbnail_url': gift['icon'],
        'name': gift['name'],
        'media_url': gift['media_url'],
        'media_type': gift['media_type'],
        'category': gift['category'],
        'recipient_id': recipient,
        'flying_banner': true,
      };
      final optimistic = _queueOptimisticMessage(
        body: 'أرسل هدية ${gift['name'] ?? 'هدية'}',
        type: 'gift',
        payload: payload,
      );
      final giftRequest = _service.sendRoomGift(
        roomId: _roomId,
        recipientId: recipient,
        giftId: gift['id'] as String,
      );
      final messageRequest = _service.sendRoomMessage(
        _roomId,
        'أرسل هدية ${gift['name'] ?? 'هدية'}',
        type: 'gift',
        payload: payload,
      );
      try {
        await Future.wait([giftRequest, messageRequest]);
      } catch (_) {
        _removeOptimisticMessage(optimistic);
        rethrow;
      }
      _startGiftCombo();
    } catch (e) {
      _messageSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  GlobalKey? _seatKeyForGift(Map<String, dynamic> message) {
    final payload = message['payload'];
    if (payload is! Map) return null;
    return _seatKeys[payload['recipient_id']?.toString()];
  }

  Future<void> _loadRoomState() async {
    try {
      final results = await Future.wait([
        _service.isFollowingRoom(_roomId),
        _service.isRoomModerator(_roomId),
      ]);
      if (mounted) {
        setState(() {
          _followed = results[0];
          _isModerator = results[1];
        });
      }
      final ranking = await _service.roomGiftRanking(_roomId, 'يومي');
      if (mounted) setState(() => _roomGoldTotal = ranking.total);
    } catch (_) {}
  }

  Future<void> _join() async {
    try {
      await _service.joinRoom(_roomId);
      try {
        await _service.claimEquippedEntranceOnJoin(_roomId);
      } catch (_) {
        // لا يمنع فشل تسجيل الدخولية دخول المستخدم إلى الغرفة.
      }
      await _service.sendRoomMessage(_roomId, 'انضم إلى الغرفة', type: 'join');
      if (mounted) setState(() => _joined = true);
      _presenceTimer?.cancel();
      _presenceTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _service.touchRoomPresence(_roomId).catchError((_) {});
      });
    } catch (error) {
      if (mounted) {
        _messageSnack(error.toString().replaceFirst('Exception: ', ''));
        Navigator.maybePop(context);
      }
    }
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    _message.clear();
    final optimistic = _queueOptimisticMessage(
      body: body,
      type: 'chat',
      payload: const <String, dynamic>{},
    );
    if (mounted) setState(() => _isComposing = false);
    try {
      await _service.sendRoomMessage(_roomId, body);
    } catch (error) {
      _removeOptimisticMessage(optimistic);
      if (mounted) {
        _messageSnack(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Map<String, dynamic> _queueOptimisticMessage({
    required String body,
    required String type,
    required Map<String, dynamic> payload,
  }) {
    final message = <String, dynamic>{
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'sender_id': _service.uid,
      'body': body,
      'message_type': type,
      'payload': payload,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (mounted) setState(() => _optimisticMessages.add(message));
    return message;
  }

  void _removeOptimisticMessage(Map<String, dynamic> message) {
    if (mounted) {
      setState(
        () => _optimisticMessages.removeWhere(
          (item) => item['id'] == message['id'],
        ),
      );
    }
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF211F27),
        title: const Text(
          'مغادرة الغرفة؟',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'يمكنك الاحتفاظ بالجلسة وتصغير الغرفة، أو الخروج بالكامل والنزول من المقعد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('احتفظ بالغرفة'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE34D68),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('خروج كامل'),
          ),
        ],
      ),
    );
    if (result == true) {
      await RoomBackgroundBridge.setPipEligible(false);
      await _service.leaveRoomSeat(_roomId).catchError((_) {});
      await _service.leaveRoom(_roomId);
      await RoomBackgroundBridge.stop();
      if (RoomSessionController.instance.engine == _engine ||
          RoomSessionController.instance.room?['id'] == _roomId) {
        await RoomSessionController.instance.close();
      }
      return true;
    }
    if (result == false) _minimizeRoom();
    return false;
  }

  Future<void> _showRoomInfo() async {
    final image = widget.room['image_url'] as String?;
    final title = widget.room['name'] as String? ?? 'الغرفة';
    final owner = widget.room['owner_id'] == _service.uid;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: image == null
                    ? Container(
                        width: 92,
                        height: 92,
                        color: Colors.white12,
                        child: const Icon(
                          Icons.meeting_room,
                          color: Colors.white,
                          size: 40,
                        ),
                      )
                    : Image.network(
                        image,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              Text(
                'ID: ${widget.room['room_id'] ?? ''}',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _service.toggleRoomFollow(_roomId, _followed);
                        if (!mounted) return;
                        setState(() => _followed = !_followed);
                        Navigator.pop(context);
                      },
                      icon: Icon(_followed ? Icons.check : Icons.add),
                      label: Text(_followed ? 'متابَع' : 'متابعة الغرفة'),
                    ),
                  ),
                  if (owner) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showOwnerSettings();
                        },
                        icon: const Icon(Icons.settings),
                        label: const Text('إعدادات'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOwnerSettings() async {
    final latest = await _service.myOwnedRoom();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RoomSettingsPage(room: latest ?? widget.room, service: _service),
      ),
    );
  }

  Future<void> _showUserCard(
    Map<String, dynamic> profile, {
    bool selfSeat = false,
  }) async {
    if (profile.isEmpty) return;
    final userId = profile['id'] as String?;
    if (userId == null) return;
    final isOwner = widget.room['owner_id'] == _service.uid;
    final canModerate = isOwner && userId != _service.uid;
    var following = await _service.isFollowing(userId);
    final targetModerator = canModerate
        ? await _service.isUserRoomModerator(_roomId, userId)
        : false;
    final countryFlag = await _service.countryFlag(
      profile['country'] as String?,
    );
    final modules = await _service.accountModulesForUser(userId);
    final familyBadge = await _service.familyBadgeForUser(userId);
    final moderation = canModerate
        ? await _service.roomModerationStatus(_roomId, userId)
        : const <String, dynamic>{};
    final voiceMuted = moderation['mute_voice'] == true;
    final chatMuted = moderation['mute_chat'] == true;
    final banned = moderation['banned'] == true;
    final vip =
        (modules['vip_level'] as num?)?.toInt() ??
        (profile['vip_level'] as num?)?.toInt() ??
        0;
    final followers = profile['followers_count'] ?? profile['followers'] ?? 0;
    final followingCount =
        profile['following_count'] ?? profile['following'] ?? 0;
    final visitors = profile['visitors_count'] ?? profile['visitors'] ?? 0;
    final gender =
        (profile['gender']?.toString().toLowerCase() == 'male' ||
            profile['gender']?.toString() == 'ذكر')
        ? '♂'
        : '♀';
    final username = profile['username'] as String? ?? 'مستخدم SAKI';

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (dialogContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> toggleFollow() async {
            await _service.toggleFollow(userId, following);
            if (sheetContext.mounted)
              setSheetState(() => following = !following);
            if (mounted)
              _messageSnack(
                following ? 'تمت متابعة المستخدم.' : 'تم إلغاء المتابعة.',
              );
          }

          void openMainProfile() {
            Navigator.pop(dialogContext);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfilePage(userId: userId),
              ),
            );
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .28,
                  width: double.infinity,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(dialogContext),
                    child: const SizedBox.expand(),
                  ),
                ),
                _RoomMiniProfileSheet(
                  username: username,
                  profile: profile,
                  countryFlag: countryFlag,
                  gender: gender,
                  vip: vip,
                  familyBadge: familyBadge,
                  followers: followers,
                  following: followingCount,
                  isFollowing: following,
                  visitors: visitors,
                  modules: modules,
                  selfSeat: selfSeat,
                  canModerate: canModerate,
                  targetModerator: targetModerator,
                  voiceMuted: voiceMuted,
                  chatMuted: chatMuted,
                  banned: banned,
                  onClose: () => Navigator.pop(dialogContext),
                  onOpenProfile: openMainProfile,
                  onFollow: toggleFollow,
                  onGift: () {
                    Navigator.pop(dialogContext);
                    _showGiftPanel();
                  },
                  onMention: () {
                    Navigator.pop(dialogContext);
                    _message.text = '@$username ';
                    _message.selection = TextSelection.collapsed(
                      offset: _message.text.length,
                    );
                    if (mounted) {
                      setState(() => _isComposing = true);
                      _messageFocus.requestFocus();
                    }
                  },
                  onLeaveSeat: () async {
                    final left = await _confirmLeaveSeat();
                    if (!left || !mounted) return;
                    await _leaveOwnSeat();
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onModerator: () async {
                    if (targetModerator) {
                      await _service.removeRoomModerator(_roomId, userId);
                    } else {
                      await _service.addRoomModerator(_roomId, userId);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onVoiceMute: () async {
                    if (voiceMuted) {
                      await _service.roomUnmute(_roomId, userId, 'voice');
                    } else {
                      await _service.roomMute(
                        _roomId,
                        userId,
                        null,
                        kind: 'voice',
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onChatMute: () async {
                    if (chatMuted) {
                      await _service.roomUnmute(_roomId, userId, 'chat');
                    } else {
                      await _service.roomMute(
                        _roomId,
                        userId,
                        null,
                        kind: 'chat',
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onBan: () async {
                    if (banned) {
                      await _service.removeRoomBan(_roomId, userId);
                    } else {
                      await _service.roomBan(
                        _roomId,
                        userId,
                        const Duration(minutes: 1),
                      );
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onInvite: () async {
                    await _service.inviteToRoomSeat(_roomId, userId);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onBlock: () async {
                    final duration = await _banDuration();
                    if (duration != null)
                      await _service.roomBan(_roomId, userId, duration);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Duration?> _banDuration() => showModalBottomSheet<Duration?>(
    context: context,
    backgroundColor: const Color(0xFF24131A),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in const [
            ('دقيقة', Duration(minutes: 1)),
            ('ساعة', Duration(hours: 1)),
            ('يوم', Duration(days: 1)),
            ('7 أيام', Duration(days: 7)),
            ('دائم', Duration(days: 36500)),
          ])
            ListTile(
              title: Text(item.$1, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, item.$2),
            ),
        ],
      ),
    ),
  );

  void _activateSeatEmoji(String userId, Map<String, dynamic> emoji) {
    _roomEmojiTimers[userId]?.cancel();
    if (mounted) {
      setState(() => _activeSeatEmojis[userId] = emoji);
    }
    _roomEmojiTimers[userId] = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _activeSeatEmojis.remove(userId));
      }
    });
  }

  Future<void> _showEmojiPanel() async {
    final seats = await _service.roomSeats(_roomId);
    if (!mounted) return;
    final canSpeak = seats.any((seat) => seat['user_id'] == _service.uid);
    if (!canSpeak) {
      _messageSnack('اصعد إلى مقعد لاستخدام الإيموجي.');
      return;
    }
    if (_roomEmojis.isEmpty) {
      _messageSnack('لا توجد إيموجيات غرفة متاحة حالياً.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .5),
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white54,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'إيموجي المقعد',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _roomEmojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 10,
                  childAspectRatio: .82,
                ),
                itemBuilder: (_, index) {
                  final emoji = _roomEmojis[index];
                  return GestureDetector(
                    onTap: () {
                      final userId = _service.uid;
                      // Activate locally first so the sender sees the GIF immediately;
                      // the Realtime event then synchronizes the same seat for everyone else.
                      _activateSeatEmoji(userId, emoji);
                      Navigator.pop(context);
                      _service.sendRoomEmoji(_roomId, emoji['id'] as String);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.network(
                              emoji['gif_url'] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            emoji['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _messageSnack(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  bool get _canOpenMusic => _isOnSeat;

  bool get _isRoomOwner => widget.room['owner_id']?.toString() == _service.uid;

  bool get _canControlMusic =>
      _isRoomOwner || _activeMusic?['owner_id']?.toString() == _service.uid;

  Future<void> _loadRoomMusic() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.roomMusic(_roomId),
        _service.activeRoomMusic(_roomId),
      ]);
      if (!mounted) return;
      setState(() {
        _roomMusic = List<Map<String, dynamic>>.from(results[0] as List);
        _activeMusic = results[1] as Map<String, dynamic>?;
        _musicPlaying = _activeMusic?['is_playing'] == true;
        _musicOwnerId = _activeMusic?['owner_id']?.toString();
        _musicVolume = ((_activeMusic?['volume'] as num?) ?? 1)
            .toDouble()
            .clamp(0.0, 1.0);
      });
      final nested = _activeMusic?['room_music'];
      if (_musicPlaying && _isOnSeat && nested is Map) {
        final duration = await _musicPlayer.setUrl(
          nested['audio_url'] as String,
        );
        _musicDurationSeconds = duration?.inMilliseconds.toDouble() == null
            ? 0
            : duration!.inMilliseconds / 1000;
        await _musicPlayer.setVolume(_musicVolume);
        await _musicPlayer.play();
      }
    } catch (_) {}
  }

  Future<void> _syncMusicSeatAccess(bool seated) async {
    if (seated || !_musicPlaying) return;
    await _stopRoomMusic(broadcastOnly: true);
  }

  Future<void> _handleMusicEvent(Map<String, dynamic> event) async {
    if (!_isOnSeat) {
      await _syncMusicSeatAccess(false);
      return;
    }
    final action = event['action']?.toString();
    if (action == 'volume') {
      final value = ((event['volume'] as num?) ?? 1).toDouble().clamp(0.0, 1.0);
      await _musicPlayer.setVolume(value);
      if (mounted) setState(() => _musicVolume = value);
      return;
    }
    if (action == 'seek') {
      final seconds = ((event['position_seconds'] as num?) ?? 0).toDouble();
      await _musicPlayer.seek(Duration(milliseconds: (seconds * 1000).round()));
      return;
    }
    if (action == 'stop') {
      await _musicPlayer.stop();
      if (mounted) setState(() => _musicPlaying = false);
      return;
    }
    final music = Map<String, dynamic>.from(event['music'] ?? const {});
    final url = music['audio_url']?.toString();
    if (url == null || url.isEmpty) return;
    if (_activeMusic?['music_id']?.toString() != music['id']?.toString()) {
      final duration = await _musicPlayer.setUrl(url);
      _musicDurationSeconds = duration?.inMilliseconds.toDouble() == null
          ? 0
          : duration!.inMilliseconds / 1000;
    }
    if (event['position_seconds'] is num) {
      await _musicPlayer.seek(
        Duration(
          milliseconds: ((event['position_seconds'] as num) * 1000).round(),
        ),
      );
    }
    if (action == 'pause') {
      await _musicPlayer.pause();
    } else {
      await _musicPlayer.play();
    }
    if (mounted) {
      setState(() {
        _activeMusic = {'music_id': music['id'], 'room_music': music};
        _musicOwnerId = music['owner_id']?.toString();
        _musicPlaying = action != 'pause';
      });
    }
  }

  Future<void> _broadcastMusic(
    String action,
    Map<String, dynamic> music,
  ) async {
    if (action == 'pause' && !_canControlMusic) {
      _messageSnack('صاحب الأغنية فقط يستطيع إيقافها.');
      return;
    }
    if (action == 'play' &&
        _activeMusic != null &&
        _activeMusic?['owner_id']?.toString() != _service.uid &&
        !_isRoomOwner) {
      _messageSnack('صاحب الأغنية الحالية يتحكم بها.');
      return;
    }
    final changingTrack =
        _activeMusic?['music_id']?.toString() != music['id']?.toString();
    final position = changingTrack
        ? 0.0
        : _musicPlayer.position.inMilliseconds / 1000;
    final event = {
      'action': action,
      'music': music,
      'position_seconds': position,
      'volume': _musicVolume,
    };
    await _service.setActiveRoomMusic(
      _roomId,
      musicId: music['id'] as String?,
      ownerId: music['owner_id']?.toString(),
      isPlaying: action == 'play',
      positionSeconds: position,
      volume: _musicVolume,
    );
    await _roomChatChannel.sendBroadcastMessage(event: 'music', payload: event);
    await _handleMusicEvent(event);
  }

  Future<void> _broadcastMusicVolume(double value) async {
    if (!_canControlMusic) {
      _messageSnack('صاحب الأغنية فقط يستطيع تغيير الصوت.');
      return;
    }
    final volume = value.clamp(0.0, 1.0);
    setState(() => _musicVolume = volume);
    await _musicPlayer.setVolume(volume);
    try {
      await _service.setActiveRoomMusic(
        _roomId,
        musicId: _activeMusic?['music_id']?.toString(),
        ownerId: _musicOwnerId,
        isPlaying: _musicPlaying,
        positionSeconds: _musicPlayer.position.inMilliseconds / 1000,
        volume: volume,
      );
    } catch (_) {}
    await _roomChatChannel.sendBroadcastMessage(
      event: 'music',
      payload: {'action': 'volume', 'volume': volume},
    );
  }

  Future<void> _broadcastMusicSeek(double seconds) async {
    if (!_canControlMusic) {
      _messageSnack('صاحب الأغنية فقط يستطيع تحريك شريط التقدم.');
      return;
    }
    await _musicPlayer.seek(Duration(milliseconds: (seconds * 1000).round()));
    await _roomChatChannel.sendBroadcastMessage(
      event: 'music',
      payload: {'action': 'seek', 'position_seconds': seconds},
    );
  }

  Future<void> _stopRoomMusic({bool broadcastOnly = false}) async {
    if (!broadcastOnly && !_canControlMusic) {
      _messageSnack('صاحب الأغنية فقط يستطيع إيقافها.');
      return;
    }
    if (!broadcastOnly) {
      try {
        await _service.setActiveRoomMusic(
          _roomId,
          musicId: _activeMusic?['music_id']?.toString(),
          ownerId: _musicOwnerId,
          isPlaying: false,
          volume: _musicVolume,
        );
      } catch (_) {}
    }
    await _roomChatChannel.sendBroadcastMessage(
      event: 'music',
      payload: {'action': 'stop'},
    );
    await _musicPlayer.stop();
    if (mounted) {
      setState(() {
        _musicPlaying = false;
        _musicOwnerId = null;
      });
    }
  }

  Future<void> _uploadRoomMusic() async {
    final permissions = await [Permission.audio, Permission.storage].request();
    if (!permissions.values.any((status) => status.isGranted)) {
      _messageSnack('نحتاج إذن الوصول إلى ملفات الصوت لاختيار الموسيقى.');
      return;
    }
    final result = await FilePicker.pickFiles(type: FileType.audio);
    for (final file in result) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      try {
        final uploaded = await _service.uploadRoomMusic(
          _roomId,
          file.name,
          bytes,
          file.extension ?? 'mp3',
          'audio/${file.extension ?? 'mpeg'}',
        );
        if (mounted) setState(() => _roomMusic.insert(0, uploaded));
      } catch (error) {
        if (mounted) _messageSnack('تعذر رفع ${file.name}: $error');
      }
    }
  }

  Future<void> _showMusicSheet() async {
    if (!_canOpenMusic) {
      _messageSnack('يجب الجلوس على مقعد لفتح موسيقى الغرفة.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomMusicSheet(
        music: _roomMusic,
        activeMusic: _activeMusic,
        playing: _musicPlaying,
        volume: _musicVolume,
        onUpload: _uploadRoomMusic,
        onPlay: (music) => _broadcastMusic('play', music),
        onPause: (music) => _broadcastMusic('pause', music),
        onStop: _stopRoomMusic,
        canControl: _canControlMusic,
        onVolume: _broadcastMusicVolume,
        onSeek: _broadcastMusicSeek,
        positionSeconds: _musicPlayer.position.inMilliseconds / 1000,
        durationSeconds: _musicDurationSeconds,
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مسح الدردشة؟'),
        content: const Text('سيتم حذف رسائل الغرفة للجميع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await _clearRoomChatForEveryone();
        if (mounted) _messageSnack('تم مسح دردشة الغرفة للجميع.');
      } catch (_) {
        if (mounted) _messageSnack('لا تملك صلاحية مسح دردشة الغرفة.');
      }
    }
  }

  Future<void> _showRoomTools() async {
    final owner = widget.room['owner_id'] == _service.uid;
    final moderator = owner || await _service.isRoomModerator(_roomId);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (_isOnSeat)
                _toolButton(Icons.music_note, 'موسيقى', () {
                  Navigator.pop(context);
                  _showMusicSheet();
                }),
              if (moderator)
                _toolButton(Icons.delete_sweep, 'مسح الدردشة', () {
                  Navigator.pop(context);
                  _confirmClearChat();
                }),
              _toolButton(
                Icons.card_giftcard,
                'هدايا',
                () => Navigator.pop(context),
              ),
              _toolButton(Icons.card_giftcard_rounded, 'حقيبة حظ', () {
                Navigator.pop(context);
                LuckBagComposer.show(context, _roomId, (bag) {
                  if (mounted) setState(() => _newLuckBag = bag);
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white12,
              child: Icon(icon, color: Colors.amberAccent),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      );

  Future<void> _claimLuckBag(String bagId) async {
    try {
      final result = await _service.claimRoomLuckBag(bagId);
      if (!mounted) return;
      _messageSnack('استلمت ${result['amount_gold'] ?? 0} عملة ذهبية بنجاح.');
    } catch (e) {
      if (mounted) _messageSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _confirmLeaveSeat() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x6606B6D4),
                blurRadius: 22,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFF06B6D4)],
                  ),
                ),
                child: const Icon(
                  Icons.mic_off_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'النزول من المقعد؟',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم إيقاف المايك وإخلاء مقعدك للآخرين داخل الغرفة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.45),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF06B6D4),
                        side: const BorderSide(color: Color(0xFF06B6D4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('نعم، انزل'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _leaveOwnSeat() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.leaveRoomSeat(_roomId);
      await _setSeatAudio(false);
      await _service.sendRoomMessage(_roomId, 'نزل من المقعد', type: 'seat');
      if (mounted) _messageSnack('تم النزول من المقعد بنجاح.');
    } catch (error) {
      if (mounted) _messageSnack('تعذر النزول من المقعد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _seatAction(int seatNo, Map<String, dynamic>? occupied) async {
    if (_busy) return;
    if (occupied != null && occupied['user_id'] != _service.uid) return;
    final take = occupied == null;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: Icon(
                take ? Icons.mic : Icons.mic_off,
                color: Colors.amberAccent,
              ),
              title: Text(
                take ? 'خذ مقعد $seatNo' : 'نزول من المقعد',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      if (!take) {
        await _service.leaveRoomSeat(_roomId);
        await _setSeatAudio(false);
        await _service.sendRoomMessage(_roomId, 'نزل من المقعد', type: 'seat');
      } else {
        final allowed =
            _micPermission == 'everyone' ||
            (_micPermission == 'followers' && _followed) ||
            (_micPermission == 'moderators' && _isModerator) ||
            (_micPermission == 'owner' &&
                widget.room['owner_id'] == _service.uid);
        if (!allowed) {
          _messageSnack('المالك لا يسمح لك بأخذ المايك حاليًا.');
          return;
        }
        await _service.claimRoomSeat(_roomId, seatNo);
        await _setSeatAudio(true);
        await _service.sendRoomMessage(_roomId, 'صعد إلى المقعد', type: 'seat');
      }
    } catch (error) {
      if (mounted) _messageSnack('تعذر استخدام المقعد: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOnline() async {
    final rows = await _service.roomMembers(_roomId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'المتصلون الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            ...rows.map((row) {
              final profile = Map<String, dynamic>.from(row);
              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  _showUserCard(profile);
                },
                leading: SakiAvatar(
                  url: profile['avatar_url'] as String?,
                  label: profile['username'] as String?,
                  profile: profile,
                ),
                title: Text(
                  profile['username'] as String? ?? 'عضو',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  'ثروة LV${profile['wealth_level'] ?? 0}  •  سحر LV${profile['charm_level'] ?? 0}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
                trailing: const Icon(
                  Icons.circle,
                  color: Colors.green,
                  size: 10,
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    final preservedSession =
        RoomSessionController.instance.isSameRoom(_roomId) &&
        RoomSessionController.instance.engine == _engine;
    _message.dispose();
    _messageFocus.dispose();
    _comboTimer?.cancel();
    _entranceTimer?.cancel();
    _roomMembersSubscription?.cancel();
    _roomEmojiSubscription?.cancel();
    _luckBagSubscription?.cancel();
    for (final timer in _roomEmojiTimers.values) {
      timer.cancel();
    }
    _roomSettingsSubscription?.cancel();
    _presenceTimer?.cancel();
    _seatTaskTimer?.cancel();
    if (_musicPlaying && !preservedSession) {
      _roomChatChannel.sendBroadcastMessage(
        event: 'music',
        payload: {'action': 'stop', 'reason': 'room_exit'},
      );
      _musicPlayer.stop();
    }
    _service.client.removeChannel(_roomChatChannel);
    if (!preservedSession) {
      _musicPlayer.dispose();
      if (_joined) _service.leaveRoom(_roomId);
      _engine?.leaveChannel();
      _engine?.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.room['image_url'] as String?;
    final title = widget.room['name'] as String? ?? 'غرفة SAKI';
    final roomNumber = widget.room['room_id'] as String? ?? '';
    final backgroundUrl = _liveBackgroundUrl;
    final backgroundColors = backgroundUrl == 'free://ocean'
        ? const [Color(0xFF0891B2), Color(0xFF1D4ED8), Color(0xFF172554)]
        : backgroundUrl == 'free://aurora'
        ? const [Color(0xFF312E81), Color(0xFF7E22CE), Color(0xFFBE185D)]
        : backgroundUrl == 'free://sunset'
        ? const [Color(0xFFF97316), Color(0xFFDB2777), Color(0xFF4A0E17)]
        : const [Color(0xFF4A0E17), Color(0xFF8A1C30), Color(0xFF2A080C)];
    final navigator = Navigator.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF4A0E17),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: backgroundColors,
                ),
                image: backgroundUrl == null
                    ? const DecorationImage(
                        image: AssetImage(
                          'assets/trace_home/images/audio_room_background.png',
                        ),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black54,
                          BlendMode.darken,
                        ),
                      )
                    : backgroundUrl.startsWith('free://')
                    ? null
                    : DecorationImage(
                        image: NetworkImage(backgroundUrl),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: .38),
                          BlendMode.darken,
                        ),
                      ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _showRoomInfo,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: image == null
                                  ? Container(
                                      width: 42,
                                      height: 42,
                                      color: Colors.white12,
                                      child: const Icon(
                                        Icons.meeting_room,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Image.network(
                                      image,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showRoomInfo,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'ID: $roomNumber',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    _isOnSeat
                                        ? (_micMuted
                                              ? 'على مقعد • المايك مكتوم'
                                              : 'يتحدث الآن')
                                        : 'مستمع • ${_remoteUsers.length} متحدث',
                                    style: TextStyle(
                                      color: _isOnSeat && !_micMuted
                                          ? Colors.greenAccent
                                          : Colors.white54,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              if (await _confirmExit() && mounted) {
                                navigator.pop();
                              }
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
                      child: SizedBox(
                        height: 44,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 0,
                              child: RoomConnectedStrip(
                                members: _roomMembers,
                                total: _roomMembers.length,
                                onTap: _showOnline,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GiftGoldBadge(
                                total: _roomGoldTotal,
                                onTap: () => showRoomGiftRanking(
                                  context,
                                  _service,
                                  _roomId,
                                  (profile) => _showUserCard(profile),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _seatStream,
                      builder: (_, snap) {
                        final seatRows = snap.data ?? <Map<String, dynamic>>[];
                        final seatUserIds = seatRows
                            .map((row) => row['user_id']?.toString())
                            .whereType<String>()
                            .toSet();
                        final someoneLeft =
                            _previousSeatUserIds.isNotEmpty &&
                            seatUserIds.length < _previousSeatUserIds.length;
                        if (someoneLeft && _musicPlaying && !_seatStopPending) {
                          _seatStopPending = true;
                          scheduleMicrotask(() async {
                            await _stopRoomMusic(broadcastOnly: true);
                            _seatStopPending = false;
                          });
                        }
                        _previousSeatUserIds = seatUserIds;
                        final ownSeat = seatRows.any(
                          (row) => row['user_id'] == _service.uid,
                        );
                        if (ownSeat != _isOnSeat) {
                          scheduleMicrotask(() async {
                            if (!mounted) return;
                            _isOnSeat = ownSeat;
                            if (ownSeat && _activeMusic != null) {
                              await _loadRoomMusic();
                            }
                            await _syncMusicSeatAccess(ownSeat);
                            if (!ownSeat) {
                              RoomSessionController.instance.updateVoiceState(
                                isOnSeat: false,
                                micMuted: true,
                              );
                            }
                          });
                        }
                        final seats = {
                          for (final row in seatRows)
                            row['seat_no'] as int: row,
                        };
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            itemCount: _liveSeatCount,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: .8,
                                ),
                            itemBuilder: (_, index) {
                              final seatNo = index + 1;
                              final row = seats[seatNo];
                              final profile = Map<String, dynamic>.from(
                                row?['profiles'] ?? const {},
                              );
                              final occupied = row != null;
                              final isOwnSeat = row?['user_id'] == _service.uid;
                              return GestureDetector(
                                onTap: () => isOwnSeat
                                    ? _showUserCard(profile, selfSeat: true)
                                    : _seatAction(seatNo, row),
                                child: Column(
                                  children: [
                                    Container(
                                      key: occupied
                                          ? _seatKeys.putIfAbsent(
                                              row['user_id'].toString(),
                                              GlobalKey.new,
                                            )
                                          : null,
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: occupied
                                            ? const Color(0xFFEAB308)
                                            : Colors.white10,
                                        border: Border.all(
                                          color: occupied
                                              ? Colors.yellowAccent
                                              : Colors.white24,
                                          width: 1.5,
                                        ),
                                        boxShadow: occupied
                                            ? const [
                                                BoxShadow(
                                                  color: Colors.amber,
                                                  blurRadius: 10,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: occupied
                                          ? Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                GestureDetector(
                                                  onTap: () => _showUserCard(
                                                    profile,
                                                    selfSeat: isOwnSeat,
                                                  ),
                                                  child: SakiAvatar(
                                                    url:
                                                        profile['avatar_url']
                                                            as String?,
                                                    label:
                                                        profile['username']
                                                            as String?,
                                                    radius: 25,
                                                  ),
                                                ),
                                                if (row['is_speaking'] == true)
                                                  Positioned.fill(
                                                    child: IgnorePointer(
                                                      child: Center(
                                                        child: _VipVoiceWave(
                                                          profile: profile,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (_activeSeatEmojis[row['user_id']
                                                        ?.toString()] !=
                                                    null)
                                                  Positioned.fill(
                                                    child: IgnorePointer(
                                                      child: Image.network(
                                                        _activeSeatEmojis[row['user_id']
                                                                ?.toString()]!['gif_url']
                                                            as String,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            )
                                          : const Icon(
                                              Icons.mic_none_rounded,
                                              color: Colors.white70,
                                            ),
                                    ),
                                    const SizedBox(height: 4),
                                    occupied
                                        ? Text(
                                            profile['username'] as String? ??
                                                'عضو',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          )
                                        : Text(
                                            '$seatNo',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _messageStream,
                        builder: (_, snap) {
                          final serverMessages = [...(snap.data ?? [])];
                          final messages =
                              [
                                  ...serverMessages,
                                  ..._optimisticMessages.where(
                                    (local) => !serverMessages.any(
                                      (remote) =>
                                          remote['sender_id'] ==
                                              local['sender_id'] &&
                                          remote['message_type'] ==
                                              local['message_type'] &&
                                          remote['body'] == local['body'] &&
                                          (DateTime.tryParse(
                                                        remote['created_at']
                                                                ?.toString() ??
                                                            '',
                                                      ) ??
                                                      DateTime.fromMillisecondsSinceEpoch(
                                                        0,
                                                      ))
                                                  .difference(
                                                    DateTime.tryParse(
                                                          local['created_at']
                                                                  ?.toString() ??
                                                              '',
                                                        ) ??
                                                        DateTime.fromMillisecondsSinceEpoch(
                                                          0,
                                                        ),
                                                  )
                                                  .inSeconds
                                                  .abs() <
                                              10,
                                    ),
                                  ),
                                ]
                                ..removeWhere((message) {
                                  final clearedAt = _chatClearedAt;
                                  if (clearedAt == null) return false;
                                  final createdAt = DateTime.tryParse(
                                    message['created_at']?.toString() ?? '',
                                  );
                                  return createdAt != null &&
                                      !createdAt.toUtc().isAfter(clearedAt);
                                })
                                ..sort(
                                  (a, b) =>
                                      (DateTime.tryParse(
                                                a['created_at']?.toString() ??
                                                    '',
                                              ) ??
                                              DateTime.fromMillisecondsSinceEpoch(
                                                0,
                                              ))
                                          .compareTo(
                                            DateTime.tryParse(
                                                  b['created_at']?.toString() ??
                                                      '',
                                                ) ??
                                                DateTime.fromMillisecondsSinceEpoch(
                                                  0,
                                                ),
                                          ),
                                );
                          final latestMessage = messages.isEmpty
                              ? const <String, dynamic>{}
                              : messages.last;
                          final latestGift =
                              latestMessage['message_type'] == 'gift'
                              ? latestMessage
                              : const <String, dynamic>{};
                          if (latestGift.isNotEmpty &&
                              latestGift['id'] != _shownGiftMessageId) {
                            final gift = Map<String, dynamic>.from(latestGift);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted ||
                                  gift['id'] == _shownGiftMessageId) {
                                return;
                              }
                              setState(() {
                                _shownGiftMessageId = gift['id']?.toString();
                                _activeGiftMessage = gift;
                              });
                            });
                          }
                          return Stack(
                            children: [
                              ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.all(14),
                                itemCount: messages.length + 1,
                                itemBuilder: (_, i) {
                                  if (i == messages.length) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Text(
                                        'مرحباً بكم في ساكي، نرجو احترام الآخرين',
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  final msg = messages[messages.length - 1 - i];
                                  final senderId =
                                      msg['sender_id'] as String? ?? '';
                                  final messageType =
                                      msg['message_type'] as String? ?? 'chat';
                                  return FutureBuilder<Map<String, dynamic>?>(
                                    future: _service.userProfile(senderId),
                                    builder: (_, profileSnap) {
                                      final profile =
                                          profileSnap.data ??
                                          const <String, dynamic>{};
                                      final username =
                                          profile['username'] as String? ??
                                          'عضو';
                                      final body = msg['body'] as String? ?? '';
                                      final payload = Map<String, dynamic>.from(
                                        msg['payload'] ?? const {},
                                      );
                                      final displayBody = messageType == 'gift'
                                          ? 'أرسل هدية ${payload['name'] ?? 'هدية'}'
                                          : body;
                                      final giftThumbnail =
                                          payload['thumbnail_url'] as String? ??
                                          (payload['icon'] as String?);
                                      final isSpecial =
                                          messageType == 'join' ||
                                          messageType == 'seat';
                                      final isEmoji = messageType == 'emoji';
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: isSpecial
                                              ? Border.all(
                                                  color: Colors.amber
                                                      .withValues(alpha: .35),
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: () =>
                                                  _showUserCard(profile),
                                              child: SakiAvatar(
                                                url:
                                                    profile['avatar_url']
                                                        as String?,
                                                label: username,
                                                radius: 17,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  VipUsername(
                                                    profile: profile,
                                                    style: const TextStyle(
                                                      color: Colors.amberAccent,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'ثروة LV${profile['wealth_level'] ?? 0}  •  سحر LV${profile['charm_level'] ?? 0}',
                                                    style: const TextStyle(
                                                      color: Colors.white54,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  if (messageType == 'gift' &&
                                                      giftThumbnail != null &&
                                                      giftThumbnail.startsWith(
                                                        'http',
                                                      ))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 5,
                                                          ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child: Image.network(
                                                          giftThumbnail,
                                                          width: 58,
                                                          height: 58,
                                                          fit: BoxFit.contain,
                                                        ),
                                                      ),
                                                    ),
                                                  messageType == 'dice'
                                                      ? _DiceFace(
                                                          value:
                                                              (payload['value']
                                                                      as num?)
                                                                  ?.toInt() ??
                                                              1,
                                                        )
                                                      : Text(
                                                          displayBody,
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: isEmoji
                                                                ? 28
                                                                : 13,
                                                          ),
                                                        ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Row(
                        children: [
                          if (_isComposing) ...[
                            Expanded(
                              child: TextField(
                                controller: _message,
                                focusNode: _messageFocus,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'كتابة رسالة...',
                                  hintStyle: const TextStyle(
                                    color: Colors.white54,
                                  ),
                                  filled: true,
                                  fillColor: Colors.black38,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onSubmitted: (_) => _send(),
                              ),
                            ),
                            IconButton(
                              onPressed: _send,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () =>
                                    setState(() => _isComposing = true),
                                child: Container(
                                  height: 48,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Text(
                                    'كتابة رسالة...',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _showEmojiPanel,
                              icon: const Icon(
                                Icons.emoji_emotions_outlined,
                                color: Colors.amberAccent,
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleListenMute,
                              icon: Icon(
                                _listenMuted
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: _listenMuted
                                    ? Colors.redAccent
                                    : Colors.white70,
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleRoomMic,
                              icon: Icon(
                                _micMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                color: _isOnSeat
                                    ? Colors.amberAccent
                                    : Colors.white38,
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              height: _comboSeconds > 0 ? 98 : 56,
                              child: Stack(
                                alignment: AlignmentDirectional.bottomCenter,
                                children: [
                                  GestureDetector(
                                    onTap: _showGiftPanel,
                                    child: Container(
                                      width: 54,
                                      height: 54,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.white12,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/saki_gift_box_icon.png',
                                        width: 31,
                                        height: 31,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                  if (_comboSeconds > 0)
                                    Positioned(
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: _sendComboAgain,
                                        child: Container(
                                          width: 56,
                                          height: 56,
                                          decoration: const BoxDecoration(
                                            color: Colors.orangeAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$_comboSeconds',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 19,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _showRoomTools,
                              icon: const Icon(
                                Icons.grid_view_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_entranceProduct != null)
              StoreEntranceOverlay(
                product: _entranceProduct!,
                profile: _entranceProfile ?? const <String, dynamic>{},
                onDone: () {
                  if (mounted) {
                    setState(() {
                      _entranceProduct = null;
                      _entranceProfile = null;
                    });
                  }
                },
              )
            else if (_entranceProfile != null)
              Positioned(
                top: 108,
                left: 18,
                right: 18,
                child: RoomEntranceBanner(profile: _entranceProfile!),
              ),
            if (_luckBags.isNotEmpty)
              LuckBagCard(bag: _luckBags.first, onClaim: _claimLuckBag),
            if (_newLuckBag != null)
              LuckBagFlyBanner(
                bag: _newLuckBag!,
                onGo: () => setState(() => _newLuckBag = null),
              ),
            if (_activeGiftMessage != null)
              Positioned.fill(
                child: GiftFullScreenOverlay(
                  key: ValueKey(_activeGiftMessage!['id']),
                  message: _activeGiftMessage!,
                  seatKey: _seatKeyForGift(_activeGiftMessage!),
                  onClose: () {
                    if (mounted) setState(() => _activeGiftMessage = null);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GiftFullScreenOverlay extends StatefulWidget {
  const GiftFullScreenOverlay({
    super.key,
    required this.message,
    this.seatKey,
    required this.onClose,
  });
  final Map<String, dynamic> message;
  final GlobalKey? seatKey;
  final VoidCallback onClose;

  @override
  State<GiftFullScreenOverlay> createState() => _GiftFullScreenOverlayState();
}

class _GiftFullScreenOverlayState extends State<GiftFullScreenOverlay>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final SVGAAnimationController _svga;
  bool _visible = true;
  bool _flyingToSeat = false;
  bool _flightVisible = true;
  bool _bannerEntered = false;
  bool _bannerLeaving = false;
  String? _recipientAvatar;
  Timer? _flightTimer;
  Timer? _flightHideTimer;
  Timer? _bannerTimer;

  Map<String, dynamic> get _payload =>
      Map<String, dynamic>.from(widget.message['payload'] ?? const {});

  bool get _compactGift {
    final type = (_payload['media_type'] as String? ?? '').toLowerCase();
    return type != 'svga' && type != 'mp4';
  }

  @override
  void initState() {
    super.initState();
    _svga = SVGAAnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _hide();
      });
    final recipientId = _payload['recipient_id'] as String?;
    if (recipientId != null) {
      SakiService.instance.userProfile(recipientId).then((profile) {
        if (mounted) {
          setState(() => _recipientAvatar = profile?['avatar_url'] as String?);
        }
      });
    }
    _flightTimer = Timer(const Duration(milliseconds: 2100), () {
      if (mounted) setState(() => _flyingToSeat = true);
    });
    _flightHideTimer = Timer(const Duration(milliseconds: 3300), () {
      if (mounted) setState(() => _flightVisible = false);
    });
    _bannerTimer = Timer(const Duration(milliseconds: 3900), () {
      if (mounted) setState(() => _bannerLeaving = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _bannerEntered = true);
    });
    if (_compactGift) {
      Future<void>.delayed(const Duration(milliseconds: 3600), _hide);
      return;
    }
    final url = _payload['media_url'] as String?;
    final type = (_payload['media_type'] as String? ?? '').toLowerCase();
    if (url != null && url.isNotEmpty && type == 'svga') {
      SVGAParser.shared
          .decodeFromURL(url)
          .then((movie) {
            if (!mounted) return;
            _svga.videoItem = movie;
            _svga.forward(from: 0);
            setState(() {});
          })
          .catchError((_) {
            if (mounted) setState(() {});
          });
    } else if (url != null && url.isNotEmpty && type == 'mp4') {
      final video = VideoPlayerController.networkUrl(Uri.parse(url));
      _video = video;
      video.initialize().then((_) {
        if (mounted) {
          video.play();
          setState(() {});
        }
      });
      video.addListener(() {
        if (!video.value.isInitialized || video.value.isPlaying) return;
        if (video.value.position >= video.value.duration) _hide();
      });
    } else if (url != null && url.isNotEmpty && type == 'gif') {
      Future<void>.delayed(const Duration(seconds: 5), _hide);
    } else {
      Future<void>.delayed(const Duration(milliseconds: 900), _hide);
    }
  }

  void _hide() {
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    widget.onClose();
  }

  @override
  void dispose() {
    _flightTimer?.cancel();
    _flightHideTimer?.cancel();
    _bannerTimer?.cancel();
    _video?.dispose();
    _svga.dispose();
    super.dispose();
  }

  Widget _buildGiftFlight(BuildContext context) {
    final payload = _payload;
    final thumbnail = payload['thumbnail_url'] as String?;
    final media = payload['media_url'] as String?;
    final url = thumbnail?.startsWith('http') == true
        ? thumbnail
        : media?.startsWith('http') == true
        ? media
        : null;
    final screen = MediaQuery.sizeOf(context);
    final targetBox =
        widget.seatKey?.currentContext?.findRenderObject() as RenderBox?;
    final target = targetBox == null
        ? Offset(screen.width / 2, screen.height * .58)
        : targetBox.localToGlobal(
            Offset(targetBox.size.width / 2, targetBox.size.height / 2),
          );
    final delta = Offset(
      (target.dx - screen.width / 2) / screen.width,
      (target.dy - screen.height / 2) / screen.height,
    );
    final image = url != null && url.isNotEmpty
        ? Image.network(
            url,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(
              payload['icon'] as String? ?? '🎁',
              style: const TextStyle(fontSize: 48),
            ),
          )
        : Text(
            payload['icon'] as String? ?? '🎁',
            style: const TextStyle(fontSize: 48),
          );
    if (!_flightVisible) return const SizedBox.shrink();
    return IgnorePointer(
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(
          begin: Offset.zero,
          end: _flyingToSeat ? delta : Offset.zero,
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        builder: (_, offset, child) =>
            FractionalTranslation(translation: offset, child: child),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .22, end: _flyingToSeat ? .34 : 1),
          duration: const Duration(milliseconds: 2000),
          curve: Curves.easeOutBack,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                image,
                if (_recipientAvatar != null &&
                    _recipientAvatar!.startsWith('http'))
                  Positioned(
                    right: -10,
                    bottom: -6,
                    child: ClipOval(
                      child: Image.network(
                        _recipientAvatar!,
                        width: 27,
                        height: 27,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final url = _payload['media_url'] as String?;
    final type = (_payload['media_type'] as String? ?? '').toLowerCase();
    final senderId = widget.message['sender_id'] as String?;
    final recipientId = _payload['recipient_id'] as String?;
    return Material(
      color: Colors.transparent,
      child: FutureBuilder<List<Map<String, dynamic>?>>(
        future: Future.wait([
          if (senderId != null) SakiService.instance.userProfile(senderId),
          if (recipientId != null)
            SakiService.instance.userProfile(recipientId),
        ]),
        builder: (_, snapshot) {
          final sender = snapshot.data?.isNotEmpty == true
              ? snapshot.data!.first
              : null;
          final recipient = snapshot.data != null && snapshot.data!.length > 1
              ? snapshot.data![1]
              : null;
          final immersive = type == 'mp4' || type == 'svga';
          final mediaView = _svga.videoItem != null
              ? SVGAImage(_svga, fit: BoxFit.contain)
              : _video != null && _video!.value.isInitialized
              ? FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _video!.value.size.width,
                    height: _video!.value.size.height,
                    child: VideoPlayer(_video!),
                  ),
                )
              : url != null && url.isNotEmpty
              ? Image.network(url, fit: BoxFit.contain)
              : Center(
                  child: Text(
                    _payload['icon'] as String? ?? '🎁',
                    style: const TextStyle(fontSize: 100),
                  ),
                );
          final thumbnail = _payload['thumbnail_url'] as String?;
          final senderAvatar = sender?['avatar_url'] as String?;
          return Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (immersive) Positioned.fill(child: Center(child: mediaView)),
              if (immersive && _payload['flying_banner'] != false)
                Positioned(
                  top: 34,
                  left: 0,
                  right: 0,
                  child: AnimatedSlide(
                    offset: _bannerLeaving
                        ? const Offset(1.35, 0)
                        : _bannerEntered
                        ? Offset.zero
                        : const Offset(-1.35, 0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOutCubic,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(
                          start: 12,
                          end: 12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .86),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.amberAccent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            senderAvatar != null &&
                                    senderAvatar.startsWith('http')
                                ? ClipOval(
                                    child: Image.network(
                                      senderAvatar,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.amberAccent,
                                  ),
                            const SizedBox(width: 5),
                            thumbnail != null && thumbnail.startsWith('http')
                                ? ClipOval(
                                    child: Image.network(
                                      thumbnail,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.card_giftcard,
                                    color: Colors.amberAccent,
                                  ),
                            const SizedBox(width: 5),
                            _recipientAvatar != null &&
                                    _recipientAvatar!.startsWith('http')
                                ? ClipOval(
                                    child: Image.network(
                                      _recipientAvatar!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_pin,
                                    color: Colors.amberAccent,
                                  ),
                            const SizedBox(width: 7),
                            Text(
                              '${sender?['username'] ?? 'مستخدم'} أرسل ${_payload['name'] ?? 'هدية'} إلى ${recipient?['username'] ?? 'مستخدم'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_flightVisible)
                Positioned.fill(child: _buildGiftFlight(context)),
            ],
          );
        },
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
      ),
      child: Center(
        child: Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFF8A1C30),
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class CreateRoomPage extends StatefulWidget {
  const CreateRoomPage({super.key});

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  final _name = TextEditingController();
  final _description = TextEditingController(text: 'مرحبا بكم في غرفتي!');
  final _picker = ImagePicker();
  XFile? _image;
  String _country = 'جاري التحديد...';
  String _type = 'public';
  String _category = 'Cp';
  bool _loading = false;
  String? _error;

  static const _categories = [
    'Cp',
    'شعر وموسيقى',
    'حفلة',
    'سينما',
    'ألعاب',
    'مسابقات',
  ];

  @override
  void initState() {
    super.initState();
    _loadCountry();
  }

  Future<void> _loadCountry() async {
    try {
      final country = await SakiService.instance.myCountry();
      if (mounted) setState(() => _country = country);
    } catch (_) {
      if (mounted) setState(() => _country = 'الأردن');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم الغرفة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final room = await SakiService.instance.createRoom(
        name: _name.text,
        description: _description.text,
        country: _country == 'جاري التحديد...' ? 'الأردن' : _country,
        type: _type,
        image: _image,
      );
      if (mounted) Navigator.of(context).pop(room);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white12),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white60),
    ),
    border: const UnderlineInputBorder(
      borderSide: BorderSide(color: Colors.white12),
    ),
    filled: false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1534880606858-29b0e8a24e8d?q=80&w=1000&auto=format&fit=crop',
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Container(color: const Color.fromRGBO(15, 10, 5, .78)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.sizeOf(context).height - 52,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    _glassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                TextField(
                                  controller: _name,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: _input('الرجاء إدخال اسم الغرفة'),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _description,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  decoration: _input('وصف الغرفة'),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: _pickImage,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 82,
                                height: 82,
                                child: _image == null
                                    ? Container(
                                        color: Colors.white10,
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          color: Colors.white70,
                                          size: 28,
                                        ),
                                      )
                                    : Image.file(
                                        File(_image!.path),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'فئة الغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((item) {
                        final selected = item == _category;
                        return GestureDetector(
                          onTap: () => setState(() => _category = item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFED100)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              item,
                              style: TextStyle(
                                color: selected
                                    ? const Color(0xFFFED100)
                                    : Colors.white70,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    _glassCard(
                      child: Row(
                        children: [
                          const Text(
                            'دولة الغرفة',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '🌍',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  _country,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text(
                          'نوع الغرفة',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const Spacer(),
                        DropdownButton<String>(
                          value: _type,
                          dropdownColor: const Color(0xFF292929),
                          underline: const SizedBox.shrink(),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Text('عامة'),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Text('خاصة'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _type = value ?? 'public'),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 40),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _create,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFED100),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 10,
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'إنشاء غرفة',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color.fromRGBO(30, 30, 30, .68),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white10),
    ),
    child: child,
  );
}

class _VipVoiceWave extends StatefulWidget {
  const _VipVoiceWave({required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<_VipVoiceWave> createState() => _VipVoiceWaveState();
}

class _VipVoiceWaveState extends State<_VipVoiceWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
    final colors = level >= 6
        ? const [Colors.red, Colors.amber, Colors.blue]
        : const [Color(0xFF38BDF8), Color(0xFF2563EB), Color(0xFF38BDF8)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final size = 56 + (_controller.value * 5);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: colors[1].withValues(alpha: .9),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: .55),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final height =
                    8.0 + (((i + 1) % 3) * 5) + (_controller.value * 4);
                return Container(
                  width: 3,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class RoomMusicSheet extends StatelessWidget {
  const RoomMusicSheet({
    super.key,
    required this.music,
    required this.activeMusic,
    required this.playing,
    required this.volume,
    required this.onUpload,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onVolume,
    required this.onSeek,
    required this.canControl,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  final List<Map<String, dynamic>> music;
  final Map<String, dynamic>? activeMusic;
  final bool playing;
  final double volume;
  final Future<void> Function() onUpload;
  final Future<void> Function(Map<String, dynamic>) onPlay;
  final Future<void> Function(Map<String, dynamic>) onPause;
  final Future<void> Function() onStop;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onSeek;
  final bool canControl;
  final double positionSeconds;
  final double durationSeconds;

  Map<String, dynamic>? get _active {
    final nested = activeMusic?['room_music'];
    return nested is Map ? Map<String, dynamic>.from(nested) : null;
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .72,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24144D), Color(0xFF0D1029)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'موسيقى الغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onUpload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE9B949), Color(0xFFB87916)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_upload_rounded,
                            color: Colors.white,
                            size: 17,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'رفع موسيقى',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: music.isEmpty
                  ? const Center(
                      child: Text(
                        'لم تتم إضافة موسيقى بعد\nارفع ملفات صوتية لتشغيلها للجميع',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.7),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                      itemCount: music.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (_, index) {
                        final item = music[index];
                        final selected =
                            active?['id']?.toString() == item['id']?.toString();
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF6D4AFF).withValues(alpha: .3)
                                : Colors.white.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFFE9B949)
                                  : Colors.white12,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFE9B949)
                                      : Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  selected && playing
                                      ? Icons.equalizer_rounded
                                      : Icons.music_note_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  item['title']?.toString() ?? 'موسيقى',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => selected && playing
                                    ? onPause(item)
                                    : onPlay(item),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF7658FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    selected && playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: const BoxDecoration(
                color: Color(0xCC11142E),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.graphic_eq_rounded,
                        color: Color(0xFFE9B949),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          active?['title']?.toString() ??
                              'لا توجد موسيقى تعمل الآن',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (active != null && !canControl)
                        const Text(
                          'تحكم المالك',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      GestureDetector(
                        onTap: onStop,
                        child: const Text(
                          'إيقاف',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (active != null && durationSeconds > 0)
                    Row(
                      children: [
                        const Icon(
                          Icons.fast_forward_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFF8B7BFF),
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: positionSeconds.clamp(
                                0.0,
                                durationSeconds,
                              ),
                              min: 0,
                              max: durationSeconds,
                              onChanged: canControl ? onSeek : null,
                            ),
                          ),
                        ),
                        Text(
                          '${positionSeconds.floor()}s',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: canControl
                            ? () => onVolume((volume - .1).clamp(0.0, 1.0))
                            : null,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.volume_down_rounded,
                          color: Colors.white60,
                          size: 19,
                        ),
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: const Color(0xFFE9B949),
                            inactiveTrackColor: Colors.white12,
                            thumbColor: Colors.white,
                            overlayColor: const Color(0x33E9B949),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: volume.clamp(0.0, 1.0),
                            min: 0,
                            max: 1,
                            onChanged: canControl ? onVolume : null,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: canControl
                            ? () => onVolume((volume + .1).clamp(0.0, 1.0))
                            : null,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white60,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _miniProfileBg = Color(0xFF16151A);
const _miniProfilePanel = Color(0xFF211F27);
const _miniProfileMuted = Color(0xFF92909A);
const _miniProfilePurple = Color(0xFF7C4DFF);

class _RoomMiniProfileSheet extends StatelessWidget {
  const _RoomMiniProfileSheet({
    required this.username,
    required this.profile,
    required this.countryFlag,
    required this.gender,
    required this.vip,
    required this.familyBadge,
    required this.followers,
    required this.following,
    required this.isFollowing,
    required this.visitors,
    required this.modules,
    required this.selfSeat,
    required this.canModerate,
    required this.targetModerator,
    required this.voiceMuted,
    required this.chatMuted,
    required this.banned,
    required this.onClose,
    required this.onOpenProfile,
    required this.onFollow,
    required this.onGift,
    required this.onMention,
    required this.onLeaveSeat,
    required this.onModerator,
    required this.onVoiceMute,
    required this.onChatMute,
    required this.onBan,
    required this.onInvite,
    required this.onBlock,
  });

  final String username;
  final Map<String, dynamic> profile;
  final String countryFlag;
  final String gender;
  final int vip;
  final Map<String, dynamic>? familyBadge;
  final dynamic followers;
  final dynamic following;
  final bool isFollowing;
  final dynamic visitors;
  final Map<String, dynamic> modules;
  final bool selfSeat;
  final bool canModerate;
  final bool targetModerator;
  final bool voiceMuted;
  final bool chatMuted;
  final bool banned;
  final VoidCallback onClose;
  final VoidCallback onOpenProfile;
  final VoidCallback onFollow;
  final VoidCallback onGift;
  final VoidCallback onMention;
  final VoidCallback onLeaveSeat;
  final VoidCallback onModerator;
  final VoidCallback onVoiceMute;
  final VoidCallback onChatMute;
  final VoidCallback onBan;
  final VoidCallback onInvite;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final isVip = vip > 0;
    final wealth = modules['wealth_level'] ?? profile['wealth_level'] ?? 0;
    final charm = modules['charm_level'] ?? profile['charm_level'] ?? 0;
    final isAdmin =
        profile['is_super_admin'] == true ||
        (profile['saki_id'] as num?)?.toInt() == 1000;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 620),
      decoration: const BoxDecoration(
        color: _miniProfileBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isVip)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: .16,
                    child: VipSvgaAsset(
                      assetPath: 'assets/vip/user_center_svip$vip.svga',
                      fallbackAsset: 'assets/vip/title_vip$vip.png',
                      size: 420,
                    ),
                  ),
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onOpenProfile,
                  child: _RoomProfileAvatar(profile: profile),
                ),
                const SizedBox(height: 10),
                VipNameText(
                  profile: {...profile, 'vip_level': vip},
                  fontSize: 21,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                VipTitleBadge(profile: {...profile, 'vip_level': vip}),
                const SizedBox(height: 5),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Text(countryFlag, style: const TextStyle(fontSize: 14)),
                    const Text('|', style: TextStyle(color: _miniProfileMuted)),
                    Text(
                      gender,
                      style: const TextStyle(
                        color: _miniProfileMuted,
                        fontSize: 13,
                      ),
                    ),
                    const Text('|', style: TextStyle(color: _miniProfileMuted)),
                    Text(
                      'UID: ${profile['saki_id'] ?? '—'}',
                      style: const TextStyle(
                        color: _miniProfileMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    if (isVip)
                      _RoomProfileBadge(
                        icon: Icons.workspace_premium_rounded,
                        label: 'VIP $vip',
                        color: const Color(0xFFFF9800),
                        darkText: true,
                      ),
                    _RoomProfileBadge(
                      icon: Icons.diamond_rounded,
                      label: 'ثروة Lv.$wealth',
                      color: const Color(0xFF00C853),
                    ),
                    _RoomProfileBadge(
                      icon: Icons.star_rounded,
                      label: 'رائج Lv.$charm',
                      color: const Color(0xFFAA00FF),
                    ),
                    if (familyBadge != null)
                      _RoomProfileBadge(
                        icon: Icons.groups_rounded,
                        label: familyBadge!['name']?.toString() ?? 'عائلة',
                        color: const Color(0xFF3949AB),
                      ),
                    if (isAdmin)
                      const _RoomProfileBadge(
                        icon: Icons.verified_rounded,
                        label: 'Super Admin',
                        color: Color(0xFFE91E63),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _RoomProfileStat(value: visitors, label: 'الزوار'),
                    _RoomProfileStat(value: followers, label: 'المتابعين'),
                    _RoomProfileStat(value: following, label: 'يتابع'),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _RoomProfileButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'رسالة',
                        color: _miniProfilePanel,
                        onTap: onMention,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RoomProfileButton(
                        icon: isFollowing
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                        label: isFollowing ? 'متابَع' : 'متابعة',
                        color: _miniProfilePurple,
                        onTap: onFollow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RoomProfileButton(
                  icon: Icons.card_giftcard_rounded,
                  label: 'إرسال هدية',
                  color: const Color(0xFF2A2A35),
                  onTap: onGift,
                ),
                if (selfSeat) ...[
                  const SizedBox(height: 10),
                  _RoomProfileButton(
                    icon: Icons.mic_off_rounded,
                    label: 'النزول من المقعد',
                    color: const Color(0xFFB63D55),
                    onTap: onLeaveSeat,
                  ),
                ],
                if (canModerate) ...[
                  const SizedBox(height: 18),
                  const Divider(color: Color(0x22FFFFFF), height: 1),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'إدارة المستخدم',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .7),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      _RoomProfileAdminAction(
                        icon: targetModerator
                            ? Icons.shield_outlined
                            : Icons.shield_rounded,
                        label: targetModerator ? 'إلغاء مشرف' : 'مشرف',
                        onTap: onModerator,
                      ),
                      _RoomProfileAdminAction(
                        icon: voiceMuted
                            ? Icons.mic_rounded
                            : Icons.mic_off_rounded,
                        label: voiceMuted ? 'إلغاء مايك' : 'كتم مايك',
                        onTap: onVoiceMute,
                      ),
                      _RoomProfileAdminAction(
                        icon: chatMuted
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        label: chatMuted ? 'إلغاء دردشة' : 'كتم دردشة',
                        onTap: onChatMute,
                      ),
                      _RoomProfileAdminAction(
                        icon: banned
                            ? Icons.person_add_rounded
                            : Icons.logout_rounded,
                        label: banned ? 'إلغاء طرد' : 'طرد',
                        onTap: onBan,
                      ),
                      _RoomProfileAdminAction(
                        icon: Icons.phone_disabled_rounded,
                        label: 'دعوة',
                        onTap: onInvite,
                      ),
                      _RoomProfileAdminAction(
                        icon: Icons.block_rounded,
                        label: 'حظر',
                        onTap: onBlock,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            Positioned(
              top: -38,
              left: 0,
              child: _RoomProfileCircleAction(
                icon: Icons.more_vert_rounded,
                onTap: () => _showRoomProfileNotice(context),
              ),
            ),
            Positioned(
              top: -38,
              right: 0,
              child: _RoomProfileCircleAction(
                icon: Icons.close_rounded,
                onTap: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomProfileNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('المزيد من خيارات المستخدم قريبًا')),
    );
  }
}

class _RoomProfileAvatar extends StatefulWidget {
  const _RoomProfileAvatar({required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<_RoomProfileAvatar> createState() => _RoomProfileAvatarState();
}

class _RoomProfileAvatarState extends State<_RoomProfileAvatar>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _svga = SVGAAnimationController(
    vsync: this,
  );
  int get _vip =>
      ((widget.profile['vip_level'] as num?)?.toInt() ?? 0).clamp(0, 10);
  Color get _color => vipEntranceColors[_vip] ?? const Color(0xFF7C4DFF);
  String get _asset => _vip >= 4
      ? 'assets/vip/user_center_svip$_vip.svga'
      : 'assets/vip/icon_svip${_vip.clamp(1, 3)}_medal.svga';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_vip < 1) return;
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(_asset);
      if (!mounted) return;
      _svga.videoItem = movie;
      setState(() {});
      _svga.repeat();
    } catch (_) {}
  }

  @override
  void dispose() {
    _svga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 122,
    height: 122,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _color, width: 3),
            boxShadow: [
              BoxShadow(
                color: _color.withValues(alpha: .65),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SakiAvatar(
            url: widget.profile['avatar_url'] as String?,
            label: widget.profile['username'] as String?,
            radius: 42,
            profile: {...widget.profile, 'vip_frame_enabled': false},
          ),
        ),
        if (_svga.videoItem != null)
          IgnorePointer(
            child: SizedBox(
              width: 122,
              height: 122,
              child: SVGAImage(_svga, fit: BoxFit.contain),
            ),
          ),
      ],
    ),
  );
}

class _RoomProfileBadge extends StatelessWidget {
  const _RoomProfileBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.darkText = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool darkText;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: darkText ? Colors.black : Colors.white),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: darkText ? Colors.black : Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _RoomProfileStat extends StatelessWidget {
  const _RoomProfileStat({required this.value, required this.label});
  final dynamic value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: _miniProfileMuted, fontSize: 11),
        ),
      ],
    ),
  );
}

class _RoomProfileButton extends StatelessWidget {
  const _RoomProfileButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomProfileCircleAction extends StatelessWidget {
  const _RoomProfileCircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0x14FFFFFF),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white70, size: 18),
    ),
  );
}

class _RoomProfileAdminAction extends StatelessWidget {
  const _RoomProfileAdminAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 68,
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFF2A2A35),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white70, size: 16),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _miniProfileMuted, fontSize: 9),
          ),
        ],
      ),
    ),
  );
}
