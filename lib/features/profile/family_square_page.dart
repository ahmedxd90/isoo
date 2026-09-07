import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _autoOpened = false;

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
      if (_myFamily != null && !_autoOpened && mounted) {
        _autoOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _myFamily != null) _openFamily(_myFamily!);
        });
      }
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

class _FamilyDetailsPageState extends State<FamilyDetailsPage>
    with SingleTickerProviderStateMixin {
  final _service = SakiService.instance;
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _senders = [];
  String _notice = 'رمز تغير 4499';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.family['id']?.toString();
    if (id == null) return;
    try {
      final result = await Future.wait<dynamic>([
        _service.familyMembers(id),
        _service.familyTasks(id),
        _service.familyGiftLeaderboard(id, 'sender'),
      ]);
      if (!mounted) return;
      setState(() {
        _members = List<Map<String, dynamic>>.from(result[0] as List);
        _tasks = List<Map<String, dynamic>>.from(result[1] as List);
        _senders = List<Map<String, dynamic>>.from(result[2] as List);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  String _text(Object? value, [String fallback = '—']) =>
      value?.toString().trim().isNotEmpty == true ? value.toString() : fallback;

  String? _avatar(Map<String, dynamic> row) {
    final profile = row['profiles'] is Map
        ? Map<String, dynamic>.from(row['profiles'])
        : row;
    final value = profile['avatar_url']?.toString();
    return value == null || value.isEmpty ? null : value;
  }

  void _showTasks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FamilyTasksSheet(
        tasks: _tasks,
        familyName: _text(widget.family['name'], 'عائلتنا'),
      ),
    );
  }

  void _showMember(Map<String, dynamic> member, {String? badge}) {
    final profile = member['profiles'] is Map
        ? Map<String, dynamic>.from(member['profiles'])
        : member;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MemberProfileSheet(
        name: _text(profile['username'], 'عضو العائلة'),
        role: member['role'] == 'owner' ? 'رئيس العائلة' : 'عضو العائلة',
        badge: badge ?? (member['role'] == 'owner' ? 'رئيس' : 'عضو'),
        avatarUrl: _avatar(member),
      ),
    );
  }

  Future<void> _copyId() async {
    final id = _text(widget.family['h_id']);
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نسخ ID العائلة')));
    }
  }

  Future<void> _editNotice() async {
    final controller = TextEditingController(text: _notice);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إشعار العائلة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty && mounted)
      setState(() => _notice = value);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.family;
    final current =
        (_senders.isNotEmpty ? _senders.first['total'] : null) as num? ?? 0;
    final max = 6000000000.0;
    final progress = (current / max).clamp(0.0, 1.0).toDouble();
    final visibleMembers = _members.take(8).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          color: _familyGold,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _FamilyRoyalHeader(
                  family: f,
                  onBack: () => Navigator.pop(context),
                  onCopy: _copyId,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Transform.translate(
                      offset: const Offset(0, -12),
                      child: _PremiumCard(
                        child: Column(
                          children: [
                            _SectionHeading(
                              title: 'عضو العائلة ${_members.length}/1050',
                              icon: Icons.groups_rounded,
                            ),
                            const SizedBox(height: 12),
                            if (_loading)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(
                                  color: _familyGold,
                                ),
                              )
                            else if (visibleMembers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('لا يوجد أعضاء بعد'),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: visibleMembers.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisExtent: 92,
                                      crossAxisSpacing: 7,
                                    ),
                                itemBuilder: (_, i) {
                                  final member = visibleMembers[i];
                                  final profile = member['profiles'] is Map
                                      ? Map<String, dynamic>.from(
                                          member['profiles'],
                                        )
                                      : member;
                                  final owner = member['role'] == 'owner';
                                  return GestureDetector(
                                    onTap: () => _showMember(member),
                                    child: _MemberAvatarTile(
                                      name: _text(profile['username'], 'عضو'),
                                      avatarUrl: _avatar(member),
                                      owner: owner,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    _PremiumCard(
                      child: Row(
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            color: _familyGold,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'إشعار العائلة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: _familyInk,
                                  ),
                                ),
                                Text(
                                  _notice,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _editNotice,
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'دعم العائلة',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _familyInk,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SupportCard(
                      progress: progress,
                      current: current,
                      animation: _progress,
                      onTasks: _showTasks,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'أفضل الداعمين',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _familyInk,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SupportersRow(
                      rows: _senders.take(3).toList(),
                      onTap: _showMember,
                    ),
                    const SizedBox(height: 14),
                    if (_tasks.isNotEmpty)
                      _PremiumCard(
                        child: GestureDetector(
                          onTap: _showTasks,
                          child: Row(
                            children: [
                              const Text('🎁', style: TextStyle(fontSize: 25)),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'مهام العائلة اليومية\nأكمل المهام لزيادة مستوى العائلة',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_left_rounded),
                            ],
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyRoyalHeader extends StatelessWidget {
  const _FamilyRoyalHeader({
    required this.family,
    required this.onBack,
    required this.onCopy,
  });
  final Map<String, dynamic> family;
  final VoidCallback onBack;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final avatar = family['avatar_url']?.toString();
    return Container(
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.35),
          radius: 1.25,
          colors: [Color(0xFF5B1E88), Color(0xFF240A42), Color(0xFF120422)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (_) => const SafeArea(
                    child: ListTile(title: Text('خيارات العائلة')),
                  ),
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                ),
              ),
              const Expanded(
                child: Text(
                  'عائلة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (avatar == null)
                Container(
                  width: 104,
                  height: 104,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFF996515)],
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircleAvatar(
                      backgroundColor: _familyPurple,
                      child: Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 104,
                  height: 104,
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFFD700),
                        Color(0xFFFFFFFF),
                        Color(0xFF996515),
                      ],
                    ),
                  ),
                  child: CircleAvatar(backgroundImage: NetworkImage(avatar)),
                ),
              const Positioned(
                top: -19,
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD54F),
                  size: 32,
                ),
              ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7E22CE), Color(0xFF4338CA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _familyGold, width: 2),
                  ),
                  child: Text(
                    'Lv.${family['level'] ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _familyPurple,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _familyGold),
                ),
                child: Text(
                  '${family['level'] ?? 0}',
                  style: const TextStyle(
                    color: _familyGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                family['name']?.toString() ?? 'عائلتنا',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.copy_rounded,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${family['h_id'] ?? '—'}  :ايدي العائلة',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoyalPill(
                icon: Icons.shield_rounded,
                label: 'Lv.${family['level'] ?? 0}',
              ),
              const SizedBox(width: 10),
              _RoyalPill(
                icon: Icons.emoji_events_rounded,
                label: '${family['rank'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoyalPill extends StatelessWidget {
  const _RoyalPill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _familyGold.withValues(alpha: .45)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 14, color: _familyGold),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: _familyGold,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFEFF1F5)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D1F2937),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.icon});
  final String title;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: _familyGold),
      const SizedBox(width: 7),
      Text(
        title,
        style: const TextStyle(
          color: _familyInk,
          fontWeight: FontWeight.w900,
          fontSize: 13,
        ),
      ),
      const Spacer(),
      const Icon(Icons.chevron_left_rounded, size: 18, color: Colors.black38),
    ],
  );
}

