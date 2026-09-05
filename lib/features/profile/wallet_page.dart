import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});
  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _service = SakiService.instance;
  Map<String, dynamic> _account = {};
  bool _loading = true;
  bool _converting = false;
  int _tab = 0;
  final _diamonds = TextEditingController();

  static const _orange = Color(0xFFF97316);
  static const _cyan = Color(0xFF06B6D4);
  static const _ink = Color(0xFF0F172A);
  static const _panel = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = await _service.accountModules();
      if (mounted) setState(() => _account = account);
    } catch (error) {
      if (mounted) _message('تعذر تحميل المحفظة من Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convert() async {
    final amount = int.tryParse(_diamonds.text.trim()) ?? 0;
    final balance = (_account['diamonds'] as num?)?.toInt() ?? 0;
    if (amount <= 0 || amount > balance) {
      _message('أدخل كمية صحيحة ضمن رصيد الماس الحالي.');
      return;
    }
    setState(() => _converting = true);
    try {
      final updated = await _service.convertDiamondsToGold(amount);
      if (mounted) {
        setState(() {
          _account = {..._account, ...updated};
          _diamonds.clear();
        });
        _message('تم تحويل $amount ماسة إلى عملات ذهبية بنجاح.');
      }
    } catch (_) {
      if (mounted) _message('فشل التحويل أو أن رصيد الماس غير كافٍ.');
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _diamonds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gold = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    final diamonds = (_account['diamonds'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: _ink,
      appBar: AppBar(
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _cyan),
          onPressed: () => Navigator.pop(context, true),
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tabButton('ذهبيات', 0, _orange),
              _tabButton('الماس', 1, _cyan),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tab == 0 ? _goldView(gold) : _diamondView(diamonds),
            ),
    );
  }

  Widget _tabButton(String label, int index, Color color) => GestureDetector(
    onTap: () => setState(() => _tab = index),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
      decoration: BoxDecoration(
        color: _tab == index ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _tab == index ? Colors.white : color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    ),
  );

  Widget _goldView(int gold) => ListView(
    key: const ValueKey('gold'),
    padding: const EdgeInsets.only(bottom: 30),
    children: [
      _balanceCard(
        'رصيدك الحالي',
        '$gold',
        'عملات Saki الذهبية المتاحة',
        _orange,
        Icons.monetization_on_rounded,
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(18, 6, 18, 12),
        child: Text(
          'شراء العملات الذهبية',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
      ),
      ...[
        ('7,500', '1.00'),
        ('37,500', '5.00'),
        ('75,000', '10.00'),
        ('187,500', '25.00'),
        ('750,000', '100.00'),
      ].map((package) => _packageCard(package.$1, package.$2)),
      Center(
        child: TextButton.icon(
          onPressed: () => _message('الدعم الفني متاح لمساعدتك.'),
          icon: const Icon(Icons.support_agent, color: _cyan),
          label: const Text(
            'تواصل معنا',
            style: TextStyle(color: _cyan, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ],
  );

  Widget _diamondView(int diamonds) => ListView(
    key: const ValueKey('diamond'),
    padding: const EdgeInsets.only(bottom: 30),
    children: [
      _balanceCard(
        'رصيد الألماس الخاص بك',
        '$diamonds',
        'كل 1 ماسة تساوي 1 عملة ذهبية Saki',
        _cyan,
        Icons.diamond_rounded,
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: _cyan),
                SizedBox(width: 8),
                Text(
                  'تحويل الألماس إلى ذهبيات',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'التحويل يتم مباشرة في قاعدة البيانات بمعدل 1 إلى 1.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _diamonds,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'كمية الماس',
                labelStyle: const TextStyle(color: _cyan),
                filled: true,
                fillColor: _ink,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _converting ? null : _convert,
              style: FilledButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _converting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: const Text(
                'تأكيد تحويل الألماس',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _balanceCard(
    String label,
    String value,
    String subtitle,
    Color color,
    IconData icon,
  ) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [color, color.withValues(alpha: .75)]),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .25),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(icon, color: Colors.white70, size: 30),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color.fromRGBO(255, 255, 255, .9),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _packageCard(String coins, String price) => InkWell(
    onTap: () => _message(
      'سيتم إكمال شراء $coins عملة مقابل \$US $price بعد تفعيل بوابة الدفع.',
    ),
    borderRadius: BorderRadius.circular(18),
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '\$US $price',
              style: const TextStyle(
                color: _orange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Row(
            children: [
              Text(
                coins,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 14,
                backgroundColor: _orange,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
