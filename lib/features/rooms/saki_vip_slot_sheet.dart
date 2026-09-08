import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _slotGold = Color(0xFFFFD700);
const _slotTeal = Color(0xFF084841);
const _slotDark = Color(0xFF032622);
const _slotSymbols = <String, String>{
  'diamond': '💎',
  'crown': '👑',
  'watermelon': '🍉',
  'grape': '🍇',
  'cherry': '🍒',
  'mango': '🥭',
};

Future<void> showSakiVipSlot(
  BuildContext context,
  SakiService service,
  String roomId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => SakiVipSlotSheet(service: service, roomId: roomId),
);

class SakiVipSlotSheet extends StatefulWidget {
  const SakiVipSlotSheet({
    super.key,
    required this.service,
    required this.roomId,
  });
  final SakiService service;
  final String roomId;
  @override
  State<SakiVipSlotSheet> createState() => _SakiVipSlotSheetState();
}

class _SakiVipSlotSheetState extends State<SakiVipSlotSheet> {
  static const _wagers = [10, 50, 100, 500, 1000, 5000, 10000];
  final _random = math.Random();
  List<String> _grid = List.filled(9, 'diamond');
  int _wager = 100;
  int _balance = 0;
  int _win = 0;
  bool _spinning = false;
  Timer? _timer;
  String? _message;

  @override
  void initState() {
    super.initState();
    _randomize();
    _loadBalance();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _randomize() => _grid = List.generate(
    9,
    (_) => _slotSymbols.keys.elementAt(_random.nextInt(_slotSymbols.length)),
  );

  Future<void> _loadBalance() async {
    try {
      final account = await widget.service.accountModules();
      if (mounted) {
        setState(
          () => _balance = (account['gold_coins'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
  }

  Future<void> _spin() async {
    if (_spinning) return;
    if (_balance < _wager) {
      setState(() => _message = 'رصيد الذهب غير كافٍ لهذه الجولة');
      return;
    }
    setState(() {
      _spinning = true;
      _win = 0;
      _message = 'جاري تدوير البكرات...';
    });
    _timer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (mounted) setState(_randomize);
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    _timer?.cancel();
    try {
      final result = await widget.service.sakiVipSlotSpin(
        roomId: widget.roomId,
        wager: _wager,
      );
      final symbols = result['symbols'];
      final parsed = symbols is List
          ? symbols.map((e) => e.toString()).toList()
          : <String>[];
      if (parsed.length == 9) _grid = parsed;
      if (!mounted) return;
      final payout = (result['payout'] as num?)?.toInt() ?? 0;
      setState(() {
        _win = payout;
        _balance =
            (result['gold_coins'] as num?)?.toInt() ??
            _balance - _wager + payout;
        _spinning = false;
        _message = payout > 0
            ? 'فوز حقيقي: +$payout ذهب'
            : 'لم تربح هذه الجولة';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _message = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      height: MediaQuery.sizeOf(context).height * .94,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_slotDark, _slotTeal],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 46,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white38,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ماكينة السلوت الملكية VIP',
                    style: TextStyle(
                      color: _slotGold,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(Icons.monetization_on_rounded, color: _slotGold),
                const SizedBox(width: 5),
                Text(
                  '$_balance',
                  style: const TextStyle(
                    color: _slotGold,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'لعبة ترفيهية بعملات SAKI الذهبية داخل التطبيق',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 15),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F2D7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _slotGold, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 18),
              ],
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (_, index) => AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD0AE56), width: 2),
                  boxShadow: _win > 0
                      ? const [BoxShadow(color: _slotGold, blurRadius: 10)]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _slotSymbols[_grid[index]] ?? '💎',
                    style: const TextStyle(fontSize: 42),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'اختر قيمة الرهان',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            children: _wagers
                .map(
                  (value) => ChoiceChip(
                    label: Text('$value'),
                    selected: value == _wager,
                    selectedColor: _slotGold,
                    onSelected: _spinning
                        ? null
                        : (_) => setState(() => _wager = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _win > 0 ? _slotGold : Colors.white70,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const Spacer(),
          SizedBox(
            width: 230,
            height: 58,
            child: FilledButton.icon(
              onPressed: _spinning ? null : _spin,
              icon: _spinning
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _slotDark,
                      ),
                    )
                  : const Icon(Icons.casino_rounded),
              label: Text(_spinning ? 'جاري الدوران...' : 'دوران $_wager ذهب'),
              style: FilledButton.styleFrom(
                backgroundColor: _slotGold,
                foregroundColor: _slotDark,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'الخصم والنتيجة والربح تتم ذريًا عبر Supabase',
            style: TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
