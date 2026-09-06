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
  late String _name;
  late String _announcement;
  late String _category;
  late String _themeKey;
  late int _membershipFee;
  late double _rewardRate;
  late String _micPermission;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _seatCount = (widget.room['seat_count'] as int?) ?? 10;
    _background = widget.room['background_url'] as String?;
    _name = widget.room['name'] as String? ?? 'غرفتي';
    _announcement = widget.room['announcement'] as String? ?? '';
    _category = widget.room['category'] as String? ?? 'عام';
    _themeKey = widget.room['theme_key'] as String? ?? 'default';
    _membershipFee = (widget.room['membership_fee'] as num?)?.toInt() ?? 0;
    _rewardRate = (widget.room['reward_rate'] as num?)?.toDouble() ?? 0;
    _micPermission = widget.room['mic_permission'] as String? ?? 'everyone';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.service.updateRoomSettings(
        widget.room['id'] as String,
        seatCount: _seatCount,
        backgroundUrl: _background,
        name: _name,
        announcement: _announcement,
        category: _category,
        themeKey: _themeKey,
        membershipFee: _membershipFee,
        rewardRate: _rewardRate,
        micPermission: _micPermission,
      );
      await widget.service.recordRoomActivity(
        widget.room['id'] as String,
        'settings_updated',
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ إعدادات الغرفة حقيقيًا')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editText(
    String title,
    String current,
    ValueChanged<String> apply,
  ) async {
    final c = TextEditingController(text: current);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: title.contains('إشعار') ? 4 : 1,
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              apply(c.text.trim());
              Navigator.pop(context);
              _save();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
  }

  Future<void> _chooseCategory() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ChoiceSheet(
        title: 'التصنيف',
        values: const ['عام', 'موسيقى', 'دردشة', 'ألعاب', 'ترفيه', 'تعليم'],
        selected: _category,
      ),
    );
    if (value != null) {
      setState(() => _category = value);
      await _save();
    }
  }

  Future<void> _chooseTheme() async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => RoomThemesPage(selected: _themeKey)),
    );
    if (value != null) {
      setState(() => _themeKey = value);
      await _save();
    }
  }

  Future<void> _chooseMicPermission() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => _ChoiceSheet(
        title: 'الإذن لأخذ المايك',
        values: const ['everyone', 'followers', 'moderators', 'owner'],
        labels: const {
          'everyone': 'الجميع',
          'followers': 'المتابعون فقط',
          'moderators': 'المشرفون فقط',
          'owner': 'المالك فقط',
        },
        selected: _micPermission,
      ),
    );
    if (value != null) {
      setState(() => _micPermission = value);
      await _save();
    }
  }

  Future<void> _membership() async {
    final c = TextEditingController(text: '$_membershipFee');
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('رسوم العضوية'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'عملة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _membershipFee = int.tryParse(c.text) ?? 0);
              Navigator.pop(context);
              _save();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    c.dispose();
  }

  Future<void> _reward() async {
    final value = await Navigator.push<double>(
      context,
      MaterialPageRoute(
        builder: (_) => RewardSettingsPage(selected: _rewardRate),
      ),
    );
    if (value != null) {
      setState(() => _rewardRate = value);
      await _save();
    }
  }

  String _micLabel() =>
      const {
        'everyone': 'الجميع',
        'followers': 'المتابعون فقط',
        'moderators': 'المشرفون فقط',
        'owner': 'المالك فقط',
      }[_micPermission] ??
      'الجميع';

  @override
  Widget build(BuildContext context) {
    final image = widget.room['image_url'] as String?;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'الإعدادات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 28),
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _ProfileRow(image: image, name: _name),
                _HtmlSettingRow(
                  title: 'اسم الغرفة',
                  value: _name,
                  onTap: () => _editText(
                    'اسم الغرفة',
                    _name,
                    (v) => setState(() => _name = v),
                  ),
                ),
                _HtmlSettingRow(
                  title: 'إشعار عام',
                  value: _announcement.isEmpty
                      ? 'لم يتم تحديد إشعار'
                      : _announcement,
                  onTap: () => _editText(
                    'إشعار عام',
                    _announcement,
                    (v) => setState(() => _announcement = v),
                  ),
                ),
                _HtmlSettingRow(
                  title: 'التصنيف',
                  value: _category,
                  onTap: _chooseCategory,
                ),
                _HtmlSettingRow(
                  title: 'الثيم',
                  value: _themeKey == 'default' ? 'الافتراضي' : _themeKey,
                  dot: _themeKey,
                  onTap: _chooseTheme,
                ),
                _HtmlSettingRow(
                  title: 'خلفية الغرفة',
                  value: _background == null ? 'الافتراضية' : 'خلفية مخصصة',
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
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _HtmlSettingRow(
                  title: 'رسوم العضوية',
                  value: '$_membershipFee عملة',
                  valueColor: Colors.amber.shade700,
                  onTap: _membership,
                ),
                _HtmlSettingRow(
                  title: 'المكافأة',
                  value: '${_rewardRate.toStringAsFixed(0)}% من النقاط',
                  valueColor: Colors.amber.shade700,
                  onTap: _reward,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: _HtmlSettingRow(
              title: 'الإذن لأخذ المايك',
              value: _micLabel(),
              onTap: _chooseMicPermission,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _HtmlSettingRow(
                  title: 'المشرفون',
                  value: 'إدارة المشرفين',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomModeratorsPage(
                        roomId: widget.room['id'] as String,
                        service: widget.service,
                      ),
                    ),
                  ),
                ),
                _HtmlSettingRow(
                  title: 'المحظورون',
                  value: 'إدارة المحظورين',
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
                _HtmlSettingRow(
                  title: 'سجلات العمل',
                  value: 'جديد',
                  valueColor: Colors.cyan.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoomLogsPage(
                        roomId: widget.room['id'] as String,
                        service: widget.service,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ إعدادات الغرفة'),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.image, required this.name});
  final String? image;
  final String name;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF0F0F2))),
    ),
    child: Row(
      children: [
        ClipOval(
          child: image == null
              ? Container(
                  width: 48,
                  height: 48,
                  color: _cyan.withValues(alpha: .12),
                  child: const Icon(Icons.meeting_room, color: _cyan),
                )
              : Image.network(image!, width: 48, height: 48, fit: BoxFit.cover),
        ),
        const Spacer(),
        const Text(
          'صورة الملف الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF303039),
          ),
        ),
      ],
    ),
  );
}

