import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _giftOrange = Color(0xFFF97316);
const _giftCyan = Color(0xFF06B6D4);

class RoomGiftsSheet extends StatefulWidget {
  const RoomGiftsSheet({
    super.key,
    required this.service,
    required this.roomId,
    required this.onSent,
  });
  final SakiService service;
  final String roomId;
  final Future<void> Function(String recipientId, Map<String, dynamic> gift)
  onSent;
  @override
  State<RoomGiftsSheet> createState() => _RoomGiftsSheetState();
}

class _RoomGiftsSheetState extends State<RoomGiftsSheet> {
  final _categories = const {
    'الكل': null,
    'العامة': 'general',
    'هدايا الحظ': 'luck',
    'مشاهير': 'famous',
    'الدول': 'countries',
    'VIP': 'vip',
    'CP': 'cp',
    'الحقيبة': 'bag',
  };
  String _category = 'الكل';
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic>? _selected;
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
      final recipientsRaw = await widget.service.client
          .from('room_members')
          .select('user_id,profiles:user_id(id,username,avatar_url,vip_level)')
          .eq('room_id', widget.roomId)
          .limit(100);
      final recipients = List<Map<String, dynamic>>.from(recipientsRaw)
          .map((r) => Map<String, dynamic>.from(r['profiles'] ?? {}))
          .where((p) => p['id'] != null)
          .toList();
      final me = await widget.service.myProfile();
      if (me != null && !recipients.any((p) => p['id'] == me['id'])) {
        recipients.insert(0, Map<String, dynamic>.from(me));
      }
      final gifts = await widget.service.roomGiftCatalog();
      if (mounted)
        setState(() {
          _gold = (account['gold_coins'] as num?)?.toInt() ?? 0;
          _recipients = recipients;
          _gifts = gifts;
          _selected = recipients.isEmpty ? null : recipients.first;
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
    final gifts = value == 'bag'
        ? await widget.service.roomGiftInventory()
        : await widget.service.roomGiftCatalog(category: value);
    final normalized = value == 'bag'
        ? gifts.map((r) => Map<String, dynamic>.from(r['gift'] ?? {})).toList()
        : gifts;
    if (mounted)
      setState(() {
        _gifts = normalized;
        _loading = false;
      });
  }

  Future<void> _send(Map<String, dynamic> gift) async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد مستخدمًا لاستقبال الهدية')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSent(_selected!['id'] as String, gift);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _recipients
                  .map(
                    (p) => GestureDetector(
                      onTap: () => setState(() => _selected = p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          children: [
                            SakiAvatar(
                              url: p['avatar_url'] as String?,
                              label: p['username'] as String?,
                              radius: 18,
                            ),
                            Text(
                              (p['username'] as String? ?? 'عضو').length > 7
                                  ? '${(p['username'] as String).substring(0, 7)}…'
                                  : p['username'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: p == _selected
                                    ? FontWeight.w900
                                    : FontWeight.normal,
                                color: p == _selected
                                    ? _giftOrange
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _categories.entries
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(e.key),
                        selected: e.key == _category,
                        selectedColor: _giftCyan.withValues(alpha: .2),
                        onSelected: (_) => _selectCategory(e.key, e.value),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    shrinkWrap: true,
                    itemCount: _gifts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: .78,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemBuilder: (_, i) {
                      final gift = _gifts[i];
                      return InkWell(
                        onTap: _sending ? null : () => _send(gift),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _giftCyan.withValues(alpha: .14),
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                gift['icon'] as String? ?? '🎁',
                                style: const TextStyle(fontSize: 30),
                              ),
                              Text(
                                gift['name'] as String? ?? 'هدية',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${gift['price'] ?? 0} ذهب',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _giftOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Row(
            children: [
              Text(
                'رصيدك: $_gold ذهب',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _giftOrange,
                ),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _sending
                    ? null
                    : () {
                        if (_gifts.isNotEmpty) _send(_gifts.first);
                      },
                icon: const Icon(Icons.send_rounded),
                label: const Text('إرسال هدية'),
                style: FilledButton.styleFrom(backgroundColor: _giftOrange),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
