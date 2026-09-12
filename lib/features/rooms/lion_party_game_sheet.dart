import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class LionPartyItem {
  const LionPartyItem(this.id, this.name, this.emoji, this.multiplier);
  final int id;
  final String name;
  final String emoji;
  final int multiplier;
}

const _lionItems = <LionPartyItem>[
  LionPartyItem(1, 'الأسد الذهبي', '🦁', 10),
  LionPartyItem(2, 'التاج', '👑', 15),
  LionPartyItem(3, 'الجوهرة', '💎', 25),
  LionPartyItem(4, 'العرش', '🪑', 45),
  LionPartyItem(5, 'الشعلة', '🔥', 5),
  LionPartyItem(6, 'الدرع', '🛡️', 5),
  LionPartyItem(7, 'النجمة', '⭐', 5),
  LionPartyItem(8, 'الذهب', '🪙', 5),
];

class LionPartyGameSheet extends StatefulWidget {
  const LionPartyGameSheet({super.key, required this.roomId});
  final String roomId;

  @override
  State<LionPartyGameSheet> createState() => _LionPartyGameSheetState();
}

class _LionPartyGameSheetState extends State<LionPartyGameSheet> {
  final _service = SakiService.instance;
  StreamSubscription<List<Map<String, dynamic>>>? _roundSub;
  StreamSubscription<List<Map<String, dynamic>>>? _walletSub;
  Timer? _clock;
  Timer? _spin;
  Map<String, dynamic>? _round;
  int _balance = 0;
  int _seconds = 30;
  int _bet = 1000;
  int? _selected;
  int? _winner;
  int? _flashing;
  bool _loading = true;
  bool _busy = false;
  bool _spinning = false;
  final Map<int, int> _myBets = {};
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _leaders = [];

