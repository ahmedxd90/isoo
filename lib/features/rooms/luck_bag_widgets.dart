import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

import '../../shared/widgets/custom_toast.dart';

const _bagRed = Color(0xFFF43F5E);
const _bagGold = Color(0xFFFFD166);

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
          width: 126,
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B2A86), Color(0xFFB52B75)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _bagGold.withValues(alpha: .72),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x664A1D68),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
              BoxShadow(color: Colors.black45, blurRadius: 8),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: _bagGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'حقيبة حظ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '${widget.bag['claimed_count']}/${widget.bag['recipient_limit']} • ${open ? '${_left.inMinutes}:${(_left.inSeconds % 60).toString().padLeft(2, '0')}' : 'انتهت'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
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

class LuckBagClaimDialog extends StatefulWidget {
  const LuckBagClaimDialog({
    super.key,
    required this.bag,
    required this.onClaim,
  });

  final Map<String, dynamic> bag;
  final Future<Map<String, dynamic>> Function() onClaim;

  @override
  State<LuckBagClaimDialog> createState() => _LuckBagClaimDialogState();
}

class _LuckBagClaimDialogState extends State<LuckBagClaimDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  bool _claiming = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  String _formatGold(dynamic value) =>
      (value is num
              ? value.toInt()
              : int.tryParse(value?.toString() ?? '') ?? 0)
          .toString()
          .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('luck_bag_already_claimed')) {
      return 'لقد استلمت هذه الحقيبة بالفعل';
    }
    if (raw.contains('luck_bag_closed') || raw.contains('luck_bag_empty')) {
      return 'انتهت هذه الحقيبة أو لم تعد متاحة';
    }
    if (raw.contains('not_room_member')) {
      return 'يجب أن تكون داخل الغرفة لاستلام الحقيبة';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _claim() async {
    if (_claiming || _result != null) return;
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      final result = await widget.onClaim();
      if (!mounted) return;
      setState(() => _result = result);
      await _open.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _claiming = false;
          _error = _friendlyError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = _formatGold(_result?['amount_gold']);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 26),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF20133D), Color(0xFF3D1D35)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _bagGold.withValues(alpha: .75),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA11051D),
              blurRadius: 28,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'استلام حقيبة الحظ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'اضغط استلام لفتح صندوق الكنز',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 210,
              height: 190,
              child: AnimatedBuilder(
                animation: _open,
                builder: (_, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_result != null)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _open.value,
                          child: Image.asset(
                            'assets/rooms/luck_gold_burst.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    Transform.scale(
                      scale: 1 + (_open.value * .08),
                      child: Image.asset(
                        _result == null
                            ? 'assets/rooms/luck_treasure_closed.png'
                            : 'assets/rooms/luck_treasure_open.png',
                        width: 150,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              Text(
                'حصلت على $amount عملة ذهبية',
                style: const TextStyle(
                  color: _bagGold,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'تمت الإضافة إلى رصيدك الحقيقي',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ] else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _claiming ? null : _claim,
                  icon: _claiming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.card_giftcard_rounded),
                  label: Text(_claiming ? 'جارٍ الاستلام...' : 'استلام'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _bagGold,
                    foregroundColor: const Color(0xFF301A10),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LuckBagFlyBanner extends StatefulWidget {
  const LuckBagFlyBanner({
    super.key,
    required this.bag,
    required this.onGo,
    required this.onDone,
  });
  final Map<String, dynamic> bag;
  final VoidCallback onGo;
  final VoidCallback onDone;
  @override
  State<LuckBagFlyBanner> createState() => _LuckBagFlyBannerState();
}

class _LuckBagFlyBannerState extends State<LuckBagFlyBanner>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..forward();
  late final AnimationController _coins = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  )..repeat();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 5200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _coins.dispose();
    super.dispose();
  }

  String _formatGold(dynamic value) {
    final gold = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return gold.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
  }

  Map<String, dynamic> _nested(String key) {
    final value = widget.bag[key];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Widget _flyingCoin(double right, double top, double phase) => AnimatedBuilder(
    animation: _coins,
    builder: (_, _) {
      final t = (_coins.value + phase) % 1;
      return Positioned(
        right: right + math.sin(t * math.pi * 2) * 3,
        top: top - t * 8,
        child: Transform.rotate(
          angle: t * math.pi * 1.7,
          child: Icon(
            Icons.monetization_on_rounded,
            size: 13,
            color: Color.lerp(_bagGold, const Color(0xFFFFF1B2), t),
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      final t = _c.value;
      final x = t < .18
          ? 1 - t / .18
          : t > .84
          ? -(t - .84) / .16
          : 0;
      final sender = _nested('_sender');
      final room = _nested('_room');
      final senderName =
          (sender['display_name'] ?? sender['username'] ?? 'مستخدم').toString();
      final roomName = (room['name'] ?? 'غرفة').toString();
      final gold = _formatGold(widget.bag['total_gold']);

      return Positioned(
        top: 92,
        left: 8,
        right: 8,
        child: Transform.translate(
          offset: Offset(x * MediaQuery.sizeOf(context).width, 0),
          child: Center(
            child: GestureDetector(
              onTap: widget.onGo,
              child: Container(
                width: math.min(MediaQuery.sizeOf(context).width - 20, 380),
                height: 82,
                decoration: BoxDecoration(
                  color: const Color(0xFF3D2107),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _bagGold, width: 1.25),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8877460B),
                      blurRadius: 19,
                      offset: Offset(0, 5),
                    ),
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(21),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/room_effects/luck_bag_ribbon.webp',
                        fit: BoxFit.fill,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF492905).withValues(alpha: .04),
                              const Color(0xFF241202).withValues(alpha: .34),
                            ],
                            begin: AlignmentDirectional.topCenter,
                            end: AlignmentDirectional.bottomCenter,
                          ),
                        ),
                      ),
                      _flyingCoin(76, 13, 0),
                      _flyingCoin(55, 23, .42),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          88,
                          8,
                          14,
                          8,
                        ),
                        child: Row(
                          children: [
                            _SenderAvatar(
                              url: sender['avatar_url']?.toString(),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$senderName أرسل حقيبة حظ',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black87,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.monetization_on_rounded,
                                        color: Color(0xFFFFE27A),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          '$gold ذهبية · $roomName',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFFFE7A0),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.white,
      backgroundImage: url != null && url!.isNotEmpty
          ? NetworkImage(url!)
          : null,
      child: url == null || url!.isEmpty
          ? const Icon(Icons.person, color: _bagRed)
          : null,
    );
  }
}
