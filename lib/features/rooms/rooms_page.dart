import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';
import '../search/search_page.dart';
import 'ranking_page.dart';
import 'room_gift_ranking_sheet.dart';
import 'zego_live_audio_room_page.dart';
import 'zego_live_streaming_page.dart';
import '../profile/vip_widgets.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

import '../../shared/widgets/custom_toast.dart';

Widget _zegoRoomDestination(Map<String, dynamic> room) {
  final type = room['room_type']?.toString() ?? 'audio';
  if (type == 'live') return zegoLiveStreamingPageFor(room);
  return zegoRoomPageFor(room);
}

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
  Timer? _roomApiPollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _roomApiPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refreshRoomsOnly();
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
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, 'تعذر تحميل الغرف: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _roomPresenceSubscription?.cancel();
    _roomRefreshTimer?.cancel();
    _roomApiPollTimer?.cancel();
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
    try {
      final owned = await _service.myOwnedRoom();
      if (!mounted) return;
      if (owned != null) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => _zegoRoomDestination(owned)));
        return;
      }
      final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreateRoomPage()),
      );
      if (!mounted || created == null) return;
      await _load();
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => _zegoRoomDestination(created)));
    } catch (error) {
      if (mounted) CustomToast.show(context, 'تعذر فتح إنشاء الغرفة: $error');
    }
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
      if (!context.mounted) return;
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => _zegoRoomDestination(room)));
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
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _zegoRoomDestination(widget.room)),
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
    final roomCode = room['room_id']?.toString() ?? '';
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
                  if (roomCode.isNotEmpty)
                    Text(
                      'room_id: $roomCode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
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

class LuckMultiplierOverlay extends StatefulWidget {
  const LuckMultiplierOverlay({
    super.key,
    required this.message,
    required this.onClose,
  });
  final Map<String, dynamic> message;
  final VoidCallback onClose;
  @override
  State<LuckMultiplierOverlay> createState() => _LuckMultiplierOverlayState();
}

class _LuckMultiplierOverlayState extends State<LuckMultiplierOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..forward();
  Map<String, dynamic> get payload =>
      Map<String, dynamic>.from(widget.message['payload'] ?? const {});
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), widget.onClose);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: .88),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Opacity(
            opacity: (1 - _controller.value).clamp(.25, 1),
            child: Transform.scale(
              scale: .82 + _controller.value * .22,
              child: child,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 18; i++)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment((i % 6) / 2.5 - 1, (i % 3) / 1.8 - .8),
                    child: Text(
                      i.isEven ? '✦' : '•',
                      style: TextStyle(
                        color: [
                          Colors.amberAccent,
                          Colors.orangeAccent,
                          Colors.pinkAccent,
                          Colors.cyanAccent,
                        ][i % 4],
                        fontSize: 18 + (i % 4) * 8,
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'مبروك!',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SakiAvatar(
                    url: payload['recipient_avatar_url']?.toString(),
                    label: payload['recipient_username']?.toString(),
                    radius: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لقد حصل ${payload['recipient_username'] ?? 'المستخدم'} على ضعف',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '×${payload['multiplier']}  •  ${payload['reward_gold']} عملة ذهبية',
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
    _flightTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _flyingToSeat = true);
    });
    _flightHideTimer = Timer(const Duration(milliseconds: 820), () {
      if (mounted) setState(() => _flightVisible = false);
    });
    _bannerTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _bannerLeaving = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _bannerEntered = true);
    });
    if (_compactGift) {
      Future<void>.delayed(const Duration(milliseconds: 1900), _hide);
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
          duration: const Duration(milliseconds: 260),
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
              if (_payload['flying_banner'] != false)
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
                    duration: const Duration(milliseconds: 220),
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
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
                                thumbnail != null &&
                                        thumbnail.startsWith('http')
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
                                const SizedBox(width: 8),
                                Text(
                                  '×${(_payload['combo_count'] as num?)?.toInt() ?? 1}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black87,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 190,
                                height: 4,
                                child: LinearProgressIndicator(
                                  value:
                                      (((_payload['combo_count'] as num?)
                                                      ?.toDouble() ??
                                                  1) /
                                              10)
                                          .clamp(0.08, 1.0),
                                  backgroundColor: Colors.white24,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF34D399),
                                      ),
                                ),
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
  String _accessType = 'public';
  String _roomMode = 'audio';
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
        type: _roomMode,
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

  Widget _modeCard({
    required String mode,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _roomMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _roomMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4C1D95) : const Color(0x66111827),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFFFED100) : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFFFED100) : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
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
                    const Text(
                      'نوع البث والغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _modeCard(
                          mode: 'audio',
                          title: 'غرفة صوتية',
                          subtitle: 'مقاعد ودردشة وهدايا',
                          icon: Icons.mic_rounded,
                        ),
                        _modeCard(
                          mode: 'party',
                          title: 'حفلة مباشرة',
                          subtitle: 'غرفة حفلة متعددة المقاعد',
                          icon: Icons.celebration_rounded,
                        ),
                        _modeCard(
                          mode: 'live',
                          title: 'بث مباشر',
                          subtitle: 'كاميرا وفيديو وهدايا وPK',
                          icon: Icons.videocam_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
                          value: _accessType,
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
                              setState(() => _accessType = value ?? 'public'),
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
            profile: widget.profile,
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
