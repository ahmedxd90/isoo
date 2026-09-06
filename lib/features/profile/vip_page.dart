import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  static const _rose = Color(0xFFFFD6E5);
  static const _roseDark = Color(0xFFE889A9);
  static const _pageBg = Color(0xFFF6F7FB);
  static const _ink = Color(0xFF252531);
  static const _muted = Color(0xFF8E8E9A);
  static const _memberCard = Color(0xFF29253D);
  static const _prices = <int, int>{
    1: 60000,
    2: 200000,
    3: 500000,
    4: 1000000,
    5: 2000000,
    6: 4000000,
    7: 8000000,
  };
  static const _requiredPoints = <int>[10000, 50000, 100000, 200000, 500000, 1000000, 2000000];
  static const _privilegeNames = <String>[
    'إشعارات الأولوية',
    'مؤثرات خاصة',
    'شارة VIP',
    'إطار الصورة',
    'بطاقة الاسم',
    'عميل حصري',
    'غرفة خاصة مجانية',
    'مقعد VIP',
    'خلفية الرسائل',
    'خصوصية مميزة',
    'مزايا الحالة',
    'حظر رسائل الغرفة',
    'إزالة المستخدمين',
    'هدايا حصرية',
    'إخفاء الترتيب',
    'إخفاء المساهمين',
    'إخفاء المتابعة',
    'حصانة الرسائل',
    'رسائل مميزة',
    'ترشيح الحساب',
  ];

  final _service = SakiService.instance;
  final _pageController = PageController(viewportFraction: .91);
  final _sakiId = TextEditingController();
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _account = {};
  int _selected = 1;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        _service.myProfile(),
        _service.accountModules(),
      ]);
      final profile = results[0] as Map<String, dynamic>? ?? {};
      final current = (profile['vip_level'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _account = Map<String, dynamic>.from(results[1] as Map);
        _selected = current.clamp(1, 7);
      });
    } catch (_) {
      if (mounted) _message('تعذر تحميل بيانات VIP من Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _format(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '$value';
  }

  Future<void> _buy() async {
    final price = _prices[_selected]!;
    final balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (balance < price) {
      _message('رصيد العملات الذهبية غير كافٍ.');
      return;
    }
    final ok = await _confirm(
      'تفعيل VIP $_selected',
      'سيتم خصم ${_format(price)} عملة وتفعيل العضوية لمدة 30 يومًا.',
    );
    if (!ok) return;
    setState(() => _working = true);
    try {
      await _service.purchaseVip(_selected);
      _message('تم تفعيل VIP $_selected لمدة 30 يومًا.');
      await _load();
    } catch (_) {
      _message('تعذر تنفيذ شراء VIP.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _gift() async {
    final id = int.tryParse(_sakiId.text.trim());
    if (id == null) {
      _message('أدخل SAKI ID صحيحًا.');
      return;
    }
    final ok = await _confirm(
      'إرسال VIP $_selected',
      'سيتم إرسال VIP إلى المستخدم رقم $id وخصم ${_format(_prices[_selected]!)} عملة.',
    );
    if (!ok) return;
    setState(() => _working = true);
    try {
      final result = await _service.giftVip(sakiId: id, level: _selected);
      _sakiId.clear();
      _message('تم إرسال VIP إلى ${result['recipient_username'] ?? id}.');
      await _load();
    } catch (_) {
      _message('تعذر إرسال VIP. تأكد من الرقم ورصيدك.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأكيد')),
            ],
          ),
        ) ??
        false;
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _pageController.dispose();
    _sakiId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = (_profile['vip_level'] as num?)?.toInt() ?? 0;
    final points = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('امتيازات VIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
        actions: [
          IconButton(onPressed: () => _message('تظهر تفاصيل كل ميزة عند توفرها.'), icon: const Icon(Icons.help_outline, size: 21)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _roseDark))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _membershipHeader(current, points),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 26, 16, 14),
                  child: Text('نظام العضوية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
                ),
                SizedBox(
                  height: 214,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 7,
                    onPageChanged: (index) => setState(() => _selected = index + 1),
                    itemBuilder: (_, index) => _levelCard(index + 1, points),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text('مزايا العضوية ($_selected/7)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
                ),
                _privilegeGrid(),
                _giftPanel(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
                  child: FilledButton(
                    onPressed: _working ? null : _buy,
                    style: FilledButton.styleFrom(backgroundColor: _rose, foregroundColor: _ink, minimumSize: const Size.fromHeight(48), shape: const StadiumBorder()),
                    child: Text('تفعيل / تجديد VIP $_selected — ${_format(_prices[_selected]!)} عملة', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(child: Text('الرصيد ${_format(points)} عملة ذهبية • مدة العضوية 30 يومًا', style: const TextStyle(color: _muted, fontSize: 11))),
                ),
              ],
            ),
    );
  }

  Widget _membershipHeader(int current, int points) {
    final username = _profile['display_name'] as String? ?? _profile['username'] as String? ?? 'عضو SAKI';
    final avatar = _profile['avatar_url'] as String?;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 154,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_rose, Color(0xFFFFEEF4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(38)),
          ),
          child: Center(child: Image.asset('assets/trace_vip/images/ic_vip_background.png', height: 110, opacity: const AlwaysStoppedAnimation(.5))),
        ),
        Positioned(
          top: 78,
          left: 18,
          right: 18,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 8))]),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (avatar != null) ClipOval(child: Image.network(avatar, width: 58, height: 58, fit: BoxFit.cover)) else const CircleAvatar(radius: 29, child: Icon(Icons.person)),
                        Image.asset('assets/trace_vip/images/ic_vip_crown.png', width: 70, height: 70),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _ink)),
                      const SizedBox(height: 5),
                      Text(current == 0 ? 'لست عضو VIP بعد' : 'عضويتك الحالية VIP $current', style: const TextStyle(color: _muted, fontSize: 11)),
                    ]),
                  ],
                ),
                const Divider(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _stat('المستوى الحالي', current == 0 ? '—' : 'VIP $current'),
                  _stat('العملات الذهبية', _format(points)),
                  _stat('المستوى المختار', 'VIP $_selected'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value) => Column(children: [Text(label, style: const TextStyle(color: _muted, fontSize: 10)), const SizedBox(height: 4), Text(value, style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w900))]);

  Widget _levelCard(int level, int points) {
    final required = _requiredPoints[level - 1];
    final progress = (points / required).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: () => setState(() => _selected = level),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), image: DecorationImage(image: AssetImage('assets/trace_vip/images/vip_bg_cover_$level.png'), fit: BoxFit.cover), color: _memberCard),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Image.asset('assets/trace_vip/images/ic_vip_$level.png', width: 72, height: 42, fit: BoxFit.contain),
              Text('VIP $level', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
            ]),
            const Spacer(),
            Text('ترقية VIP $level • ${_format(_prices[level]!)} عملة', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [Text('${_format(points)}', style: const TextStyle(color: Colors.white, fontSize: 11)), const SizedBox(width: 7), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: progress, minHeight: 7, backgroundColor: Colors.white24, color: _rose))), const SizedBox(width: 7), Text(_format(required), style: const TextStyle(color: Colors.white70, fontSize: 11))]),
          ]),
        ),
      ),
    );
  }

  Widget _privilegeGrid() {
    final enabled = _selected >= 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 20,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 12, childAspectRatio: .78),
        itemBuilder: (_, index) => GestureDetector(
          onTap: () => _message(_privilegeNames[index]),
          child: Column(children: [
            Container(width: 51, height: 51, decoration: BoxDecoration(shape: BoxShape.circle, color: _rose.withValues(alpha: .25)), padding: const EdgeInsets.all(8), child: Image.asset('assets/trace_vip/images/${enabled ? 'ic_privilege_enable' : 'ic_privilege_desable'}${index + 1}.png')),
            const SizedBox(height: 6),
            Text(_privilegeNames[index], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _giftPanel() => Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFEDEDF2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('إرسال VIP إلى مستخدم آخر', style: TextStyle(color: _ink, fontWeight: FontWeight.w900)),
          const SizedBox(height: 9),
          TextField(controller: _sakiId, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'أدخل SAKI ID', prefixIcon: const Icon(Icons.person_search, color: _roseDark), filled: true, fillColor: _pageBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          const SizedBox(height: 9),
          OutlinedButton.icon(onPressed: _working ? null : _gift, icon: const Icon(Icons.card_giftcard, color: _roseDark), label: const Text('إرسال لمدة 30 يومًا')),
        ]),
      );
}
