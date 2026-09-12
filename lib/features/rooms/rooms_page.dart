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
import 'cinema_player.dart';
import 'room_gifts_sheet.dart';
import 'room_gift_ranking_sheet.dart';
import 'room_global_gift_banner.dart';
import 'luck_bag_widgets.dart';
import 'buffet_game_sheet.dart';
import '../profile/store_pages.dart';
import '../profile/user_profile_page.dart';
import '../messages/messages_page.dart';
import '../profile/vip_widgets.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

import '../../shared/widgets/custom_toast.dart';

const _roomPrimary = Color(0xFFFF6B35);
const _roomSecondary = Color(0xFF06B6D4);
const _roomTrophyGold = Color(0xFFF3B83F);
const _roomTrendOrange = Color(0xFFFF6B35);
const _roomBg = Colors.white;
const _roomMuted = Color(0xFF64748B);

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
  StreamSubscription<List<Map<String, dynamic>>>? _roomPresenceSubscription;
  Timer? _roomRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _roomPresenceSubscription = _service.client
        .from('room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .listen((_) => _scheduleRoomRefresh());
  }

  void _scheduleRoomRefresh() {
    _roomRefreshTimer?.cancel();
    _roomRefreshTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _refreshRoomsOnly();
    });
  }

  Future<void> _refreshRoomsOnly() async {
    try {
      final rooms = await _service.rooms();
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } catch (_) {
      // Keep the last good list during transient realtime failures.
    }
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
        CustomToast.show(context, 'تعذر تحميل الغرف من Supabase');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _roomPresenceSubscription?.cancel();
    _roomRefreshTimer?.cancel();
    super.dispose();
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
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) => RoomGridCard(
                            room: _visibleRooms[index],
                            rank: index + 1,
                          ),
                          childCount: _visibleRooms.length,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: .72,
                            ),
                      ),
                    ),
                ],
              ),
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

class RoomGridCard extends StatefulWidget {
  const RoomGridCard({super.key, required this.room, required this.rank});
  final Map<String, dynamic> room;
  final int rank;

  @override
  State<RoomGridCard> createState() => _RoomGridCardState();
}

