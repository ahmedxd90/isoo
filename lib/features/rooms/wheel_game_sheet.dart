import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class WheelItem {
  const WheelItem(this.key, this.name, this.emoji, this.multiplier);
  final String key;
  final String name;
  final String emoji;
  final int multiplier;
}

const _wheelItems = <WheelItem>[
  WheelItem('tomato', 'طماطم', '🍅', 100),
  WheelItem('burger', 'برجر', '🍔', 45),
  WheelItem('cake', 'كيك', '🍰', 25),
  WheelItem('pizza', 'بيتزا', '🍕', 15),
  WheelItem('shrimp', 'جمبري', '🦐', 10),
  WheelItem('ice_cream', 'آيس كريم', '🍦', 7),
  WheelItem('orange', 'برتقال', '🍊', 5),
  WheelItem('corn', 'ذرة', '🌽', 5),
  WheelItem('carrot', 'جزر', '🥕', 3),
];

class WheelGameSheet extends StatefulWidget {
  const WheelGameSheet({super.key, required this.roomId});
  final String roomId;

  @override
  State<WheelGameSheet> createState() => _WheelGameSheetState();
}

class _WheelGameSheetState extends State<WheelGameSheet>
    with SingleTickerProviderStateMixin {
  final _service = SakiService.instance;
  Timer? _poll;
  Timer? _clock;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  Map<String, dynamic>? _round;
  final Map<String, int> _myBets = {};
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _roundWinners = [];
  int _balance = 0;
  int _seconds = 0;
  int _bet = 100;
  String? _winner;
  bool _loading = true;
  bool _busy = false;
  String? _lastResultRound;
  bool _errorShown = false;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _load() async {
    try {
      await _refresh();
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final next = await _service.wheelGetRound(widget.roomId);
      Map<String, dynamic> wallet = const {};
      List<Map<String, dynamic>> history = const [];
      try {
        wallet = await _service.accountModules();
      } catch (_) {}
      try {
        history = await _service.wheelHistory(widget.roomId);
      } catch (_) {}
      if (!mounted) return;
      final changed = _round?['id']?.toString() != next['id']?.toString();
      if (changed) {
        _myBets.clear();
        _winner = null;
        _roundWinners = [];
        _flash.reset();
      }
      final winner = next['winning_food']?.toString();
      setState(() {
        _round = next;
        _balance = (wallet['gold_coins'] as num?)?.toInt() ?? _balance;
        _history = history;
        _winner = winner;
      });
      _errorShown = false;
      if (next['status'] == 'result' && winner != null) {
        _flash.forward(from: 0);
        _showResultOnce(next);
      }
      _tick();
    } catch (error) {
      if (mounted && !_errorShown) {
        _errorShown = true;
        _message(_friendly(error));
      }
    }
  }

  void _tick() {
    final end = DateTime.tryParse(_round?['betting_ends_at']?.toString() ?? '');
    final left = end == null
        ? 0
        : end.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 30);
    if (mounted) setState(() => _seconds = left);
    if (left == 0 && _round?['status'] == 'betting' && !_busy) _resolve();
  }

  Future<void> _resolve() async {
    final id = int.tryParse(_round?['id']?.toString() ?? '');
    if (id == null || _busy) return;
    _busy = true;
    try {
      final result = await _service.wheelResolve(roundId: id);
      if (mounted) {
        setState(() => _round = result);
        await _refresh();
      }
    } catch (_) {
      // Another player may resolve the same round; polling will synchronize it.
    } finally {
      _busy = false;
    }
  }

  Future<void> _placeBet(WheelItem item) async {
    if (_round?['status'] != 'betting' || _seconds <= 0 || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await _service.wheelPlaceBet(
        roomId: widget.roomId,
        foodKey: item.key,
        amount: _bet,
      );
      if (!mounted) return;
      setState(() {
        _myBets[item.key] = (_myBets[item.key] ?? 0) + _bet;
        _balance = (result['gold_coins'] as num?)?.toInt() ?? _balance - _bet;
      });
      _message('راهنت $_bet على ${item.name}');
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showResultOnce(Map<String, dynamic> round) async {
    final key = round['id']?.toString();
    if (key == null || key == _lastResultRound) return;
    _lastResultRound = key;
    final item = _wheelItems.where((x) => x.key == _winner).firstOrNull;
    final id = int.tryParse(key);
    if (item == null || id == null || !mounted) return;
    try {
      _roundWinners = await _service.wheelRoundLeaderboard(id);
    } catch (_) {
      _roundWinners = [];
    }
    if (!mounted) return;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    final stake = _myBets[item.key] ?? 0;
    final payout = stake * item.multiplier;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: .30),
      builder: (_) => _WheelResultDialog(
        item: item,
        stake: stake,
        payout: payout,
        winners: _roundWinners,
      ),
    );
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('insufficient')) {
      return 'رصيدك من العملات الذهبية لا يكفي.';
    }
    if (text.contains('permission denied')) {
      return 'صلاحيات اللعبة غير مفعلة. أعد فتح التطبيق بعد تحديث قاعدة البيانات.';
    }
    if (text.contains('closed') || text.contains('finished')) {
      return 'انتهى وقت الرهان، انتظر الجولة التالية.';
    }
    if (text.contains('not_room_member')) return 'يجب أن تكون عضواً في الغرفة.';
    return text;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF143B1E),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/games/saki_farm_wheel_background.png'),
              fit: BoxFit.cover,
              opacity: .28,
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF376D35), Color(0xFF132B17)],
            ),
          ),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                )
              : Column(
                  children: [
                    _topBar(),
                    Expanded(child: _wheelArea()),
                    _bottomControls(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _circleButton(
              Icons.arrow_forward_rounded,
              () => Navigator.pop(context),
            ),
            const SizedBox(width: 6),
            _circleButton(Icons.list_alt_rounded, _showHistory),
            const SizedBox(width: 6),
            _circleButton(Icons.emoji_events_rounded, _showLeaderboard),
          ],
        ),
        const Text(
          'مزرعة ساكي',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextButton(
          onPressed: _showRules,
          style: TextButton.styleFrom(
            backgroundColor: Colors.black45,
            foregroundColor: const Color(0xFFFFD59A),
          ),
          child: const Text('القواعد'),
        ),
      ],
    ),
  );

  Widget _circleButton(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(30),
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF4B8F55),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFFD66B), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );

  Widget _wheelArea() => LayoutBuilder(
    builder: (context, constraints) {
      final size = math.min(constraints.maxWidth - 24, 340.0);
      return SingleChildScrollView(
        child: Column(
          children: [
            const Text(
              'مزرعة ساكي',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'الجولة ${_round?['round_no'] ?? '-'}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _round?['status'] == 'result'
                  ? 'النتيجة ظهرت'
                  : 'اختر صنفاً وارهن قبل انتهاء العدّاد',
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: size,
              height: size + 18,
              child: AnimatedBuilder(
                animation: _flash,
                builder: (_, _) => _WheelBoard(
                  size: size,
                  flashProgress: _flash.value,
                  winner: _winner,
                  seconds: _seconds,
                  bets: _myBets,
                  onTap: _placeBet,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _bottomControls() => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF86B24D), Color(0xFF3E6B2E)]),
      border: Border(top: BorderSide(color: Color(0xFF244A20), width: 5)),
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 14)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Text(
              'الرهان',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            for (final amount in [10, 100, 1000, 10000, 100000])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _betButton(amount),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _historyBar(),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _pill(Icons.monetization_on, '$_balance'),
            Text(
              'الجولة ${_round?['status'] == 'betting' ? 'مفتوحة' : 'مغلقة'}',
              style: const TextStyle(
                color: Color(0xFFFFE3A3),
                fontWeight: FontWeight.bold,
              ),
            ),
            _pill(Icons.timer_outlined, '${_seconds}s'),
          ],
        ),
      ],
    ),
  );

  Widget _betButton(int amount) {
    final active = amount == _bet;
    return InkWell(
      onTap: () => setState(() => _bet = amount),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFB938) : const Color(0xFF315A28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.white : Colors.black38,
            width: active ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            amount >= 1000 ? '${amount ~/ 1000}K' : '$amount',
            style: TextStyle(
              color: active ? Colors.black : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyBar() => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white70,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        const Text(
          'النتائج',
          style: TextStyle(
            color: Color(0xFF244A20),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _history.length,
            separatorBuilder: (_, _) => const SizedBox(width: 3),
            itemBuilder: (_, index) {
              final key = _history[index]['winning_food']?.toString();
              final item = _wheelItems.where((x) => x.key == key).firstOrNull;
              return CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white,
                child: Text(
                  item?.emoji ?? '•',
                  style: const TextStyle(fontSize: 13),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _pill(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black45,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.amberAccent),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  void _showRules() => showDialog<void>(
    context: context,
    builder: (_) => const AlertDialog(
      title: Text('طريقة مزرعة ساكي'),
      content: Text(
        'العجلة ثابتة. لديك 30 ثانية لاختيار قيمة الرهان والصنف. بعد انتهاء العدّاد يومض إطار الأصناف 5 ثوانٍ، ثم تظهر النتيجة وتبدأ جولة جديدة.',
      ),
    ),
  );

  void _showHistory() => showModalBottomSheet<void>(
    context: context,
    builder: (_) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'سجل النتائج',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ..._history.map((row) {
          final item = _wheelItems
              .where((x) => x.key == row['winning_food'])
              .firstOrNull;
          return ListTile(
            leading: Text(
              item?.emoji ?? '•',
              style: const TextStyle(fontSize: 28),
            ),
            title: Text(item?.name ?? 'نتيجة'),
            subtitle: Text('الجولة ${row['round_no'] ?? row['id'] ?? ''}'),
          );
        }),
      ],
    ),
  );

  Future<void> _showLeaderboard() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WheelLeaderboardSheet(service: _service),
    );
  }
}

class _WheelBoard extends StatelessWidget {
  const _WheelBoard({
    required this.size,
    required this.flashProgress,
    required this.winner,
    required this.seconds,
    required this.bets,
    required this.onTap,
  });
  final double size;
  final double flashProgress;
  final String? winner;
  final int seconds;
  final Map<String, int> bets;
  final ValueChanged<WheelItem> onTap;

  @override
  Widget build(BuildContext context) {
    final center = size / 2;
    final radius = size * .39;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _WheelPainter(flashProgress: flashProgress),
          ),
        ),
        Positioned(
          left: center - 60,
          top: center - 60,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFF5D1), Color(0xFF75B84A)],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFFD4A348), width: 6),
              ),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12)],
            ),
            child: Center(
              child: Text(
                '$seconds\nثانية',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF214C24),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < _wheelItems.length; i++) _slot(i, center, radius),
      ],
    );
  }

  Widget _slot(int index, double center, double radius) {
    final item = _wheelItems[index];
    final angle = -math.pi / 2 + (index * 2 * math.pi / _wheelItems.length);
    final x = center + math.cos(angle) * radius - 40;
    final y = center + math.sin(angle) * radius - 40;
    final isWinner = winner == item.key;
    final isFlashing = flashProgress > 0;
    final pulse = isFlashing
        ? (math.sin(flashProgress * math.pi * 10 + index) + 1) / 2
        : 0.0;
    final borderColor = isWinner && flashProgress >= .98
        ? Colors.white
        : (isFlashing
              ? HSVColor.fromAHSV(
                  1,
                  (index * 40 + flashProgress * 360) % 360,
                  1,
                  1,
                ).toColor()
              : const Color(0xFFEAB308));
    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onTap: () => onTap(item),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFEBA8), Color(0xFFFCD34D)],
            ),
            border: Border.all(
              color: borderColor,
              width: isFlashing ? 4 + pulse * 4 : (isWinner ? 6 : 4),
            ),
            boxShadow: [
              BoxShadow(
                color: isFlashing
                    ? borderColor.withValues(alpha: .8)
                    : Colors.black38,
                blurRadius: isFlashing ? 8 + pulse * 14 : 7,
                spreadRadius: isFlashing ? pulse * 3 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 30)),
              Text(
                'x${item.multiplier}',
                style: const TextStyle(
                  color: Color(0xFF713F12),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              if ((bets[item.key] ?? 0) > 0)
                Text(
                  '${bets[item.key]}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter({required this.flashProgress});
  final double flashProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * .47;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFE6C280), Color(0xFF6D9B43)],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = const Color(0xFF8B5A2B),
    );
    final spoke = Paint()
      ..color = const Color(0xFF673B1C)
      ..strokeWidth = 7;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        center - Offset(math.cos(a) * r, math.sin(a) * r),
        center + Offset(math.cos(a) * r, math.sin(a) * r),
        spoke,
      );
    }
    if (flashProgress > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = HSVColor.fromAHSV(
          1,
          flashProgress * 360 % 360,
          .9,
          1,
        ).toColor();
      canvas.drawCircle(
        center,
        r + 3 + math.sin(flashProgress * math.pi * 10) * 3,
        ring,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.flashProgress != flashProgress;
}

class _WheelResultDialog extends StatelessWidget {
  const _WheelResultDialog({
    required this.item,
    required this.stake,
    required this.payout,
    required this.winners,
  });
  final WheelItem item;
  final int stake;
  final int payout;
  final List<Map<String, dynamic>> winners;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .70),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amberAccent, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'نتيجة الجولة',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(item.emoji, style: const TextStyle(fontSize: 64)),
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'رهانك: $stake   ربحك: $payout',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'أكثر 3 فائزين في الجولة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          ...winners.map((row) => _WinnerRow(row: row)),
          const SizedBox(height: 8),
          const Text(
            'تبدأ جولة جديدة تلقائياً',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _WinnerRow extends StatelessWidget {
  const _WinnerRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: CircleAvatar(
      backgroundImage: (row['avatar_url']?.toString().isNotEmpty ?? false)
          ? NetworkImage(row['avatar_url'].toString())
          : null,
      child: const Icon(Icons.person),
    ),
    title: Text(
      row['username']?.toString() ?? 'مستخدم',
      style: const TextStyle(color: Colors.white),
    ),
    trailing: Text(
      '+${row['gold_won'] ?? 0}',
      style: const TextStyle(
        color: Colors.amberAccent,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _WheelLeaderboardSheet extends StatefulWidget {
  const _WheelLeaderboardSheet({required this.service});
  final SakiService service;
  @override
  State<_WheelLeaderboardSheet> createState() => _WheelLeaderboardSheetState();
}

class _WheelLeaderboardSheetState extends State<_WheelLeaderboardSheet> {
  int _tab = 0;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.service.wheelLeaderboard('daily');
  }

  void _changeTab(int tab) {
    setState(() {
      _tab = tab;
      _future = widget.service.wheelLeaderboard(tab == 0 ? 'daily' : 'weekly');
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.sizeOf(context).height * .78,
    decoration: const BoxDecoration(
      color: Color(0xFF16381E),
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 48,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.white54,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'كأس مزرعة ساكي — أفضل 100 فائز',
          style: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: [_tab == 0, _tab == 1],
          onPressed: _changeTab,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text('اليومي'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 28),
              child: Text('الأسبوعي'),
            ),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'تعذر تحميل الترتيب',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد أرباح بعد',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (_, index) => _WinnerRow(row: rows[index]),
              );
            },
          ),
        ),
      ],
    ),
  );
}
