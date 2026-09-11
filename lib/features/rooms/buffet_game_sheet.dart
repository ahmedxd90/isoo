import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';

class BuffetFood {
  const BuffetFood(this.id, this.name, this.multiplier, this.emoji);
  final int id;
  final String name;
  final int multiplier;
  final String emoji;
}

const _foods = <BuffetFood>[
  BuffetFood(1, 'نقانق', 10, '🌭'),
  BuffetFood(2, 'دجاج', 15, '🍗'),
  BuffetFood(3, 'جمبري', 25, '🦐'),
  BuffetFood(4, 'لحم', 45, '🥩'),
  BuffetFood(5, 'طماطم', 5, '🍅'),
  BuffetFood(6, 'فجل', 5, '🍠'),
  BuffetFood(7, 'فطر', 5, '🍄'),
  BuffetFood(8, 'ذرة', 5, '🌽'),
];

class BuffetGameCatalogSheet extends StatelessWidget {
  const BuffetGameCatalogSheet({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .72,
    ),
    decoration: const BoxDecoration(
      color: Color(0xFF176B37),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'الألعاب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Future<void>.delayed(Duration.zero, () {
                  if (!context.mounted) return;
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => BuffetGameSheet(roomId: roomId),
                  );
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD166), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.asset(
                        'assets/games/buffet_game_cover.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 13),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'لعبة بوفيه الأطعمة',
                              style: TextStyle(
                                color: Color(0xFF14532D),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFC83B), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'العب الآن',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BuffetGameSheet extends StatefulWidget {
  const BuffetGameSheet({super.key, required this.roomId});
  final String roomId;

  @override
  State<BuffetGameSheet> createState() => _BuffetGameSheetState();
}

class _BuffetGameSheetState extends State<BuffetGameSheet> {
  final _service = SakiService.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _roundSubscription;
  Timer? _timer;
  Timer? _spinTimer;
  Map<String, dynamic>? _round;
  final Map<int, int> _myBets = {};
  final List<String> _history = [];
  int _balance = 0;
  final int _todayProfit = 0;
  int _currentBet = 100;
  int _seconds = 30;
  int? _winnerId;
  bool _loading = true;
  bool _busy = false;
  bool _revealing = false;
  bool _soundEnabled = true;
  String? _resultShownRound;
  int? _flashFoodId;
  List<Map<String, dynamic>> _leaders = [];

  @override
  void initState() {
    super.initState();
    _load();
    _roundSubscription = _service.client
        .from('saki_buffet_rounds')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('id', ascending: false)
        .limit(1)
        .listen((rows) {
          if (rows.isNotEmpty && mounted) _applyRound(rows.first);
        });
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<dynamic>([
        _service.buffetGetRound(widget.roomId),
        _service.accountModules(),
        _service.buffetHistory(widget.roomId),
      ]);
      if (!mounted) return;
      _applyRound(Map<String, dynamic>.from(values[0] as Map));
      setState(() {
        _balance = ((values[1] as Map)['gold_coins'] as num?)?.toInt() ?? 0;
        _history
          ..clear()
          ..addAll(
            (values[2] as List).map((row) {
              final winner = (row['winner_food_id'] as num?)?.toInt();
              return winner == null
                  ? '•'
                  : _foods.firstWhere((food) => food.id == winner).emoji;
            }),
          );
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _toast(_friendlyError(error));
      }
    }
  }

  void _applyRound(Map<String, dynamic> next) {
    final id = int.tryParse(next['id']?.toString() ?? '');
    if (id == null) return;
    final changed = _round?['id']?.toString() != next['id']?.toString();
    if (changed) {
      _myBets.clear();
      _winnerId = null;
      _flashFoodId = null;
      _revealing = false;
      _leaders = [];
    }
    setState(() {
      _round = next;
      final end = DateTime.tryParse(next['betting_ends_at']?.toString() ?? '');
      _seconds = end == null
          ? 0
          : end.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 30);
      if (next['status'] == 'finished') {
        _winnerId = (next['winner_food_id'] as num?)?.toInt();
        _flashFoodId = _winnerId;
        _revealing = true;
      }
    });
    _startTimer();
    if (next['status'] == 'spinning') {
      _beginSpin(next);
    } else if (next['status'] == 'finished') {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showRoundResult(next),
      );
    }
  }

