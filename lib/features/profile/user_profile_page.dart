import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../messages/messages_page.dart';
import '../posts/posts_page.dart';

const _profileYellow = Color(0xFFFFC107);
const _profileBg = Color(0xFFF3F4F6);
const _profileInk = Color(0xFF111827);
const _profileMuted = Color(0xFF9CA3AF);
const _traceLiveBackground = 'assets/trace_profile/images/live_bg.png';
const _traceFansBadge = 'assets/trace_profile/images/ic_fans_badge.png';
const _traceSortPriority = 'assets/trace_profile/images/ic_sort_priority.png';
const _traceExclusiveGift = 'assets/trace_profile/images/ic_exclusive_gift.png';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId});
  final String userId;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? _profile;
  Map<String, int> _stats = {};
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _vehicles = [];
  bool _following = false;
  bool _loading = true;
  bool _actionLoading = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        SakiService.instance.userProfile(widget.userId),
        SakiService.instance.familyBadgeForUser(widget.userId),
        SakiService.instance.userProfileStats(widget.userId),
        SakiService.instance.userPosts(widget.userId),
        SakiService.instance.userReceivedGifts(widget.userId),
        SakiService.instance.userVehicles(widget.userId),
        SakiService.instance.isFollowing(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        final base = results[0] as Map<String, dynamic>?;
        final family = results[1] as Map<String, dynamic>?;
        _profile = base == null ? null : {...base, 'family_badge': family};
        _stats = Map<String, int>.from(results[2] as Map);
        _posts = List<Map<String, dynamic>>.from(results[3] as List);
        _gifts = List<Map<String, dynamic>>.from(results[4] as List);
        _vehicles = List<Map<String, dynamic>>.from(results[5] as List);
        _following = results[6] as bool;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تحميل بروفايل المستخدم من Supabase'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_actionLoading) return;
    final oldValue = _following;
    setState(() {
      _actionLoading = true;
      _following = !oldValue;
    });
    try {
      await SakiService.instance.toggleFollow(widget.userId, oldValue);
      final stats = await SakiService.instance.userProfileStats(widget.userId);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (mounted) setState(() => _following = oldValue);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _message() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    try {
      final conversationId = await SakiService.instance.createConversation(
        widget.userId,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: conversationId,
            participant: _profile ?? const {},
          ),
        ),
      );
    } catch (error, stackTrace) {
      final details = _privateChatErrorDetails(error, stackTrace);
      developer.log(
        details,
        name: 'SAKI_PRIVATE_CHAT',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) await _showPrivateChatDiagnostics(details);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  String _privateChatErrorDetails(Object error, StackTrace stackTrace) {
    final authUser = SakiService.instance.currentUser;
    final lines = <String>[
      'SAKI_PRIVATE_CHAT_ERROR',
      'time: ${DateTime.now().toIso8601String()}',
      'other_user_id: ${widget.userId}',
      'current_user_id: ${authUser?.id ?? '<null>'}',
      'session_present: ${authUser != null}',
      'error_type: ${error.runtimeType}',
      'error: $error',
    ];
    if (error is PostgrestException) {
      lines.add('postgrest_code: ${error.code ?? '<null>'}');
      lines.add('postgrest_message: ${error.message}');
      lines.add('postgrest_details: ${error.details}');
      lines.add('postgrest_hint: ${error.hint ?? '<null>'}');
    }
    lines
      ..add('stack_trace:')
      ..add(stackTrace.toString());
    return lines.join('\n');
  }

  Future<void> _showPrivateChatDiagnostics(String details) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تشخيص الدردشة الخاصة - إصدار 40'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              details,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('تم نسخ الخطأ كاملًا')),
                );
              }
            },
            child: const Text('نسخ الخطأ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyId() async {
    await Clipboard.setData(
      ClipboardData(text: '${_profile?['saki_id'] ?? ''}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم نسخ SAKI ID')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _profileBg,
        body: Center(child: CircularProgressIndicator(color: _profileYellow)),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return const Scaffold(
        backgroundColor: _profileBg,
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'المستخدم غير موجود',
          subtitle: 'قد يكون الحساب محذوفًا أو غير متاح.',
        ),
      );
    }

    final username =
        profile['username'] as String? ??
        profile['display_name'] as String? ??
        'مستخدم SAKI';
    final avatar = profile['avatar_url'] as String?;
    final country = profile['country'] as String? ?? '—';
    final gender = profile['gender'] as String? ?? '';
    final level = (_stats['posts'] ?? 0).clamp(0, 99);
    final isSelf = widget.userId == SakiService.instance.currentUser?.id;

    return Scaffold(
      backgroundColor: _profileBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _ProfileHero(
                      profile: profile,
                      username: username,
                      avatar: avatar,
                      country: country,
                      gender: gender,
                      level: level,
                      stats: _stats,
                      onCopy: _copyId,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _TraceProfileSummary(
                      profile: profile,
                      stats: _stats,
                      onCopy: _copyId,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(height: 8, color: _profileBg),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabsDelegate(
                      selected: _tab,
                      onSelect: (value) => setState(() => _tab = value),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _ProfileTabContent(
                      tab: _tab,
                      profile: profile,
                      posts: _posts,
                      gifts: _gifts,
                      vehicles: _vehicles,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            if (!isSelf)
              _ProfileBottomActions(
                following: _following,
                loading: _actionLoading,
                onFollow: _toggleFollow,
                onMessage: _message,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.username,
    required this.avatar,
    required this.country,
    required this.gender,
    required this.level,
    required this.stats,
    required this.onCopy,
  });

  final Map<String, dynamic> profile;
  final String username;
  final String? avatar;
  final String country;
  final String gender;
  final int level;
  final Map<String, int> stats;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final isFemale = gender == 'female' || gender == 'أنثى';
    return SizedBox(
      height: 360,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (avatar != null && avatar!.isNotEmpty)
            Image.network(
              avatar!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF374151)),
            )
          else
            Image.asset(
              _traceLiveBackground,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF334155), Color(0xFF111827)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x22000000), Color(0xCC000000)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const FaIcon(
                FontAwesomeIcons.arrowRight,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const Positioned(
            top: 16,
            right: 18,
            child: FaIcon(
              FontAwesomeIcons.hexagonNodes,
              color: Colors.white,
              size: 20,
            ),
          ),
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        color: Colors.greenAccent,
                        size: 10,
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'متصل الآن',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/trace_profile/images/ic_guard_avatar_frame.webp',
                  width: 70,
                  height: 70,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 92,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: avatar == null
                        ? const ColoredBox(
                            color: Color(0xFF64748B),
                            child: Center(
                              child: FaIcon(
                                FontAwesomeIcons.user,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          )
                        : Image.network(
                            avatar!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFF64748B),
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.user,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                VipUsername(
                  profile: profile,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
                if (profile['family_badge'] is Map) ...[
                  const SizedBox(height: 6),
                  FamilyTitleBadge(
                    family: Map<String, dynamic>.from(profile['family_badge']),
                  ),
                ],
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onCopy,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.copy,
                        color: Color(0xFFE5E7EB),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ID:${profile['saki_id'] ?? '—'}',
                        style: const TextStyle(
                          color: Color(0xFFE5E7EB),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: Text(
                        'ثروة LV${profile['wealth_level'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFA855F7),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: Text(
                        'سحر LV${profile['charm_level'] ?? 0}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      country,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF60A5FA),
                        borderRadius: BorderRadius.all(Radius.circular(3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            isFemale
                                ? FontAwesomeIcons.venus
                                : FontAwesomeIcons.mars,
                            color: Colors.white,
                            size: 9,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isFemale ? 'أنثى' : 'ذكر',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceProfileSummary extends StatelessWidget {
  const _TraceProfileSummary({
    required this.profile,
    required this.stats,
    required this.onCopy,
  });
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final username =
        profile['display_name'] as String? ??
        profile['username'] as String? ??
        'مستخدم SAKI';
    final country = profile['country'] as String? ?? '—';
    final gender = profile['gender'] as String? ?? '';
    final female = gender == 'female' || gender == 'أنثى';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _profileInk,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      female ? Icons.female : Icons.male,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      female ? 'أنثى' : 'ذكر',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              Text(
                country,
                style: const TextStyle(color: _profileMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onCopy,
            child: Row(
              children: [
                const Icon(Icons.copy, size: 16, color: _profileMuted),
                const SizedBox(width: 5),
                Text(
                  'SAKI ID: ${profile['saki_id'] ?? '—'}',
                  style: const TextStyle(
                    color: _profileMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProfileStat(
                value: '${stats['following'] ?? 0}',
                label: 'المتابعة',
                padding: EdgeInsets.zero,
              ),
              _ProfileStat(
                value: '${stats['followers'] ?? 0}',
                label: 'المتابعين',
                padding: EdgeInsets.zero,
              ),
              _ProfileStat(
                value: '${stats['posts'] ?? 0}',
                label: 'المنشورات',
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.value,
    required this.label,
    required this.padding,
  });
  final String value;
  final String label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  _ProfileTabsDelegate({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  double get minExtent => 54;
  @override
  double get maxExtent => 54;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ProfileTab(
            label: 'المجموعات',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          _ProfileTab(
            label: 'الأوسمة',
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
          _ProfileTab(
            label: 'اللحظات',
            selected: selected == 2,
            onTap: () => onSelect(2),
          ),
          _ProfileTab(
            label: 'الصفحة الشخصية',
            selected: selected == 3,
            onTap: () => onSelect(3),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabsDelegate oldDelegate) =>
      oldDelegate.selected != selected;
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 17),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _profileYellow : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : _profileMuted,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _ProfileTabContent extends StatelessWidget {
  const _ProfileTabContent({
    required this.tab,
    required this.profile,
    required this.posts,
    required this.gifts,
    required this.vehicles,
  });
  final int tab;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> gifts;
  final List<Map<String, dynamic>> vehicles;

  @override
  Widget build(BuildContext context) {
    if (tab == 0) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _CollectionCard(
              title: 'مجموعة الهدايا',
              subtitle: '${gifts.length} هدية مستلمة',
              icon: FontAwesomeIcons.gift,
              colors: const [Color(0xFF7C3AED), Color(0xFFEC4899)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GiftCollectionPage(
                    username: profile['username']?.toString() ?? 'المستخدم',
                    gifts: gifts,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _CollectionCard(
              title: 'مجموعة المركبات',
              subtitle: '${vehicles.length} مركبة مملوكة',
              icon: FontAwesomeIcons.carSide,
              colors: const [Color(0xFF0284C7), Color(0xFF22D3EE)],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleCollectionPage(
                    username: profile['username']?.toString() ?? 'المستخدم',
                    vehicles: vehicles,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _CollectionCard(
              title: 'الخواتم والألقاب',
              subtitle: 'الأوسمة والإنجازات الخاصة بالمستخدم',
              icon: FontAwesomeIcons.ring,
              colors: const [Color(0xFFDB2777), Color(0xFFF59E0B)],
              onTap: () {},
            ),
          ],
        ),
      );
    }
    if (tab == 1) return _BadgeCollection(profile: profile);
    if (tab == 3) {
      final bio = (profile['bio'] as String?)?.trim();
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الصفحة الشخصية',
              style: TextStyle(
                color: _profileInk,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bio?.isNotEmpty == true ? bio! : 'لا توجد سيرة ذاتية بعد.',
              style: const TextStyle(
                color: _profileMuted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 12),
            _InfoLine(
              icon: FontAwesomeIcons.calendarDays,
              title: 'تاريخ الانضمام',
              value: _joinedDays(profile),
            ),
            const SizedBox(height: 8),
            _InfoLine(
              icon: FontAwesomeIcons.users,
              title: 'المجموعات',
              value: 'العائلة والمجموعات التي ينتمي إليها المستخدم',
            ),
            const SizedBox(height: 20),
            _TraceProfileBenefits(vipLevel: profile['vip_level'] as int? ?? 0),
            const SizedBox(height: 24),
            const Text(
              'علامة التعريف',
              style: TextStyle(
                color: _profileInk,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.idCard,
                  color: _profileYellow,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'SAKI ID: ${profile['saki_id'] ?? '—'}',
                  style: const TextStyle(
                    color: _profileMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: EmptyState(
          icon: Icons.photo_library_outlined,
          title: 'لا يوجد محتوى بعد',
          subtitle: 'لم ينشر هذا المستخدم محتوى بعد.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: posts
            .map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HtmlPostCard(post: post, onChanged: () {}),
              ),
            )
            .toList(),
      ),
    );
  }

  String _joinedDays(Map<String, dynamic> profile) {
    final raw = DateTime.tryParse(profile['created_at']?.toString() ?? '');
    if (raw == null) return 'غير متاح';
    return '${DateTime.now().difference(raw).inDays} يوم';
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final FaIconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Ink(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .22),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: FaIcon(icon, color: Colors.white, size: 21)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const FaIcon(
            FontAwesomeIcons.chevronLeft,
            color: Colors.white,
            size: 13,
          ),
        ],
      ),
    ),
  );
}

class _BadgeCollection extends StatelessWidget {
  const _BadgeCollection({required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Badge(asset: _traceFansBadge, title: 'شارة المعجبين'),
          _Badge(asset: _traceSortPriority, title: 'أولوية الترتيب'),
          _Badge(asset: _traceExclusiveGift, title: 'الهدايا الحصرية'),
          _Badge(
            asset: 'assets/trace_profile/images/ic_guard_avatar_frame.webp',
            title: 'حارس الملف',
          ),
          _Badge(
            asset: 'assets/trace_profile/images/ic_vip_badge.png',
            title: 'VIP ${profile['vip_level'] ?? 0}',
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.asset, required this.title});
  final String asset;
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    width: 104,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFF0F1F5)),
    ),
    child: Column(
      children: [
        Image.asset(
          asset,
          width: 48,
          height: 48,
          errorBuilder: (_, _, _) => const FaIcon(
            FontAwesomeIcons.medal,
            color: _profileYellow,
            size: 34,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _profileInk,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.title,
    required this.value,
  });
  final FaIconData icon;
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      FaIcon(icon, color: _profileYellow, size: 15),
      const SizedBox(width: 8),
      Text(
        '$title: ',
        style: const TextStyle(
          color: _profileInk,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(color: _profileMuted, fontSize: 11),
        ),
      ),
    ],
  );
}

class GiftCollectionPage extends StatelessWidget {
  const GiftCollectionPage({
    super.key,
    required this.username,
    required this.gifts,
  });
  final String username;
  final List<Map<String, dynamic>> gifts;
  @override
  Widget build(BuildContext context) => _CollectionPageShell(
    title: 'هدايا $username',
    child: gifts.isEmpty
        ? const EmptyState(
            icon: Icons.card_giftcard_outlined,
            title: 'لا توجد هدايا بعد',
            subtitle: 'ستظهر الهدايا عند استلامها.',
          )
        : ListView(
            padding: const EdgeInsets.all(14),
            children: gifts.map((gift) => _GiftRow(gift: gift)).toList(),
          ),
  );
}

class VehicleCollectionPage extends StatelessWidget {
  const VehicleCollectionPage({
    super.key,
    required this.username,
    required this.vehicles,
  });
  final String username;
  final List<Map<String, dynamic>> vehicles;
  @override
  Widget build(BuildContext context) => _CollectionPageShell(
    title: 'مركبات $username',
    child: vehicles.isEmpty
        ? const EmptyState(
            icon: Icons.directions_car_outlined,
            title: 'لا توجد مركبات',
            subtitle: 'ستظهر المركبات المملوكة والمفعلة هنا.',
          )
        : ListView(
            padding: const EdgeInsets.all(14),
            children: vehicles
                .map((vehicle) => _VehicleRow(vehicle: vehicle))
                .toList(),
          ),
  );
}

class _CollectionPageShell extends StatelessWidget {
  const _CollectionPageShell({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _profileBg,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      centerTitle: true,
      title: Text(
        title,
        style: const TextStyle(
          color: _profileInk,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
      ),
    ),
    body: child,
  );
}

class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift});
  final Map<String, dynamic> gift;
  @override
  Widget build(BuildContext context) {
    final media = gift['media_url']?.toString();
    final count = (gift['received_count'] as num?)?.toInt() ?? 0;
    final price = (gift['price'] as num?)?.toInt() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: media == null || media.isEmpty
                ? const FaIcon(
                    FontAwesomeIcons.gift,
                    color: Color(0xFF8B5CF6),
                    size: 25,
                  )
                : Image.network(media, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift['name']?.toString() ?? 'هدية',
                  style: const TextStyle(
                    color: _profileInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'السعر: $price • القيمة المستلمة: ${(gift['received_value'] as num?)?.toInt() ?? 0}',
                  style: const TextStyle(color: _profileMuted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  'استلمها $count مرة',
                  style: const TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleRow extends StatelessWidget {
  const _VehicleRow({required this.vehicle});
  final Map<String, dynamic> vehicle;
  @override
  Widget build(BuildContext context) {
    final expires = DateTime.tryParse(vehicle['expires_at']?.toString() ?? '');
    final days = expires?.difference(DateTime.now()).inDays.clamp(0, 9999);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2FE),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Image.asset(
              vehicle['asset_key']?.toString() ?? '',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const FaIcon(
                FontAwesomeIcons.carSide,
                color: Color(0xFF0284C7),
                size: 25,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle['name']?.toString() ?? 'مركبة',
                  style: const TextStyle(
                    color: _profileInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'السعر: ${(vehicle['price_gold_coins'] as num?)?.toInt() ?? 0} عملة ذهبية',
                  style: const TextStyle(color: _profileMuted, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  days == null ? 'المدة غير محددة' : '$days يوم متبقٍ',
                  style: const TextStyle(
                    color: Color(0xFF0284C7),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceProfileBenefits extends StatelessWidget {
  const _TraceProfileBenefits({required this.vipLevel});
  final int vipLevel;

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (_traceFansBadge, 'شارة المعجبين'),
      (_traceSortPriority, 'أولوية الترتيب'),
      (_traceExclusiveGift, 'الهدايا الحصرية'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), Color(0xFFFFF7ED)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.crown,
                color: _profileYellow,
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                vipLevel > 0 ? 'VIP المستوى $vipLevel' : 'مزايا الملف الشخصي',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _profileInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final benefit in benefits)
                Expanded(
                  child: Column(
                    children: [
                      Image.asset(benefit.$1, width: 34, height: 34),
                      const SizedBox(height: 5),
                      Text(
                        benefit.$2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: _profileMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileBottomActions extends StatelessWidget {
  const _ProfileBottomActions({
    required this.following,
    required this.loading,
    required this.onFollow,
    required this.onMessage,
  });
  final bool following;
  final bool loading;
  final VoidCallback onFollow;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 14,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onFollow,
                  icon: FaIcon(
                    following
                        ? FontAwesomeIcons.check
                        : FontAwesomeIcons.userPlus,
                    size: 14,
                  ),
                  label: Text(following ? 'متابَع' : 'متابعة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: following ? Colors.green : _profileInk,
                    side: BorderSide(
                      color: following
                          ? Colors.green.shade300
                          : const Color(0xFFD1D5DB),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onMessage,
                  icon: const FaIcon(FontAwesomeIcons.paperPlane, size: 14),
                  label: const Text('رسالة خاصة'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _profileYellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
