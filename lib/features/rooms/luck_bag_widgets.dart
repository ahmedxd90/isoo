import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

import '../../shared/widgets/custom_toast.dart';

const _bagRed = Color(0xFFE73855);
const _bagGold = Color(0xFFFFC857);

class LuckBagComposer extends StatefulWidget {
  const LuckBagComposer({
    super.key,
    required this.roomId,
    required this.onCreated,
  });
  final String roomId;
  final ValueChanged<Map<String, dynamic>> onCreated;
  static Future<void> show(
    BuildContext context,
    String roomId,
    ValueChanged<Map<String, dynamic>> onCreated,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LuckBagComposer(roomId: roomId, onCreated: onCreated),
    );
  }

  @override
  State<LuckBagComposer> createState() => _LuckBagComposerState();
}

class _LuckBagComposerState extends State<LuckBagComposer> {
  int _people = 5;
  int _gold = 1000;
  bool _sending = false;
  final _peopleOptions = const [5, 10, 20, 50, 100];
  final _goldOptions = const [1000, 10000, 100000, 1000000];
  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final bag = await SakiService.instance.createRoomLuckBag(
        widget.roomId,
        _gold,
        _people,
      );
      if (mounted) Navigator.pop(context);
      widget.onCreated(bag);
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF24131A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'حقيبة الحظ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('كيف تعمل؟'),
                    content: Text(
                      'أرسل العملات، وأول المستخدمين يستلمونها خلال دقيقتين.',
                    ),
                  ),
                ),
                icon: const Icon(Icons.help_outline, color: _bagGold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'عدد المستلمين',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          _chips(_peopleOptions, _people, (v) => setState(() => _people = v)),
          const SizedBox(height: 10),
          const Text(
            'العملات الذهبية',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          _chips(
            _goldOptions,
            _gold,
            (v) => setState(() => _gold = v),
            money: true,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: _bagRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_sending ? 'جارٍ الإرسال...' : 'إرسال حقيبة الحظ'),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _chips(
    List<int> values,
    int current,
    ValueChanged<int> onTap, {
    bool money = false,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: values
        .map(
          (v) => GestureDetector(
            onTap: () => onTap(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: current == v ? _bagGold : Colors.white10,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                money ? _format(v) : '$v',
                style: TextStyle(
                  color: current == v ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
  String _format(int v) => v >= 1000000
      ? '1M'
      : v >= 1000
      ? '${v ~/ 1000}K'
      : '$v';
}

class LuckBagCard extends StatefulWidget {
  const LuckBagCard({super.key, required this.bag, required this.onClaim});
  final Map<String, dynamic> bag;
  final Future<void> Function(String id) onClaim;
  @override
  State<LuckBagCard> createState() => _LuckBagCardState();
}

class _LuckBagCardState extends State<LuckBagCard> {
  Timer? _timer;
  Duration _left = Duration.zero;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final d = DateTime.tryParse(widget.bag['expires_at']?.toString() ?? '');
    if (mounted) {
      setState(
        () => _left = d == null
            ? Duration.zero
            : d.difference(DateTime.now().toUtc()),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _left > Duration.zero && widget.bag['status'] == 'open';
    return Positioned(
      left: 12,
      bottom: 112,
      child: GestureDetector(
        onTap: open && !_busy
            ? () async {
                setState(() => _busy = true);
                try {
                  await widget.onClaim(widget.bag['id'].toString());
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              }
            : null,
        child: Container(
          width: 154,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _bagRed,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bagGold, width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _bagGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, color: _bagRed),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حقيبة حظ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${widget.bag['claimed_count']}/${widget.bag['recipient_limit']} • ${open ? '${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}' : 'انتهت'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LuckBagFlyBanner extends StatefulWidget {
  const LuckBagFlyBanner({super.key, required this.bag, required this.onGo});
  final Map<String, dynamic> bag;
  final VoidCallback onGo;
  @override
  State<LuckBagFlyBanner> createState() => _LuckBagFlyBannerState();
}

class _LuckBagFlyBannerState extends State<LuckBagFlyBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..forward();
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 12), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = _c.value;
      final x = t < .25
          ? 1 - t / .25
          : t < .75
          ? 0
          : (t - .75) / .25 - 1;
      return Positioned(
        top: 72,
        left: x == 0 ? 12 : null,
        right: x == 0 ? 12 : null,
        child: Transform.translate(
          offset: Offset(x * MediaQuery.sizeOf(context).width, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _bagRed,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _bagGold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  backgroundColor: _bagGold,
                  child: Icon(Icons.card_giftcard, color: _bagRed),
                ),
                const SizedBox(width: 8),
                const Text(
                  'أرسل حقيبة حظ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: widget.onGo, child: const Text('اذهب')),
              ],
            ),
          ),
        ),
      );
    },
  );
}
