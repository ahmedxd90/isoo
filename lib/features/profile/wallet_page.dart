import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _GoldPackage {
  const _GoldPackage({required this.gold, required this.usd});
  final int gold;
  final int usd;
}

class _WalletPageState extends State<WalletPage> {
  final _service = SakiService.instance;
  final _diamonds = TextEditingController();
  Map<String, dynamic> _account = {};
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _historyLoading = false;
  bool _converting = false;
  int _tab = 0;

  static const _orange = Color(0xFFF97316);
  static const _amber = Color(0xFFF59E0B);
  static const _cyan = Color(0xFF06B6D4);
  static const _blue = Color(0xFF2563EB);
  static const _ink = Color(0xFF0F172A);
  static const _page = Color(0xFFF7F8FC);
  static const _panelBorder = Color(0xFFE5E7EB);

  static const _packages = <_GoldPackage>[
    _GoldPackage(gold: 1000000, usd: 1),
    _GoldPackage(gold: 5000000, usd: 5),
    _GoldPackage(gold: 10000000, usd: 10),
    _GoldPackage(gold: 25000000, usd: 25),
  ];

  TextStyle get _cairo => GoogleFonts.cairo();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = await _service.accountModules();
      if (mounted) setState(() => _account = account);
    } catch (_) {
      if (mounted) _message('تعذر تحميل أرصدة المحفظة من Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _format(int value) {
    final text = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
      buffer.write(text[i]);
    }
    return buffer.toString();
  }

  void _message(String text) => CustomToast.show(context, text);

  Future<void> _convert() async {
    final amount = int.tryParse(_diamonds.text.trim()) ?? 0;
    final balance = (_account['diamonds'] as num?)?.toInt() ?? 0;
    if (amount <= 0 || amount > balance) {
      _message('أدخل كمية صحيحة ضمن رصيد الألماس الحالي.');
      return;
    }
    setState(() => _converting = true);
    try {
      final updated = await _service.convertDiamondsToGold(amount);
      if (!mounted) return;
      setState(() {
        _account = {..._account, ...updated};
        _diamonds.clear();
      });
      _message('تم تحويل ${_format(amount)} ماسة إلى ذهبيات بنجاح.');
    } catch (error) {
      final detail = error.toString();
      final message = detail.contains('insufficient_diamonds')
          ? 'رصيد الألماس غير كافٍ.'
          : detail.contains('invalid_amount')
          ? 'أدخل كمية ألماس صحيحة.'
          : 'تعذر تحويل الألماس الآن، حاول مرة أخرى.';
      if (mounted) _message(message);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  Future<void> _showHistory() async {
    if (_historyLoading) return;
    setState(() => _historyLoading = true);
    try {
      final rows = await _service.walletHistory();
      if (mounted) setState(() => _history = rows);
    } catch (_) {
      if (mounted) _message('تعذر تحميل سجل المحفظة.');
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HistorySheet(rows: _history, format: _format),
    );
  }

  Future<void> _showPackage(_GoldPackage package) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        title: Text('تأكيد باقة الشحن', style: _cairo.copyWith(fontWeight: FontWeight.w900, color: _ink)),
        content: Text(
          'ستطلب شحن ${_format(package.gold)} عملة ذهبية مقابل ${package.usd} دولار.\n\nلن تتم إضافة الرصيد إلا بعد تأكيد الدفع من بوابة دفع معتمدة أو وكيل شحن؛ التطبيق لا ينفذ إضافة وهمية من داخله.',
          textAlign: TextAlign.right,
          style: _cairo.copyWith(color: const Color(0xFF64748B), height: 1.6, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('إلغاء', style: _cairo.copyWith(color: const Color(0xFF64748B), fontWeight: FontWeight.bold))),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _message('لم تُنفذ عملية دفع بعد. استخدم بوابة الدفع أو وكيل الشحن المعتمد.');
            },
            style: FilledButton.styleFrom(backgroundColor: _orange),
            child: Text('متابعة الدفع', style: _cairo.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _diamonds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    final diamonds = (_account['diamonds'] as num?)?.toInt() ?? 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF374151)),
            onPressed: () => Navigator.pop(context, true),
          ),
          centerTitle: true,
          title: _tabs(),
          actions: [
            IconButton(
              tooltip: 'سجل المعاملات',
              onPressed: _showHistory,
              icon: _historyLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _orange))
                  : const Icon(Icons.history_rounded, color: Color(0xFF6B7280), size: 21),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _orange))
            : AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tab == 0 ? _goldView(gold) : _diamondView(diamonds),
              ),
      ),
    );
  }

  Widget _tabs() => Container(
    width: 190,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 5)]),
    child: Row(children: [_tabButton('ذهبيات', 0, _orange), _tabButton('الماس', 1, _cyan)]),
  );

  Widget _tabButton(String label, int index, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(color: _tab == index ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(18), boxShadow: _tab == index ? const [BoxShadow(color: Color(0x16000000), blurRadius: 4)] : null),
        child: Text(label, textAlign: TextAlign.center, style: _cairo.copyWith(color: _tab == index ? color : const Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    ),
  );

  Widget _goldView(int gold) => ListView(
    key: const ValueKey('gold'),
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      _balanceCard('الرصيد الحالي من العملات', _format(gold), 'عملات Saki الذهبية المتاحة', _orange, Icons.monetization_on_rounded, 'التفاصيل'),
      _firstRechargeBanner(),
      const SizedBox(height: 18),
      _sectionTitle('باقات الشحن المتاحة'),
      const SizedBox(height: 8),
      ..._packages.map(_packageCard),
      const SizedBox(height: 8),
      _securityNote(),
    ],
  );

  Widget _diamondView(int diamonds) {
    final amount = int.tryParse(_diamonds.text.trim()) ?? 0;
    final output = amount.clamp(0, diamonds);
    return ListView(
      key: const ValueKey('diamond'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _balanceCard('رصيدك من الألماس', _format(diamonds), 'كل 1 ألماسة = 1 عملة ذهبية', _blue, Icons.diamond_rounded, 'التفاصيل'),
        const SizedBox(height: 4),
        _conversionCard(diamonds, output),
        const SizedBox(height: 14),
        _diamondInfoCard(),
      ],
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Text(text, style: _cairo.copyWith(color: const Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w900)),
  );

  Widget _balanceCard(String label, String value, String subtitle, Color color, IconData icon, String action) => Container(
    height: 148,
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color, _tab == 0 ? const Color(0xFFDB2777) : const Color(0xFF06B6D4)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [BoxShadow(color: color.withValues(alpha: .28), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Stack(
      children: [
        Positioned(right: -35, bottom: -40, child: Container(width: 145, height: 145, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .10)))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: _cairo.copyWith(color: Colors.white.withValues(alpha: .86), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                Row(children: [Text(value, style: _cairo.copyWith(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: .5)), const SizedBox(width: 8), Icon(icon, color: Colors.white.withValues(alpha: .9), size: 25)]),
                const SizedBox(height: 3),
                Text(subtitle, style: _cairo.copyWith(color: Colors.white.withValues(alpha: .86), fontSize: 10)),
              ]),
              TextButton(onPressed: () => _showHistory(), style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .18), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(action, style: _cairo.copyWith(fontSize: 10, fontWeight: FontWeight.w900))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _firstRechargeBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFFDE68A)), boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 5)]),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x33F59E0B), blurRadius: 8)]), child: const Icon(Icons.card_giftcard_rounded, color: Colors.white)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('حزمة الشحن الأولى', style: _cairo.copyWith(color: const Color(0xFF78350F), fontSize: 12, fontWeight: FontWeight.w900)), Text('تواصل مع الدعم لمعرفة العروض الموثقة', style: _cairo.copyWith(color: const Color(0xFFB45309), fontSize: 10, fontWeight: FontWeight.w600))])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_amber, _orange]), borderRadius: BorderRadius.circular(20)), child: Text('عروض خاصة', style: _cairo.copyWith(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900))),
    ]),
  );

  Widget _packageCard(_GoldPackage package) => InkWell(
    onTap: () => _showPackage(package),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _panelBorder), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 7, offset: Offset(0, 2))]),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFEF3C7))), child: const Icon(Icons.monetization_on_rounded, color: _amber, size: 25)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(_compact(package.gold), style: _cairo.copyWith(color: const Color(0xFF1F2937), fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(5)), child: Text('ذهبية', style: _cairo.copyWith(color: const Color(0xFF92400E), fontSize: 8, fontWeight: FontWeight.w900))) ]), Text('سعر ثابت وموضح قبل الدفع', style: _cairo.copyWith(color: const Color(0xFF9CA3AF), fontSize: 9))])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_amber, _orange]), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x33F59E0B), blurRadius: 6)]), child: Text('\$${package.usd}.00', style: _cairo.copyWith(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
      ]),
    ),
  );

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).round()}M';
    if (value >= 1000) return '${(value / 1000).round()}K';
    return _format(value);
  }

  Widget _conversionCard(int diamonds, int output) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _panelBorder), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 7)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFECFEFF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFCFFAFE))), child: const Icon(Icons.swap_horiz_rounded, color: _cyan, size: 20)), const SizedBox(width: 9), Expanded(child: Text('تحويل الألماس إلى ذهبيات', style: _cairo.copyWith(color: const Color(0xFF1F2937), fontSize: 14, fontWeight: FontWeight.w900))), Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFECFEFF), borderRadius: BorderRadius.circular(20)), child: Text('1 = 1', style: _cairo.copyWith(color: const Color(0xFF0E7490), fontSize: 10, fontWeight: FontWeight.w900)))]),
      const Padding(padding: EdgeInsets.symmetric(vertical: 13), child: Divider(height: 1, color: _panelBorder)),
      Text('أدخل عدد الألماس المراد تحويله:', style: _cairo.copyWith(color: const Color(0xFF4B5563), fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 7),
      TextField(controller: _diamonds, onChanged: (_) => setState(() {}), keyboardType: TextInputType.number, style: _cairo.copyWith(color: const Color(0xFF1F2937), fontWeight: FontWeight.w800), decoration: InputDecoration(hintText: 'أدخل الكمية...', hintStyle: _cairo.copyWith(color: const Color(0xFF9CA3AF), fontSize: 12), filled: true, fillColor: const Color(0xFFF9FAFB), suffixIcon: TextButton(onPressed: diamonds > 0 ? () { _diamonds.text = '$diamonds'; setState(() {}); } : null, child: Text('الكل', style: _cairo.copyWith(color: _cyan, fontSize: 11, fontWeight: FontWeight.w900))), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE5E7EB))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE5E7EB))))),
      const SizedBox(height: 11),
      Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFEF3C7))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('ستحصل مقابلها على:', style: _cairo.copyWith(color: const Color(0xFF92400E), fontSize: 10, fontWeight: FontWeight.w700)), Row(children: [Text(_format(output), style: _cairo.copyWith(color: const Color(0xFFB45309), fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(width: 5), const Icon(Icons.monetization_on_rounded, color: _amber, size: 17)])])),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _converting || diamonds == 0 ? null : _convert, style: FilledButton.styleFrom(backgroundColor: _cyan, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), icon: _converting ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline_rounded, size: 19), label: Text('تأكيد التحويل الفوري', style: _cairo.copyWith(fontSize: 12, fontWeight: FontWeight.w900))),
    ]),
  );

  Widget _diamondInfoCard() => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDBEAFE))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_user_rounded, color: _blue, size: 20), const SizedBox(width: 9), Expanded(child: Text('التحويل يتم داخل معاملة آمنة في Supabase. يتم التحقق من رصيدك قبل الخصم، ولا يمكن للتطبيق إنشاء ألماس أو ذهبيات من تلقاء نفسه.', style: _cairo.copyWith(color: const Color(0xFF1D4ED8), fontSize: 10, height: 1.7, fontWeight: FontWeight.w700)))]));

  Widget _securityNote() => Padding(padding: const EdgeInsets.only(top: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.lock_outline_rounded, color: Color(0xFF9CA3AF), size: 14), const SizedBox(width: 5), Text('الرصيد والمعاملات محمية عبر Supabase', style: _cairo.copyWith(color: const Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w700))]));
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({required this.rows, required this.format});
  final List<Map<String, dynamic>> rows;
  final String Function(int) format;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .65,
    child: Container(
      decoration: const BoxDecoration(color: Color(0xFFF7F8FC), borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: SafeArea(child: Column(children: [
        Container(width: 44, height: 5, margin: const EdgeInsets.only(top: 10, bottom: 8), decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(8))),
        Padding(padding: const EdgeInsets.fromLTRB(18, 4, 18, 12), child: Row(children: [const Icon(Icons.receipt_long_rounded, color: Color(0xFFF97316)), const SizedBox(width: 8), Text('سجل معاملات المحفظة', style: GoogleFonts.cairo(color: const Color(0xFF1F2937), fontSize: 16, fontWeight: FontWeight.w900))])),
        const Divider(height: 1),
        Expanded(child: rows.isEmpty ? Center(child: Text('لا توجد معاملات مسجلة بعد', style: GoogleFonts.cairo(color: const Color(0xFF9CA3AF), fontWeight: FontWeight.w700))) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, index) { final row = rows[index]; final type = row['type']?.toString() ?? 'معاملة'; final gold = (row['gold_coins'] as num?)?.toInt() ?? 0; final diamonds = (row['diamonds'] as num?)?.toInt() ?? 0; final date = row['created_at']?.toString() ?? ''; return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE5E7EB))), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: type.contains('ألماس') ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12)), child: Icon(type.contains('ألماس') ? Icons.swap_horiz_rounded : Icons.monetization_on_rounded, color: type.contains('ألماس') ? const Color(0xFF2563EB) : const Color(0xFFF59E0B), size: 20)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(type, style: GoogleFonts.cairo(color: const Color(0xFF1F2937), fontSize: 11, fontWeight: FontWeight.w900)), Text(date.isEmpty ? '—' : date.substring(0, date.length > 10 ? 10 : date.length), style: GoogleFonts.cairo(color: const Color(0xFF9CA3AF), fontSize: 9))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [if (gold > 0) Text('+${format(gold)} ذهبية', style: GoogleFonts.cairo(color: const Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.w900)), if (diamonds > 0) Text('${format(diamonds)} ألماس', style: GoogleFonts.cairo(color: const Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.w900))])])); }))
      ])),
    ),
  );
}
