import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import 'agora_audio_room_page.dart';
import 'room_settings_page.dart';
import 'room_gifts_sheet.dart';
import '../../shared/widgets/saki_widgets.dart';

const _roomPrimary = Color(0xFF8B5CF6);
const _roomSecondary = Color(0xFFEC4899);
const _roomAccent = Color(0xFFF59E0B);
const _roomBg = Color(0xFFF8FAFC);
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
  bool _loading = true;
  bool _followingOnly = false;
  String _country = 'الكل';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rooms = await _service.rooms();
      List<Map<String, dynamic>> banners = [];
      try {
        banners = await _service.roomBanners();
      } catch (_) {
        // Banners are optional; never hide the real room list if they fail.
      }
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _banners = banners;
        });
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل الغرف من Supabase')),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visibleRooms {
    final cutoff = DateTime.now().subtract(const Duration(days: 2));
    final query = _searchQuery.trim().toLowerCase();
    return _rooms.where((room) {
      final name = (room['name'] as String? ?? '').toLowerCase();
      final country = (room['country'] as String? ?? '').toLowerCase();
      final matchesSearch =
          query.isEmpty || name.contains(query) || country.contains(query);
      final matchesCountry =
          _country == 'الكل' || country.contains(_country.toLowerCase());
      final created = DateTime.tryParse(room['created_at'] as String? ?? '');
      final members = List<Map<String, dynamic>>.from(
        room['room_members'] ?? const [],
      );
      final matchesFollowing =
          !_followingOnly ||
          members.any((member) => member['user_id'] == _service.uid);
      return matchesSearch &&
          matchesCountry &&
          matchesFollowing &&
          (!_followingOnly || (created != null && created.isAfter(cutoff)));
    }).toList();
  }

  Future<void> _search() async {
    final controller = TextEditingController(text: _searchQuery);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'البحث في الغرف',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'اسم الغرفة أو الدولة',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('مسح'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('بحث'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) setState(() => _searchQuery = result);
  }

  Future<void> _create() async {
    final owned = await _service.myOwnedRoom();
    if (!mounted) return;
    if (owned != null) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: owned)));
      return;
    }
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateRoomPage()),
    );
    if (!mounted || created == null) return;
    await _load();
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: created)));
  }

  void _ranking(String title, FaIconData icon) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            FaIcon(icon, color: _roomPrimary, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم ترتيب الغرف والحسابات من البيانات الحقيقية في Supabase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _roomMuted),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countries = ['الكل', 'السعودية', 'المغرب', 'مصر', 'الإمارات'];
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
              onTap: () => setState(() => _followingOnly = false),
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
                  SliverToBoxAdapter(
                    child: RoomBannerCarousel(banners: _banners),
                  ),
                  SliverToBoxAdapter(child: _RoomRankings(onTap: _ranking)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 54,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 5, 16, 6),
                        scrollDirection: Axis.horizontal,
                        itemCount: countries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, index) {
                          final selected = countries[index] == _country;
                          return ChoiceChip(
                            label: Text(countries[index]),
                            selected: selected,
                            selectedColor: _roomPrimary,
                            labelStyle: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF4B5563),
                              fontWeight: FontWeight.w800,
                            ),
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? _roomPrimary
                                  : const Color(0xFFE5E7EB),
                            ),
                            onSelected: (_) =>
                                setState(() => _country = countries[index]),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Chip(
                            label: Text(_searchQuery),
                            onDeleted: () => setState(() => _searchQuery = ''),
                          ),
                        ),
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
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      sliver: SliverGrid.builder(
                        itemCount: _visibleRooms.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 14,
                              mainAxisSpacing: 14,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (_, index) => HtmlRoomCard(
                          room: _visibleRooms[index],
                          rank: index + 1,
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

class _RoomRankings extends StatelessWidget {
  const _RoomRankings({required this.onTap});
  final void Function(String, FaIconData) onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _RankingItem(
          icon: FontAwesomeIcons.layerGroup,
          title: 'ترتيب الثروة',
          colors: const [Color(0xFFFFF7CD), Color(0xFFFCD34D)],
          onTap: () => onTap('ترتيب الثروة', FontAwesomeIcons.layerGroup),
        ),
        _RankingItem(
          icon: FontAwesomeIcons.heart,
          title: 'ترتيب السحر',
          colors: const [Color(0xFFFCE7F3), Color(0xFFF9A8D4)],
          onTap: () => onTap('ترتيب السحر', FontAwesomeIcons.heart),
        ),
        _RankingItem(
          icon: FontAwesomeIcons.crown,
          title: 'ترتيب الغرف',
          colors: const [Color(0xFFEDE9FE), Color(0xFFC4B5FD)],
          onTap: () => onTap('ترتيب الغرف', FontAwesomeIcons.crown),
        ),
      ],
    ),
  );
}

