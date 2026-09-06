import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class PkBattlePage extends StatefulWidget {
  const PkBattlePage({
    super.key,
    required this.roomId,
    required this.channelName,
    required this.title,
  });
  final String roomId, channelName, title;
  @override
  State<PkBattlePage> createState() => _PkBattlePageState();
}

class _PkBattlePageState extends State<PkBattlePage> {
  final _service = SakiService.instance;
  Map<String, dynamic>? _battle;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _timer;
  int _seconds = 0;
  String? _error;
  @override
  void initState() {
    super.initState();
    _sub = _service.pkBattlesStream(widget.roomId).listen((rows) {
      if (mounted && rows.isNotEmpty)
        setState(() {
          _battle = rows.first;
          _syncTimer();
        });
    });
  }

  void _syncTimer() {
    final end = DateTime.tryParse(_battle?['ends_at']?.toString() ?? '');
    _seconds = end == null
        ? 0
        : end.difference(DateTime.now()).inSeconds.clamp(0, 3600);
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds = (_seconds - 1).clamp(0, 3600);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    try {
      final row = await action();
      if (mounted)
        setState(() {
          _battle = row;
          _error = null;
          _syncTimer();
        });
    } catch (e) {
      if (mounted)
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _battle?['status'] == 'active';
    final pending = _battle?['status'] == 'pending';
    final host = (_battle?['host_score'] as num?)?.toInt() ?? 0;
    final opponent = (_battle?['opponent_score'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFF160E2B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('PK • ${widget.title}'),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFF7C3AED)],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _score('أنت', host, Colors.orangeAccent),
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  _score('الخصم', opponent, Colors.cyanAccent),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              active
                  ? 'الوقت المتبقي ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}'
                  : pending
                  ? 'بانتظار قبول الخصم'
                  : 'لا يوجد تحدي نشط',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const Spacer(),
            if (_battle == null ||
                _battle?['status'] == 'finished' ||
                _battle?['status'] == 'cancelled')
              FilledButton.icon(
                onPressed: () => _run(
                  () =>
                      _service.startPkBattle(widget.roomId, widget.channelName),
                ),
                icon: const Icon(Icons.flash_on),
                label: const Text('بدء تحدي PK'),
              ),
            if (pending)
              FilledButton.icon(
                onPressed: () => _run(
                  () => _service.acceptPkBattle(_battle!['id'] as String),
                ),
                icon: const Icon(Icons.sports_mma),
                label: const Text('قبول التحدي'),
              ),
            if (active)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _run(
                      () => _service.addPkPoints(_battle!['id'] as String, 100),
                    ),
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('+100 نقاط'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => _run(
                      () => _service.finishPkBattle(_battle!['id'] as String),
                    ),
                    child: const Text('إنهاء PK'),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _score(String label, int score, Color color) => Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(
        '$score',
        style: TextStyle(
          color: color,
          fontSize: 36,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}
