import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _blue = Color(0xFF656BF9);
const _ink = Color(0xFF262633);
const _muted = Color(0xFF8D8E99);
const _bg = Color(0xFFF7F7F7);
const _asset = 'assets/trace_profile/features/';

class TraceProfileFeaturesPage extends StatefulWidget {
  const TraceProfileFeaturesPage({super.key, required this.feature});
  final String feature;
  @override
  State<TraceProfileFeaturesPage> createState() =>
      _TraceProfileFeaturesPageState();
}

class _TraceProfileFeaturesPageState extends State<TraceProfileFeaturesPage> {
  final service = SakiService.instance;
  Map<String, dynamic> modules = {};
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      modules = await service.accountModules();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save(Map<String, dynamic> patch) async {
    final settings = Map<String, dynamic>.from(
      modules['settings'] as Map? ?? {},
    );
    settings.addAll(patch);
    await service.updateAccountSettings(settings);
    if (mounted) setState(() => modules = {...modules, 'settings': settings});
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(child: CircularProgressIndicator(color: _blue));
    final title =
        {
          'store': 'المتجر',
          'agency': 'الوكالة',
          'family': 'العائلة',
          'level': 'المستوى',
        }[widget.feature] ??
        'المميزات';
    final settings = Map<String, dynamic>.from(
      modules['settings'] as Map? ?? {},
    );
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: _blue,
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            if (widget.feature == 'store')
              StoreFeature(settings: settings, onSave: save),
            if (widget.feature == 'agency')
              AgencyFeature(settings: settings, onSave: save),
            if (widget.feature == 'family')
              FamilyFeature(settings: settings, onSave: save),
            if (widget.feature == 'level') LevelFeature(settings: modules),
          ],
        ),
      ),
    );
  }
}

class StoreFeature extends StatefulWidget {
  const StoreFeature({super.key, required this.settings, required this.onSave});
  final Map<String, dynamic> settings;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<StoreFeature> createState() => _StoreFeatureState();
}

class _StoreFeatureState extends State<StoreFeature>
    with SingleTickerProviderStateMixin {
  late final tabs = TabController(length: 3, vsync: this);
  final data = const [
    ('إطارات الصور', 'bg_avatar_frame_selected.png', 'frame'),
    ('ثيمات الغرف', 'bg_party_them_selected.png', 'theme'),
    ('تأثيرات الدخول', 'bg_entrance_effect_selected.png', 'entrance'),
  ];
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const TraceBanner(
        image: '${_asset}my_icon_store.png',
        title: 'متجر Trace',
        subtitle: 'اختر مظهرك وفعّله على حسابك',
      ),
      const SizedBox(height: 14),
      TabBar(
        controller: tabs,
        labelColor: _blue,
        unselectedLabelColor: _muted,
        indicatorColor: _blue,
        tabs: [for (final item in data) Tab(text: item.$1)],
      ),
      SizedBox(
        height: 470,
        child: TabBarView(
          controller: tabs,
          children: [
            for (final item in data)
              StoreGrid(
                item: item,
                settings: widget.settings,
                onSave: widget.onSave,
              ),
          ],
        ),
      ),
    ],
  );
}

class StoreGrid extends StatelessWidget {
  const StoreGrid({
    super.key,
    required this.item,
    required this.settings,
    required this.onSave,
  });
  final (String, String, String) item;
  final Map<String, dynamic> settings;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.only(top: 14),
    itemCount: 6,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: .86,
    ),
    itemBuilder: (_, i) {
      final active =
          settings['active_${item.$3}'] == true &&
          settings['${item.$3}_index'] == i;
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('$_asset${item.$2}', fit: BoxFit.cover),
                  const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _Pill(
                      text: active ? 'مفعّل' : 'متاح',
                      active: active,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.$1} ${i + 1}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSave({
                      'active_${item.$3}': true,
                      '${item.$3}_index': i,
                    }),
                    child: const Text('تفعيل'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class AgencyFeature extends StatefulWidget {
  const AgencyFeature({
    super.key,
    required this.settings,
    required this.onSave,
  });
  final Map<String, dynamic> settings;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<AgencyFeature> createState() => _AgencyFeatureState();
}

class _AgencyFeatureState extends State<AgencyFeature> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const TraceBanner(
        image: '${_asset}agency_bg.png',
        title: 'الوكالة',
        subtitle: 'انضم إلى وكالة أو تابع طلبك',
      ),
      const SizedBox(height: 14),
      FeatureCard(
        icon: '${_asset}ic_tab_profile_agency.png',
        title: 'الانضمام إلى وكالة',
        subtitle: 'أدخل رمز الوكيل لحفظ طلبك في حسابك',
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'رمز الوكيل',
                  filled: true,
                  fillColor: _bg,
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await widget.onSave({
                  'agency_agent_id': controller.text.trim(),
                  'agency_status': 'pending',
                });
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حفظ طلب الوكالة')),
                  );
              },
              child: const Text('إرسال'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const InfoList(
        title: 'مميزات الوكالة',
        items: [
          'مكافآت البث والتفاعل',
          'إدارة الدعوات',
          'متابعة المهام والأرباح',
        ],
      ),
    ],
  );
}

