import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class VipPage extends StatefulWidget {
  const VipPage({super.key});
  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> with SingleTickerProviderStateMixin {
  final _service = SakiService.instance;
  final _sakiId = TextEditingController();
  late final AnimationController _animation;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _account = {};
  int _selected = 1;
  bool _loading = true;
  bool _working = false;

  static const _prices = <int, int>{
    1: 60000,
    2: 200000,
    3: 500000,
    4: 1000000,
    5: 2000000,
    6: 4000000,
    7: 8000000,
  };
  static const _privileges = <String>[
    'شارة VIP',
    'هدية VIP',
    'مقعد VIP',
    'مكافحة ركلة',
    'مكافحة الأسود',
    'اسم التدرج اللوني',
  ];
  static const _gold = Color(0xFFD4AF37);
  static const _bg = Color(0xFF080606);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.myProfile();
      final account = await _service.accountModules();
      if (mounted)
        setState(() {
          _profile = profile ?? {};
          _account = account;
          _selected = ((_profile['vip_level'] as num?)?.toInt() ?? 0).clamp(
            1,
            7,
          );
        });
    } catch (_) {
      if (mounted) _message('تعذر تحميل بيانات VIP.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _format(int value) {
    if (value >= 1000000)
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000)
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '$value';
  }

  Future<void> _buy() async {
    final price = _prices[_selected]!;
    final balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    final ok = await _confirm(
      'تأكيد شراء VIP $_selected',
      'سيتم خصم ${_format(price)} عملة ذهبية وتفعيل العضوية لمدة 30 يومًا.',
    );
    if (!ok) return;
    if (balance < price) {
      _message('رصيد العملات الذهبية غير كافٍ.');
      return;
    }
    setState(() => _working = true);
    try {
      await _service.purchaseVip(_selected);
      if (mounted) {
        _message('تم تفعيل VIP $_selected لمدة 30 يومًا.');
        _load();
      }
    } catch (_) {
      if (mounted) _message('تعذر تنفيذ الشراء.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _gift() async {
    final id = int.tryParse(_sakiId.text.trim());
    final price = _prices[_selected]!;
    if (id == null) {
      _message('أدخل Saki ID صحيحًا.');
      return;
    }
    final ok = await _confirm(
      'تأكيد إرسال VIP $_selected',
      'سيتم إرسال VIP لمدة 30 يومًا إلى المستخدم رقم $id وخصم ${_format(price)} عملة ذهبية.',
    );
    if (!ok) return;
    setState(() => _working = true);
    try {
      final result = await _service.giftVip(sakiId: id, level: _selected);
      if (mounted) {
        _sakiId.clear();
        _message('تم إرسال VIP إلى ${result['recipient_username'] ?? id}.');
        _load();
      }
    } catch (_) {
      if (mounted) _message('تعذر الإرسال. تأكد من Saki ID ورصيدك.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF211810),
          title: Text(
            title,
            style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
          ),
          content: Text(body, style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _animation.dispose();
    _sakiId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = (_profile['vip_level'] as num?)?.toInt() ?? 0;
    final balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text(
          'عضوية VIP',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : Column(
              children: [
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: 7,
                    separatorBuilder: (_, __) => const SizedBox(width: 22),
                    itemBuilder: (_, i) {
                      final level = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _selected = level),
                        child: _vipLabel(level, active: _selected == level),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                    children: [
                      _hero(current),
                      const SizedBox(height: 28),
                      _status(current),
                      const SizedBox(height: 28),
                      const Center(
                        child: Text(
                          'امتيازات حصرية',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      _privilegeGrid(),
                      const SizedBox(height: 22),
                      _giftBox(),
                      const SizedBox(height: 15),
                      FilledButton(
                        onPressed: _working ? null : _buy,
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: const Color(0xFF3D2407),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: Text(
                          'تفعيل / تجديد VIP $_selected — ${_format(_prices[_selected]!)} عملة',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'رصيدك: ${_format(balance)} عملة ذهبية • مدة العضوية 30 يومًا',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _vipLabel(int level, {required bool active}) => ShaderMask(
    shaderCallback: (rect) => LinearGradient(
      colors: level >= 6
          ? const [Colors.red, Colors.amber, Colors.blue, Colors.red]
          : const [Color(0xFFFCE08B), _gold],
      begin: Alignment(-1 + (_animation.value * 2), 0),
      end: Alignment(1 + (_animation.value * 2), 0),
    ).createShader(rect),
    blendMode: BlendMode.srcIn,
    child: Text(
      'VIP $level',
      style: TextStyle(
        fontSize: active ? 16 : 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
  );

  Widget _hero(int current) => Container(
    padding: const EdgeInsets.all(25),
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        colors: [Color(0xFF5B431C), Color(0xFF160F09)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _gold.withValues(alpha: .55)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.workspace_premium_rounded,
          color: Color(0xFFFCE08B),
          size: 74,
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (rect) =>
              const LinearGradient(colors: [Color(0xFFFCE08B), _gold])
                  .createShader(rect),
          child: Text(
            'VIP $_selected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          current >= _selected
              ? 'عضويتك الحالية مفعّلة'
              : 'ترقية مميزة لمدة 30 يومًا',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _status(int current) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF201813),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _gold.withValues(alpha: .25)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('حالة العضوية', style: TextStyle(color: Colors.white60)),
        Text(
          current == 0 ? 'لم يتم التفعيل بعد' : 'VIP $current',
          style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _privilegeGrid() {
    final active = _selected == 1
        ? 2
        : _selected == 2
        ? 3
        : _selected == 3
        ? 4
        : _selected == 4
        ? 5
        : 6;
    final icons = [
      Icons.workspace_premium,
      Icons.card_giftcard,
      Icons.event_seat,
      Icons.directions_run,
      Icons.shield,
      Icons.text_fields,
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .86,
      ),
      itemBuilder: (_, i) => Container(
        decoration: BoxDecoration(
          color: i < active
              ? const Color(0xFF2A2018)
              : Colors.white.withValues(alpha: .03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: i < active ? _gold : Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icons[i],
              size: 32,
              color: i < active ? const Color(0xFFFCE08B) : Colors.white24,
            ),
            const SizedBox(height: 8),
            Text(
              _privileges[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: i < active ? Colors.white : Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _giftBox() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFF17100B),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'إرسال VIP إلى مستخدم آخر',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _sakiId,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'أدخل Saki ID',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(Icons.person_search, color: _gold),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 9),
        OutlinedButton.icon(
          onPressed: _working ? null : _gift,
          icon: const Icon(Icons.card_giftcard, color: _gold),
          label: const Text(
            'إرسال لمدة 30 يومًا',
            style: TextStyle(color: _gold),
          ),
        ),
      ],
    ),
  );
}
