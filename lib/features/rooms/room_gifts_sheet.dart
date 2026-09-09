import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

import '../../shared/widgets/custom_toast.dart';

const _giftOrange = Color(0xFFFF8A3D);
const _giftCyan = Color(0xFF32D7FF);
const _giftViolet = Color(0xFF9B6CFF);

class RoomGiftsSheet extends StatefulWidget {
  const RoomGiftsSheet({
    super.key,
    required this.service,
    required this.roomId,
    required this.onSent,
  });

  final SakiService service;
  final String roomId;
  final Future<void> Function(
    String recipientId,
    Map<String, dynamic> gift,
    bool flyingBanner,
  )
  onSent;

  @override
  State<RoomGiftsSheet> createState() => _RoomGiftsSheetState();
}

class _RoomGiftsSheetState extends State<RoomGiftsSheet> {
  final _categories = const {
    'عامة': 'general',
    'المشاهير': 'famous',
    'الحظ': 'luck',
    'CP': 'cp',
    'الدول': 'countries',
    'VIP': 'vip',
  };

  String _category = 'عامة';
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _recipients = [];
  final Set<String> _selectedIds = <String>{};
  Map<String, dynamic>? _selectedGift;
  int _gold = 0;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final account = await widget.service.accountModules();
      final rows = await widget.service.client
          .from('room_seats')
          .select('user_id,profiles:user_id(id,username,avatar_url,vip_level)')
          .eq('room_id', widget.roomId)
          .limit(20);
      final recipients = List<Map<String, dynamic>>.from(rows)
          .map((row) => Map<String, dynamic>.from(row['profiles'] ?? {}))
          .where((profile) => profile['id'] != null)
          .toList();
      final gifts = await widget.service.roomGiftCatalog(category: 'general');
      if (!mounted) return;
      setState(() {
        _gold = (account['gold_coins'] as num?)?.toInt() ?? 0;
        _recipients = recipients;
        _gifts = gifts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectCategory(String label, String? value) async {
    setState(() {
      _category = label;
      _loading = true;
    });
    final gifts = await widget.service.roomGiftCatalog(category: value);
    final normalized = gifts;
    if (mounted) {
      setState(() {
        _gifts = normalized;
        _loading = false;
      });
    }
  }

  Widget _giftVisual(Map<String, dynamic> gift, {double size = 38}) {
    final icon = gift['icon'] as String? ?? '🎁';
    final thumbnail = icon.startsWith('http')
        ? icon
        : (gift['thumbnail_url'] as String?);
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return Image.network(
        thumbnail,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) =>
            Text(icon, style: TextStyle(fontSize: size * .75)),
      );
    }
    return Text(icon, style: TextStyle(fontSize: size * .75));
  }

  Future<void> _send() async {
    final gift = _selectedGift;
    if (gift == null) {
      _message('اختر هدية أولاً');
      return;
    }
    if (_selectedIds.isEmpty) {
      _message('حدد مستخدماً واحداً على الأقل من المقاعد');
      return;
    }
    setState(() => _sending = true);
    try {
      for (final recipientId in _selectedIds.toList()) {
        await widget.onSent(recipientId, gift, true);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Exception: ', ''));
        setState(() => _sending = false);
      }
    }
  }

  void _message(String text) {
    CustomToast.show(context, text);
  }

  void _toggleRecipient(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_recipients.every((p) => _selectedIds.contains(p['id'].toString()))) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_recipients.map((p) => p['id'].toString()));
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      height: MediaQuery.sizeOf(context).height * .55,
      decoration: const BoxDecoration(
        color: Color(0xF20B1515),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: Color(0x6648E0B0), width: 1.2)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [SizedBox(height: 4)],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Text(
                  'المستلمون',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _recipients.isEmpty ? null : _toggleAll,
                  child: Text(
                    _selectedIds.length == _recipients.length &&
                            _recipients.isNotEmpty
                        ? 'إلغاء الكل'
                        : 'تحديد الكل',
                    style: const TextStyle(
                      color: _giftCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedIds.length}/${_recipients.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 92,
            child: _recipients.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد مستخدمون على المقاعد',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recipients.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final profile = _recipients[index];
                      final id = profile['id'].toString();
                      final selected = _selectedIds.contains(id);
                      return GestureDetector(
                        onTap: () => _toggleRecipient(id),
                        child: SizedBox(
                          width: 58,
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  SakiAvatar(
                                    url: profile['avatar_url'] as String?,
                                    label: profile['username'] as String?,
                                    radius: 25,
                                  ),
                                  if (selected)
                                    PositionedDirectional(
                                      end: -2,
                                      top: -4,
                                      child: Container(
                                        width: 19,
                                        height: 19,
                                        decoration: const BoxDecoration(
                                          color: _giftCyan,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile['username'] as String? ?? 'عضو',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? _giftCyan : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              children: _categories.entries
                  .map(
                    (entry) => GestureDetector(
                      onTap: () => _selectCategory(entry.key, entry.value),
                      child: Container(
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: _category == entry.key
                              ? _giftViolet
                              : Colors.white.withValues(alpha: .06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _category == entry.key
                                ? _giftViolet
                                : Colors.white12,
                          ),
                        ),
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            color: _category == entry.key
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _giftCyan),
                  )
                : _gifts.isEmpty
                ? const _GiftEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    itemCount: _gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: .78,
                        ),
                    itemBuilder: (_, index) {
                      final gift = _gifts[index];
                      final selected = identical(gift, _selectedGift);
                      return GestureDetector(
                        onTap: _sending
                            ? null
                            : () => setState(() => _selectedGift = gift),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: selected
                                ? _giftViolet.withValues(alpha: .24)
                                : Colors.white.withValues(alpha: .055),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: selected ? _giftCyan : Colors.white12,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(child: _giftVisual(gift)),
                              Text(
                                gift['name'] as String? ?? 'هدية',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${gift['price'] ?? 0} ذهب',
                                style: const TextStyle(
                                  color: _giftOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_giftOrange, Color(0xFFFF4F81)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x55FF6B35),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      _sending ? '...' : 'إرسال',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _BalanceBadge(gold: _gold),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({required this.gold});
  final int gold;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.amber.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.amber.withValues(alpha: .25)),
    ),
    child: Text(
      '$gold ذهب',
      style: const TextStyle(
        color: Colors.amberAccent,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _GiftEmptyState extends StatelessWidget {
  const _GiftEmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.card_giftcard_outlined, color: Colors.white24, size: 52),
        const SizedBox(height: 8),
        const Text(
          'لا توجد هدايا هنا حالياً',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    ),
  );
}