class _RoomGridCardState extends State<RoomGridCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final active = RoomSessionController.instance.room;
    if (active != null && active['id'] != widget.room['id']) {
      await RoomSessionController.instance.close();
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoomDetailPage(room: widget.room)),
    );
  }

  String? get _frame => switch (widget.rank) {
    1 => 'assets/rooms/top_square_frame.png',
    2 => 'assets/rooms/top2_square_frame.png',
    3 => 'assets/rooms/top3_square_frame.png',
    _ => null,
  };

  String? get _badge => switch (widget.rank) {
    1 => 'assets/rooms/top1_badge.png',
    2 => 'assets/rooms/top2_badge.png',
    3 => 'assets/rooms/top3_badge.png',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final image = room['image_url']?.toString() ?? '';
    final name = room['name']?.toString() ?? 'غرفة SAKI';
    final country = room['country']?.toString() ?? '';
    final members = (room['_members_count'] as num?)?.toInt() ?? 0;
    final official = room['is_official'] == true;
    final pinned = room['is_pinned'] == true;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F3FF)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: widget.rank <= 3
                ? const Color(0xFFF2C14E)
                : const Color(0xFFE6E8F0),
            width: widget.rank <= 3 ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(9),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: image.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFF312E81),
                              child: Icon(
                                Icons.meeting_room_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            )
                          : Image.network(image, fit: BoxFit.cover),
                    ),
                  ),
                  if (_frame != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: IgnorePointer(
                          child: Image.asset(_frame!, fit: BoxFit.fill),
                        ),
                      ),
                    ),
                  if (_badge != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Image.asset(_badge!, width: 48, height: 48),
                    ),
                  if (pinned)
                    const Positioned(
                      top: 12,
                      right: 12,
                      child: Icon(
                        Icons.push_pin_rounded,
                        color: Color(0xFFFFB800),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 0, 11, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF17203A),
                          ),
                        ),
                      ),
                      if (country.isNotEmpty)
                        Text(
                          _flagForCountry(country),
                          style: const TextStyle(fontSize: 17),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (official)
                    Row(
                      children: [
                        Image.asset(
                          'assets/rooms/official_badge.png',
                          width: 20,
                          height: 20,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'غرفة رسمية',
                          style: TextStyle(
                            color: Color(0xFF9A6500),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(height: 20),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        color: Color(0xFF10B981),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$members متصل',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      _RoomVoiceWaves(animation: _wave),
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

class _RoomVoiceWaves extends StatelessWidget {
  const _RoomVoiceWaves({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (_, _) => Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        final phase = (animation.value + index * .16) % 1;
        final height = 5 + (10 * (phase < .5 ? phase * 2 : (1 - phase) * 2));
        return Container(
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF656BF9),
            borderRadius: BorderRadius.circular(4),
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
  final _picker = ImagePicker();
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
  String _liveThemeKey = 'default';
  String? _liveImageUrl;
  String? _liveBackgroundUrl;
  Map<String, dynamic>? _activeGiftMessage;
  String? _shownGiftMessageId;
  Map<String, dynamic>? _activeBuffetWin;
  String? _shownBuffetWinId;
  List<Map<String, dynamic>> _roomMembers = [];
  final List<Map<String, dynamic>> _optimisticMessages = [];
  StreamSubscription<List<Map<String, dynamic>>>? _roomMembersSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _roomEmojiSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _luckBagSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _roomBanSubscription;
  final Map<String, Timer> _roomEmojiTimers = {};
  final Map<String, Map<String, dynamic>> _activeSeatEmojis = {};
  final Map<String, GlobalKey> _seatKeys = {};
  List<Map<String, dynamic>> _roomEmojis = [];
  int _roomGoldTotal = 0;
  Map<String, dynamic>? _entranceProfile;
  Map<String, dynamic>? _entranceProduct;
  Timer? _entranceTimer;
  StreamSubscription<List<Map<String, dynamic>>>? _musicStateSubscription;
  StreamSubscription<ProcessingState>? _musicCompletionSubscription;
  bool _membersInitialized = false;
  late AudioPlayer _musicPlayer;
  List<Map<String, dynamic>> _roomMusic = [];
  List<Map<String, dynamic>> _roomPlaylist = [];
  Map<String, dynamic>? _activeMusic;
  bool _musicPlaying = false;
  String _musicRepeatMode = 'off';
  bool _musicShuffle = false;
  bool _closingRoom = false;
  bool _handlingRoomBan = false;
  bool _localActuallySpeaking = false;
  double _musicVolume = 1;
  double _musicDurationSeconds = 0;
  String? _musicOwnerId;
  Set<String> _previousSeatUserIds = <String>{};
  bool _seatStopPending = false;

  Future<void> _openGlobalGiftRoom(Map<String, dynamic> room) async {
    if (!mounted || room['id'] == null) return;
    final current = RoomSessionController.instance.room;
    if (current != null && current['id'] == room['id']) return;
    if (current != null && current['id'] != room['id']) {
      final move = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF161126),
          title: const Text(
            'انتقال إلى الغرفة؟',
            textAlign: TextAlign.right,
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'أنت الآن في غرفة أخرى. هل تريد الانتقال إلى غرفة ${room['name'] ?? 'الهدية'}؟',
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      if (move != true) return;
      await _service.setRoomSpeaking(_roomId, false).catchError((_) {});
      await _service.leaveRoomSeat(_roomId).catchError((_) {});
      await _service.leaveRoom(_roomId).catchError((_) {});
      await RoomSessionController.instance.close().catchError((_) {});
      if (!mounted) return;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
        (route) => route.isFirst,
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)));
  }

  Timer? _seatTaskTimer;
  Map<String, dynamic>? _optimisticSeatRow;
  List<Map<String, dynamic>> _luckBags = [];
  Map<String, dynamic>? _newLuckBag;
  StreamSubscription<List<Map<String, dynamic>>>? _globalLuckBagSubscription;
  Timer? _luckBagExpiryTimer;
  final Set<String> _seenGlobalLuckBagIds = <String>{};
  bool _globalLuckBagsInitialized = false;

  @override
  void initState() {
    super.initState();
    // Stop the external bubble only after this room page has actually started.
    RoomBackgroundBridge.stop();
    final session = RoomSessionController.instance;
    _musicPlayer = session.isSameRoom(_roomId)
        ? (session.musicPlayer ?? AudioPlayer())
        : AudioPlayer();
    _musicCompletionSubscription = _musicPlayer.processingStateStream.listen((
      state,
    ) {
      if (state == ProcessingState.completed) _handleMusicCompleted();
    });
    _seatStream = _service.roomSeatsStream(_roomId);
    _roomSettingsStream = _service.roomSettingsStream(_roomId);
    _liveSeatCount = (widget.room['seat_count'] as num?)?.toInt() ?? 10;
    _liveThemeKey = widget.room['theme_key']?.toString() ?? 'default';
    _liveImageUrl = widget.room['image_url'] as String?;
    _liveBackgroundUrl = widget.room['background_url'] as String?;
    _micPermission = widget.room['mic_permission'] as String? ?? 'everyone';
    _roomSettingsSubscription = _roomSettingsStream.listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final updated = rows.first;
      setState(() {
        _liveSeatCount =
            (updated['seat_count'] as num?)?.toInt() ?? _liveSeatCount;
        _liveThemeKey = updated['theme_key']?.toString() ?? _liveThemeKey;
        _liveImageUrl = updated['image_url'] as String?;
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
    _roomBanSubscription = _service.roomBanStream(_roomId).listen((rows) {
      if (rows.isEmpty || _handlingRoomBan) return;
      final expiresAt = DateTime.tryParse(
        rows.first['expires_at']?.toString() ?? '',
      );
      if (expiresAt == null || expiresAt.isAfter(DateTime.now().toUtc())) {
        _handleRoomBan();
      }
    });
    final existingEngine = RoomSessionController.instance.engine;
    final restoredSession =
        existingEngine != null &&
        RoomSessionController.instance.isSameRoom(_roomId);
    if (restoredSession) {
      _engine = existingEngine;
      final session = RoomSessionController.instance;
      _isOnSeat = session.isOnSeat;
      _micMuted = session.micMuted;
      _joined = true;
      RoomSessionController.instance.hideBubble();
    }
    if (!restoredSession) {
      _join().then((allowed) {
        if (allowed) _startRoomAudio();
      });
    }
    _loadRoomState();
    _loadRoomMusic();
    _musicStateSubscription = _service.roomMusicStateStream(_roomId).listen((
      _,
    ) {
      _loadRoomMusic();
    });
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
      _refreshVisibleLuckBags(bags);
    });
    _luckBagExpiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _refreshVisibleLuckBags(_luckBags);
    });
    _globalLuckBagSubscription = _service.allRoomLuckBagsStream().listen((
      bags,
    ) {
      if (!mounted) return;
      final ids = bags.map((bag) => bag['id']?.toString()).whereType<String>();
      if (!_globalLuckBagsInitialized) {
        _seenGlobalLuckBagIds.addAll(ids);
        _globalLuckBagsInitialized = true;
        return;
      }
      final fresh = bags.where((bag) {
        final id = bag['id']?.toString();
        return id != null && !_seenGlobalLuckBagIds.contains(id);
      }).toList();
      _seenGlobalLuckBagIds.addAll(ids);
      for (final bag in fresh) {
        final expires = DateTime.tryParse(bag['expires_at']?.toString() ?? '');
        if (expires == null || !expires.isAfter(DateTime.now().toUtc())) {
          continue;
        }
        _service.enrichRoomLuckBag(bag).then((enriched) {
          if (!mounted) return;
          setState(() => _newLuckBag = enriched);
        });
      }
    });
  }

  void _refreshVisibleLuckBags(List<Map<String, dynamic>> bags) {
    final now = DateTime.now().toUtc();
    final visible = bags.where((bag) {
      final expires = DateTime.tryParse(bag['expires_at']?.toString() ?? '');
      return bag['status'] == 'open' && expires != null && expires.isAfter(now);
    }).toList();
    if (mounted) setState(() => _luckBags = visible);
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
          onAudioVolumeIndication:
              (connection, speakers, speakerNumber, totalVolume) {
                // Agora reports the local speaker with uid 0 in this callback.
                final local = speakers
                    .where((speaker) => speaker.uid == 0)
                    .firstOrNull;
                final speaking =
                    !_micMuted &&
                    _isOnSeat &&
                    local != null &&
                    ((local.vad ?? 0) == 1 || (local.volume ?? 0) >= 18);
                if (speaking == _localActuallySpeaking) return;
                _localActuallySpeaking = speaking;
                _service.setRoomSpeaking(_roomId, speaking).catchError((_) {});
              },
          onTokenPrivilegeWillExpire: (_, _) => _refreshRoomToken(),
        ),
      );
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.enableAudio();
      await engine.enableAudioVolumeIndication(
        interval: 200,
        smooth: 3,
        reportVad: true,
      );
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

  Future<void> _minimizeRoom() async {
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
    await RoomBackgroundBridge.start(
      roomId: _roomId,
      roomName: widget.room['name']?.toString() ?? 'غرفة SAKI',
      imageUrl: widget.room['image_url']?.toString(),
    );
    // The in-app bubble is the only visible bubble while the app is active;
    // the native view is toggled on only when the app goes to the background.
    await RoomSessionController.instance.setOverlayVisible(false);
    if (!mounted) return;
    _joined = true;
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
    _localActuallySpeaking = false;
    await _service.setRoomSpeaking(_roomId, false);
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
          try {
            await _service.sendRoomGift(
              roomId: _roomId,
              recipientId: recipientId,
              giftId: gift['id'] as String,
            );
            await _service.sendRoomMessage(
              _roomId,
              'أرسل هدية ${gift['name'] ?? 'هدية'}',
              type: 'gift',
              payload: payload,
            );
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

  Future<void> _handleRoomBan() async {
    if (_handlingRoomBan || _closingRoom) return;
    _handlingRoomBan = true;
    _closingRoom = true;
    _seatTaskTimer?.cancel();
    _localActuallySpeaking = false;
    try {
      await _service.setRoomSpeaking(_roomId, false).catchError((_) {});
      await _service.leaveRoomSeat(_roomId).catchError((_) {});
      await _service.leaveRoom(_roomId).catchError((_) {});
      await RoomBackgroundBridge.setPipEligible(false).catchError((_) {});
      await RoomBackgroundBridge.stop().catchError((_) {});
      await RoomSessionController.instance.close().catchError((_) {});
      final engine = _engine;
      if (engine != null) {
        await engine.leaveChannel().catchError((_) {});
        await engine.release().catchError((_) {});
      }
    } finally {
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => Directionality(
            textDirection: TextDirection.rtl,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB347),
                      Color(0xFF67E8F9),
                      Colors.white,
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
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
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.gpp_bad_rounded,
                        color: Color(0xFFEA580C),
                        size: 38,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تم حظرك من الغرفة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'لا يمكنك العودة إلى هذه الغرفة حتى يفك مالك الغرفة الحظر عنك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'إغلاق',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (mounted) {
          _joined = false;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    }
  }

  Future<bool> _join() async {
    try {
      if (await _service.isRoomBanned(_roomId)) {
        await _handleRoomBan();
        return false;
      }
      await _service.joinRoom(_roomId);
      try {
        await _service.claimEquippedEntranceOnJoin(_roomId);
      } catch (_) {
        // لا يمنع فشل تسجيل الدخولية دخول المستخدم إلى الغرفة.
      }
      await _service.sendRoomMessage(_roomId, 'انضم إلى الغرفة', type: 'join');
      if (mounted) setState(() => _joined = true);
      RoomSessionController.instance.startPresenceHeartbeat(
        () => _service.touchRoomPresence(_roomId),
      );
      return true;
    } catch (error) {
      if (error.toString().contains('room_banned')) {
        await _handleRoomBan();
        return false;
      }
      if (mounted) {
        _messageSnack(error.toString().replaceFirst('Exception: ', ''));
        Navigator.maybePop(context);
      }
      return false;
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
    if (_closingRoom) return true;
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
      _closingRoom = true;
      if (mounted) setState(() {});
      try {
        await RoomBackgroundBridge.setPipEligible(false);
        await _service.setRoomSpeaking(_roomId, false).catchError((_) {});
        await _service.leaveRoomSeat(_roomId).catchError((_) {});
        await _service.leaveRoom(_roomId).catchError((_) {});
      } finally {
        await RoomBackgroundBridge.stop().catchError((_) {});
        if (RoomSessionController.instance.engine == _engine ||
            RoomSessionController.instance.room?['id'] == _roomId) {
          await RoomSessionController.instance.close().catchError((_) {});
        }
        if (mounted) {
          _joined = false;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
      return true;
    }
    if (result == false) await _minimizeRoom();
    return false;
  }

  Future<void> _showRoomInfo() async {
    final image = _liveImageUrl;
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
                  if (!owner)
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
    final isShippingAgent = await _service.isShippingAgent(userId);
    final moderation = canModerate
        ? await _service.roomModerationStatus(_roomId, userId)
        : const <String, dynamic>{};
    final voiceMuted = moderation['mute_voice'] == true;
    final chatMuted = moderation['mute_chat'] == true;
    final banned = moderation['banned'] == true;
    final vip = activeVipLevel({...profile, ...modules});
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
            if (sheetContext.mounted) {
              setSheetState(() => following = !following);
            }
            if (mounted) {
              _messageSnack(
                following ? 'تمت متابعة المستخدم.' : 'تم إلغاء المتابعة.',
              );
            }
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
                  profile: {...profile, ...modules, 'vip_level': vip},
                  countryFlag: countryFlag,
                  gender: gender,
                  vip: vip,
                  familyBadge: familyBadge,
                  isShippingAgent: isShippingAgent,
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
                  onMention: () async {
                    Navigator.pop(dialogContext);
                    if (selfSeat) return;
                    final conversationId = await _service.createConversation(
                      userId,
                    );
                    if (!mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          conversationId: conversationId,
                          participant: profile,
                        ),
                      ),
                    );
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
                      await _service.roomBan(_roomId, userId, null);
                    }
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onInvite: () async {
                    await _service.inviteToRoomSeat(_roomId, userId);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  onReport: () => _showRoomReportSheet(userId, username),
                  onBlock: () async {
                    final duration = await _banDuration();
                    if (duration != null) {
                      await _service.roomBan(_roomId, userId, duration);
                    }
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

  Future<void> _showRoomReportSheet(String userId, String username) async {
    String category = 'abuse';
    final details = TextEditingController();
    XFile? evidence;
    var sending = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF20202D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'إبلاغ عن مستخدم',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '@$username',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 16),
                for (final item in const {
                  'abuse': 'سب وشتم',
                  'promotion': 'ترويج لتطبيقات أخرى',
                  'sexual': 'محتوى جنسي',
                  'harassment': 'مستخدم مسيء',
                }.entries)
                  GestureDetector(
                    onTap: () => setSheet(() => category = item.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: category == item.key
                            ? const Color(0xFFFF6B55)
                            : const Color(0xFF2B2B3A),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        item.value,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                TextField(
                  controller: details,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'أضف تفاصيل البلاغ (اختياري)',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF2B2B3A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final picked = await _picker.pickVideo(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) setSheet(() => evidence = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2B3A),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.video_library_rounded,
                          color: Color(0xFF20C5D5),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            evidence == null
                                ? 'إرفاق فيديو إثبات'
                                : 'تم اختيار فيديو الإثبات',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(Icons.add_rounded, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: sending
                      ? null
                      : () async {
                          setSheet(() => sending = true);
                          try {
                            final url = evidence == null
                                ? null
                                : await _service.uploadReportEvidence(
                                    evidence!,
                                  );
                            await _service.reportUser(
                              userId,
                              category,
                              details: details.text,
                              roomId: _roomId,
                              evidenceUrl: url,
                            );
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            _messageSnack('تم إرسال البلاغ للمراجعة بنجاح');
                          } finally {
                            if (context.mounted) {
                              setSheet(() => sending = false);
                            }
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: sending ? Colors.white24 : const Color(0xFFFF6B55),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      sending ? 'جارٍ الإرسال...' : 'إرسال البلاغ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    details.dispose();
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

  void _messageSnack(String value) => CustomToast.show(context, value);

  bool get _canOpenMusic => _isOnSeat;

  bool get _isRoomOwner => widget.room['owner_id']?.toString() == _service.uid;

  bool get _canControlMusic =>
      _isRoomOwner || _activeMusic?['owner_id']?.toString() == _service.uid;

  Future<void> _loadRoomMusic() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.roomMusic(_roomId),
        _service.activeRoomMusic(_roomId),
        _service.roomPlaylist(_roomId),
      ]);
      if (!mounted) return;
      setState(() {
        _roomMusic = List<Map<String, dynamic>>.from(results[0] as List);
        _activeMusic = results[1] as Map<String, dynamic>?;
        _roomPlaylist = List<Map<String, dynamic>>.from(results[2] as List);
        _musicPlaying = _activeMusic?['is_playing'] == true;
        _musicOwnerId = _activeMusic?['owner_id']?.toString();
        _musicRepeatMode = _activeMusic?['repeat_mode']?.toString() ?? 'off';
        _musicShuffle = _activeMusic?['shuffle_mode'] == true;
        _musicVolume = ((_activeMusic?['volume'] as num?) ?? 1)
            .toDouble()
            .clamp(0.0, 1.0);
      });
      final nested = _activeMusic?['room_music'];
      if (_isOnSeat && nested is Map) {
        final duration = await _musicPlayer.setUrl(
          nested['audio_url'] as String,
        );
        _musicDurationSeconds = duration?.inMilliseconds.toDouble() == null
            ? 0
            : duration!.inMilliseconds / 1000;
        await _musicPlayer.setVolume(_musicVolume);
        var position = ((_activeMusic?['position_seconds'] as num?) ?? 0)
            .toDouble();
        final startedAt = DateTime.tryParse(
          _activeMusic?['started_at']?.toString() ?? '',
        );
        if (_musicPlaying && startedAt != null) {
          position +=
              DateTime.now().toUtc().difference(startedAt).inMilliseconds /
              1000;
        }
        if (_musicDurationSeconds > 0) {
          position = position.clamp(0.0, _musicDurationSeconds);
        }
        await _musicPlayer.seek(
          Duration(milliseconds: (position * 1000).round()),
        );
        if (_musicPlaying) {
          await _musicPlayer.play();
        } else {
          await _musicPlayer.pause();
        }
      }
    } catch (_) {}
  }

  Future<void> _syncMusicSeatAccess(bool seated) async {
    if (seated || !_musicPlaying) return;
    await _stopRoomMusic(broadcastOnly: true);
  }

  List<Map<String, dynamic>> get _playlistTracks => _roomPlaylist
      .map((row) => row['room_music'])
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();

  Future<void> _handleMusicCompleted() async {
    if (!mounted || !_musicPlaying || !_canControlMusic) return;
    final tracks = _playlistTracks;
    final currentId = _activeMusic?['music_id']?.toString();
    if (_musicRepeatMode == 'one' && currentId != null) {
      final current = tracks.where(
        (item) => item['id']?.toString() == currentId,
      );
      if (current.isNotEmpty) {
        await _broadcastMusic('play', current.first);
        return;
      }
    }
    if (tracks.isEmpty) {
      await _stopRoomMusic();
      return;
    }
    var index = tracks.indexWhere(
      (item) => item['id']?.toString() == currentId,
    );
    if (index < 0) index = 0;
    if (_musicShuffle) {
      index = (index + 1) % tracks.length;
    } else {
      index += 1;
    }
    if (index >= tracks.length) {
      if (_musicRepeatMode != 'all') {
        await _stopRoomMusic();
        return;
      }
      index = 0;
    }
    await _broadcastMusic('play', tracks[index]);
  }

  Future<void> _nextRoomMusic() async {
    if (!_canControlMusic) {
      _messageSnack('لا تملك صلاحية تغيير الأغنية.');
      return;
    }
    final tracks = _playlistTracks;
    if (tracks.isEmpty) return;
    final current = tracks.indexWhere(
      (item) => item['id']?.toString() == _activeMusic?['music_id']?.toString(),
    );
    await _broadcastMusic('play', tracks[(current + 1) % tracks.length]);
  }

  Future<void> _previousRoomMusic() async {
    if (!_canControlMusic) {
      _messageSnack('لا تملك صلاحية تغيير الأغنية.');
      return;
    }
    final tracks = _playlistTracks;
    if (tracks.isEmpty) return;
    final current = tracks.indexWhere(
      (item) => item['id']?.toString() == _activeMusic?['music_id']?.toString(),
    );
    final index = current <= 0 ? tracks.length - 1 : current - 1;
    await _broadcastMusic('play', tracks[index]);
  }

  Future<void> _addMusicToPlaylist(Map<String, dynamic> music) async {
    try {
      await _service.addRoomPlaylistTrack(_roomId, music['id'].toString());
      await _loadRoomMusic();
    } catch (error) {
      if (mounted) _messageSnack('تعذر إضافة الأغنية إلى القائمة: $error');
    }
  }

  Future<void> _removeMusicFromPlaylist(Map<String, dynamic> row) async {
    try {
      await _service.removeRoomPlaylistTrack(row['id'].toString());
      await _loadRoomMusic();
    } catch (error) {
      if (mounted) _messageSnack('تعذر حذف الأغنية من القائمة: $error');
    }
  }

  Future<void> _toggleMusicRepeat() async {
    if (!_canControlMusic) return;
    const modes = ['off', 'all', 'one'];
    final next = modes[(modes.indexOf(_musicRepeatMode) + 1) % modes.length];
    setState(() => _musicRepeatMode = next);
    await _service.setActiveRoomMusic(
      _roomId,
      musicId: _activeMusic?['music_id']?.toString(),
      ownerId: _musicOwnerId,
      isPlaying: _musicPlaying,
      positionSeconds: _musicPlayer.position.inMilliseconds / 1000,
      volume: _musicVolume,
      repeatMode: next,
      shuffleMode: _musicShuffle,
    );
    await _roomChatChannel.sendBroadcastMessage(
      event: 'music',
      payload: {
        'action': 'mode',
        'repeat_mode': next,
        'shuffle_mode': _musicShuffle,
      },
    );
  }

  Future<void> _toggleMusicShuffle() async {
    if (!_canControlMusic) return;
    final next = !_musicShuffle;
    setState(() => _musicShuffle = next);
    await _service.setActiveRoomMusic(
      _roomId,
      musicId: _activeMusic?['music_id']?.toString(),
      ownerId: _musicOwnerId,
      isPlaying: _musicPlaying,
      positionSeconds: _musicPlayer.position.inMilliseconds / 1000,
      volume: _musicVolume,
      repeatMode: _musicRepeatMode,
      shuffleMode: next,
    );
    await _roomChatChannel.sendBroadcastMessage(
      event: 'music',
      payload: {
        'action': 'mode',
        'repeat_mode': _musicRepeatMode,
        'shuffle_mode': next,
      },
    );
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
    if (action == 'mode') {
      if (mounted) {
        setState(() {
          _musicRepeatMode =
              event['repeat_mode']?.toString() ?? _musicRepeatMode;
          _musicShuffle = event['shuffle_mode'] == true;
        });
      }
      return;
    }
    if (action == 'stop') {
      await _musicPlayer.stop();
      if (mounted) setState(() => _musicPlaying = false);
      return;
    }
    if (event['repeat_mode'] != null) {
      _musicRepeatMode = event['repeat_mode'].toString();
    }
    if (event['shuffle_mode'] != null) {
      _musicShuffle = event['shuffle_mode'] == true;
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
        _musicRepeatMode = event['repeat_mode']?.toString() ?? _musicRepeatMode;
        _musicShuffle = event['shuffle_mode'] == true;
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
      'started_at': DateTime.now()
          .toUtc()
          .subtract(Duration(milliseconds: (position * 1000).round()))
          .toIso8601String(),
      'repeat_mode': _musicRepeatMode,
      'shuffle_mode': _musicShuffle,
    };
    await _service.setActiveRoomMusic(
      _roomId,
      musicId: music['id'] as String?,
      ownerId: music['owner_id']?.toString(),
      isPlaying: action == 'play',
      positionSeconds: position,
      volume: _musicVolume,
      startedAt: DateTime.tryParse(event['started_at'] as String),
      repeatMode: _musicRepeatMode,
      shuffleMode: _musicShuffle,
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
        playlist: _roomPlaylist,
        activeMusic: _activeMusic,
        playing: _musicPlaying,
        volume: _musicVolume,
        onUpload: _uploadRoomMusic,
        onPlay: (music) => _broadcastMusic('play', music),
        onPause: (music) => _broadcastMusic('pause', music),
        onStop: _stopRoomMusic,
        onNext: _nextRoomMusic,
        onPrevious: _previousRoomMusic,
        onAddToPlaylist: _addMusicToPlaylist,
        onRemoveFromPlaylist: _removeMusicFromPlaylist,
        onRepeat: _toggleMusicRepeat,
        onShuffle: _toggleMusicShuffle,
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
                  _service.enrichRoomLuckBag(bag).then((enriched) {
                    if (mounted) setState(() => _newLuckBag = enriched);
                  });
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGamesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BuffetGameCatalogSheet(roomId: _roomId),
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

  Future<void> _goToLuckBag(Map<String, dynamic> bag) async {
    final targetRoom = (bag['_room'] as Map?)?.cast<String, dynamic>();
    final targetId = targetRoom?['id']?.toString();
    if (targetRoom == null || targetId == null || targetId.isEmpty) return;
    if (targetId == _roomId) {
      if (mounted) setState(() => _newLuckBag = null);
      return;
    }
    await RoomSessionController.instance.close();
    if (!mounted) return;
    setState(() => _newLuckBag = null);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => RoomDetailPage(room: targetRoom)),
    );
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
    setState(() {
      _busy = true;
      _optimisticSeatRow = null;
      _isOnSeat = false;
    });
    unawaited(_setSeatAudio(false));
    try {
      await _service.leaveRoomSeat(_roomId);
      unawaited(
        _service
            .sendRoomMessage(_roomId, 'نزل من المقعد', type: 'seat')
            .catchError((_) {}),
      );
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
        setState(() {
          _optimisticSeatRow = null;
          _isOnSeat = false;
        });
        unawaited(_setSeatAudio(false));
        await _service.leaveRoomSeat(_roomId);
        unawaited(
          _service
              .sendRoomMessage(_roomId, 'نزل من المقعد', type: 'seat')
              .catchError((_) {}),
        );
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
        final profile = occupied?['profiles'] ?? <String, dynamic>{};
        setState(() {
          _optimisticSeatRow = {
            'room_id': _roomId,
            'seat_no': seatNo,
            'user_id': _service.uid,
            'is_speaking': false,
            'profiles': profile,
          };
          _isOnSeat = true;
        });
        unawaited(_setSeatAudio(true));
        await _service.claimRoomSeat(_roomId, seatNo);
        unawaited(
          _service
              .sendRoomMessage(_roomId, 'صعد إلى المقعد', type: 'seat')
              .catchError((_) {}),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _optimisticSeatRow = null;
          _isOnSeat = false;
        });
        unawaited(_setSeatAudio(false));
      }
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
                  'ثروة LV${profile['wealth_level'] ?? 0}',
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
    _globalLuckBagSubscription?.cancel();
    _luckBagExpiryTimer?.cancel();
    _roomBanSubscription?.cancel();
    for (final timer in _roomEmojiTimers.values) {
      timer.cancel();
    }
    _roomSettingsSubscription?.cancel();
    _seatTaskTimer?.cancel();
    if (_musicPlaying && !preservedSession) {
      _roomChatChannel.sendBroadcastMessage(
        event: 'music',
        payload: {'action': 'stop', 'reason': 'room_exit'},
      );
      _musicPlayer.stop();
    }
    _musicStateSubscription?.cancel();
    _musicCompletionSubscription?.cancel();
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
    final image = _liveImageUrl;
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
                image: _liveThemeKey == 'cinema'
                    ? const DecorationImage(
                        image: AssetImage('assets/rooms/cinema_background.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black45,
                          BlendMode.darken,
                        ),
                      )
                    : backgroundUrl == null
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
                              await _confirmExit();
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
                    if (_liveThemeKey == 'cinema')
                      CinemaPlayer(
                        roomId: _roomId,
                        service: _service,
                        canControl: _isRoomOwner || _isModerator,
                      ),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _seatStream,
                      builder: (_, snap) {
                        final serverSeatRows =
                            snap.data ?? <Map<String, dynamic>>[];
                        final optimistic = _optimisticSeatRow;
                        final seatRows = optimistic == null
                            ? serverSeatRows
                            : [
                                ...serverSeatRows.where(
                                  (row) => row['user_id'] != _service.uid,
                                ),
                                optimistic,
                              ];
                        if (optimistic != null &&
                            serverSeatRows.any(
                              (row) =>
                                  row['user_id'] == _service.uid &&
                                  row['seat_no'] == optimistic['seat_no'],
                            )) {
                          scheduleMicrotask(() {
                            if (mounted && _optimisticSeatRow != null) {
                              setState(() => _optimisticSeatRow = null);
                            }
                          });
                        }
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
                                      width: _liveThemeKey == 'cinema'
                                          ? 42
                                          : 52,
                                      height: _liveThemeKey == 'cinema'
                                          ? 42
                                          : 52,
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
                                              clipBehavior: Clip.none,
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
                                                    radius:
                                                        _liveThemeKey ==
                                                            'cinema'
                                                        ? 20
                                                        : 25,
                                                    profile: profile,
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
                                          : _liveThemeKey == 'cinema'
                                          ? Image.asset(
                                              'assets/rooms/cinema_seat_icon.png',
                                              width: 46,
                                              height: 46,
                                              fit: BoxFit.contain,
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
                          final latestBuffetWin =
                              latestMessage['message_type'] == 'buffet_big_win'
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
                          if (latestBuffetWin.isNotEmpty &&
                              latestBuffetWin['id'] != _shownBuffetWinId) {
                            final win = Map<String, dynamic>.from(
                              latestBuffetWin,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted || win['id'] == _shownBuffetWinId) {
                                return;
                              }
                              setState(() {
                                _shownBuffetWinId = win['id']?.toString();
                                _activeBuffetWin = win;
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
                                          : messageType == 'buffet_big_win'
                                          ? 'فوز كبير: ${payload['profit'] ?? 0} عملة ذهبية'
                                          : body;
                                      final giftThumbnail =
                                          payload['thumbnail_url'] as String? ??
                                          (payload['icon'] as String?);
                                      final isSpecial =
                                          messageType == 'join' ||
                                          messageType == 'seat';
                                      final isBuffetWin =
                                          messageType == 'buffet_big_win';
                                      final isEmoji = messageType == 'emoji';
                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isBuffetWin
                                              ? const Color(0xFF129447)
                                                    .withValues(alpha: .88)
                                              : Colors.black26,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: isSpecial || isBuffetWin
                                              ? Border.all(
                                                  color:
                                                      (isBuffetWin
                                                              ? Colors
                                                                    .greenAccent
                                                              : Colors.amber)
                                                          .withValues(
                                                            alpha: .35,
                                                          ),
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
                                                    'ثروة LV${profile['wealth_level'] ?? 0}',
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
                            IconButton(
                              tooltip: 'ألعاب الغرفة',
                              onPressed: _showGamesSheet,
                              icon: const Icon(
                                Icons.sports_esports_rounded,
                                color: Color(0xFFFFD166),
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
                onGo: () => _goToLuckBag(_newLuckBag!),
                onDone: () {
                  if (mounted) setState(() => _newLuckBag = null);
                },
              ),
            if (_activeBuffetWin != null)
              Positioned(
                top: 112,
                left: 12,
                right: 12,
                child: BuffetBigWinBanner(
                  key: ValueKey(_activeBuffetWin!['id']),
                  message: _activeBuffetWin!,
                  onGo: () {
                    if (mounted) setState(() => _activeBuffetWin = null);
                    _showGamesSheet();
                  },
                  onClose: () {
                    if (mounted) setState(() => _activeBuffetWin = null);
                  },
                ),
              ),
            RoomGlobalGiftBanner(onOpenRoom: _openGlobalGiftRoom),
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
    hintStyle: const TextStyle(color: _roomMuted, fontSize: 15),
    enabledBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: _roomPrimary, width: 2),
    ),
    border: const UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
    ),
    filled: false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.white),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x14FF6B35), Color(0x1006B6D4), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
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
    final vip = activeVipLevel(widget.profile);
    if (vip >= 8) {
      // The SVGA is already a complete 420x420 circular composition. Do not
      // ClipOval it: clipping the 52px seat bounds cuts the outer rings and
      // makes the effect look like a partial glow instead of a full wave.
      return const VipSvgaAsset(
        assetPath: 'assets/vip/vip8_voice_waves.svga',
        fallbackAsset: 'assets/vip/title_vip8.png',
        size: 82,
        loop: true,
      );
    }
    final level = (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
    final colors = level >= 6
        ? const [Colors.red, Colors.amber, Colors.blue]
        : const [Color(0xFF38BDF8), Color(0xFF2563EB), Color(0xFF38BDF8)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        final size = 70 + (_controller.value * 8);
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
                    10.0 + (((i + 1) % 3) * 7) + (_controller.value * 6);
                return Container(
                  width: 4,
                  height: height,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
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
    required this.playlist,
    required this.activeMusic,
    required this.playing,
    required this.volume,
    required this.onUpload,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onNext,
    required this.onPrevious,
    required this.onAddToPlaylist,
    required this.onRemoveFromPlaylist,
    required this.onRepeat,
    required this.onShuffle,
    required this.onVolume,
    required this.onSeek,
    required this.canControl,
    required this.positionSeconds,
    required this.durationSeconds,
  });

  final List<Map<String, dynamic>> music;
  final List<Map<String, dynamic>> playlist;
  final Map<String, dynamic>? activeMusic;
  final bool playing;
  final double volume;
  final Future<void> Function() onUpload;
  final Future<void> Function(Map<String, dynamic>) onPlay;
  final Future<void> Function(Map<String, dynamic>) onPause;
  final Future<void> Function() onStop;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function(Map<String, dynamic>) onAddToPlaylist;
  final Future<void> Function(Map<String, dynamic>) onRemoveFromPlaylist;
  final Future<void> Function() onRepeat;
  final Future<void> Function() onShuffle;
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
                  IconButton(
                    tooltip: 'بحث عن أغنية',
                    onPressed: () => showSearch<void>(
                      context: context,
                      delegate: _RoomMusicSearchDelegate(music),
                    ),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white70,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Shuffle',
                        onPressed: canControl ? onShuffle : null,
                        icon: const Icon(
                          Icons.shuffle_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        tooltip: 'السابق',
                        onPressed: canControl ? onPrevious : null,
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: 'التالي',
                        onPressed: canControl ? onNext : null,
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        tooltip: 'تكرار',
                        onPressed: canControl ? onRepeat : null,
                        icon: const Icon(
                          Icons.repeat_rounded,
                          color: Color(0xFFE9B949),
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
    required this.isShippingAgent,
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
    required this.onReport,
  });

  final String username;
  final Map<String, dynamic> profile;
  final String countryFlag;
  final String gender;
  final int vip;
  final Map<String, dynamic>? familyBadge;
  final bool isShippingAgent;
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
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final isVip = vip > 0;
    final wealth = modules['wealth_level'] ?? profile['wealth_level'] ?? 0;
    final isAdmin =
        profile['is_super_admin'] == true ||
        (profile['saki_id'] as num?)?.toInt() == 1000;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 620),
      decoration: BoxDecoration(
        color: _miniProfileBg,
        image: isVip
            ? DecorationImage(
                image: AssetImage('assets/vip/profile_cards/vip$vip.jpg'),
                fit: BoxFit.cover,
                opacity: .42,
              )
            : null,
        gradient: isVip
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA111321), Color(0xEE111321)],
              )
            : null,
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        border: isVip
            ? Border.all(
                color: vipAccent(vip).withValues(alpha: .72),
                width: 1.3,
              )
            : null,
        boxShadow: isVip
            ? [
                BoxShadow(
                  color: vipAccent(vip).withValues(alpha: .25),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ]
            : null,
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
                  profile: {
                    ...profile,
                    'display_name': username,
                    'vip_level': vip,
                  },
                  fontSize: 21,
                  maxLines: 1,
                ),
                const SizedBox(height: 6),
                VipSakiId(profile: {...profile, 'vip_level': vip}),
                const SizedBox(height: 5),
                VipTitleBadge(profile: {...profile, 'vip_level': vip}),
                WealthLevelBadge(profile: profile, compact: true),
                if (isShippingAgent) ...[
                  const SizedBox(height: 5),
                  const RoleTitleBadge(label: 'وكيل شحن', compact: true),
                ],
                const SizedBox(height: 8),
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
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _RoomProfileBadge(
                      icon: Icons.diamond_rounded,
                      label: '$wealth',
                      color: const Color(0xFF00C853),
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
                if (!selfSeat)
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
                icon: Icons.alternate_email_rounded,
                onTap: selfSeat ? onClose : onMention,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomProfileNotice(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF20202D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            onReport();
          },
          child: const Row(
            children: [
              Icon(Icons.flag_rounded, color: Color(0xFFFF6B6B)),
              SizedBox(width: 12),
              Text(
                'إبلاغ عن المستخدم',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
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
  }) : darkText = false;
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

class _RoomMusicSearchDelegate extends SearchDelegate<void> {
  _RoomMusicSearchDelegate(this.tracks);
  final List<Map<String, dynamic>> tracks;

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results();

  @override
  Widget buildSuggestions(BuildContext context) => _results();

  Widget _results() {
    final needle = query.trim().toLowerCase();
    final result = tracks.where((track) {
      final title = track['title']?.toString().toLowerCase() ?? '';
      final artist = track['artist']?.toString().toLowerCase() ?? '';
      return needle.isEmpty ||
          title.contains(needle) ||
          artist.contains(needle);
    }).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: result.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, index) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.music_note)),
        title: Text(result[index]['title']?.toString() ?? 'موسيقى'),
        subtitle: Text(result[index]['artist']?.toString() ?? 'SAKI Creator'),
      ),
    );
  }
}

class BuffetBigWinBanner extends StatefulWidget {
  const BuffetBigWinBanner({
    super.key,
    required this.message,
    required this.onGo,
    required this.onClose,
  });

  final Map<String, dynamic> message;
  final VoidCallback onGo;
  final VoidCallback onClose;

  @override
  State<BuffetBigWinBanner> createState() => _BuffetBigWinBannerState();
}

class _BuffetBigWinBannerState extends State<BuffetBigWinBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payload = Map<String, dynamic>.from(
      widget.message['payload'] ?? const {},
    );
    final avatar = payload['avatar_url']?.toString() ?? '';
    final username = payload['username']?.toString() ?? 'مستخدم';
    final profit = (payload['profit'] as num?)?.toInt() ?? 0;
    final amount = _compactBuffetAmount(profit);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(
                const Color(0xFF087F23),
                const Color(0xFF35D45A),
                _pulse.value,
              )!,
              const Color(0xFF0A9F35),
              Color.lerp(
                const Color(0xFF35D45A),
                const Color(0xFF087F23),
                _pulse.value,
              )!,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: .85),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: .45),
              blurRadius: 18,
            ),
          ],
        ),
        child: child,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundImage: avatar.startsWith('http')
                ? NetworkImage(avatar)
                : null,
            child: avatar.startsWith('http')
                ? null
                : const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مبروك $username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'ربح $amount عملة ذهبية',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onGo,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF087F23),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'GO',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

String _compactBuffetAmount(int value) {
  final absolute = value.abs();
  String trim(num number) {
    final text = number.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (absolute >= 1000000000000) return '${trim(value / 1000000000000)}T';
  if (absolute >= 1000000000) return '${trim(value / 1000000000)}b';
  if (absolute >= 1000000) return '${trim(value / 1000000)}m';
  if (absolute >= 1000) return '${trim(value / 1000)}k';
  return '$value';
}
