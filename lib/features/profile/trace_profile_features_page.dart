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
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }
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
    if (widget.feature == 'level') {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F7FB),
        body: SafeArea(
          child: Column(
            children: [
              const _LevelPageHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 38),
                  children: [LevelFeature(settings: settings)],
                ),
              ),
            ],
          ),
        ),
      );
    }
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

class _LevelPageHeader extends StatelessWidget {
  const _LevelPageHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFEDEAF3))),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: const Icon(Icons.arrow_forward_rounded, color: _ink),
        ),
        const Expanded(
          child: Text(
            'المستويات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1E8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Color(0xFFFF8A3D),
            size: 18,
          ),
        ),
      ],
    ),
  );
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
                if (!context.mounted) return;
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
          title: family ?? 'العائلة',
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
                  if (!context.mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final wealth = tab == 0;
    final xp = (widget.settings[wealth ? 'wealth_xp' : 'charm_xp'] as num? ?? 0)
        .toInt();
    final level =
        (widget.settings[wealth ? 'wealth_level' : 'charm_level'] as num?)
            ?.toInt() ??
        _levelFor(xp, wealth);
    final current = _required(level, wealth);
    final next = level >= 500 ? current : _required(level + 1, wealth);
    final progress = level >= 500
        ? 1.0
        : ((xp - current).clamp(0, next - current) / (next - current));
    final accent = wealth ? const Color(0xFFFF8A3D) : const Color(0xFF20C5D5);
    final features = wealth
        ? const [
            ('إرسال الهدايا', 'كل عملة = خبرة', Icons.card_giftcard_rounded),
            ('شارة الثروة', 'تظهر في ملفك', Icons.workspace_premium_rounded),
            ('ترتيب المتصدرين', 'تقدم في القائمة', Icons.leaderboard_rounded),
            ('مؤثرات الغرفة', 'تتطور مع المستوى', Icons.auto_awesome_rounded),
            ('إطارات خاصة', 'تفتح تدريجيًا', Icons.crop_square_rounded),
            ('هدايا المستوى', 'مكافآت حقيقية', Icons.redeem_rounded),
          ]
        : const [
            ('استقبال الهدايا', 'كل عملة = خبرة', Icons.card_giftcard_rounded),
            ('شارة السحر', 'تظهر في ملفك', Icons.auto_awesome_rounded),
            ('ترتيب السحر', 'تقدم في القائمة', Icons.leaderboard_rounded),
            ('تأثيرات الدخول', 'تتطور مع المستوى', Icons.bolt_rounded),
            ('مظهر الملف', 'مزايا VIP', Icons.badge_rounded),
            ('مكافآت التفاعل', 'تفتح تدريجيًا', Icons.stars_rounded),
          ];
    return Column(
      children: [
        _LevelHero(
          tab: tab,
          level: level,
          xp: xp,
          progress: progress.toDouble(),
          accent: accent,
          next: next,
          compact: _compact,
          onTab: (v) => setState(() => tab = v),
        ),
        const SizedBox(height: 16),
        _LevelSectionTitle(
          title: wealth ? 'مميزات مستوى الثروة' : 'مميزات مستوى السحر',
          accent: accent,
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: .86,
          ),
          itemBuilder: (_, i) => _LevelFeatureTile(
            item: features[i],
            accent: accent,
            unlocked: level >= i + 1,
          ),
        ),
        const SizedBox(height: 18),
        _LevelSectionTitle(title: 'المكافآت والمزايا', accent: accent),
        const SizedBox(height: 10),
        for (final item in [
          (
            wealth ? 'أرسل الهدايا في الغرف' : 'استقبل الهدايا في الغرف',
            wealth ? 'يرفع خبرة الثروة' : 'يرفع خبرة السحر',
            Icons.stars_rounded,
          ),
          (
            'كل مستوى يفتح ميزة جديدة',
            'المكافأة مرتبطة بمستواك الحقيقي',
            Icons.lock_open_rounded,
          ),
          (
            'المستوى الحالي LV $level',
            level >= 500
                ? 'وصلت إلى القمة'
                : 'المطلوب التالي ${_compact((next - xp).clamp(0, next))} خبرة',
            Icons.emoji_events_rounded,
          ),
        ])
          _LevelRewardTile(
            title: item.$1,
            subtitle: item.$2,
            icon: item.$3,
            accent: accent,
          ),
      ],
    );
  }
}

class _LevelHero extends StatelessWidget {
  const _LevelHero({
    required this.tab,
    required this.level,
    required this.xp,
    required this.progress,
    required this.accent,
    required this.next,
    required this.compact,
    required this.onTab,
  });
  final int tab, level, xp, next;
  final double progress;
  final Color accent;
  final String Function(int) compact;
  final ValueChanged<int> onTab;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [accent.withValues(alpha: .95), const Color(0xFF201A37)],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: .25),
          blurRadius: 20,
          offset: const Offset(0, 9),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: _levelTab('الثروة', 0)),
            Expanded(child: _levelTab('السحر', 1)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .16),
                border: Border.all(color: Colors.white54),
              ),
              child: Icon(
                tab == 0
                    ? Icons.card_giftcard_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مستواك الحالي',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'LV $level',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${compact(xp)} خبرة',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'LV ${level + 1}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LV $level',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            Text(
              level >= 500
                  ? 'الحد الأعلى'
                  : 'المتبقي ${compact((next - xp).clamp(0, next))}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Stack(
          children: [
            Container(
              height: 9,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _levelTab(String text, int value) => GestureDetector(
    onTap: () => onTab(value),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: tab == value ? Colors.white24 : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        'مستوى $text',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontWeight: tab == value ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    ),
  );
}

class _LevelSectionTitle extends StatelessWidget {
  const _LevelSectionTitle({required this.title, required this.accent});
  final String title;
  final Color accent;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 22,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          color: _ink,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
    ],
  );
}

class _LevelFeatureTile extends StatelessWidget {
  const _LevelFeatureTile({
    required this.item,
    required this.accent,
    required this.unlocked,
  });
  final (String, String, IconData) item;
  final Color accent;
  final bool unlocked;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: unlocked
            ? accent.withValues(alpha: .24)
            : const Color(0xFFE9EAF0),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: unlocked
                ? accent.withValues(alpha: .12)
                : const Color(0xFFF1F2F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            unlocked ? item.$3 : Icons.lock_rounded,
            color: unlocked ? accent : _muted,
            size: 20,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.$1,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          unlocked ? item.$2 : 'مغلق',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: unlocked ? accent : _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _LevelRewardTile extends StatelessWidget {
  const _LevelRewardTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });
  final String title, subtitle;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: .15)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.check_circle_rounded, color: accent, size: 20),
      ],
    ),
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
          errorBuilder: (_, _, _) =>
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
              errorBuilder: (_, _, _) => const Icon(Icons.star, color: _blue),
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