class FamilyFeature extends StatefulWidget {
  const FamilyFeature({
    super.key,
    required this.settings,
    required this.onSave,
  });
  final Map<String, dynamic> settings;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<FamilyFeature> createState() => _FamilyFeatureState();
}

class _FamilyFeatureState extends State<FamilyFeature> {
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final family = widget.settings['family_name'] as String?;
    return Column(
      children: [
        TraceBanner(
          image: '${_asset}my_icon_member.png',
          title: family == null ? 'العائلة' : family,
          subtitle: 'أنشئ عائلتك أو انضم إلى عائلة',
        ),
        const SizedBox(height: 14),
        FeatureCard(
          icon: '${_asset}my_icon_member.png',
          title: family == null ? 'الانضمام إلى عائلة' : 'عضو في العائلة',
          subtitle: 'بياناتك تحفظ في Supabase',
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'اسم العائلة أو الرمز',
                    filled: true,
                    fillColor: _bg,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  await widget.onSave({
                    'family_name': controller.text.trim(),
                    'family_status': 'active',
                  });
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حفظ بيانات العائلة')),
                    );
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoList(
          title: 'مميزات العائلة',
          items: ['مهام وجوائز جماعية', 'ترتيب أفراد العائلة', 'محادثات خاصة'],
        ),
      ],
    );
  }
}

class LevelFeature extends StatefulWidget {
  const LevelFeature({super.key, required this.settings});
  final Map<String, dynamic> settings;
  @override
  State<LevelFeature> createState() => _LevelFeatureState();
}

class _LevelFeatureState extends State<LevelFeature> {
  int tab = 0;

  int _levelFor(int xp, bool wealth) {
    var level = 0;
    for (var i = 1; i <= 500; i++) {
      final required = wealth
          ? (i == 1
                ? 5000
                : i == 2
                ? 15000
                : 15000 * (1 << (i - 2)))
          : 20000 * (1 << (i - 1));
      if (xp < required) break;
      level = i;
    }
    return level;
  }

  int _required(int level, bool wealth) {
    if (level <= 0) return 0;
    if (wealth && level == 1) return 5000;
    if (wealth && level == 2) return 15000;
    return wealth ? 15000 * (1 << (level - 2)) : 20000 * (1 << (level - 1));
  }

  String _compact(int value) {
    if (value >= 1000000000)
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  Color _bandColor(int level, bool wealth) {
    if (level < 10)
      return wealth ? const Color(0xFFFF2E74) : const Color(0xFF9B30FF);
    const colors = [
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
      Color(0xFFA855F7),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF14B8A6),
    ];
    return colors[((level ~/ 10) - 1) % colors.length];
  }

