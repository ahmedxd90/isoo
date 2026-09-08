import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import 'saki_vip_slot_sheet.dart';

const _gold = Color(0xFFFFC107);
const _blue = Color(0xFF1357B8);
const _foods = <Map<String, dynamic>>[
  {'key': 'tomato', 'name': 'طماطم', 'emoji': '🍅', 'x': 100},
  {'key': 'burger', 'name': 'برجر', 'emoji': '🍔', 'x': 45},
  {'key': 'cake', 'name': 'كيك', 'emoji': '🍰', 'x': 25},
  {'key': 'pizza', 'name': 'بيتزا', 'emoji': '🍕', 'x': 15},
  {'key': 'shrimp', 'name': 'روبيان', 'emoji': '🍤', 'x': 10},
  {'key': 'ice_cream', 'name': 'آيس كريم', 'emoji': '🍦', 'x': 7},
  {'key': 'orange', 'name': 'برتقال', 'emoji': '🍊', 'x': 5},
  {'key': 'corn', 'name': 'ذرة', 'emoji': '🌽', 'x': 5},
  {'key': 'carrot', 'name': 'جزرة', 'emoji': '🥕', 'x': 3},
];

Future<void> showSakiGames(
  BuildContext context,
  SakiService service,
  String roomId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => SakiGamesSheet(service: service, roomId: roomId),
);
Future<void> showSakiWheel(
  BuildContext context,
  SakiService service,
  String roomId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => SakiWheelGameSheet(service: service, roomId: roomId),
);

class SakiGamesSheet extends StatelessWidget {
  const SakiGamesSheet({
    super.key,
    required this.service,
    required this.roomId,
  });
  final SakiService service;
  final String roomId;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, color: _blue),
              SizedBox(width: 8),
              Text(
                'ألعاب الغرفة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              showSakiWheel(context, service, roomId);
            },
            borderRadius: BorderRadius.circular(22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/saki_wheel/game_card.png',
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 14,
                    right: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'عجلة ساكي',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_circle_up_rounded,
                          color: _gold,
                          size: 34,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'راهن بالعملات الذهبية واربح حسب الطعام الفائز',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              showSakiGoldReels(context, service, roomId);
            },
            borderRadius: BorderRadius.circular(22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/saki_games/saki_gold_reels_thumbnail.png',
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .82),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 14,
                    right: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'بكرات الذهب',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(Icons.casino_rounded, color: _gold, size: 34),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'طابق الرموز في شبكة 3×5 واربح مضاعفات ذهبية',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              showSakiVipSlot(context, service, roomId);
            },
            borderRadius: BorderRadius.circular(22),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Image.asset(
                    'assets/saki_games/saki_slot_thumbnail.png',
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: .84),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 14,
                    right: 16,
                    left: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ماكينة السلوت الملكية VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Icon(Icons.casino_rounded, color: _gold, size: 34),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '3×3 و5 خطوط فوز • الخصم والنتيجة بعملات SAKI الذهبية',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class SakiWheelGameSheet extends StatefulWidget {
  const SakiWheelGameSheet({
    super.key,
    required this.service,
    required this.roomId,
  });
  final SakiService service;
  final String roomId;
  @override
  State<SakiWheelGameSheet> createState() => _SakiWheelGameSheetState();
}

