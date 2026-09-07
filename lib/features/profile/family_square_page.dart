import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../rooms/rooms_page.dart';
import '../../shared/widgets/saki_widgets.dart';

const _familyGold = Color(0xFFFFB800);
const _familyInk = Color(0xFF171A27);
const _familyPurple = Color(0xFF7B35D4);

class FamilySquarePage extends StatefulWidget {
  const FamilySquarePage({super.key});
  @override
  State<FamilySquarePage> createState() => _FamilySquarePageState();
}

class _FamilySquarePageState extends State<FamilySquarePage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _families = [];
  Map<String, dynamic>? _myFamily;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait<dynamic>([
        _service.familySquare(),
        _service.myFamily(),
      ]);
      if (!mounted) return;
      setState(() {
        _families = List<Map<String, dynamic>>.from(result[0] as List);
        _myFamily = result[1] as Map<String, dynamic>?;
      });
    } catch (error) {
      if (mounted) _snack(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> _create() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateFamilyPage()));
    if (created == true) _load();
  }

  Future<void> _join(Map<String, dynamic> family) async {
    try {
      await _service.requestFamilyJoin(family['id'].toString());
      if (mounted) _snack('تم إرسال طلب الانضمام إلى العائلة');
    } catch (error) {
      if (mounted) _snack(error);
    }
  }

  void _openFamily(Map<String, dynamic> family) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FamilyDetailsPage(family: family)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = _families.take(3).toList();
    final rest = _families.skip(3).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _FamilyHeader(onBack: () => Navigator.pop(context)),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _familyGold),
                    )
                  : RefreshIndicator(
                      color: _familyGold,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
                        children: [
                          if (_myFamily != null)
                            _MyFamilyBanner(
                              family: _myFamily!,
                              onTap: () => _openFamily(_myFamily!),
                            ),
                          if (_myFamily != null) const SizedBox(height: 12),
                          if (top.isNotEmpty)
                            SizedBox(
                              height: 244,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: top.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (_, i) => _TopFamilyCard(
                                  family: top[i],
                                  rank: i + 1,
                                  isMine: _myFamily?['id'] == top[i]['id'],
                                  onTap: () => _openFamily(top[i]),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          const _SectionTitle(
                            title: 'جميع العائلات',
                            subtitle: 'اكتشف عائلتك وانضم إلى مجتمعك',
                          ),
                          const SizedBox(height: 8),
                          ...rest.map(
                            (family) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: _FamilyListTile(
                                family: family,
                                isMine: _myFamily?['id'] == family['id'],
                                onOpen: () => _openFamily(family),
                                onJoin: () => _join(family),
                              ),
                            ),
                          ),
                          if (_families.isEmpty) const _FamilyEmptyState(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: GestureDetector(
          onTap: _create,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFC928), Color(0xFFFF9F0A)],
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x447F5300),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Text(
              '+  أنشئ عائلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateFamilyPage extends StatefulWidget {
  const CreateFamilyPage({super.key});
  @override
  State<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends State<CreateFamilyPage> {
  final _service = SakiService.instance;
  final _name = TextEditingController();
  final _alias = TextEditingController();
  final _description = TextEditingController();
  XFile? _image;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (picked != null && mounted) setState(() => _image = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final alias = _alias.text.trim();
    if (name.length < 2 || alias.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل اسم العائلة ولقباً من 5 أحرف على الأقل'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_image != null)
        imageUrl =
            (await _service.uploadFamilyImage(_image!))?['url'] as String?;
      await _service.createFamily(
        name: name,
        alias: alias,
        description: _description.text,
        avatarUrl: imageUrl,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: const Text('إنشاء عائلة'),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: _familyInk,
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5D7),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _familyGold.withValues(alpha: .35)),
            ),
            child: _image == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        color: _familyGold,
                        size: 34,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'أضف صورة العائلة',
                        style: TextStyle(
                          color: _familyInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(File(_image!.path), fit: BoxFit.cover),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        _Field(
          controller: _name,
          label: 'اسم العائلة',
          hint: 'مثال: عائلة النخبة',
        ),
        _Field(
          controller: _alias,
          label: 'لقب العائلة / H-NAME',
          hint: '5 أحرف أو أرقام على الأقل',
        ),
        _Field(
          controller: _description,
          label: 'نبذة عن العائلة',
          hint: 'اكتب تعريفاً قصيراً عن عائلتك',
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.monetization_on_rounded, color: _familyGold),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'تكلفة إنشاء العائلة 500,000 عملة ذهبية. ستكون أنت رئيس العائلة ويحصل النظام على H-ID من 6 أرقام.',
                  style: TextStyle(
                    color: Color(0xFF854D0E),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 55,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _familyGold,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _saving ? 'جارٍ الإنشاء...' : 'إنشاء العائلة - 500K',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class FamilyDetailsPage extends StatefulWidget {
  const FamilyDetailsPage({super.key, required this.family});
  final Map<String, dynamic> family;
  @override
  State<FamilyDetailsPage> createState() => _FamilyDetailsPageState();
}

class _FamilyDetailsPageState extends State<FamilyDetailsPage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _senders = [];
  List<Map<String, dynamic>> _receivers = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.family['id'].toString();
    try {
      final results = await Future.wait([
        _service.familyMembers(id),
        _service.familyTasks(id),
        _service.familyGiftLeaderboard(id, 'sender'),
        _service.familyGiftLeaderboard(id, 'receiver'),
      ]);
      if (mounted)
        setState(() {
          _members = results[0];
          _tasks = results[1];
          _senders = results[2];
          _receivers = results[3];
        });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.family;
    final ownerRoomId = f['owner_room_id']?.toString();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 220,
              backgroundColor: _familyInk,
              foregroundColor: Colors.white,
              title: Text(f['name']?.toString() ?? 'العائلة'),
              flexibleSpace: FlexibleSpaceBar(
                background: _FamilyHero(family: f),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(14),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(
                    children: [
                      _StatBox(label: 'H-ID', value: '${f['h_id'] ?? '—'}'),
                      _StatBox(
                        label: 'المستوى',
                        value: 'LV ${f['level'] ?? 1}',
                      ),
                      _StatBox(
                        label: 'الأعضاء',
                        value: '${f['member_count'] ?? _members.length}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (ownerRoomId != null)
                    GestureDetector(
                      onTap: () async {
                        final room = await _service.client
                            .from('rooms')
                            .select(
                              'id,room_id,owner_id,name,description,country,room_type,image_url,background_url,seat_count,is_active,profiles:owner_id(username,avatar_url,vip_level,vip_expires_at)',
                            )
                            .eq('id', ownerRoomId)
                            .maybeSingle();
                        if (room != null && context.mounted)
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoomDetailPage(
                                room: Map<String, dynamic>.from(room),
                              ),
                            ),
                          );
                      },
                      child: const _OwnerRoomBanner(),
                    ),
                  const SizedBox(height: 14),
                  const _SectionTitle(
                    title: 'مهام العائلة',
                    subtitle: 'اجمعوا النقاط وارفعوا مستوى العائلة',
                  ),
                  ..._tasks.map((task) => _TaskTile(task: task)),
                  const SizedBox(height: 12),
                  _LeaderboardBlock(
                    title: 'TOP 1 مرسل هدايا',
                    rows: _senders,
                    icon: Icons.card_giftcard_rounded,
                  ),
                  const SizedBox(height: 10),
                  _LeaderboardBlock(
                    title: 'TOP 1 مستقبل هدايا',
                    rows: _receivers,
                    icon: Icons.redeem_rounded,
                  ),
                  const SizedBox(height: 12),
                  const _SectionTitle(
                    title: 'أعضاء العائلة',
                    subtitle: 'ترتيب النشاط والهدايا',
                  ),
                  ..._members
                      .take(20)
                      .map((member) => _MemberTile(member: member)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyHeader extends StatelessWidget {
  const _FamilyHeader({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    color: _familyInk,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const Expanded(
          child: Text(
            'ميدان العائلة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Icon(Icons.help_outline_rounded, color: Colors.white, size: 22),
      ],
    ),
  );
}

class _MyFamilyBanner extends StatelessWidget {
  const _MyFamilyBanner({required this.family, required this.onTap});
  final Map<String, dynamic> family;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3A245B), Color(0xFF171A27)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: _familyGold, size: 27),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'عائلتي: ${family['name'] ?? ''}\nH-ID ${family['h_id'] ?? '—'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white),
        ],
      ),
    ),
  );
}

class _TopFamilyCard extends StatelessWidget {
  const _TopFamilyCard({
    required this.family,
    required this.rank,
    required this.isMine,
    required this.onTap,
  });
  final Map<String, dynamic> family;
  final int rank;
  final bool isMine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: _familyInk,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank == 1 ? _familyGold : Colors.white24),
      ),
      child: Column(
        children: [
          Text(
            'TOP $rank',
            style: TextStyle(
              color: rank == 1 ? _familyGold : Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _FamilyAvatar(family: family, radius: 54),
          const SizedBox(height: 8),
          Text(
            family['name']?.toString() ?? 'عائلة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Text(
            '${family['member_count'] ?? 0}/${family['stars'] ?? 0}  أعضاء',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const Spacer(),
          Text(
            isMine ? 'ممثلي' : 'عرض العائلة',
            style: const TextStyle(
              color: _familyGold,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FamilyListTile extends StatelessWidget {
  const _FamilyListTile({
    required this.family,
    required this.isMine,
    required this.onOpen,
    required this.onJoin,
  });
  final Map<String, dynamic> family;
  final bool isMine;
  final VoidCallback onOpen;
  final VoidCallback onJoin;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onOpen,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E9EF)),
      ),
      child: Row(
        children: [
          Text(
            '#${family['h_id'] ?? '—'}',
            style: const TextStyle(
              color: Colors.black45,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 10),
          _FamilyAvatar(family: family, radius: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family['name']?.toString() ?? 'عائلة',
                  style: const TextStyle(
                    color: _familyInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${family['member_count'] ?? 0} عضو  •  LV ${family['level'] ?? 1}',
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: isMine ? null : onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine ? Colors.black12 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMine ? Colors.transparent : _familyGold,
                ),
              ),
              child: Text(
                isMine ? 'ممثلي' : 'انضمام',
                style: TextStyle(
                  color: isMine ? Colors.black38 : _familyGold,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FamilyAvatar extends StatelessWidget {
  const _FamilyAvatar({required this.family, required this.radius});
  final Map<String, dynamic> family;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final url = family['avatar_url']?.toString();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE7A3),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Icon(Icons.groups_rounded, color: _familyPurple, size: radius)
          : null,
    );
  }
}

class _FamilyHero extends StatelessWidget {
  const _FamilyHero({required this.family});
  final Map<String, dynamic> family;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4E2D76), _familyInk],
      ),
    ),
    child: Center(child: _FamilyAvatar(family: family, radius: 62)),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _familyInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black45, fontSize: 11),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _familyPurple,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.black45, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});
  final Map<String, dynamic> task;
  @override
  Widget build(BuildContext context) {
    final target = (task['target'] as num?)?.toDouble() ?? 1;
    final progress = (task['progress'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task['title']?.toString() ?? 'مهمة',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: _familyInk,
            ),
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            value: (progress / target).clamp(0, 1),
            color: _familyGold,
            backgroundColor: const Color(0xFFFFF3C4),
          ),
          const SizedBox(height: 5),
          Text(
            '${task['progress'] ?? 0}/${task['target'] ?? 0}  •  +${task['reward_points'] ?? 0} نقطة',
            style: const TextStyle(color: Colors.black45, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});
  final Map<String, dynamic> member;
  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(member['profiles'] ?? const {});
    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          SakiAvatar(
            url: p['avatar_url'] as String?,
            label: p['username'] as String?,
            radius: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              p['username']?.toString() ?? 'عضو',
              style: const TextStyle(
                color: _familyInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            member['role'] == 'owner' ? 'رئيس العائلة' : 'عضو',
            style: const TextStyle(
              color: _familyPurple,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardBlock extends StatelessWidget {
  const _LeaderboardBlock({
    required this.title,
    required this.rows,
    required this.icon,
  });
  final String title;
  final List<Map<String, dynamic>> rows;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: _familyGold, size: 24),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            rows.isEmpty
                ? '$title\nلا توجد بيانات بعد'
                : '$title\n${rows.first['username'] ?? 'عضو'}  •  ${rows.first['gold_total'] ?? 0} ذهب',
            style: const TextStyle(
              color: _familyInk,
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
          ),
        ),
        if (rows.isNotEmpty)
          const Icon(Icons.emoji_events_rounded, color: _familyGold),
      ],
    ),
  );
}

class _OwnerRoomBanner extends StatelessWidget {
  const _OwnerRoomBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF241936), Color(0xFF53306C)],
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.mic_rounded, color: _familyGold),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'غرفة رئيس العائلة\nاضغط للدخول إلى الغرفة',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ),
        Icon(Icons.chevron_left_rounded, color: Colors.white),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _familyInk,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    ),
  );
}

class _FamilyEmptyState extends StatelessWidget {
  const _FamilyEmptyState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(44),
    child: Column(
      children: [
        Icon(Icons.groups_rounded, color: Colors.black26, size: 54),
        SizedBox(height: 10),
        Text(
          'لا توجد عائلات بعد',
          style: TextStyle(color: Colors.black45, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
