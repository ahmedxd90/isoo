import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _profileMint = Color(0xFF0F9F8D);
const _profileInk = Color(0xFF1E293B);
const _profileMuted = Color(0xFF64748B);
const _profileLine = Color(0xFFE2E8F0);

class AristocracyPage extends StatefulWidget {
  const AristocracyPage({super.key});

  @override
  State<AristocracyPage> createState() => _AristocracyPageState();
}

class _AristocracyPageState extends State<AristocracyPage> {
  late Future<List<Map<String, dynamic>>> _levels;

  @override
  void initState() {
    super.initState();
    _levels = SakiService.instance.aristocracyLevels();
  }

  Future<void> _refresh() async {
    final next = SakiService.instance.aristocracyLevels();
    setState(() => _levels = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FBFA),
    appBar: AppBar(
      title: const Text('الأرستقراطية'),
      centerTitle: true,
      backgroundColor: Colors.white.withValues(alpha: .92),
      surfaceTintColor: Colors.transparent,
      foregroundColor: _profileInk,
      elevation: 0,
    ),
    body: RefreshIndicator(
      color: _profileMint,
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _levels,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _profileMint),
            );
          }
          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 90),
                const Icon(Icons.error_outline, size: 42, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  'تعذر تحميل مستويات الأرستقراطية: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _profileMuted),
                ),
              ],
            );
          }
          final levels = snapshot.data ?? const [];
          if (levels.isEmpty) {
            return const Center(child: Text('لا توجد مستويات متاحة حاليًا.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              const Text(
                'مستويات النظام المتاحة',
                style: TextStyle(
                  color: _profileInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'البيانات والأسعار معروضة من كتالوج Supabase المحفوظ.',
                style: TextStyle(color: _profileMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              for (final level in levels) _AristocracyLevelCard(level: level),
            ],
          );
        },
      ),
    ),
  );
}

class _AristocracyLevelCard extends StatelessWidget {
  const _AristocracyLevelCard({required this.level});
  final Map<String, dynamic> level;

  Color _parseColor(Object? value, Color fallback) {
    final text = value?.toString().replaceFirst('#', '');
    if (text == null || text.length != 6) return fallback;
    final parsed = int.tryParse(text, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }

  String _formatNumber(Object? value) {
    final digits = value?.toString() ?? '0';
    return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final first = _parseColor(level['color_primary'], _profileMint);
    final second = _parseColor(level['color_secondary'], _profileInk);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [first, second]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: second.withValues(alpha: .16),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white38),
            ),
            child: const Icon(Icons.diamond_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level['name_ar']?.toString() ?? 'مستوى',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatNumber(level['price_gold'])} ذهب • ${level['duration_days'] ?? 30} يومًا',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

class HostAgencyDashboardPage extends StatefulWidget {
  const HostAgencyDashboardPage({super.key});

  @override
  State<HostAgencyDashboardPage> createState() =>
      _HostAgencyDashboardPageState();
}

class _HostAgencyDashboardPageState extends State<HostAgencyDashboardPage> {
  late Future<Map<String, dynamic>> _overview;

  @override
  void initState() {
    super.initState();
    _overview = SakiService.instance.hostAgencyOverview();
  }

  Future<void> _refresh() async {
    final next = SakiService.instance.hostAgencyOverview();
    setState(() => _overview = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FBFA),
    appBar: AppBar(
      title: const Text('وكالة المضيفين'),
      centerTitle: true,
      backgroundColor: Colors.white.withValues(alpha: .92),
      surfaceTintColor: Colors.transparent,
      foregroundColor: _profileInk,
      elevation: 0,
    ),
    body: RefreshIndicator(
      color: _profileMint,
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _profileMint),
            );
          }
          if (snapshot.hasError) {
            final message = snapshot.error.toString();
            final notMember =
                message.contains('agency_not_found') ||
                message.contains('host_agency_not_found');
            return ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const SizedBox(height: 72),
                Icon(
                  notMember ? Icons.mic_off_rounded : Icons.error_outline,
                  size: 46,
                  color: notMember ? _profileMint : Colors.redAccent,
                ),
                const SizedBox(height: 14),
                Text(
                  notMember
                      ? 'لا توجد وكالة مضيفين مرتبطة بحسابك حاليًا.'
                      : 'تعذر تحميل لوحة الوكالة: $message',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _profileMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (notMember) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'تظهر بيانات الوكالة هنا بعد قبول دعوة أو ربط حسابك بوكالة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _profileMuted, fontSize: 12),
                  ),
                ],
              ],
            );
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _AgencySummaryCard(data: data),
              const SizedBox(height: 14),
              if (data['role'] == 'owner')
                _AgencyMetricGrid(data: data)
              else
                _HostMetricGrid(data: data),
            ],
          );
        },
      ),
    ),
  );
}

class _AgencySummaryCard extends StatelessWidget {
  const _AgencySummaryCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final agency = data['agency'] is Map
        ? Map<String, dynamic>.from(data['agency'] as Map)
        : (data['host'] is Map
              ? Map<String, dynamic>.from(data['host'] as Map)['agency'] is Map
                    ? Map<String, dynamic>.from(
                        (data['host'] as Map)['agency'] as Map,
                      )
                    : <String, dynamic>{}
              : <String, dynamic>{});
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 25,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agency['name']?.toString() ?? 'وكالة المضيفين',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['role'] == 'owner' ? 'مالك وكالة' : 'مضيف ضمن وكالة',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgencyMetricGrid extends StatelessWidget {
  const _AgencyMetricGrid({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.55,
    children: [
      _AgencyMetric(
        label: 'المضيفون النشطون',
        value: '${data['host_count'] ?? 0}',
      ),
      _AgencyMetric(
        label: 'طلبات معلقة',
        value: '${data['pending_count'] ?? 0}',
      ),
      _AgencyMetric(
        label: 'الغرف المباشرة',
        value: '${data['active_rooms'] ?? 0}',
      ),
      _AgencyMetric(label: 'ذهب الهدايا', value: '${data['gift_gold'] ?? 0}'),
    ],
  );
}

class _HostMetricGrid extends StatelessWidget {
  const _HostMetricGrid({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final host = Map<String, dynamic>.from(data['host'] as Map? ?? const {});
    final wallet = Map<String, dynamic>.from(
      data['wallet'] as Map? ?? const {},
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AgencyMetric(
                label: 'الماس',
                value: '${host['diamonds'] ?? wallet['diamonds'] ?? 0}',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AgencyMetric(
                label: 'القيمة التقديرية',
                value:
                    '${host['usd_amount'] ?? wallet['usd_balance'] ?? 0} USD',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AgencyMetric(
                label: 'الرصيد المستحق',
                value: '${wallet['usd_balance'] ?? 0} USD',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AgencyMetric(
                label: 'إجمالي الأرباح',
                value: '${wallet['total_usd_earned'] ?? 0} USD',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AgencyMetric extends StatelessWidget {
  const _AgencyMetric({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _profileLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _profileMuted, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _profileInk,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );
}