  void _beginSpin(Map<String, dynamic> round) {
    _spinTimer?.cancel();
    final winner = (round['winner_food_id'] as num?)?.toInt();
    final started =
        DateTime.tryParse(round['spinning_started_at']?.toString() ?? '') ??
        DateTime.now().toUtc();
    final elapsed = DateTime.now()
        .toUtc()
        .difference(started)
        .inMilliseconds
        .clamp(0, 5000);
    var index = (elapsed ~/ 80) % _foods.length;
    setState(() => _revealing = true);
    _spinTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!mounted) return;
      final current = DateTime.now().toUtc().difference(started).inMilliseconds;
      if (current >= 5000) {
        _spinTimer?.cancel();
        setState(() {
          _flashFoodId = winner;
          _winnerId = winner;
        });
        await _finishSpinning(round);
      } else {
        index = (index + 1) % _foods.length;
        setState(() => _flashFoodId = _foods[index].id);
      }
    });
  }

  Future<void> _finishSpinning(Map<String, dynamic> round) async {
    final id = int.tryParse(round['id']?.toString() ?? '');
    if (id == null) return;
    try {
      final finished = await _service.buffetFinishRound(
        roomId: widget.roomId,
        roundId: id,
      );
      if (mounted) _applyRound(finished);
    } catch (error) {
      if (mounted && !_friendlyError(error).contains('result_not_ready')) {
        _toast(_friendlyError(error));
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _round == null) return;
      final end = DateTime.tryParse(
        _round!['betting_ends_at']?.toString() ?? '',
      );
      final left = end == null
          ? 0
          : end.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 30);
      if (left > 0) {
        setState(() => _seconds = left);
      } else if (!_revealing && !_busy) {
        setState(() => _revealing = true);
        await _resolve();
      }
    });
  }

  Future<void> _resolve() async {
    final id = int.tryParse(_round?['id']?.toString() ?? '');
    if (id == null) return;
    try {
      final spinning = await _service.buffetResolveRound(
        roomId: widget.roomId,
        roundId: id,
      );
      if (mounted) _applyRound(spinning);
    } catch (error) {
      if (mounted && !_friendlyError(error).contains('round_not_ready')) {
        _toast(_friendlyError(error));
      }
    }
  }

  Future<void> _showRoundResult(Map<String, dynamic> result) async {
    final roundKey = result['id']?.toString();
    final winner = (result['winner_food_id'] as num?)?.toInt();
    if (!mounted ||
        roundKey == null ||
        winner == null ||
        _resultShownRound == roundKey) {
      return;
    }
    _resultShownRound = roundKey;
    final food = _foods.firstWhere((item) => item.id == winner);
    final win = (_myBets[winner] ?? 0) * food.multiplier;
    try {
      _leaders = await _service.buffetLeaderboard(int.parse(roundKey));
    } catch (_) {
      _leaders = [];
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text(
            '✨ نتيجة الجولة الحالية ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFF8F00),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(food.emoji, style: const TextStyle(fontSize: 58)),
              Text(
                '${food.name} — فوز ${food.multiplier}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                win > 0
                    ? 'مبروك! ربحت +${_compact(win)} 🪙'
                    : 'لم تصب الخيار الفائز في هذه الجولة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: win > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_leaders.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'أفضل 3 فائزين في الجولة',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 94,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_leaders.length, (index) {
                      final leader = _leaders[index];
                      final avatar = leader['avatar_url']?.toString() ?? '';
                      return Expanded(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 23,
                              backgroundImage: avatar.startsWith('http')
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar.startsWith('http')
                                  ? null
                                  : const Icon(Icons.person),
                            ),
                            Text(
                              leader['username']?.toString() ?? 'مستخدم',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              '+${_compact((leader['profit'] as num?)?.toInt() ?? 0)} 🪙',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFFF8F00),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (mounted && _round?['id']?.toString() == roundKey) {
      _applyRound(await _service.buffetGetRound(widget.roomId));
    }
  }

  Future<void> _placeBet(BuffetFood food) async {
    if (_busy || _round == null || _seconds <= 0 || _revealing) return;
    final existing = _myBets.containsKey(food.id);
    if (!existing && _myBets.length >= 6) {
      _toast('يمكنك الرهان على 6 أطعمة كحد أقصى في الجولة');
      return;
    }
    if (_balance < _currentBet) {
      _toast('رصيدك لا يكفي لهذا الرهان');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.buffetPlaceBet(
        roomId: widget.roomId,
        roundId: int.parse(_round!['id'].toString()),
        foodId: food.id,
        amount: _currentBet,
      );
      if (!mounted) return;
      setState(() {
        _myBets[food.id] =
            (result['food_total'] as num?)?.toInt() ?? _currentBet;
        _balance =
            (result['balance'] as num?)?.toInt() ?? (_balance - _currentBet);
      });
      _toast('تم الرهان على ${food.name} ${food.emoji} بـ $_currentBet');
    } catch (error) {
      if (mounted) _toast(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('insufficient_gold')) {
      return 'رصيد العملات الذهبية غير كافٍ';
    }
    if (text.contains('betting_closed')) return 'انتهى وقت الرهان لهذه الجولة';
    if (text.contains('max_six_foods')) return 'الحد الأقصى 6 أطعمة في الجولة';
    if (text.contains('not_room_member')) return 'يجب أن تكون داخل الغرفة للعب';
    return 'تعذر تنفيذ العملية، حاول مرة أخرى';
  }

  void _toast(String text) {
    CustomToast.show(
      context,
      text,
      icon: Icons.casino_rounded,
      accent: const Color(0xFFFFC83B),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roundSubscription?.cancel();
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 480,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC83B)),
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .96,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF71CD88), Color(0xFF4DAE64)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
          child: Column(
            children: [
              _dragHandle(),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '🍱 لعبة بوفيه الأطعمة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _circleButton(Icons.rule_rounded, () => _showRules()),
                  _circleButton(
                    _soundEnabled ? Icons.music_note : Icons.music_off,
                    () => setState(() => _soundEnabled = !_soundEnabled),
                  ),
                  _circleButton(
                    Icons.close_rounded,
                    () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _floatingFood('🥗'),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC83B), Color(0xFFFF8C00)],
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '${_seconds.toString().padLeft(2, '0')}s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _floatingFood('🍕'),
                ],
              ),
              const SizedBox(height: 8),
              _yellowBoard(),
              const SizedBox(height: 10),
              _betSelector(),
              const SizedBox(height: 8),
              _balanceRow(),
              const SizedBox(height: 8),
              _historyRow(),
              if (_revealing && _winnerId != null) _resultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      width: 48,
      height: 6,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
  Widget _circleButton(IconData icon, VoidCallback onTap) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, color: const Color(0xFF287A3C), size: 19),
    style: IconButton.styleFrom(
      backgroundColor: Colors.white70,
      padding: EdgeInsets.zero,
      minimumSize: const Size(34, 34),
    ),
  );
  Widget _floatingFood(String emoji) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .9),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
    ),
    child: Text(emoji, style: const TextStyle(fontSize: 23)),
  );

  Widget _yellowBoard() => Container(
    padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        colors: [Colors.white, Color(0xFFFFF8A6), Color(0xFFFFEA55)],
      ),
      border: Border.all(color: Colors.white, width: 5),
      borderRadius: BorderRadius.circular(42),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
    ),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _foods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 5,
        mainAxisSpacing: 7,
        childAspectRatio: .82,
      ),
      itemBuilder: (_, index) {
        final food = _foods[index];
        final selected = _myBets.containsKey(food.id);
        final winner = _winnerId == food.id;
        final flashing = _flashFoodId == food.id && _revealing;
        return GestureDetector(
          onTap: () => _placeBet(food),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: flashing
                            ? Colors.red
                            : winner
                            ? Colors.red
                            : selected
                            ? const Color(0xFFFF9800)
                            : const Color(0xFF3ECF6D),
                        width: winner ? 5 : 3,
                      ),
                      boxShadow: [
                        if (selected || winner || flashing)
                          const BoxShadow(
                            color: Colors.orangeAccent,
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                      ],
                    ),
                    child: Text(
                      food.emoji,
                      style: const TextStyle(fontSize: 31),
                    ),
                  ),
                  if (_myBets[food.id] != null)
                    Positioned(
                      right: -4,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF9100), Color(0xFFFF2A00)],
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _compact(_myBets[food.id]!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                'فوز ${food.multiplier}',
                style: TextStyle(
                  color: food.multiplier >= 25
                      ? Colors.red.shade800
                      : const Color(0xFFE65100),
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _betSelector() => Row(
    children: [100, 1000, 10000, 100000].map((amount) {
      final selected = amount == _currentBet;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _currentBet = amount),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: selected
                    ? [const Color(0xFFFFD000), const Color(0xFFFF9100)]
                    : [const Color(0xFF52E165), const Color(0xFF20B033)],
              ),
              border: Border.all(color: Colors.white, width: 2.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, offset: Offset(0, 3)),
              ],
            ),
            child: Center(
              child: Text(
                _compact(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _balanceRow() => Row(
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF2CB742),
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundColor: Color(0xFFFFC107),
                child: Icon(Icons.star, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                _compact(_balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFCA28), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'تعبئة رصيد',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 6),
      Container(
        width: 82,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: const BoxDecoration(
                color: Color(0xFF38B000),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: const Text(
                'أرباح اليوم',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(3),
              child: Text(
                '+$_todayProfit',
                style: const TextStyle(
                  color: Color(0xFFFF8F00),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _historyRow() => Container(
    height: 43,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      children: [
        const Text(
          'السجل',
          style: TextStyle(
            color: Color(0xFF287A3C),
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 10),
        ..._history.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(e, style: const TextStyle(fontSize: 21)),
          ),
        ),
      ],
    ),
  );

  Widget _resultCard() {
    final food = _foods.firstWhere((item) => item.id == _winnerId);
    final myWin = (_myBets[food.id] ?? 0) * food.multiplier;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFC107), width: 3),
      ),
      child: Column(
        children: [
          const Text(
            '✨ نتيجة الجولة الحالية ✨',
            style: TextStyle(
              color: Color(0xFFFF8F00),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(food.emoji, style: const TextStyle(fontSize: 48)),
          Text(
            '${food.name} — فوز ${food.multiplier}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            myWin > 0
                ? 'مبروك! ربحت +${_compact(myWin)} 🪙'
                : 'لم تصب الخيار الفائز في هذه الجولة',
            style: TextStyle(
              color: myWin > 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showRules() => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('قواعد اللعبة'),
      content: const Text(
        'اختر طعامًا واحدًا أو أكثر بحد أقصى 6 أطعمة، ثم اختر قيمة الرهان. عند انتهاء 30 ثانية يحدد الخادم الطعام الفائز وتظهر النتيجة للجميع داخل الغرفة. العملات ذهبية ترفيهية داخل SAKI.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('حسنًا'),
        ),
      ],
    ),
  );
  String _compact(int value) => value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(1)}M'
      : value >= 1000
      ? '${(value / 1000).toStringAsFixed(0)}K'
      : '$value';
}
