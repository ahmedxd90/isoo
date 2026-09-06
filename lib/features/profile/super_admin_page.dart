import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import 'admin_trace_modules_page.dart';

const _blue = Color(0xFF4F46E5);
const _cyan = Color(0xFF06B6D4);

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('لوحة تحكم سوبر أدمن')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(colors: [_blue, _cyan]),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 42),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUPER ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'صلاحيات الإدارة محمية من Supabase',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: SakiService.instance.adminDashboard(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              );
            }
            final data = snapshot.data ?? const <String, dynamic>{};
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _MetricCard('المستخدمون', data['users'], Icons.people_alt),
                _MetricCard(
                  'VIP نشط',
                  data['active_vip'],
                  Icons.workspace_premium,
                ),
                _MetricCard('الغرف', data['rooms'], Icons.meeting_room),
                _MetricCard('الرسائل', data['messages'], Icons.forum),
                _MetricCard('الوكالات', data['agencies'], Icons.business),
                _MetricCard('العائلات', data['families'], Icons.groups),
                _MetricCard('المنشورات', data['posts'], Icons.article),
                _MetricCard('الحظر النشط', data['bans'], Icons.block),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _AdminCard(
          icon: Icons.people_alt_rounded,
          title: 'إدارة المستخدمين',
          subtitle: 'Saki ID والذهب وVIP والحظر العام',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.card_giftcard_rounded,
          title: 'إدارة الهدايا',
          subtitle: 'إضافة وتعديل وحذف هدايا صندوق الغرفة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminGiftsPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.meeting_room_rounded,
          title: 'إدارة الغرف',
          subtitle: 'تغيير Room ID وتعيين الغرفة الرسمية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminRoomsPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.business_rounded,
          title: 'إدارة الوكالات',
          subtitle: 'عرض الوكالات وتفعيلها أو تعليقها أو إغلاقها',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAgenciesPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.groups_rounded,
          title: 'إدارة العائلات',
          subtitle: 'عرض العائلات وتغيير الحالة الإدارية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFamiliesPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.military_tech_rounded,
          title: 'إدارة المستويات والجوائز',
          subtitle: 'المستويات والنقاط والجوائز المرتبطة بالمستخدمين',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminLevelsPage()),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);
  final String label;
  final Object? value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(icon, color: _blue, size: 25),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${value ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        backgroundColor: _cyan.withValues(alpha: .15),
        child: Icon(icon, color: _blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  Future<void> _find() async {
    setState(() => _loading = true);
    try {
      _users = await SakiService.instance.adminUsers(_search.text.trim());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _action(Map<String, dynamic> user) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('إضافة ذهب'),
              onTap: () => Navigator.pop(context, 'gold'),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium),
              title: const Text('تعيين VIP 5 لمدة 30 يومًا'),
              onTap: () => Navigator.pop(context, 'vip'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('حظر من التطبيق 7 أيام'),
              onTap: () => Navigator.pop(context, 'ban'),
            ),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('تغيير Saki ID'),
              onTap: () => Navigator.pop(context, 'id'),
            ),
          ],
        ),
      ),
    );
    final saki = (user['saki_id'] as num?)?.toInt() ?? 0;
    try {
      if (action == 'gold') {
        final c = TextEditingController();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('إضافة ذهب'),
            content: TextField(
              controller: c,
              keyboardType: TextInputType.number,
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  await SakiService.instance.adminAddGold(
                    saki,
                    int.parse(c.text),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      } else if (action == 'vip') {
        await SakiService.instance.adminSetVip(saki, 5, 30);
      } else if (action == 'ban') {
        await SakiService.instance.adminBanApp(
          saki,
          const Duration(days: 7),
          'حظر بواسطة سوبر أدمن',
        );
      } else if (action == 'id') {
        final c = TextEditingController();
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Saki ID الجديد'),
            content: TextField(
              controller: c,
              keyboardType: TextInputType.number,
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  await SakiService.instance.adminSetSakiId(
                    user['id'] as String,
                    int.parse(c.text),
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        );
      }
      if (mounted) _find();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة المستخدمين')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'اسم المستخدم أو Saki ID',
                  ),
                ),
              ),
              IconButton(onPressed: _find, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    return ListTile(
                      leading: SakiAvatar(
                        url: u['avatar_url'] as String?,
                        label: u['username'] as String?,
                      ),
                      title: Text(u['username'] as String? ?? 'عضو'),
                      subtitle: Text(
                        'Saki ID: ${u['saki_id'] ?? '—'} • VIP ${u['vip_level'] ?? 0}',
                      ),
                      trailing: IconButton(
                        onPressed: () => _action(u),
                        icon: const Icon(Icons.more_vert),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class AdminGiftsPage extends StatefulWidget {
  const AdminGiftsPage({super.key});
  @override
  State<AdminGiftsPage> createState() => _AdminGiftsPageState();
}

class _AdminGiftsPageState extends State<AdminGiftsPage> {
  List<Map<String, dynamic>> _gifts = [];
  static const _categories = {
    'عامة': 'general',
    'هدايا الحظ': 'luck',
    'المشاهير': 'famous',
    'والدول': 'countries',
    'CP': 'cp',
    'VIP فقط': 'vip',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _gifts = await SakiService.instance.adminGiftCatalog();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error.toString());
    }
  }

  void _snack(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value.replaceFirst('Exception: ', ''))),
  );

  Future<PlatformFile?> _pickFile(List<String> extensions) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      withData: false,
    );
    return result.isEmpty ? null : result.single;
  }

  Future<void> _add() async {
    final name = TextEditingController(), price = TextEditingController();
    String category = 'general';
    PlatformFile? thumbnail;
    PlatformFile? media;
    String mediaType = 'PNG';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          backgroundColor: const Color(0xFF130F24),
          title: const Text(
            'رفع هدية جديدة',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'اسم الهدية'),
                ),
                TextField(
                  controller: price,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر بالذهب'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: const Color(0xFF21163B),
                  decoration: const InputDecoration(labelText: 'فئة الهدية'),
                  items: _categories.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.value,
                          child: Text(e.key),
                        ),
                      )
                      .toList(),
                  onChanged: (x) => set(() => category = x ?? category),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    thumbnail = await _pickFile(['png']);
                    set(() {});
                  },
                  icon: const Icon(Icons.image_outlined),
                  label: Text(
                    thumbnail == null
                        ? 'رفع الصورة المصغرة PNG'
                        : thumbnail!.name,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    media = await _pickFile(['png', 'mp4', 'gif', 'svga']);
                    if (media != null) {
                      mediaType = media!.extension?.toUpperCase() ?? 'PNG';
                    }
                    set(() {});
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    media == null
                        ? 'رفع ملف الهدية PNG / MP4 / GIF / SVGA'
                        : '${media!.name} • $mediaType',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'يتم اختيار الملفات من ملفات الجهاز مباشرة، وليس من معرض الصور فقط.',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (name.text.trim().isEmpty || int.tryParse(price.text) == null) {
        _snack('أدخل اسم الهدية والسعر بشكل صحيح.');
        return;
      }
      String? thumbnailUrl;
      String? mediaUrl;
      if (thumbnail?.path != null) {
        thumbnailUrl = await SakiService.instance.adminUploadGift(
          XFile(thumbnail!.path!),
        );
      }
      if (media?.path != null) {
        mediaUrl = await SakiService.instance.adminUploadGift(
          XFile(media!.path!),
        );
      }
      await SakiService.instance.adminCreateGift(
        name: name.text.trim(),
        icon: thumbnailUrl ?? '🎁',
        category: category,
        price: int.parse(price.text),
        mediaUrl: mediaUrl ?? thumbnailUrl,
        mediaType: mediaUrl == null ? 'emoji' : mediaType.toLowerCase(),
      );
      _snack('تم حفظ الهدية وإضافتها إلى شبكة الهدايا.');
      await _load();
    } catch (error) {
      _snack(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B0914),
    appBar: AppBar(
      backgroundColor: const Color(0xFF130F24),
      title: const Text('متجر الهدايا التفاعلية'),
      actions: [
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('رفع هدية'),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .78,
      ),
      itemBuilder: (_, i) {
        final g = _gifts[i];
        final icon = g['icon'] as String? ?? '🎁';
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withValues(alpha: .35)),
          ),
          child: Column(
            children: [
              Expanded(
                child: icon.startsWith('http')
                    ? Image.network(icon, fit: BoxFit.contain)
                    : Center(
                        child: Text(icon, style: const TextStyle(fontSize: 35)),
                      ),
              ),
              Text(
                g['name'] as String? ?? 'هدية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${g['price'] ?? 0} ذهب',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
              ),
              IconButton(
                onPressed: () async {
                  await SakiService.instance.adminDeleteGift(g['id'] as String);
                  _load();
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AdminRoomsPage extends StatefulWidget {
  const AdminRoomsPage({super.key});
  @override
  State<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends State<AdminRoomsPage> {
  List<Map<String, dynamic>> _rooms = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _rooms = await SakiService.instance.adminRooms();
    if (mounted) setState(() {});
  }

  Future<void> _edit(Map<String, dynamic> room) async {
    final id = TextEditingController(text: room['room_id'] as String? ?? '');
    bool official = room['is_official'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إدارة الغرفة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: id,
                keyboardType: TextInputType.number,
                maxLength: 9,
                decoration: const InputDecoration(
                  labelText: 'Room ID - 9 أرقام',
                ),
              ),
              SwitchListTile(
                value: official,
                onChanged: (v) => set(() => official = v),
                title: const Text('غرفة رسمية'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await SakiService.instance.adminSetRoomId(
        room['id'] as String,
        id.text,
        official,
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الغرف')),
    body: ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (_, i) {
        final r = _rooms[i];
        return ListTile(
          title: Text(r['name'] as String? ?? 'غرفة'),
          subtitle: Text('Room ID: ${r['room_id'] ?? '—'}'),
          trailing: IconButton(
            onPressed: () => _edit(r),
            icon: const Icon(Icons.edit),
          ),
        );
      },
    ),
  );
}
