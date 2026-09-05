import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _orange = Color(0xFFF97316);
const _cyan = Color(0xFF06B6D4);

class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({
    super.key,
    required this.room,
    required this.service,
  });
  final Map<String, dynamic> room;
  final SakiService service;
  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  late int _seatCount;
  String? _background;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _seatCount = (widget.room['seat_count'] as int?) ?? 10;
    _background = widget.room['background_url'] as String?;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateRoomSettings(
        widget.room['id'] as String,
        seatCount: _seatCount,
        backgroundUrl: _background,
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الغرفة حقيقيًا')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.room['image_url'] as String?;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إعدادات الغرفة'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(colors: [_orange, _cyan]),
              image: image == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(image),
                      fit: BoxFit.cover,
                      colorFilter: const ColorFilter.mode(
                        Colors.black38,
                        BlendMode.darken,
                      ),
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.settings_suggest_rounded,
                  color: Colors.white,
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.room['name'] as String? ?? 'غرفتي',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'إعدادات المالك • ID ${widget.room['room_id'] ?? ''}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _SettingTile(
            icon: Icons.event_seat_rounded,
            title: 'عدد مقاعد الغرفة',
            subtitle: '$_seatCount مقاعد',
            onTap: () async {
              final value = await Navigator.push<int>(
                context,
                MaterialPageRoute(
                  builder: (_) => SeatCountPage(selected: _seatCount),
                ),
              );
              if (value != null) {
                setState(() => _seatCount = value);
                await _save();
              }
            },
          ),
          _SettingTile(
            icon: Icons.block_rounded,
            title: 'المحظورون',
            subtitle: 'إدارة المستخدمين المحظورين في غرفتي',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BannedUsersPage(
                  roomId: widget.room['id'] as String,
                  service: widget.service,
                ),
              ),
            ),
          ),
          _SettingTile(
            icon: Icons.wallpaper_rounded,
            title: 'خلفية الغرفة',
            subtitle: 'اختر خلفية مجانية أو ارفع خلفية VIP5+',
            onTap: () async {
              final value = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomBackgroundPage(
                    roomId: widget.room['id'] as String,
                    service: widget.service,
                  ),
                ),
              );
              if (value != null) setState(() => _background = value);
            },
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ إعدادات الغرفة'),
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
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
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: CircleAvatar(
        backgroundColor: _cyan.withValues(alpha: .13),
        child: Icon(icon, color: _cyan),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class SeatCountPage extends StatelessWidget {
  const SeatCountPage({super.key, required this.selected});
  final int selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('عدد مقاعد الغرفة')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final count in [5, 10, 15, 20])
          Card(
            child: ListTile(
              title: Text(
                '$count مقاعد',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: count == selected
                  ? const Icon(Icons.check_circle, color: _orange)
                  : null,
              onTap: () => Navigator.pop(context, count),
            ),
          ),
      ],
    ),
  );
}

class BannedUsersPage extends StatefulWidget {
  const BannedUsersPage({
    super.key,
    required this.roomId,
    required this.service,
  });
  final String roomId;
  final SakiService service;
  @override
  State<BannedUsersPage> createState() => _BannedUsersPageState();
}

class _BannedUsersPageState extends State<BannedUsersPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = widget.service.roomBansForOwner(widget.roomId);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المحظورون')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        final rows = snap.data!;
        if (rows.isEmpty)
          return const Center(child: Text('لا يوجد مستخدمون محظورون'));
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final row = rows[i];
            final p = Map<String, dynamic>.from(row['profiles'] ?? const {});
            return ListTile(
              leading: SakiAvatar(
                url: p['avatar_url'] as String?,
                label: p['username'] as String?,
              ),
              title: Text(
                p['username'] as String? ?? 'عضو',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Saki ID: ${p['saki_id'] ?? '—'}'),
              trailing: OutlinedButton(
                onPressed: () async {
                  await widget.service.removeRoomBan(
                    widget.roomId,
                    p['id'] as String,
                  );
                  if (mounted) setState(_reload);
                },
                child: const Text('فك الحظر'),
              ),
            );
          },
        );
      },
    ),
  );
}

class RoomBackgroundPage extends StatefulWidget {
  const RoomBackgroundPage({
    super.key,
    required this.roomId,
    required this.service,
  });
  final String roomId;
  final SakiService service;
  @override
  State<RoomBackgroundPage> createState() => _RoomBackgroundPageState();
}

class _RoomBackgroundPageState extends State<RoomBackgroundPage> {
  bool _busy = false;
  List<Map<String, dynamic>> _saved = [];
  final _picker = ImagePicker();
  final _free = const ['free://sunset', 'free://ocean', 'free://aurora'];

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final rows = await widget.service.roomBackgrounds(widget.roomId);
      if (mounted) setState(() => _saved = rows);
    } catch (_) {}
  }

  Future<void> _freeBackground(String value) async {
    setState(() => _busy = true);
    await widget.service.updateRoomSettings(
      widget.roomId,
      backgroundUrl: value,
    );
    if (mounted) {
      setState(() => _busy = false);
      Navigator.pop(context, value);
    }
  }

  Future<void> _upload() async {
    final p = await widget.service.myProfile();
    final vip = (p?['vip_level'] as num?)?.toInt() ?? 0;
    if (vip < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رفع خلفية من الجهاز متاح لمالك الغرفة VIP5 فأعلى'),
        ),
      );
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _busy = true);
    final url = await widget.service.uploadRoomBackground(widget.roomId, file);
    await widget.service.saveRoomBackground(widget.roomId, url);
    await widget.service.updateRoomSettings(widget.roomId, backgroundUrl: url);
    if (mounted) {
      setState(() => _busy = false);
      Navigator.pop(context, url);
    }
  }

  Widget _savedBackgroundTile(String url) => GestureDetector(
    onTap: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            await widget.service.updateRoomSettings(
              widget.roomId,
              backgroundUrl: url,
            );
            if (mounted) {
              setState(() => _busy = false);
              Navigator.pop(context, url);
            }
          },
    child: Container(
      height: 150,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        color: Colors.black45,
        child: const Text(
          'خلفياتي المرفوعة',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('خلفية الغرفة')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'خلفياتي المرفوعة',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        if (_saved.isEmpty)
          const Text(
            'لم ترفع خلفيات خاصة بعد',
            style: TextStyle(color: Colors.black54),
          )
        else
          ..._saved.map(
            (row) => _savedBackgroundTile(row['image_url'] as String),
          ),
        const SizedBox(height: 8),
        const Text(
          'خلفيات مجانية',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (final x in _free)
          GestureDetector(
            onTap: _busy ? null : () => _freeBackground(x),
            child: Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: x.endsWith('sunset')
                      ? const [_orange, Colors.pink]
                      : x.endsWith('ocean')
                      ? const [_cyan, Colors.indigo]
                      : const [Colors.indigo, Colors.purple, Colors.pink],
                ),
              ),
              child: Center(
                child: Text(
                  x.split('//').last,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _upload,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('رفع صورة أو GIF من الجهاز (VIP5+)'),
        ),
      ],
    ),
  );
}
