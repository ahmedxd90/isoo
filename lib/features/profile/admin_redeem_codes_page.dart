import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _adminOrange = Color(0xFFF97316);
const _adminCyan = Color(0xFF06B6D4);
const _adminInk = Color(0xFF111827);

class AdminRedeemCodesPage extends StatefulWidget {
  const AdminRedeemCodesPage({super.key});
  @override
  State<AdminRedeemCodesPage> createState() => _AdminRedeemCodesPageState();
}

class _AdminRedeemCodesPageState extends State<AdminRedeemCodesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SakiService.instance.adminRedeemCodes();
  Future<void> _add() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRedeemCodePage()),
    );
    if (created == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FC),
    appBar: AppBar(
      title: const Text(
        'استرداد كود',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: _adminInk,
      elevation: 0,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          onPressed: _add,
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      backgroundColor: _adminOrange,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'إضافة رمز',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _adminOrange),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'تعذر تحميل الأكواد\n${snapshot.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد أكواد مضافة بعد',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(_reload);
            await _future;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: rows.length,
            itemBuilder: (_, index) => _CodeCard(row: rows[index]),
          ),
        );
      },
    ),
  );
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final expires = DateTime.tryParse(row['expires_at']?.toString() ?? '')
        ?.toLocal();
    final expired = expires == null || expires.isBefore(DateTime.now());
    final rewards = (row['rewards'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['code']?.toString() ?? '',
                  style: const TextStyle(
                    letterSpacing: 2,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _adminInk,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: expired
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFE9FBEF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expired ? 'منتهي' : 'فعال',
                  style: TextStyle(
                    color: expired ? Colors.red : Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'الاستخدام: ${row['used_count'] ?? 0} / ${row['max_uses'] ?? 0}',
            style: const TextStyle(color: Colors.black54),
          ),
          Text(
            'الانتهاء: ${expires == null ? '—' : _date(expires)}',
            style: const TextStyle(color: Colors.black54),
          ),
          Text(
            'عدد المكافآت: $rewards',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class AddRedeemCodePage extends StatefulWidget {
  const AddRedeemCodePage({super.key});
  @override
  State<AddRedeemCodePage> createState() => _AddRedeemCodePageState();
}

class _AddRedeemCodePageState extends State<AddRedeemCodePage> {
  final _code = TextEditingController();
  final _uses = TextEditingController(text: '1');
  final _gold = TextEditingController(text: '0');
  final _vipLevel = TextEditingController(text: '1');
  final _vipDays = TextEditingController(text: '30');
  final _wealth = TextEditingController(text: '1');
  final _itemDays = TextEditingController(text: '30');
  DateTime _expires = DateTime.now().add(const Duration(days: 30));
  List<Map<String, dynamic>> _items = [];
  final Set<String> _selectedItems = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _code.text = _generateCode();
    _loadItems();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> _loadItems() async {
    try {
      final rows = await SakiService.instance.adminTraceStoreCatalog();
      if (mounted) setState(() => _items = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [
      _code,
      _uses,
      _gold,
      _vipLevel,
      _vipDays,
      _wealth,
      _itemDays,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickItems() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد عناصر متجر فعالة')));
      return;
    }
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StorePicker(
        items: _items,
        selected: _selectedItems,
        days: _itemDays,
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedItems
          ..clear()
          ..addAll(selected);
      });
    }
  }

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _expires,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expires),
    );
    if (time != null) {
      setState(
        () => _expires = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _save() async {
    final code = _code.text.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{6,12}$').hasMatch(code)) {
      _error('الكود يجب أن يحتوي على أحرف وأرقام من 6 إلى 12 خانة');
      return;
    }
    final rewards = <Map<String, dynamic>>[];
    final gold = int.tryParse(_gold.text) ?? 0;
    if (gold > 0) {
      rewards.add({'reward_type': 'gold', 'quantity': gold});
    }
    for (final item in _items.where(
      (item) => _selectedItems.contains(item['id'].toString()),
    )) {
      rewards.add({
        'reward_type': 'store_item',
        'item_id': item['id'],
        'duration_days': int.tryParse(_itemDays.text) ?? item['duration_days'],
      });
    }
    final vip = int.tryParse(_vipLevel.text) ?? 0;
    if (vip > 0) {
      rewards.add({
        'reward_type': 'vip',
        'vip_level': vip,
        'duration_days': int.tryParse(_vipDays.text) ?? 30,
      });
    }
    final wealth = int.tryParse(_wealth.text) ?? 0;
    if (wealth > 0) {
      rewards.add({'reward_type': 'wealth', 'wealth_level': wealth});
    }
    if (rewards.isEmpty) {
      _error('أضف مكافأة واحدة على الأقل');
      return;
    }
    setState(() => _saving = true);
    try {
      await SakiService.instance.adminCreateRedeemCode(
        code: code,
        expiresAt: _expires,
        maxUses: int.tryParse(_uses.text) ?? 1,
        rewards: rewards,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        _error(
          error.toString().contains('code_already_exists')
              ? 'هذا الكود موجود مسبقًا'
              : 'تعذر إنشاء الكود',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F8FC),
    appBar: AppBar(
      title: const Text(
        'إضافة رمز',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: _adminInk,
      elevation: 0,
      surfaceTintColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: [
        _Section(
          title: 'بيانات الكود',
          children: [
            _Input(
              controller: _code,
              label: 'الكود (6–12 أحرف وأرقام)',
              suffix: IconButton(
                onPressed: () => setState(() => _code.text = _generateCode()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            _Input(
              controller: _uses,
              label: 'عدد المستخدمين المسموح',
              keyboard: TextInputType.number,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.event_available_rounded,
                color: _adminCyan,
              ),
              title: const Text(
                'مدة صلاحية الكود',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_date(_expires)),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _pickExpiry,
            ),
          ],
        ),
        _Section(
          title: 'مكافآت العملات وVIP والثروة',
          children: [
            _Input(
              controller: _gold,
              label: 'إضافة عملات ذهبية',
              keyboard: TextInputType.number,
            ),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _vipLevel,
                    label: 'مستوى VIP (0 لإلغاء)',
                    keyboard: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Input(
                    controller: _vipDays,
                    label: 'مدة VIP بالأيام',
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            _Input(
              controller: _wealth,
              label: 'رفع مستوى الثروة إلى (0 لإلغاء)',
              keyboard: TextInputType.number,
            ),
          ],
        ),
        _Section(
          title: 'مكافآت المتجر',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.storefront_rounded,
                color: _adminOrange,
              ),
              title: const Text(
                'اختيار الإطارات والدخوليات',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                _selectedItems.isEmpty
                    ? 'لم يتم اختيار أصناف'
                    : 'تم اختيار ${_selectedItems.length} صنف',
              ),
              trailing: const Icon(Icons.keyboard_arrow_up_rounded),
              onTap: _pickItems,
            ),
            if (_selectedItems.isNotEmpty)
              _Input(
                controller: _itemDays,
                label: 'مدة أصناف المتجر بالأيام',
                keyboard: TextInputType.number,
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(
              _saving ? 'جارٍ الحفظ...' : 'إضافة الرمز',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _adminOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StorePicker extends StatefulWidget {
  const _StorePicker({
    required this.items,
    required this.selected,
    required this.days,
  });
  final List<Map<String, dynamic>> items;
  final Set<String> selected;
  final TextEditingController days;
  @override
  State<_StorePicker> createState() => _StorePickerState();
}

class _StorePickerState extends State<_StorePicker> {
  late final Set<String> selected = {...widget.selected};
  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .72,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    child: Column(
      children: [
        Container(width: 44, height: 5, color: Colors.black12),
        const SizedBox(height: 14),
        const Text(
          'متجر المكافآت',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'حدد أكثر من صنف ليتم منحها للمستخدم عند الاسترداد',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: widget.items.length,
            itemBuilder: (_, index) {
              final item = widget.items[index];
              final id = item['id'].toString();
              final checked = selected.contains(id);
              final asset =
                  'assets/trace_profile/images/${item['asset_key'] ?? 'ic_guard_avatar_frame.webp'}';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: checked,
                  onChanged: (value) => setState(
                    () =>
                        value == true ? selected.add(id) : selected.remove(id),
                  ),
                  secondary: Image.asset(
                    asset,
                    width: 44,
                    height: 44,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.card_giftcard_rounded),
                  ),
                  title: Text(
                    item['name']?.toString() ?? 'عنصر',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(item['category']?.toString() ?? ''),
                  activeColor: _adminCyan,
                ),
              );
            },
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, selected),
            style: FilledButton.styleFrom(backgroundColor: _adminCyan),
            child: const Text(
              'حفظ الاختيار',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _adminInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.keyboard = TextInputType.text,
    this.suffix,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType keyboard;
  final Widget? suffix;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

String _date(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
