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
    'الكل': null,
    'عامة': 'general',
    'هدايا الحظ': 'luck',
    'CP': 'cp',
    'المشاهير': 'famous',
    'والدول': 'countries',
    'VIP فقط': 'vip',
    'الحقيبة': 'bag',
  };
  String _category = 'الكل';
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _recipients = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _selectedGift;
  int _gold = 0;
  bool _loading = true;
  bool _sending = false;
  bool _flyingBanner = true;
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
      await widget.onSent(_selected!['id'] as String, gift, _flyingBanner);
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

  Widget _giftVisual(Map<String, dynamic> gift, {double size = 30}) {
    final media = gift['media_url'] as String?;
    final icon = gift['icon'] as String? ?? '🎁';
    final thumbnail = icon.startsWith('http')
        ? icon
        : (gift['thumbnail_url'] as String?);
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return Image.network(
        thumbnail,
        width: size + 18,
        height: size + 18,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Text(icon, style: TextStyle(fontSize: size)),
      );
    }
    return Text(
      media != null && media.toLowerCase().endsWith('.mp4') ? '▶️' : icon,
      style: TextStyle(fontSize: size),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D091A),
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
          if (_selectedGift != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFA855F7).withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA855F7)),
              ),
              child: Row(
                children: [
                  _giftVisual(_selectedGift!, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedGift!['name'] as String? ?? 'هدية',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${_selectedGift!['price'] ?? 0} ذهب',
                    style: const TextStyle(color: _giftOrange),
                  ),
                ],
              ),
            ),
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
                        onTap: _sending
                            ? null
                            : () => setState(() => _selectedGift = gift),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1432),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: identical(gift, _selectedGift)
                                  ? const Color(0xFFA855F7)
                                  : _giftCyan.withValues(alpha: .14),
                              width: identical(gift, _selectedGift) ? 2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _giftVisual(gift),
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
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _flyingBanner,
            onChanged: _sending
                ? null
                : (value) => setState(() => _flyingBanner = value),
            title: const Text('إظهار شريط طائر للجميع'),
            subtitle: const Text(
              'يظهر اسم المرسل والمستقبل وصورة الهدية أعلى الغرفة',
            ),
            activeColor: const Color(0xFFA855F7),
          ),
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
                    : _selectedGift == null
                    ? null
                    : () => _send(_selectedGift!),
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
