import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

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
      ],
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
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _gifts = await SakiService.instance.adminGiftCatalog();
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final name = TextEditingController(),
        icon = TextEditingController(text: '🎁'),
        price = TextEditingController();
    String category = 'general';
    XFile? file;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إضافة هدية'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الهدية'),
                ),
                TextField(
                  controller: icon,
                  decoration: const InputDecoration(
                    labelText: 'رمز/صورة مصغرة',
                  ),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر بالذهب'),
                ),
                DropdownButton<String>(
                  value: category,
                  items:
                      const [
                            'general',
                            'luck',
                            'famous',
                            'countries',
                            'vip',
                            'cp',
                          ]
                          .map(
                            (x) => DropdownMenuItem(value: x, child: Text(x)),
                          )
                          .toList(),
                  onChanged: (x) => set(() => category = x!),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    file = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    set(() {});
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    file == null ? 'اختيار PNG/GIF' : 'تم اختيار الملف',
                  ),
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
    String? url;
    if (file != null) url = await SakiService.instance.adminUploadGift(file!);
    await SakiService.instance.adminCreateGift(
      name: name.text,
      icon: icon.text,
      category: category,
      price: int.parse(price.text),
      mediaUrl: url,
      mediaType: url == null ? 'emoji' : 'image',
    );
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('إدارة الهدايا'),
      actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add))],
    ),
    body: ListView.builder(
      itemCount: _gifts.length,
      itemBuilder: (_, i) {
        final g = _gifts[i];
        return ListTile(
          leading: Text(
            g['icon'] ?? '🎁',
            style: const TextStyle(fontSize: 28),
          ),
          title: Text(g['name'] ?? ''),
          subtitle: Text('${g['price'] ?? 0} ذهب • ${g['category'] ?? ''}'),
          trailing: IconButton(
            onPressed: () async {
              await SakiService.instance.adminDeleteGift(g['id'] as String);
              _load();
            },
            icon: const Icon(Icons.delete, color: Colors.red),
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