class _SakiWheelGameSheetState extends State<SakiWheelGameSheet>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _round;
  final Map<String, int> _bets = {};
  int _coin = 10;
  int _seconds = 0;
  bool _loading = true;
  String? _winner;
  String? _message;
  Timer? _timer;
  late final AnimationController _pulse;
  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.service.sakiWheelCurrentRound(widget.roomId);
      if (!mounted) return;
      setState(() {
        _round = r;
        _loading = false;
      });
      _startClock();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _startClock() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _round == null) return;
      final field = _round!['status'] == 'betting'
          ? 'betting_ends_at'
          : 'result_ends_at';
      final end = DateTime.tryParse(_round![field] as String? ?? '');
      if (end == null) return;
      final left = end.difference(DateTime.now().toUtc()).inSeconds;
      setState(() => _seconds = math.max(0, left));
      if (_round!['status'] == 'betting' && left <= 0) {
        try {
          final r = await widget.service.sakiWheelResolve(
            (_round!['id'] as num).toInt(),
          );
          if (mounted) {
            setState(() {
              _round = r;
              _winner = r['winning_food'] as String?;
            });
          }
        } catch (_) {}
      } else if (_round!['status'] == 'settled' ||
          (_round!['status'] == 'result' && left <= 0)) {
        if (_round!['status'] == 'result') {
          try {
            await widget.service.sakiWheelResolve(
              (_round!['id'] as num).toInt(),
            );
          } catch (_) {}
        }
        _load();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _bet(String key) async {
    if (_round?['status'] != 'betting' || _seconds <= 0) return;
    try {
      await widget.service.sakiWheelPlaceBet(
        roomId: widget.roomId,
        foodKey: key,
        amount: _coin,
      );
      if (mounted) {
        setState(() {
          _bets[key] = (_bets[key] ?? 0) + _coin;
          _message = 'تم تسجيل رهان $_coin ذهب';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Map<String, dynamic> _food(String key) =>
      _foods.firstWhere((f) => f['key'] == key);
  @override
  Widget build(BuildContext context) {
    final betting = _round?['status'] == 'betting';
    return SafeArea(
      child: Container(
        height: MediaQuery.sizeOf(context).height * .94,
        decoration: const BoxDecoration(
          color: _blue,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/saki_wheel/background.png',
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(.4),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'عجلة ساكي • الجولة ${_round?['round_no'] ?? '-'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            Text(
                              betting ? 'اختر طعامك' : 'النتيجة قادمة',
                              style: TextStyle(
                                color: betting ? _gold : Colors.redAccent,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _timerPill(betting),
                      Expanded(child: Center(child: _wheel())),
                      _summary(),
                      _chips(betting),
                      if (_message != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  if (_winner != null) _result(),
                ],
              ),
      ),
    );
  }

  Widget _timerPill(bool betting) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(
      color: betting ? _gold : Colors.redAccent,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Text(
      betting ? 'Select Time  $_seconds' : 'The result is coming  $_seconds',
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
  );
  Widget _wheel() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight) * .9;
        final items = <Widget>[];
        for (var i = 0; i < _foods.length; i++) {
          final angle = 2 * math.pi * i / _foods.length - math.pi / 2;
          final food = _foods[i];
          final key = food['key'] as String;
          final active =
              _winner == key ||
              (_round?['status'] == 'result' && _seconds % _foods.length == i);
          items.add(
            Positioned(
              left: size * .5 + math.cos(angle) * size * .29 - 34,
              top: size * .5 + math.sin(angle) * size * .29 - 34,
              child: GestureDetector(
                onTap: () => _bet(key),
                child: _foodBubble(food, active),
              ),
            ),
          );
        }
        items.add(
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SAKI',
                  style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Text(
                  _winner == null
                      ? 'اختَر واربح'
                      : _food(_winner!)['emoji'] as String,
                  style: const TextStyle(fontSize: 38),
                ),
              ],
            ),
          ),
        );
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: size * .78,
                  height: size * .78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF174EB0),
                    border: Border.all(color: _gold, width: 8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 18),
                    ],
                  ),
                ),
              ),
              ...items,
            ],
          ),
        );
      },
    );
  }

  Widget _foodBubble(Map<String, dynamic> food, bool active) {
    final key = food['key'] as String;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) => Transform.scale(
        scale: active ? 1 + _pulse.value * .16 : 1,
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: .93),
            shape: BoxShape.circle,
            border: Border.all(
              color: active ? _gold : Colors.white38,
              width: active ? 4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                food['emoji'] as String,
                style: const TextStyle(fontSize: 26),
              ),
              Text(
                '×${food['x']}',
                style: TextStyle(
                  color: active ? _blue : Colors.black87,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if ((_bets[key] ?? 0) > 0)
                Text(
                  'you: ${_bets[key]}',
                  style: const TextStyle(
                    color: _blue,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary() {
    final total = _bets.values.fold<int>(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: _gold),
          const SizedBox(width: 5),
          Text(
            'رهانك: $total ذهب',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          const Text(
            'اضغط الطعام بعد اختيار القيمة',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _chips(bool betting) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [10, 100, 1000, 10000, 100000]
          .map(
            (x) => ChoiceChip(
              label: Text('$x'),
              selected: _coin == x,
              selectedColor: _gold,
              onSelected: betting ? (_) => setState(() => _coin = x) : null,
            ),
          )
          .toList(),
    ),
  );
  Widget _result() {
    final f = _food(_winner!);
    return Positioned(
      bottom: 130,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _gold, width: 2),
        ),
        child: Row(
          children: [
            Text(f['emoji'] as String, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الفائز: ${f['name']}  ×${f['x']}',
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
            const Icon(Icons.celebration_rounded, color: _gold),
          ],
        ),
      ),
    );
  }
}

Future<void> showSakiGoldReels(
  BuildContext context,
  SakiService service,
  String roomId,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => SakiGoldReelsSheet(service: service, roomId: roomId),
);

class SakiGoldReelsSheet extends StatefulWidget {
  const SakiGoldReelsSheet({
    super.key,
    required this.service,
    required this.roomId,
  });
  final SakiService service;
  final String roomId;
  @override
  State<SakiGoldReelsSheet> createState() => _SakiGoldReelsSheetState();
}

class _SakiGoldReelsSheetState extends State<SakiGoldReelsSheet> {
  static const _wagers = [10, 50, 100, 500, 1000, 5000, 10000];
  static const _icons = {
    'diamond': '💎',
    'ruby': '🔴',
    'sapphire': '🔵',
    'crown': '👑',
    'chest': '🎁',
    'coin': '🪙',
  };
  final _random = math.Random();
  final List<String> _grid = List.filled(15, 'diamond');
  int _wager = 100;
  int _balance = 0;
  int _payout = 0;
  bool _spinning = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _grid.setAll(
      0,
      List.generate(
        15,
        (_) => _icons.keys.elementAt(_random.nextInt(_icons.length)),
      ),
    );
    _loadBalance();
  }

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
      setState(() => _message = 'رصيد العملات الذهبية غير كافٍ');
      return;
    }
    setState(() {
      _spinning = true;
      _payout = 0;
      _message = 'جاري تدوير البكرات...';
    });
    final animation = Timer.periodic(const Duration(milliseconds: 85), (_) {
      if (!mounted) return;
      setState(
        () => _grid.setAll(
          0,
          List.generate(
            15,
            (_) => _icons.keys.elementAt(_random.nextInt(_icons.length)),
          ),
        ),
      );
    });
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    animation.cancel();
    try {
      final result = await widget.service.sakiGoldReelsSpin(
        roomId: widget.roomId,
        wager: _wager,
      );
      final symbols = result['symbols'];
      final parsed = symbols is List
          ? symbols.map((e) => e.toString()).toList()
          : <String>[];
      if (parsed.length == 15) _grid.setAll(0, parsed);
      if (!mounted) return;
      setState(() {
        _payout = (result['payout'] as num?)?.toInt() ?? 0;
        _balance = (result['gold_coins'] as num?)?.toInt() ?? _balance - _wager;
        _message = _payout > 0
            ? 'مبروك! ربحت $_payout ذهب'
            : 'حظًا أوفر في الجولة القادمة';
        _spinning = false;
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
        color: Color(0xFF160B42),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/saki_games/saki_gold_reels_background.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(.55),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'بكرات الذهب',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.monetization_on_rounded, color: _gold),
                    const SizedBox(width: 5),
                    Text(
                      '$_balance',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'لعبة ترفيهية بعملات SAKI الافتراضية',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 15),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xDD09052A),
                  border: Border.all(color: _gold, width: 2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 15,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 7,
                    crossAxisSpacing: 7,
                  ),
                  itemBuilder: (_, index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 130),
                    decoration: BoxDecoration(
                      color: const Color(0xFF281260),
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: _payout > 0
                          ? const [BoxShadow(color: _gold, blurRadius: 7)]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        _icons[_grid[index]] ?? '💎',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'اختر قيمة الجولة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                children: _wagers
                    .map(
                      (value) => ChoiceChip(
                        label: Text('$value'),
                        selected: value == _wager,
                        selectedColor: _gold,
                        onSelected: _spinning
                            ? null
                            : (_) => setState(() => _wager = value),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 17),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _payout > 0 ? _gold : Colors.white70,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const Spacer(),
              SizedBox(
                width: 210,
                height: 55,
                child: FilledButton.icon(
                  onPressed: _spinning ? null : _spin,
                  icon: _spinning
                      ? const SizedBox.square(
                          dimension: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow_rounded),
                  label: Text(_spinning ? 'جاري اللعب' : 'ابدأ الجولة $_wager'),
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'النتيجة والخصم يتمان بأمان عبر Supabase',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    ),
  );
}
