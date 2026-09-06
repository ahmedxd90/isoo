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
            if (widget.feature == 'level') LevelFeature(settings: settings),
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

class LevelFeature extends StatelessWidget {
  const LevelFeature({super.key, required this.settings});
  final Map<String, dynamic> settings;
  @override
  Widget build(BuildContext context) {
    final points = (settings['experience_points'] as num? ?? 0).toDouble();
    final level = points ~/ 1000 + 1;
    final progress = (points % 1000) / 1000;
    return Column(
      children: [
        TraceBanner(
          image: '${_asset}grade_bg.png',
          title: 'المستوى $level',
          subtitle: '${points.toInt()} نقطة خبرة',
        ),
        const SizedBox(height: 16),
        FeatureCard(
          icon: '${_asset}grade_up.png',
          title: 'تقدم المستوى',
          subtitle: 'اجمع النقاط من الغرف واللحظات والريلز',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                color: _blue,
                backgroundColor: _blue.withValues(alpha: .12),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toInt()}% إلى المستوى التالي',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoList(
          title: 'امتيازات المستوى',
          items: [
            'شارات مميزة',
            'إطارات وتأثيرات إضافية',
            'مكافآت عند الترقية',
          ],
        ),
      ],
    );
  }
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
