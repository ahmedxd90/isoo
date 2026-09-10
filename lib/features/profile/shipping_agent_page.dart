import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import 'vip_widgets.dart';

const _shipBlue = Color(0xFF2563EB);

class ShippingAgentPage extends StatefulWidget {
  const ShippingAgentPage({super.key});
  @override
  State<ShippingAgentPage> createState() => _ShippingAgentPageState();
}

class _ShippingAgentPageState extends State<ShippingAgentPage> {
  Map<String, dynamic>? _dashboard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SakiService.instance.shippingAgentDashboard();
      if (mounted) setState(() => _dashboard = data);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openTopup() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TopupSheet(),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _dashboard ?? const <String, dynamic>{};
    final coins = (data['saki_coins'] as num?)?.toInt() ?? 0;
    final username = data['username']?.toString() ?? 'وكيل شحن';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'وكيل شحن',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: SakiLoading())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        SakiAvatar(
                          url: data['avatar_url'] as String?,
                          label: username,
                          radius: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Saki ID: ${data['saki_id'] ?? '—'}',
                                style: const TextStyle(color: Colors.blueGrey),
                              ),
                              const SizedBox(height: 6),
                              const HostAgencyTitleBadge(
                                label: 'وكيل شحن',
                                compact: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_shipBlue, Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332563EB),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .18),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset('assets/badges/saki_coin.png'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'عملة ساكي',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '$coins',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                'عملة ساكي واحدة = 8,000 عملة ذهبية',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _openTopup,
                      icon: const Icon(Icons.add_card_rounded),
                      label: const Text(
                        'شحن رصيد مستخدم',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _shipBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TopupSheet extends StatefulWidget {
  const _TopupSheet();
  @override
  State<_TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends State<_TopupSheet> {
  final _id = TextEditingController();
  final _coins = TextEditingController(text: '1');
  Map<String, dynamic>? _user;
  bool _searching = false;
  bool _sending = false;

  @override
  void dispose() {
    _id.dispose();
    _coins.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = int.tryParse(_id.text.trim());
    if (id == null) return;
    setState(() => _searching = true);
    try {
      final user = await SakiService.instance.shippingFindUser(id);
      if (mounted) setState(() => _user = user);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _send() async {
    final user = _user;
    final id = int.tryParse(_id.text.trim());
    final coins = int.tryParse(_coins.text.trim());
    if (user == null || id == null || coins == null || coins <= 0) return;
    setState(() => _sending = true);
    try {
      await SakiService.instance.shippingTopupUser(id, coins);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم شحن العملة الذهبية للمستخدم وإرسال إشعار النظام.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'شحن مستخدم',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _id,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Saki ID المستخدم',
              suffixIcon: IconButton(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search_rounded),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_user != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: SakiAvatar(
                  url: _user!['avatar_url'] as String?,
                  label: _user!['username']?.toString() ?? 'مستخدم',
                ),
                title: Text(
                  _user!['username']?.toString() ?? 'مستخدم',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('Saki ID: ${_user!['saki_id']}'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _coins,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد عملات ساكي',
                helperText: 'سيحصل المستخدم على 8,000 عملة ذهبية لكل عملة ساكي',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Text(_sending ? 'جارٍ الشحن...' : 'تأكيد الشحن'),
            ),
          ],
        ],
      ),
    ),
  );
}