class _RankingItem extends StatelessWidget {
  const _RankingItem({
    required this.icon,
    required this.title,
    required this.colors,
    required this.onTap,
  });
  final FaIconData icon;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(17),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: FaIcon(icon, color: Colors.white, size: 26)),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF374151),
          ),
        ),
      ],
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
                    errorBuilder: (_, __, ___) => const DecoratedBox(
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

class HtmlRoomCard extends StatelessWidget {
  const HtmlRoomCard({super.key, required this.room, required this.rank});
  final Map<String, dynamic> room;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(room['profiles'] ?? const {});
    final name = room['name'] as String? ?? 'غرفة SAKI';
    final image = room['image_url'] as String?;
    final members = room['_members_count'] as int? ?? 0;
    final country = room['country'] as String? ?? '🌐';
    final badge = rank <= 3 ? 'TOP $rank' : null;
    final badgeColors = rank == 1
        ? const [Color(0xFFFFD700), Color(0xFFFFA500)]
        : rank == 2
        ? const [Color(0xFFE0E0E0), Color(0xFF9E9E9E)]
        : const [Color(0xFFCD7F32), Color(0xFF8B4513)];
    return InkWell(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => RoomDetailPage(room: room))),
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image == null || image.isEmpty
                ? const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_roomPrimary, _roomSecondary],
                      ),
                    ),
                  )
                : Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const DecoratedBox(
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
                  colors: [
                    Color(0xE6000000),
                    Color(0x66000000),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: badgeColors),
                    borderRadius: const BorderRadius.only(
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: SakiAvatar(
                url: profile['avatar_url'] as String?,
                label: profile['username'] as String?,
                radius: 17,
              ),
            ),
            Positioned(
              top: 8,
              right: 48,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  country,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 11,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _RoomWave(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.headphones,
                              color: Colors.white,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$members',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
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
          ],
        ),
      ),
    );
  }
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
      builder: (_, __) {
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
  late final String _roomId = widget.room['id'] as String;
  late final Stream<List<Map<String, dynamic>>> _seatStream;
  late final Stream<List<Map<String, dynamic>>> _roomSettingsStream;
  StreamSubscription<List<Map<String, dynamic>>>? _roomSettingsSubscription;
  late final Stream<List<Map<String, dynamic>>> _messageStream;
  bool _joined = false;
  bool _busy = false;
  bool _followed = false;
  RtcEngine? _engine;
  bool _audioJoined = false;
  bool _isOnSeat = false;
  bool _micMuted = true;
  bool _listenMuted = false;
  bool _isComposing = false;
  int _comboSeconds = 0;
  Timer? _comboTimer;
  String? _lastGiftRecipient;
  Map<String, dynamic>? _lastGift;
  final Set<int> _remoteUsers = <int>{};
  late int _liveSeatCount;
  String? _liveBackgroundUrl;

  @override
  void initState() {
    super.initState();
    _seatStream = _service.roomSeatsStream(_roomId);
    _roomSettingsStream = _service.roomSettingsStream(_roomId);
    _liveSeatCount = (widget.room['seat_count'] as num?)?.toInt() ?? 10;
    _liveBackgroundUrl = widget.room['background_url'] as String?;
    _roomSettingsSubscription = _roomSettingsStream.listen((rows) {
      if (!mounted || rows.isEmpty) return;
      final updated = rows.first;
      setState(() {
        _liveSeatCount =
            (updated['seat_count'] as num?)?.toInt() ?? _liveSeatCount;
        _liveBackgroundUrl = updated['background_url'] as String?;
      });
    });
    _messageStream = _service.roomMessagesStream(_roomId);
    _join();
    _loadRoomState();
    _startRoomAudio();
  }

  int _numericUid(String value) {
    final compact = value.replaceAll('-', '');
    final prefix = compact.length > 8 ? compact.substring(0, 8) : compact;
    return int.parse(prefix, radix: 16) & 0x7fffffff;
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
      if (appId == null || token == null || appId.isEmpty || token.isEmpty)
        return;
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
          onJoinChannelSuccess: (_, __) {
            if (mounted) setState(() => _audioJoined = true);
          },
          onUserJoined: (_, remoteUid, __) {
            if (mounted) setState(() => _remoteUsers.add(remoteUid));
          },
          onUserOffline: (_, remoteUid, __) {
            if (mounted) setState(() => _remoteUsers.remove(remoteUid));
          },
          onTokenPrivilegeWillExpire: (_, __) => _refreshRoomToken(),
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

  Future<void> _setSeatAudio(bool seated) async {
    _isOnSeat = seated;
    if (!seated) {
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
      backgroundColor: Colors.transparent,
      builder: (_) => RoomGiftsSheet(
        service: _service,
        roomId: _roomId,
        onSent: (recipientId, gift) async {
          _lastGiftRecipient = recipientId;
          _lastGift = gift;
          await _service.sendRoomGift(
            roomId: _roomId,
            recipientId: recipientId,
            giftId: gift['id'] as String,
          );
          await _service.sendRoomMessage(
            _roomId,
            'أرسل ${gift['icon'] ?? '🎁'} ${gift['name'] ?? 'هدية'}',
            type: 'gift',
            payload: {
              'gift_id': gift['id'],
              'icon': gift['icon'],
              'name': gift['name'],
            },
          );
        },
      ),
    );
    if (sent == true) _startGiftCombo();
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
    try {
      await _service.sendRoomGift(
        roomId: _roomId,
        recipientId: recipient,
        giftId: gift['id'] as String,
      );
      await _service.sendRoomMessage(
        _roomId,
        'أرسل ${gift['icon'] ?? '🎁'} ${gift['name'] ?? 'هدية'}',
        type: 'gift',
        payload: {
          'gift_id': gift['id'],
          'icon': gift['icon'],
          'name': gift['name'],
        },
      );
      _startGiftCombo();
    } catch (e) {
      _messageSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _loadRoomState() async {
    try {
      final followed = await _service.isFollowingRoom(_roomId);
      if (mounted) setState(() => _followed = followed);
    } catch (_) {}
  }

  Future<void> _join() async {
    try {
      await _service.joinRoom(_roomId);
      await _service.sendRoomMessage(_roomId, 'انضم إلى الغرفة', type: 'join');
      if (mounted) setState(() => _joined = true);
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
    await _service.sendRoomMessage(_roomId, body);
    if (mounted) setState(() => _isComposing = false);
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF291018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'مغادرة الغرفة؟',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'يمكنك الخروج من الغرفة أو الاحتفاظ بها مفتوحة أثناء استخدام التطبيق.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('احتفظ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    if (result == true) {
      await _service.leaveRoom(_roomId);
      return true;
    }
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
                        if (mounted) setState(() => _followed = !_followed);
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomSettingsPage(room: widget.room, service: _service),
      ),
    );
  }

  Future<void> _showUserCard(Map<String, dynamic> profile) async {
    if (profile.isEmpty) return;
    final userId = profile['id'] as String?;
    if (userId == null) return;
    final isOwner = widget.room['owner_id'] == _service.uid;
    final canModerate = isOwner && userId != _service.uid;
    final vip = (profile['vip_level'] as num?)?.toInt() ?? 0;
    final followers = profile['followers_count'] ?? profile['followers'] ?? 0;
    final gender =
        (profile['gender']?.toString().toLowerCase() == 'male' ||
            profile['gender']?.toString() == 'ذكر')
        ? '♂'
        : '♀';
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFFFE7A3)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66D4AF37),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _messageSnack('تم إرسال البلاغ للمراجعة.');
                  },
                  icon: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF9A6B00),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _profileRing(profile, const Color(0xFFD4AF37)),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF4C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFFD4AF37),
                            size: 17,
                          ),
                        ),
                        _profileRing(
                          profile['cp_profile'] is Map
                              ? Map<String, dynamic>.from(profile['cp_profile'])
                              : null,
                          const Color(0xFFEC4899),
                          cp: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profile['username'] as String? ?? 'مستخدم',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF3F2A12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          gender,
                          style: TextStyle(
                            color: gender == '♂' ? Colors.blue : Colors.pink,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _pill('VIP $vip', const [
                          Color(0xFFF59E0B),
                          Color(0xFFD4AF37),
                        ]),
                        _pill('اللورد', const [
                          Color(0xFF7C3AED),
                          Color(0xFF4C1D95),
                        ]),
                        _pill('★ Lv.${profile['level'] ?? 21}', const [
                          Color(0xFF22C55E),
                          Color(0xFF15803D),
                        ]),
                        _pill('🔥 ${profile['charisma'] ?? '99k'}', const [
                          Color(0xFFF472B6),
                          Color(0xFFDB2777),
                        ]),
                        Text(
                          profile['country_flag'] as String? ??
                              profile['country'] as String? ??
                              '🌍',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${profile['saki_id'] ?? '—'}   │   المتابعون: $followers',
                      style: const TextStyle(
                        color: Color(0xFF8A5A00),
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                    if (profile['is_super_admin'] == true ||
                        (profile['saki_id'] as num?)?.toInt() == 1000)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: SuperAdminBadge(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _roundAction(
                          Icons.alternate_email,
                          Colors.lightBlue,
                          () {},
                        ),
                        _roundAction(
                          Icons.chat_bubble_rounded,
                          Colors.green,
                          () {},
                        ),
                        _roundAction(
                          Icons.person_rounded,
                          Colors.deepPurple,
                          () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showGiftPanel();
                            },
                            icon: const Icon(Icons.card_giftcard),
                            label: const Text('أرسل هدايا'),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _messageSnack('تم إرسال طلب المتابعة.');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('متابعة'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade600),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (canModerate) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(color: Color(0x66C9A227)),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _adminIcon(Icons.shield_rounded, 'مشرف', () async {
                            await _service.addRoomModerator(_roomId, userId);
                            if (mounted) Navigator.pop(context);
                          }),
                          _adminIcon(Icons.mic_off_rounded, 'مايك', () async {
                            await _service.roomMute(_roomId, userId, null);
                            if (mounted) Navigator.pop(context);
                          }),
                          _adminIcon(
                            Icons.chat_bubble_outline_rounded,
                            'دردشة',
                            () async {
                              await _service.roomMute(_roomId, userId, null);
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                          _adminIcon(
                            Icons.phone_disabled_rounded,
                            'دعوة',
                            () async {
                              await _service.inviteToRoomSeat(_roomId, userId);
                              if (mounted) Navigator.pop(context);
                            },
                          ),
                          _adminIcon(Icons.logout_rounded, 'طرد', () async {
                            await _service.roomBan(
                              _roomId,
                              userId,
                              const Duration(minutes: 1),
                            );
                            if (mounted) Navigator.pop(context);
                          }),
                          _adminIcon(Icons.block_rounded, 'حظر', () async {
                            final d = await _banDuration();
                            if (d != null)
                              await _service.roomBan(_roomId, userId, d);
                            if (mounted) Navigator.pop(context);
                          }),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRing(
    Map<String, dynamic>? p,
    Color color, {
    bool cp = false,
  }) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
        ),
        child: SakiAvatar(
          url: p?['avatar_url'] as String?,
          label: p?['username'] as String?,
          radius: 30,
        ),
      ),
      if (cp)
        Positioned(
          right: -5,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.pink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'CP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
    ],
  );
  Widget _pill(String text, List<Color> colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
  Widget _roundAction(IconData icon, Color color, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white,
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      );
  Widget _adminIcon(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Column(
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Colors.white,
          child: Icon(icon, size: 17, color: const Color(0xFF8A5A00)),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 8, color: Color(0xFF6B4A12)),
        ),
      ],
    ),
  );

  Widget _userAction(String label, IconData icon, VoidCallback action) =>
      ListTile(
        leading: Icon(icon, color: Colors.amberAccent),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        onTap: action,
      );

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

  Future<void> _showEmojiPanel() async {
    final seats = await _service.roomSeats(_roomId);
    if (!mounted) return;
    final canSpeak = seats.any((seat) => seat['user_id'] == _service.uid);
    if (!canSpeak) {
      _messageSnack('اصعد إلى مقعد لاستخدام الإيموجي.');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 18,
            runSpacing: 16,
            children: ['❤️', '😂', '🔥', '👏', '😍', '🎉', '👍', '😮', '💎']
                .map(
                  (emoji) => InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      _service.sendRoomMessage(
                        _roomId,
                        emoji,
                        type: 'emoji',
                        payload: {'emoji': emoji},
                      );
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _messageSnack(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));

  Future<void> _showRoomTools() async {
    final owner = widget.room['owner_id'] == _service.uid;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF3D0B12),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _toolButton(
                Icons.music_note,
                'موسيقى',
                () => Navigator.pop(context),
              ),
              if (owner)
                _toolButton(Icons.delete_sweep, 'مسح الدردشة', () {
                  Navigator.pop(context);
                  _confirmClearChat();
                }),
              _toolButton(Icons.casino, 'نرد', () {
                Navigator.pop(context);
                final value = Random().nextInt(6) + 1;
                _service.sendRoomMessage(
                  _roomId,
                  '🎲 النرد: $value',
                  type: 'dice',
                  payload: {'value': value},
                );
              }),
              _toolButton(
                Icons.card_giftcard,
                'هدايا',
                () => Navigator.pop(context),
              ),
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
    if (yes == true) await _service.clearRoomMessages(_roomId);
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
        await _service.claimRoomSeat(_roomId, seatNo);
        await _setSeatAudio(true);
        await _service.sendRoomMessage(_roomId, 'صعد إلى المقعد', type: 'seat');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showOnline() async {
    final rows = await _service.client
        .from('room_members')
        .select('user_id,joined_at,profiles:user_id(username,avatar_url)')
        .eq('room_id', _roomId);
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
            ...List<Map<String, dynamic>>.from(rows).map((row) {
              final profile = Map<String, dynamic>.from(
                row['profiles'] ?? const {},
              );
              return ListTile(
                leading: SakiAvatar(
                  url: profile['avatar_url'] as String?,
                  label: profile['username'] as String?,
                ),
                title: Text(
                  profile['username'] as String? ?? 'عضو',
                  style: const TextStyle(color: Colors.white),
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
    _message.dispose();
    _comboTimer?.cancel();
    _roomSettingsSubscription?.cancel();
    if (_joined) _service.leaveRoom(_roomId);
    _engine?.leaveChannel();
    _engine?.release();
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
    return WillPopScope(
      onWillPop: () async => await _confirmExit(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4A0E17),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: backgroundColors,
            ),
            image: backgroundUrl == null || backgroundUrl.startsWith('free://')
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
                        onPressed: _showOnline,
                        icon: const Icon(
                          Icons.people_alt_outlined,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (await _confirmExit() && mounted)
                            Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_comboSeconds > 0)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: 18,
                        bottom: 4,
                      ),
                      child: InkWell(
                        onTap: _sendComboAgain,
                        borderRadius: BorderRadius.circular(32),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.orangeAccent,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'COMBO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '$_comboSeconds',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _seatStream,
                  builder: (_, snap) {
                    final seats = {
                      for (final row in (snap.data ?? []))
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
                          return GestureDetector(
                            onTap: () => _seatAction(seatNo, row),
                            child: Column(
                              children: [
                                Container(
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
                                              onTap: () =>
                                                  _showUserCard(profile),
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
                                          ],
                                        )
                                      : const Icon(
                                          Icons.mic_none_rounded,
                                          color: Colors.white70,
                                        ),
                                ),
                                const SizedBox(height: 4),
                                occupied
                                    ? VipUsername(
                                        profile: profile,
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
                      final messages = [...(snap.data ?? [])]
                        ..sort(
                          (a, b) =>
                              (DateTime.tryParse(
                                        a['created_at']?.toString() ?? '',
                                      ) ??
                                      DateTime.fromMillisecondsSinceEpoch(0))
                                  .compareTo(
                                    DateTime.tryParse(
                                          b['created_at']?.toString() ?? '',
                                        ) ??
                                        DateTime.fromMillisecondsSinceEpoch(0),
                                  ),
                        );
                      return ListView.builder(
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
                          final senderId = msg['sender_id'] as String? ?? '';
                          final messageType =
                              msg['message_type'] as String? ?? 'chat';
                          return FutureBuilder<Map<String, dynamic>?>(
                            future: _service.userProfile(senderId),
                            builder: (_, profileSnap) {
                              final profile =
                                  profileSnap.data ?? const <String, dynamic>{};
                              final username =
                                  profile['username'] as String? ?? 'عضو';
                              final body = msg['body'] as String? ?? '';
                              final payload = Map<String, dynamic>.from(
                                msg['payload'] ?? const {},
                              );
                              final isSpecial =
                                  messageType == 'join' ||
                                  messageType == 'seat';
                              final isEmoji = messageType == 'emoji';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isSpecial
                                      ? Border.all(
                                          color: Colors.amber.withValues(
                                            alpha: .35,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () => _showUserCard(profile),
                                      child: SakiAvatar(
                                        url: profile['avatar_url'] as String?,
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
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          messageType == 'dice'
                                              ? _DiceFace(
                                                  value:
                                                      (payload['value'] as num?)
                                                          ?.toInt() ??
                                                      1,
                                                )
                                              : Text(
                                                  body,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: isEmoji ? 28 : 13,
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
                            autofocus: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'كتابة رسالة...',
                              hintStyle: const TextStyle(color: Colors.white54),
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
                            onTap: () => setState(() => _isComposing = true),
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
                        IconButton(
                          onPressed: _showGiftPanel,
                          icon: const Icon(
                            Icons.card_giftcard_rounded,
                            color: Colors.pinkAccent,
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
      if (mounted)
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
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
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
      builder: (_, __) {
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
