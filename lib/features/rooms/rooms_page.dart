import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
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
      final results = await Future.wait<dynamic>([
        _service.rooms(),
        _service.roomBanners(),
      ]);
      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(results[0] as List);
          _banners = List<Map<String, dynamic>>.from(results[1] as List);
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
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateRoomSheet(),
    );
    if (created == true) _load();
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
  final _message = TextEditingController();
  late final String _roomId = widget.room['id'] as String;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final data = await SakiService.instance.client
        .from('room_messages')
        .select(
          'id,body,created_at,sender_id,profiles:sender_id(username,avatar_url)',
        )
        .eq('room_id', _roomId)
        .order('created_at')
        .limit(100);
    if (mounted)
      setState(() => _messages = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) return;
    await SakiService.instance.client.from('room_messages').insert({
      'room_id': _roomId,
      'sender_id': SakiService.instance.uid,
      'body': _message.text.trim(),
    });
    _message.clear();
    _loadMessages();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.room['name'] as String? ?? 'الغرفة')),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'الغرفة هادئة الآن',
                    subtitle: 'أرسل أول رسالة صوتية كتابية.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final message = _messages[index];
                      final profile = Map<String, dynamic>.from(
                        message['profiles'] ?? const {},
                      );
                      return ListTile(
                        leading: SakiAvatar(
                          url: profile['avatar_url'] as String?,
                          label: profile['username'] as String?,
                        ),
                        title: Text(profile['username'] as String? ?? 'عضو'),
                        subtitle: Text(message['body'] as String? ?? ''),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    decoration: const InputDecoration(
                      hintText: 'اكتب في الغرفة...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send_rounded, color: SakiColors.cyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _country = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  String _type = 'public';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _country.dispose();
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
      setState(() => _error = 'اكتب اسم الغرفة.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SakiService.instance.createRoom(
        name: _name.text,
        description: _description.text,
        country: _country.text,
        type: _type,
        image: _image,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر إنشاء الغرفة في Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SakiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'إنشاء غرفة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _image == null ? 'صورة الغرفة' : 'تم اختيار الصورة',
                ),
              ),
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(_image!.path),
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الغرفة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'وصف الغرفة'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _country,
                decoration: const InputDecoration(labelText: 'الدولة'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('نوع الغرفة'),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _type,
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('عامة')),
                      DropdownMenuItem(value: 'private', child: Text('خاصة')),
                    ],
                    onChanged: (value) =>
                        setState(() => _type = value ?? 'public'),
                  ),
                ],
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: SakiTheme.gradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'إنشاء الغرفة',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
