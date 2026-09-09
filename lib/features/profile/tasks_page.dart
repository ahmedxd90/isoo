import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/data/saki_service.dart';

import '../../shared/widgets/custom_toast.dart';

const _taskPurple = Color(0xFF5B21B6);
const _taskGold = Color(0xFFF59E0B);
const _taskInk = Color(0xFF1F2937);
const _taskMuted = Color(0xFF8B95A7);

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic> _daily = {};
  bool _loading = true;
  bool _refreshing = false;

  static const _dailyRewards = [1000, 100, 400, 600, 700, 2500, 5000];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final daily = await _service.claimDailyLogin();
      final tasks = await _service.userTasksSnapshot();
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _tasks = tasks;
      });
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, 'تعذر تحميل المهمات: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final tasks = await _service.userTasksSnapshot();
      if (mounted) setState(() => _tasks = tasks);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  FaIconData _icon(String key) => switch (key) {
    'seat' => FontAwesomeIcons.microphone,
    'heart' => FontAwesomeIcons.heart,
    'reel' => FontAwesomeIcons.film,
    'message' => FontAwesomeIcons.commentDots,
    'post' => FontAwesomeIcons.penToSquare,
    'video' => FontAwesomeIcons.video,
    'gift' => FontAwesomeIcons.gift,
    _ => FontAwesomeIcons.listCheck,
  };

  Color _color(String key) => switch (key) {
    'seat' => const Color(0xFF06B6D4),
    'heart' => const Color(0xFFEC4899),
    'reel' => const Color(0xFF8B5CF6),
    'message' => const Color(0xFF3B82F6),
    'post' => const Color(0xFFF97316),
    'video' => const Color(0xFFEF4444),
    'gift' => const Color(0xFFA855F7),
    _ => _taskPurple,
  };

  @override
  Widget build(BuildContext context) {
    final day = (_daily['cycle_day'] as num?)?.toInt() ?? 1;
    final claimed = _daily['claimed'] == true;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 17),
        ),
        title: const Text(
          'المهمات',
          style: TextStyle(
            color: _taskInk,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(FontAwesomeIcons.arrowsRotate, size: 15),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _taskPurple))
          : RefreshIndicator(
              color: _taskPurple,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _HeroBanner(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: Column(
                      children: [
                        _DailyLoginCard(
                          day: day,
                          claimed: claimed,
                          rewards: _dailyRewards,
                          onClaim: _load,
                        ),
                        const SizedBox(height: 14),
                        _SectionTitle(
                          title: 'المهمات اليومية',
                          subtitle:
                              'أنجز نشاطك الحقيقي واحصل على العملات تلقائيًا',
                        ),
                        const SizedBox(height: 8),
                        ..._tasks.map(
                          (task) => _TaskTile(
                            task: task,
                            icon: _icon(task['icon_key']?.toString() ?? ''),
                            color: _color(task['icon_key']?.toString() ?? ''),
                            onGo: () => _showRoute(
                              task['action_route']?.toString() ?? '/home',
                            ),
                          ),
                        ),
                        if (_tasks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(28),
                            child: Text(
                              'لا توجد مهمات متاحة حاليًا',
                              style: TextStyle(color: _taskMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showRoute(String route) {
    CustomToast.show(
      context,
      'اذهب إلى القسم المطلوب داخل التطبيق لإكمال المهمة ($route)',
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 215,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/saki_tasks_banner.png', fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: .05),
                const Color(0xAA32106B),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const Positioned(
          right: 22,
          bottom: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'أنجز المهمات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'واجمع عملاتك الذهبية كل يوم',
                style: TextStyle(
                  color: Color(0xFFFFE7A3),
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

class _DailyLoginCard extends StatelessWidget {
  const _DailyLoginCard({
    required this.day,
    required this.claimed,
    required this.rewards,
    required this.onClaim,
  });
  final int day;
  final bool claimed;
  final List<int> rewards;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.fromLTRB(12, 13, 12, 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.calendar_month_rounded, color: _taskGold),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تسجيل الدخول اليومي',
                    style: TextStyle(
                      color: _taskInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'مكافأة تلقائية مرة واحدة كل يوم',
                    style: TextStyle(
                      color: _taskMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              claimed ? 'تم الاستلام' : 'اليوم $day',
              style: TextStyle(
                color: claimed ? Colors.green : _taskGold,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: List.generate(7, (index) {
            final active = index + 1 == day;
            final past = index + 1 < day;
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: index == 6 ? 0 : 5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? _taskPurple
                        : past
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? _taskPurple : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : _taskInk,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        past
                            ? Icons.check_circle_rounded
                            : Icons.monetization_on_rounded,
                        color: active ? const Color(0xFFFFE7A3) : _taskGold,
                        size: 15,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${rewards[index]}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : _taskInk,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 5,
        height: 28,
        decoration: BoxDecoration(
          color: _taskPurple,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _taskInk,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: _taskMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.icon,
    required this.color,
    required this.onGo,
  });
  final Map<String, dynamic> task;
  final FaIconData icon;
  final Color color;
  final VoidCallback onGo;
  @override
  Widget build(BuildContext context) {
    final target = (task['target'] as num?)?.toInt() ?? 1;
    final progress = (task['progress'] as num?)?.toInt() ?? 0;
    final reward = (task['reward_gold'] as num?)?.toInt() ?? 0;
    final claimed = task['claimed'] == true;
    final ratio = target <= 0 ? 0.0 : (progress / target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FaIcon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  '+$reward',
                  style: const TextStyle(
                    color: _taskGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? '',
                  style: const TextStyle(
                    color: _taskInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task['description']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _taskMuted, fontSize: 10),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    color: claimed ? Colors.green : color,
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$progress/$target ${claimed ? '• مكتملة' : ''}',
                  style: TextStyle(
                    color: claimed ? Colors.green : _taskMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: claimed ? null : onGo,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: .55)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              claimed ? 'تم' : 'اذهب',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
