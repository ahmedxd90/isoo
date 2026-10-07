import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../profile/wallet_page.dart';

const _giftGold = Color(0xFFFFD54A);
const _giftCyan = Color(0xFF42DFFF);
const _giftPink = Color(0xFFFF6C9B);

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
    List<String> recipientIds,
    Map<String, dynamic> gift,
    int quantity,
  ) onSent;

  @override
  State<RoomGiftsSheet> createState() => _RoomGiftsSheetState();
}

class _RoomGiftsSheetState extends State<RoomGiftsSheet> {
  static const _categories = <String, String>{
    'العامة': 'general',
    'هدايا الحظ': 'luck',
    'المشاهير': 'famous',
    'الدول': 'countries',
    'CP': 'cp',
    'VIP': 'vip',
  };
  static const _quantities = [1, 7, 17, 77, 777];

  String _category = 'العامة';
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _recipients = [];
  final Set<String> _selectedIds = <String>{};
  Map<String, dynamic>? _selectedGift;
  int _quantity = 1;
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
      final results = await Future.wait<dynamic>([
        widget.service.accountModules().catchError((_) => <String, dynamic>{}),
        widget.service
            .roomSeats(widget.roomId)
            .catchError((_) => <Map<String, dynamic>>[]),
        widget.service
            .roomGiftCatalog(category: 'general')
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final account = Map<String, dynamic>.from(results[0] as Map);
      final rows = List<Map<String, dynamic>>.from(results[1] as List);
      final gifts = List<Map<String, dynamic>>.from(results[2] as List);
      final recipients = <Map<String, dynamic>>[];
      final recipientIds = <String>{};

      // Only occupied room seats are eligible recipients. The current user is
      // not added automatically when they are not seated.
      for (final row in rows) {
        final nested = row['profiles'];
        final profile = nested is Map
            ? Map<String, dynamic>.from(nested)
            : nested is List && nested.isNotEmpty && nested.first is Map
            ? Map<String, dynamic>.from(nested.first as Map)
            : <String, dynamic>{};
        final id = (profile['id'] ?? row['user_id'])?.toString();
        if (id == null || id.isEmpty || !recipientIds.add(id)) continue;
        final name = (profile['display_name'] ?? profile['username'])
            ?.toString()
            .trim();
        recipients.add({
          ...profile,
          'id': id,
          'user_id': id,
          'username': name == null || name.isEmpty ? 'عضو' : name,
          'seat_no': row['seat_no'],
        });
      }

      if (!mounted) return;
      setState(() {
        _gold = _asInt(account['gold_coins']);
        _recipients = recipients;
        _gifts = gifts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _selectCategory(String label, String value) async {
    setState(() {
      _category = label;
      _loading = true;
      _selectedGift = null;
    });
    try {
      final gifts = await widget.service.roomGiftCatalog(category: value);
      if (!mounted) return;
      setState(() {
        _gifts = gifts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatGold(int value) {
    if (value >= 1000000000000) return '${(value / 1000000000000).toStringAsFixed(value % 1000000000000 == 0 ? 0 : 1)}T';
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(value % 1000000000 == 0 ? 0 : 1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toString();
  }

  Widget _giftVisual(Map<String, dynamic> gift, {double size = 54}) {
    final icon = gift['icon']?.toString() ?? '🎁';
    final asset = gift['thumbnail_asset_path']?.toString() ??
        (icon.startsWith('assets/') ? icon : null);
    if (asset != null && asset.isNotEmpty) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(icon, style: TextStyle(fontSize: size * .65)),
      );
    }
    final thumbnail = gift['thumbnail_url']?.toString() ??
        (icon.startsWith('http') ? icon : null);
    if (thumbnail != null && thumbnail.isNotEmpty) {
      return Image.network(
        thumbnail,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(icon, style: TextStyle(fontSize: size * .65)),
      );
    }
    return Text(icon, style: TextStyle(fontSize: size * .65));
  }

  Future<void> _send() async {
    final gift = _selectedGift;
    final recipients = _selectedIds.toList();
    if (gift == null) {
      _message('اختر هدية أولاً');
      return;
    }
    if (recipients.isEmpty) {
      _message('حدد مستخدمًا واحدًا أو أكثر من المقاعد');
      return;
    }
    final price = _asInt(gift['price']);
    final total = price * _quantity * recipients.length;
    if (_gold < total) {
      await _showInsufficientBalance(total);
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSent(recipients, gift, _quantity);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        _message(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _showInsufficientBalance(int requiredGold) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF171717),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: _giftGold),
            SizedBox(width: 8),
            Text('الرصيد غير كافٍ', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'رصيدك ${_formatGold(_gold)} ذهب، والمطلوب ${_formatGold(requiredGold)} ذهب.',
          textDirection: TextDirection.rtl,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WalletPage()),
              );
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('شحن الذهب'),
          ),
        ],
      ),
    );
  }

  void _message(String text) => CustomToast.show(context, text);

  void _toggleRecipient(String id) {
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selectedIds.length == _recipients.length && _recipients.isNotEmpty) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_recipients.map((item) => item['id'].toString()));
      }
    });
  }

  Widget _seatSelector() {
    return Container(
      height: 96,
      color: const Color(0xE6000000),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
      child: _recipients.isEmpty
          ? const Center(
              child: Text(
                'لا يوجد مستخدمون على المقاعد',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : Row(
              children: [
                GestureDetector(
                  onTap: _toggleAll,
                  child: Container(
                    width: 54,
                    height: 68,
                    decoration: BoxDecoration(
                      color: _selectedIds.length == _recipients.length
                          ? _giftCyan.withValues(alpha: .18)
                          : Colors.white.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedIds.length == _recipients.length
                            ? _giftCyan
                            : Colors.white24,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedIds.length == _recipients.length
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          color: _giftCyan,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedIds.length == _recipients.length ? 'إلغاء' : 'الكل',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _recipients.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (_, index) {
                      final profile = _recipients[index];
                      final id = profile['id'].toString();
                      final selected = _selectedIds.contains(id);
                      final name = profile['username']?.toString() ?? 'عضو';
                      return GestureDetector(
                        onTap: () => _toggleRecipient(id),
                        child: SizedBox(
                          width: 58,
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: selected ? _giftCyan : Colors.white38,
                                        width: selected ? 2.2 : 1,
                                      ),
                                    ),
                                    child: SakiAvatar(
                                      url: profile['avatar_url']?.toString(),
                                      label: name,
                                      radius: 24,
                                    ),
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
                                        child: const Icon(Icons.check, size: 13, color: Colors.black),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name,
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
              ],
            ),
    );
  }

  Widget _categoryTabs() {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 5),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final entry = _categories.entries.elementAt(index);
          final active = entry.key == _category;
          return GestureDetector(
            onTap: _sending ? null : () => _selectCategory(entry.key, entry.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _giftPink : Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? _giftPink : Colors.white12),
              ),
              child: Text(
                entry.key,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _giftGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _giftCyan));
    if (_gifts.isEmpty) {
      return const Center(
        child: Text('لا توجد هدايا في هذه الفئة حالياً', style: TextStyle(color: Colors.white54)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: _gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: .72,
      ),
      itemBuilder: (_, index) {
        final gift = _gifts[index];
        final selected = identical(gift, _selectedGift);
        return GestureDetector(
          onTap: _sending ? null : () => setState(() => _selectedGift = gift),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: selected ? _giftPink.withValues(alpha: .20) : Colors.white.withValues(alpha: .055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? _giftGold : Colors.white12, width: selected ? 1.5 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(child: _giftVisual(gift)),
                Text(
                  gift['name']?.toString() ?? 'هدية',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on, color: _giftGold, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      _formatGold(_asInt(gift['price'])),
                      style: const TextStyle(color: _giftGold, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quantityBar() {
    return Container(
      height: 44,
      color: const Color(0xF0000000),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('الكمية', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          ..._quantities.map(
            (value) => GestureDetector(
              onTap: _sending ? null : () => setState(() => _quantity = value),
              child: Container(
                margin: const EdgeInsetsDirectional.only(end: 6),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _quantity == value ? _giftGold : Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  value.toString(),
                  style: TextStyle(
                    color: _quantity == value ? Colors.black : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final price = _asInt(_selectedGift?['price']);
    final total = price * _quantity * _selectedIds.length;
    return Container(
      height: 62,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: const BoxDecoration(color: Color(0xFC000000)),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.monetization_on_rounded, color: _giftGold, size: 22),
                const SizedBox(width: 5),
                Text(
                  _formatGold(_gold),
                  style: const TextStyle(color: _giftGold, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Text(
                    '−${_formatGold(total)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: _giftPink,
                disabledBackgroundColor: Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_sending ? 'جارٍ الإرسال' : 'إرسال الهدية'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * .78,
        decoration: const BoxDecoration(
          color: Color(0x99000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(8))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: _giftGold, size: 20),
                  const SizedBox(width: 8),
                  const Text('الهدايا', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text('${_selectedIds.length} مستلم', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            _seatSelector(),
            _categoryTabs(),
            Expanded(child: _giftGrid()),
            _quantityBar(),
            _footer(),
          ],
        ),
      ),
    );
  }
}