class _MemberAvatarTile extends StatelessWidget {
  const _MemberAvatarTile({
    required this.name,
    required this.avatarUrl,
    required this.owner,
  });
  final String name;
  final String? avatarUrl;
  final bool owner;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 53,
            height: 53,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: owner
                    ? [const Color(0xFFFFC107), const Color(0xFFFFE082)]
                    : [const Color(0xFFE5E7EB), const Color(0xFFF8FAFC)],
              ),
            ),
            child: CircleAvatar(
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl!),
              backgroundColor: const Color(0xFFEDE9FE),
              child: avatarUrl == null
                  ? const Icon(Icons.person_rounded, color: _familyPurple)
                  : null,
            ),
          ),
          if (owner)
            const Positioned(
              top: -6,
              right: -3,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: _familyGold,
              ),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: _familyInk,
        ),
      ),
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: owner ? const Color(0xFFFFF3CD) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          owner ? 'رئيس' : 'عضو',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            color: owner ? const Color(0xFFB45309) : Colors.black45,
          ),
        ),
      ),
    ],
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.progress,
    required this.current,
    required this.animation,
    required this.onTasks,
  });
  final double progress;
  final num current;
  final Animation<double> animation;
  final VoidCallback onTasks;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2), Color(0xFFFFF8E7)],
      ),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: const Color(0xFFF5D28A)),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: _familyGold,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'LV1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'مستوى هذا الأسبوع',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _familyInk,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            Column(
              children: [
                const Text(
                  'إجمالي المكافآت',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${current.toInt()} 🪙',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        AnimatedBuilder(
          animation: animation,
          builder: (_, __) => ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress * animation.value,
              minHeight: 10,
              backgroundColor: Colors.white70,
              valueColor: const AlwaysStoppedAnimation(_familyGold),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Text(
              'المستوى التالي',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${current.toInt()} / 6000000000 🪙',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const Divider(color: Color(0x55D6A84B)),
        const Text(
          'سيشارك أفضل 20 داعماً ورئيس العائلة أسبوعياً عملات المكافأة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          onTap: onTasks,
          child: const Text(
            'عرض المهام اليومية  ←',
            style: TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SupportersRow extends StatelessWidget {
  const _SupportersRow({required this.rows, required this.onTap});
  final List<Map<String, dynamic>> rows;
  final void Function(Map<String, dynamic>) onTap;
  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFFFDF0),
      const Color(0xFFF0F9FF),
      const Color(0xFFFFF5F2),
    ];
    return Row(
      children: List.generate(3, (i) {
        final row = i < rows.length ? rows[i] : <String, dynamic>{};
        final profile = row['profiles'] is Map
            ? Map<String, dynamic>.from(row['profiles'])
            : row;
        final name = profile['username']?.toString() ?? 'بانتظار الداعم';
        return Expanded(
          child: GestureDetector(
            onTap: rows.isEmpty || i >= rows.length ? null : () => onTap(row),
            child: Container(
              margin: EdgeInsets.only(left: i == 2 ? 0 : 5),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _familyGold.withValues(alpha: .25)),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        backgroundImage: profile['avatar_url'] == null
                            ? null
                            : NetworkImage(profile['avatar_url'].toString()),
                        child: profile['avatar_url'] == null
                            ? const Icon(Icons.person, color: Colors.black26)
                            : null,
                      ),
                      const Positioned(
                        top: -5,
                        right: -3,
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: _familyGold,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: _familyInk,
                    ),
                  ),
                  Text(
                    'TOP ${i + 1}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: _familyGold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MemberProfileSheet extends StatelessWidget {
  const _MemberProfileSheet({
    required this.name,
    required this.role,
    required this.badge,
    required this.avatarUrl,
  });
  final String name, role, badge;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 36,
          backgroundColor: _familyPurple,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
          child: avatarUrl == null
              ? const Icon(Icons.person, color: Colors.white, size: 35)
              : null,
        ),
        const SizedBox(height: 9),
        Text(
          name,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _familyInk,
          ),
        ),
        Text(
          role,
          style: const TextStyle(
            color: _familyGold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _MiniStat(label: 'المساهمة', value: '850,200 🪙'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStat(label: 'الرتبة', value: badge),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال طلب الهدية')),
              );
            },
            icon: const Icon(Icons.card_giftcard_rounded),
            label: const Text('إرسال هدية'),
          ),
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black45)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            color: _familyInk,
          ),
        ),
      ],
    ),
  );
}