  @override
  void initState() {
    super.initState();
    _load();
    _roundSub = _service.client
        .from('saki_lion_party_rounds')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('id', ascending: false)
        .limit(1)
        .listen((rows) {
          if (rows.isNotEmpty && mounted) _applyRound(rows.first);
        });
    _walletSub = _service.client
        .from('saki_account_modules')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', _service.uid)
        .listen((rows) {
          if (mounted && rows.isNotEmpty) {
            setState(
              () => _balance = (rows.first['gold_coins'] as num?)?.toInt() ?? 0,
            );
          }
        });
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait<dynamic>([
        _service.lionPartyGetRound(widget.roomId),
        _service.accountModules(),
        _service.lionPartyHistory(widget.roomId),
      ]);
      if (!mounted) return;
      _applyRound(Map<String, dynamic>.from(result[0] as Map));
      setState(() {
        _balance = ((result[1] as Map)['gold_coins'] as num?)?.toInt() ?? 0;
        _history = List<Map<String, dynamic>>.from(result[2] as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _message(_friendly(e));
      }
    }
  }

  void _applyRound(Map<String, dynamic> round) {
    final oldId = _round?['id']?.toString();
    final newId = round['id']?.toString();
    if (newId == null) return;
    if (oldId != newId) {
      _myBets.clear();
      _winner = null;
      _flashing = null;
      _spinning = false;
    }
    _round = round;
    final end = DateTime.tryParse(round['betting_ends_at']?.toString() ?? '');
    _seconds = end == null
        ? 0
        : end.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 30);
    final status = round['status']?.toString();
    if (status == 'spinning') {
      _winner = (round['winner_item_id'] as num?)?.toInt();
      _startSpin(round);
    } else if (status == 'finished') {
      _winner = (round['winner_item_id'] as num?)?.toInt();
      _flashing = _winner;
      _spinning = false;
      _loadLeaders(round['id']);
    }
    if (mounted) setState(() {});
    _startClock();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted || _round == null) return;
      final end = DateTime.tryParse(
        _round!['betting_ends_at']?.toString() ?? '',
      );
      final left = end == null
          ? 0
          : end.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 30);
      if (left > 0) {
        setState(() => _seconds = left);
      } else if (!_busy && !_spinning && _round!['status'] == 'open') {
        await _resolve();
      }
    });
  }

  Future<void> _resolve() async {
    final id = int.tryParse(_round?['id']?.toString() ?? '');
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      _applyRound(
        await _service.lionPartyResolveRound(
          roomId: widget.roomId,
          roundId: id,
        ),
      );
    } catch (e) {
      if (mounted && !_friendly(e).contains('round_not_ready')) {
        _message(_friendly(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startSpin(Map<String, dynamic> round) {
    if (_spinning) return;
    _spinning = true;
    _spin?.cancel();
    final started =
        DateTime.tryParse(round['spinning_started_at']?.toString() ?? '') ??
        DateTime.now().toUtc();
    var index =
        (DateTime.now().toUtc().difference(started).inMilliseconds ~/ 90) %
        _lionItems.length;
    _spin = Timer.periodic(const Duration(milliseconds: 90), (_) async {
      if (!mounted) return;
      final elapsed = DateTime.now().toUtc().difference(started).inMilliseconds;
      if (elapsed >= 5000) {
        _spin?.cancel();
        setState(() {
          _flashing = _winner;
          _spinning = false;
        });
        await _resolve();
      } else {
        index = (index + 1) % _lionItems.length;
        setState(() => _flashing = _lionItems[index].id);
      }
    });
  }

  Future<void> _placeBet(int itemId) async {
    final roundId = int.tryParse(_round?['id']?.toString() ?? '');
    if (roundId == null ||
        _round?['status'] != 'open' ||
        _seconds <= 0 ||
        _busy) {
      return;
    }
    if (_balance < _bet) {
      _message('رصيد العملات الذهبية غير كافٍ.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.lionPartyPlaceBet(
        roomId: widget.roomId,
        roundId: roundId,
        itemId: itemId,
        amount: _bet,
      );
      if (!mounted) return;
      setState(() {
        _balance = (result['balance'] as num?)?.toInt() ?? (_balance - _bet);
        _myBets[itemId] = (_myBets[itemId] ?? 0) + _bet;
        _selected = itemId;
      });
    } catch (e) {
      if (mounted) _message(_friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadLeaders(dynamic id) async {
    final roundId = int.tryParse(id?.toString() ?? '');
    if (roundId == null) return;
    try {
      final rows = await _service.lionPartyLeaderboard(roundId);
      if (mounted) setState(() => _leaders = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    _clock?.cancel();
    _spin?.cancel();
    _roundSub?.cancel();
    _walletSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * .94,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF251000), Color(0xFF08090F)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                    child: Row(
                      children: [
                        const Text(
                          'حفلة الأسد',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        _pill('🪙 ${_compact(_balance)}'),
                      ],
                    ),
                  ),
                  const Text(
                    'اختر رمزًا ثم ضع رهانك قبل انتهاء الجولة',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _wheel(),
                  _historyBar(),
                  _betControls(),
                  if (_leaders.isNotEmpty) _leadersRow(),
                ],
              ),
      ),
    );
  }

  Widget _wheel() {
    final winner = _lionItems.where((x) => x.id == _flashing).firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFF8A4B08),
                  Color(0xFFF6C453),
                  Color(0xFF5C2600),
                  Color(0xFFE4A62B),
                  Color(0xFF8A4B08),
                ],
              ),
              border: Border.all(color: Colors.amber, width: 5),
              boxShadow: const [
                BoxShadow(color: Colors.black87, blurRadius: 22),
              ],
            ),
            child: Stack(
              children: List.generate(_lionItems.length, (i) {
                final angle = i * 2 * math.pi / _lionItems.length - math.pi / 2;
                return Align(
                  alignment: Alignment(cos(angle) * .72, sin(angle) * .72),
                  child: GestureDetector(
                    onTap: () => _placeBet(_lionItems[i].id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: _flashing == _lionItems[i].id ? 68 : 58,
                      height: _flashing == _lionItems[i].id ? 68 : 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _flashing == _lionItems[i].id
                            ? Colors.white
                            : const Color(0xFF1C1420),
                        border: Border.all(
                          color: _selected == _lionItems[i].id
                              ? Colors.amber
                              : Colors.white24,
                          width: _selected == _lionItems[i].id ? 3 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _lionItems[i].emoji,
                            style: const TextStyle(fontSize: 25),
                          ),
                          Text(
                            'x${_lionItems[i].multiplier}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFB82E14),
              border: Border.all(color: Colors.amber, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 12),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'الرهان',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$_seconds',
                  style: TextStyle(
                    color: _seconds <= 5 ? Colors.redAccent : Colors.amber,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (winner != null && _round?['status'] == 'finished')
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الفائز: ${winner.emoji} ${winner.name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'آخر 10 جولات',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 5),
            itemBuilder: (_, i) {
              final id = (_history[i]['winner_item_id'] as num?)?.toInt();
              final item = _lionItems.where((x) => x.id == id).firstOrNull;
              return Container(
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: .25),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  item?.emoji ?? '•',
                  style: const TextStyle(fontSize: 21),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _betControls() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 3, 16, 8),
    child: Column(
      children: [
        Row(
          children: [
            for (final amount in [1000, 10000, 100000, 1000000])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _bet = amount),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _bet == amount
                            ? Colors.amber.shade700
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _bet == amount ? Colors.amber : Colors.white24,
                        ),
                      ),
                      child: Text(
                        _compact(amount),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _bet == amount ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _myBets.isEmpty
              ? 'اضغط على رمز في العجلة لوضع الرهان'
              : 'رهاناتك: ${_myBets.values.map(_compact).join(' + ')}',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _leadersRow() => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      'أفضل الفائزين: ${_leaders.map((x) => x['profiles'] is Map ? x['profiles']['username'] : 'لاعب').join(' • ')}',
      style: const TextStyle(
        color: Colors.amber,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.amber.withValues(alpha: .5)),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
  );
  String _compact(int value) {
    if (value >= 1000000) return '${value ~/ 1000000}M';
    if (value >= 1000) return '${value ~/ 1000}K';
    return '$value';
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('insufficient_gold')) {
      return 'رصيد العملات الذهبية غير كافٍ';
    }
    if (text.contains('betting_closed')) return 'انتهى وقت الرهان';
    if (text.contains('duplicate_item_bet')) {
      return 'لديك رهان سابق على هذا الرمز في الجولة';
    }
    if (text.contains('not_room_member')) return 'يجب أن تكون داخل الغرفة للعب';
    return 'تعذر تنفيذ العملية، حاول مرة أخرى';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  double cos(double value) => math.cos(value);
  double sin(double value) => math.sin(value);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
