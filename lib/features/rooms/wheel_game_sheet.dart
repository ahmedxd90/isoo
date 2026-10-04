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
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  );
  Map<String, dynamic>? _round;
  final Map<String, int> _myBets = {};
  List<Map<String, dynamic>> _history = [];
  int _balance = 0;
  int _seconds = 0;
  int _bet = 100;
  String? _winner;
  bool _loading = true;
  bool _busy = false;
  String? _lastResultRound;

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
      final values = await Future.wait<dynamic>([
        _service.wheelGetRound(widget.roomId),
        _service.accountModules(),
        _service.wheelHistory(widget.roomId),
      ]);
      if (!mounted) return;
      final next = Map<String, dynamic>.from(values[0] as Map);
      final changed = _round?['id']?.toString() != next['id']?.toString();
      if (changed) {
        _myBets.clear();
        _winner = null;
        _spin.reset();
      }
      final winner = next['winning_food']?.toString();
      setState(() {
        _round = next;
        _balance = ((values[1] as Map)['gold_coins'] as num?)?.toInt() ?? 0;
        _history = List<Map<String, dynamic>>.from(values[2] as List);
        _winner = winner;
      });
      if (next['status'] == 'result' && winner != null) {
        _spin.forward(from: 0);
        _showResultOnce(next);
      }
      _tick();
    } catch (_) {
      // Polling failures keep the last visible state; the next poll retries.
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
      // Another participant may have resolved it; polling will sync it.
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
    } catch (error) {
      if (mounted) _message(_friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResultOnce(Map<String, dynamic> round) {
    final key = round['id']?.toString();
    if (key == null || key == _lastResultRound) return;
    _lastResultRound = key;
    final item = _wheelItems.where((x) => x.key == _winner).firstOrNull;
    if (item == null || !mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      final stake = _myBets[item.key] ?? 0;
      final payout = stake * item.multiplier;
      showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: .72),
        builder: (_) =>
            _WheelResultDialog(item: item, stake: stake, payout: payout),
      );
    });
  }

  String _friendly(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('insufficient')) return 'رصيدك لا يكفي لهذا الرهان.';
    if (text.contains('closed')) {
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
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF6A421F), Color(0xFF1A1009)],
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
            _circleButton(Icons.emoji_events_rounded, _showHistory),
          ],
        ),
        TextButton(
          onPressed: _showRules,
          style: TextButton.styleFrom(
            backgroundColor: Colors.brown.shade700.withValues(alpha: .8),
            foregroundColor: const Color(0xFFFFD59A),
          ),
          child: const Text('قواعد اللعب'),
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
        color: const Color(0xFF4B8BC5),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB9E3FF), width: 2),
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
            Text(
              'معرف الجولة: ${_round?['round_no'] ?? '-'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _round?['status'] == 'result' ? 'ظهرت النتيجة' : 'حدد المرحلة',
              style: TextStyle(
                color: _round?['status'] == 'result'
                    ? Colors.yellowAccent
                    : Colors.amber.shade900,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: size,
              height: size + 18,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (_, _) => _WheelBoard(
                  size: size,
                  progress: _spin.value,
                  winner: _winner,
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
      gradient: LinearGradient(colors: [Color(0xFFD2944B), Color(0xFF995C21)]),
      border: Border(top: BorderSide(color: Color(0xFF6B3E12), width: 5)),
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
                color: Color(0xFF4A2912),
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
        height: 49,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5A2B), Color(0xFF5C3716)],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.greenAccent : const Color(0xFF3E240C),
            width: active ? 2 : 1.5,
          ),
          boxShadow: active
              ? const [BoxShadow(color: Colors.greenAccent, blurRadius: 8)]
              : null,
        ),
        child: Center(
          child: Text(
            amount >= 1000 ? '${amount ~/ 1000}K' : '$amount',
            style: const TextStyle(
              color: Color(0xFFFEF08A),
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
      color: const Color(0xFFDDB475),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: const Color(0xFFB08040)),
    ),
    child: Row(
      children: [
        const Text(
          'النتائج',
          style: TextStyle(
            color: Color(0xFF5C3716),
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
                backgroundColor: Colors.white70,
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
      border: Border.all(color: Colors.black54),
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
      title: Text('قواعد العجلة الدوارة'),
      content: Text(
        'اختر قيمة الرهان ثم اضغط على العنصر المطلوب قبل انتهاء العداد. يتم اختيار النتيجة من الخادم، وتضاف المكافأة تلقائياً إلى رصيدك.',
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
}

class _WheelBoard extends StatelessWidget {
  const _WheelBoard({
    required this.size,
    required this.progress,
    required this.winner,
    required this.onTap,
  });
  final double size;
  final double progress;
  final String? winner;
  final ValueChanged<WheelItem> onTap;

  @override
  Widget build(BuildContext context) {
    final center = size / 2;
    final radius = size * .39;
    final spinAngle = progress * math.pi * 12;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _WheelPainter())),
        Positioned(
          left: center - 60,
          top: center - 60,
          child: Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFF5D1), Color(0xFFF7D273)],
              ),
              border: Border.fromBorderSide(
                BorderSide(color: Color(0xFFD4A348), width: 6),
              ),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12)],
            ),
            child: Center(
              child: Text(
                    progress > 0 ? 'جاري\nالسحب' : _timerText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
        for (var i = 0; i < _wheelItems.length; i++)
          _slot(i, center, radius, spinAngle),
      ],
    );
  }

  String get _timerText => 'GO';

  Widget _slot(int index, double center, double radius, double spinAngle) {
    final item = _wheelItems[index];
    final angle =
        -math.pi / 2 + (index * 2 * math.pi / _wheelItems.length) + spinAngle;
    final x = center + math.cos(angle) * radius - 40;
    final y = center + math.sin(angle) * radius - 40;
    final isWinner = winner == item.key;
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
              color: isWinner ? Colors.white : const Color(0xFFEAB308),
              width: isWinner ? 6 : 4,
            ),
            boxShadow: [
              BoxShadow(
                color: isWinner ? Colors.yellowAccent : Colors.black38,
                blurRadius: isWinner ? 22 : 7,
                spreadRadius: isWinner ? 6 : 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 31)),
              Text(
                'x${item.multiplier}',
                style: const TextStyle(
                  color: Color(0xFF713F12),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
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
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = math.min(size.width, size.height) * .47;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFE6C280), Color(0xFFB38540)],
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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WheelResultDialog extends StatelessWidget {
  const _WheelResultDialog({
    required this.item,
    required this.stake,
    required this.payout,
  });
  final WheelItem item;
  final int stake;
  final int payout;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF60A5FA), width: 4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'النتيجة',
            style: TextStyle(
              color: Colors.amberAccent,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(item.emoji, style: const TextStyle(fontSize: 70)),
          Text(
            item.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'المضاعف x${item.multiplier}',
            style: const TextStyle(
              color: Colors.amberAccent,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (stake > 0)
            Text(
              payout > 0 ? 'مبروك! ربحت $payout' : 'حظ أوفر في الجولة القادمة',
              style: TextStyle(
                color: payout > 0 ? Colors.greenAccent : Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    ),
  );
}