class _FamilyTasksSheet extends StatelessWidget {
  const _FamilyTasksSheet({required this.tasks, required this.familyName});
  final List<Map<String, dynamic>> tasks;
  final String familyName;

  @override
  Widget build(BuildContext context) {
    final items = tasks.isEmpty
        ? <Map<String, dynamic>>[
            {'title': 'إرسال 5 هدايا للأعضاء', 'reward': '+500 EXP'},
            {'title': 'التواجد في الروم 15 دقيقة', 'reward': '+300 EXP'},
          ]
        : tasks.take(4).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 15),
          const Text('🎁', style: TextStyle(fontSize: 28)),
          const SizedBox(height: 5),
          const Text(
            'مهام العائلة اليومية',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _familyInk,
            ),
          ),
          Text(
            'أكمل المهام لزيادة مستوى $familyName',
            style: const TextStyle(color: Colors.black54, fontSize: 11),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (task) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEFF1F5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title']?.toString() ??
                              task['name']?.toString() ??
                              'مهمة العائلة',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _familyInk,
                          ),
                        ),
                        Text(
                          task['reward']?.toString() ?? '+EXP',
                          style: const TextStyle(
                            color: _familyGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل إنجاز المهمة')),
                    ),
                    child: const Text('إنجاز', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ),
        ],
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