  IconData _bandIcon(int level) {
    if (level < 10) return Icons.star_outline_rounded;
    const icons = [
      Icons.emoji_events_rounded,
      Icons.diamond_rounded,
      Icons.auto_awesome_rounded,
      Icons.local_fire_department_rounded,
      Icons.workspace_premium_rounded,
      Icons.bolt_rounded,
    ];
    return icons[((level ~/ 10) - 1) % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    final wealth = tab == 0;
    final xp = (widget.settings[wealth ? 'wealth_xp' : 'charm_xp'] as num? ?? 0)
        .toInt();
    final level =
        (widget.settings[wealth ? 'wealth_level' : 'charm_level'] as num?)
            ?.toInt() ??
        _levelFor(xp, wealth);
    final currentReq = _required(level, wealth);
    final nextReq = level >= 500 ? currentReq : _required(level + 1, wealth);
    final progress = level >= 500
        ? 1.0
        : ((xp - currentReq).clamp(0, nextReq - currentReq) /
              (nextReq - currentReq));
    final accent = _bandColor(level, wealth);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: wealth
                  ? const [Color(0xFFFF4580), Color(0xFFFF7B8E)]
                  : const [Color(0xFF9B30FF), Color(0xFFD17BF8)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: _tabButton('مستوى الثروة', 0)),
                    Expanded(child: _tabButton('مستوى السحر', 1)),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white.withValues(alpha: .25),
                    child: Icon(
                      wealth ? Icons.send_rounded : Icons.card_giftcard_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'LV $level',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LV ${level >= 500 ? 500 : level + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'LV $level',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress.toDouble(),
                        minHeight: 10,
                        backgroundColor: Colors.white38,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      level >= 500
                          ? 'وصلت إلى أعلى مستوى'
                          : '${_compact(xp)} خبرة • تحتاج ${_compact((nextReq - xp).clamp(0, nextReq))} خبرة للمستوى التالي',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ornamentTitle('اللقب الحالي'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: .3)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: .12),
                ),
                child: Icon(_bandIcon(level), color: accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LV $level',
                      style: TextStyle(
                        color: accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      level < 10 ? 'اللقب الأساسي' : 'لقب جديد كل 10 مستويات',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ornamentTitle('كيفية اكتساب الخبرة'),
        const SizedBox(height: 12),
        FeatureCard(
          icon: '${_asset}grade_up.png',
          title: wealth ? 'إرسال الهدايا في الغرف' : 'استقبال الهدايا في الغرف',
          subtitle: 'كل 1 عملة ذهبية = 1 خبرة',
          child: Row(
            children: [
              Icon(
                wealth ? Icons.send_rounded : Icons.card_giftcard_rounded,
                color: accent,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wealth
                      ? 'أرسل هدايا من رصيدك الذهبي لرفع مستوى الثروة.'
                      : 'استقبل هدايا ذهبية من الغرف لرفع مستوى السحر.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoList(
          title: 'نظام المستويات',
          items: [
            wealth
                ? 'LV 1 يبدأ عند إرسال 5K ذهب'
                : 'LV 1 يبدأ عند استقبال 20K ذهب',
            wealth
                ? 'LV 2 يبدأ عند إرسال 15K ذهب'
                : 'LV 2 يبدأ عند استقبال 40K ذهب',
            'يتضاعف المطلوب تدريجياً حتى LV 500',
          ],
        ),
      ],
    );
  }

  Widget _tabButton(String text, int value) => GestureDetector(
    onTap: () => setState(() => tab = value),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: tab == value
            ? Colors.white.withValues(alpha: .22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: tab == value ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    ),
  );

  Widget _ornamentTitle(String text) => Row(
    children: [
      const Expanded(child: Divider(color: Color(0xFFEAD0AC))),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          border: Border.all(color: const Color(0xFFF1D2A3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF4A3519),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Color(0xFFEAD0AC))),
    ],
  );
}

class TraceBanner extends StatelessWidget {
  const TraceBanner({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
  });
  final String image, title, subtitle;
  @override
  Widget build(BuildContext context) => Container(
    height: 142,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(colors: [_blue, Color(0xFF9B7BFF)]),
    ),
    child: Row(
      children: [
        Image.asset(
          image,
          width: 78,
          height: 78,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.auto_awesome, color: Colors.white, size: 50),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String icon, title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              icon,
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.star, color: _blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class InfoList extends StatelessWidget {
  const InfoList({super.key, required this.title, required this.items});
  final String title;
  final List<String> items;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: _blue, size: 17),
                const SizedBox(width: 8),
                Text(
                  item,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.active});
  final String text;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: active ? Colors.green : Colors.black54,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

// Compatibility alias for the requested feature names.
typedef TraceStorePage = TraceProfileFeaturesPage;