class _HtmlSettingRow extends StatelessWidget {
  const _HtmlSettingRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.valueColor,
    this.dot,
  });
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? valueColor;
  final String? dot;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F2))),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chevron_left_rounded,
            size: 20,
            color: Color(0xFFCCCCCC),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                if (dot != null)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF2563EB)],
                      ),
                    ),
                  ),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: valueColor ?? const Color(0xFF8A8A94),
                      fontWeight: valueColor == null
                          ? FontWeight.w500
                          : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF303039),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({
    required this.title,
    required this.values,
    required this.selected,
    this.labels,
  });
  final String title;
  final List<String> values;
  final String selected;
  final Map<String, String>? labels;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          ...values.map(
            (value) => ListTile(
              title: Text(labels?[value] ?? value, textAlign: TextAlign.right),
              trailing: value == selected
                  ? const Icon(Icons.check_circle, color: _cyan)
                  : null,
              onTap: () => Navigator.pop(context, value),
            ),
          ),
        ],
      ),
    ),
  );
}

class RoomThemesPage extends StatelessWidget {
  const RoomThemesPage({super.key, required this.selected});
  final String selected;
  static const themes = <String, List<Color>>{
    'default': [Color(0xFF1E293B), Color(0xFF312E81)],
    'ocean': [Color(0xFF0891B2), Color(0xFF1D4ED8)],
    'sunset': [Color(0xFFF97316), Color(0xFFDB2777)],
    'aurora': [Color(0xFF059669), Color(0xFF7C3AED)],
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F9),
    appBar: AppBar(title: const Text('ثيم الغرفة'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'المعاينة الحالية للثيم:',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: themes[selected] ?? themes['default']!,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: Text(
                  selected == 'default' ? 'الافتراضي' : selected,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Text('🎙️   🎬   🍿   🎙️', style: TextStyle(fontSize: 24)),
              const Text(
                'مظهر الغرفة للزوار والأعضاء',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'اختر ثيم الغرفة:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: themes.entries
              .map(
                (entry) => InkWell(
                  onTap: () => Navigator.pop(context, entry.key),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: entry.value),
                      border: Border.all(
                        color: entry.key == selected
                            ? _cyan
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        entry.key == 'default' ? 'الافتراضي' : entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class RewardSettingsPage extends StatefulWidget {
  const RewardSettingsPage({super.key, required this.selected});
  final double selected;
  @override
  State<RewardSettingsPage> createState() => _RewardSettingsPageState();
}

class _RewardSettingsPageState extends State<RewardSettingsPage> {
  late double value = widget.selected;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المكافأة'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0D8),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              const Text(
                'نسبة مكافأة الغرفة',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange,
                ),
              ),
              Slider(
                value: value,
                min: 0,
                max: 100,
                divisions: 20,
                activeColor: Colors.orange,
                onChanged: (v) => setState(() => value = v),
              ),
              const Text(
                'يتم حفظ النسبة في إعدادات الغرفة وتستخدمها خدمات المكافآت.',
                style: TextStyle(fontSize: 11, color: Colors.brown),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          style: FilledButton.styleFrom(backgroundColor: _cyan),
          child: const Text('حفظ النسبة'),
        ),
      ],
    ),
  );
}

class RoomModeratorsPage extends StatefulWidget {
  const RoomModeratorsPage({
    super.key,
    required this.roomId,
    required this.service,
  });
  final String roomId;
  final SakiService service;
  @override
  State<RoomModeratorsPage> createState() => _RoomModeratorsPageState();
}

class _RoomModeratorsPageState extends State<RoomModeratorsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _future = widget.service.roomModeratorsForOwner(widget.roomId);

  Future<void> _add() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('إضافة مشرف'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'اسم المستخدم أو SAKI ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final users = await widget.service.searchProfiles(
                controller.text,
              );
              if (users.isNotEmpty)
                await widget.service.addRoomModerator(
                  widget.roomId,
                  users.first['id'] as String,
                );
              if (dialog.mounted) Navigator.pop(dialog);
              if (mounted) setState(_reload);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('المشرفون'),
      actions: [
        IconButton(onPressed: _add, icon: const Icon(Icons.person_add_alt_1)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SakiLoading();
        final rows = snapshot.data!;
        if (rows.isEmpty)
          return const EmptyState(
            icon: Icons.shield_outlined,
            title: 'لا يوجد مشرفون',
            subtitle: 'أضف مشرفين لإدارة الغرفة.',
          );
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (_, index) {
            final profile = Map<String, dynamic>.from(
              rows[index]['profiles'] ?? const {},
            );
            final id = profile['id'] as String;
            return ListTile(
              leading: SakiAvatar(
                url: profile['avatar_url'] as String?,
                label: profile['username'] as String?,
              ),
              title: Text(
                profile['username'] as String? ?? 'مستخدم',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('SAKI ID ${profile['saki_id'] ?? '—'}'),
              trailing: IconButton(
                onPressed: () async {
                  await widget.service.removeRoomModerator(widget.roomId, id);
                  if (mounted) setState(_reload);
                },
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.redAccent,
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class RoomLogsPage extends StatefulWidget {
  const RoomLogsPage({super.key, required this.roomId, required this.service});
  final String roomId;
  final SakiService service;
  @override
  State<RoomLogsPage> createState() => _RoomLogsPageState();
}

class _RoomLogsPageState extends State<RoomLogsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.service.roomActivityLogs(widget.roomId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('سجلات العمل')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SakiLoading();
        final rows = snapshot.data!;
        if (rows.isEmpty)
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'لا توجد سجلات',
            subtitle: 'تظهر هنا تغييرات إعدادات وإدارة الغرفة.',
          );
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, index) {
            final row = rows[index];
            final profile = Map<String, dynamic>.from(
              row['profiles'] ?? const {},
            );
            final actor = profile['username'] ?? 'مستخدم';
            final time = (row['created_at'] as String? ?? '').replaceFirst(
              'T',
              ' ',
            );
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0F2FE),
                child: Icon(Icons.history, color: _cyan),
              ),
              title: Text(
                '${row['action'] ?? 'نشاط'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('$actor • $time'),
            );
          },
        );
      },
    ),
  );
}
