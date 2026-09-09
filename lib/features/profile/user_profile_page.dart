import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:developer' as developer;
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';
import '../messages/messages_page.dart';
import '../posts/posts_page.dart';
import '../rooms/rooms_page.dart';

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
  List<Map<String, dynamic>> _badges = [];
  String _countryFlag = '🌍';
  bool _following = false;
  bool _loading = true;
  bool _actionLoading = false;

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
        SakiService.instance.userBadges(widget.userId),
      ]);
      if (!mounted) return;
      final countryFlag = await SakiService.instance.countryFlag(
        ((results[0] as Map<String, dynamic>?)?['country']
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true)
            ? (results[0] as Map<String, dynamic>)['country']?.toString()
            : (results[0] as Map<String, dynamic>?)?['country_code']
                  ?.toString(),
      );
      setState(() {
        final base = results[0] as Map<String, dynamic>?;
        final family = results[1] as Map<String, dynamic>?;
        _profile = base == null ? null : {...base, 'family_badge': family};
        _stats = Map<String, int>.from(results[2] as Map);
        _posts = List<Map<String, dynamic>>.from(results[3] as List);
        _gifts = List<Map<String, dynamic>>.from(results[4] as List);
        _vehicles = List<Map<String, dynamic>>.from(results[5] as List);
        _following = results[6] as bool;
        _badges = List<Map<String, dynamic>>.from(results[7] as List);
        _countryFlag = countryFlag;
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
    final isSelf = widget.userId == SakiService.instance.currentUser?.id;

    return _HtmlProfileView(
      profile: profile,
      stats: _stats,
      posts: _posts,
      gifts: _gifts,
      vehicles: _vehicles,
      badges: _badges,
      countryFlag: _countryFlag,
      username: username,
      avatar: avatar,
      country: country,
      gender: gender,
      isSelf: isSelf,
      following: _following,
      loading: _actionLoading,
      onBack: () => Navigator.maybePop(context),
      onCopy: _copyId,
      onFollow: _toggleFollow,
      onMessage: _message,
      onReport: () {},
    );
  }
}

class _HtmlProfileView extends StatefulWidget {
  const _HtmlProfileView({
    required this.profile,
    required this.stats,
    required this.posts,
    required this.gifts,
    required this.vehicles,
    required this.badges,
    required this.countryFlag,
    required this.username,
    required this.avatar,
    required this.country,
    required this.gender,
    required this.isSelf,
    required this.following,
    required this.loading,
    required this.onBack,
    required this.onCopy,
    required this.onFollow,
    required this.onMessage,
    required this.onReport,
  });
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final List<Map<String, dynamic>> posts, gifts, vehicles;
  final List<Map<String, dynamic>> badges;
  final String countryFlag;
  final String username;
  final String? avatar, country;
  final String gender;
  final bool isSelf, following, loading;
  final VoidCallback onBack, onCopy, onFollow, onMessage, onReport;
  @override
  State<_HtmlProfileView> createState() => _HtmlProfileViewState();
}

class _HtmlProfileViewState extends State<_HtmlProfileView> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final vip = (widget.profile['vip_level'] as num? ?? 0).toInt().clamp(0, 10);
    final wealth = widget.profile['wealth_level'] ?? 0;
    final charm = widget.profile['charm_level'] ?? 0;
    final accent = vip > 0 ? vipAccent(vip) : const Color(0xFFECC271);
    return Scaffold(
      backgroundColor: const Color(0xFF120D1D),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFB5B5B8),
                      const Color(0xFFEEE8F0),
                      const Color(0xFF120D1D),
                    ],
                    stops: const [.0, .34, .55],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 42,
              left: 0,
              right: 0,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white.withValues(alpha: .18),
                size: 170,
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onReport,
                        child: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: widget.onBack,
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF421A5C),
                          Color(0xFF210D32),
                          Color(0xFF150622),
                        ],
                      ),
                      border: Border(
                        top: BorderSide(color: Color(0xFFF4D07B), width: 2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .3),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [const Color(0xFFF4D07B), accent],
                              ),
                            ),
                            child: SakiAvatar(
                              url: widget.avatar,
                              label: widget.username,
                              radius: 40,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.countryFlag,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: VipNameText(
                                  profile: {
                                    ...widget.profile,
                                    'display_name': widget.username,
                                  },
                                  fontSize: 19,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              if ((widget.gender).isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    widget.gender,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          VipSakiId(profile: widget.profile, fontSize: 11),
                          if (activeVipLevel(widget.profile) > 0) ...[
                            const SizedBox(height: 5),
                            VipTitleBadge(
                              profile: widget.profile,
                              compact: true,
                            ),
                          ],
                          if (widget.profile['is_super_admin'] == true) ...[
                            const SizedBox(height: 5),
                            const SuperAdminBadge(),
                          ],
                          const SizedBox(height: 6),
                          GestureDetector(
                            onTap: widget.onCopy,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  color: Colors.white54,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'اضغط لنسخ SAKI ID',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _HtmlStat(
                                value: '${widget.stats['following'] ?? 0}',
                                label: 'متابعة',
                                accent: accent,
                              ),
                              _HtmlStat(
                                value: '${widget.stats['followers'] ?? 0}',
                                label: 'معجبين',
                                accent: accent,
                              ),
                              _LevelMetric(
                                value: '$wealth',
                                icon: Icons.monetization_on_rounded,
                                accent: const Color(0xFF49D17D),
                              ),
                              _LevelMetric(
                                value: '$charm',
                                icon: Icons.auto_awesome_rounded,
                                accent: const Color(0xFFD699FF),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if ((widget.profile['bio']?.toString() ?? '')
                              .isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                widget.profile['bio'].toString(),
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  color: Color(0xFFD4CCE0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _HtmlTab(
                                text: 'معلوماتي',
                                active: tab == 0,
                                onTap: () => setState(() => tab = 0),
                                accent: accent,
                              ),
                              _HtmlTab(
                                text: 'اللحظات',
                                active: tab == 1,
                                onTap: () => setState(() => tab = 1),
                                accent: accent,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (tab == 0) ...[
                            _HtmlSection(
                              title: 'عائلتي',
                              accent: accent,
                              child: _FamilyPreview(
                                family: widget.profile['family_badge'] is Map
                                    ? Map<String, dynamic>.from(
                                        widget.profile['family_badge'],
                                      )
                                    : null,
                                accent: accent,
                              ),
                            ),
                            _HtmlSection(
                              title: 'الأوسمة',
                              accent: accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _HtmlCollectionPage(
                                    title: 'الأوسمة',
                                    items: _ownedBadges(
                                      widget.profile,
                                      widget.stats,
                                      widget.badges,
                                    ),
                                    kind: 'badge',
                                    accent: accent,
                                  ),
                                ),
                              ),
                              child: _HtmlCollectionPreview(
                                items: _ownedBadges(
                                  widget.profile,
                                  widget.stats,
                                  widget.badges,
                                ),
                                kind: 'badge',
                                accent: accent,
                              ),
                            ),
                            _HtmlSection(
                              title: 'دخوليات',
                              accent: accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _HtmlCollectionPage(
                                    title: 'دخولياتي',
                                    items: _itemsByCategory(
                                      widget.vehicles,
                                      'entrance_effect',
                                    ),
                                    kind: 'entrance',
                                    accent: accent,
                                  ),
                                ),
                              ),
                              child: _HtmlCollectionPreview(
                                items: _itemsByCategory(
                                  widget.vehicles,
                                  'entrance_effect',
                                ),
                                kind: 'entrance',
                                accent: accent,
                              ),
                            ),
                            _HtmlSection(
                              title: 'إطارات',
                              accent: accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _HtmlCollectionPage(
                                    title: 'إطاراتي',
                                    items: _itemsByCategory(
                                      widget.vehicles,
                                      'avatar_frame',
                                    ),
                                    kind: 'frame',
                                    accent: accent,
                                  ),
                                ),
                              ),
                              child: _HtmlCollectionPreview(
                                items: _itemsByCategory(
                                  widget.vehicles,
                                  'avatar_frame',
                                ),
                                kind: 'frame',
                                accent: accent,
                              ),
                            ),
                            _HtmlSection(
                              title: 'الهدايا',
                              accent: accent,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _HtmlCollectionPage(
                                    title: 'الهدايا المستلمة',
                                    items: widget.gifts,
                                    kind: 'gift',
                                    accent: accent,
                                  ),
                                ),
                              ),
                              child: _HtmlCollectionPreview(
                                items: widget.gifts,
                                kind: 'gift',
                                accent: accent,
                              ),
                            ),
                          ] else ...[
                            _HtmlMoments(posts: widget.posts, accent: accent),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.isSelf)
              Positioned(
                bottom: 12,
                left: 18,
                right: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: _HtmlAction(
                        label: 'رسالة',
                        icon: Icons.chat_bubble_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: widget.onMessage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HtmlAction(
                        label: widget.following ? 'متابَع' : 'متابعة',
                        icon: widget.following
                            ? Icons.check_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: accent,
                        onTap: widget.onFollow,
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
}

class _HtmlStat extends StatelessWidget {
  const _HtmlStat({
    required this.value,
    required this.label,
    required this.accent,
  });
  final String value, label;
  final Color accent;
  @override
  Widget build(BuildContext c) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFA295B3), fontSize: 10),
        ),
      ],
    ),
  );
}

class _LevelMetric extends StatelessWidget {
  const _LevelMetric({
    required this.value,
    required this.icon,
    required this.accent,
  });
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: accent, size: 18),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _HtmlTab extends StatelessWidget {
  const _HtmlTab({
    required this.text,
    required this.active,
    required this.onTap,
    required this.accent,
  });
  final String text;
  final bool active;
  final VoidCallback onTap;
  final Color accent;
  @override
  Widget build(BuildContext c) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? accent : Colors.white12,
              width: active ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? accent : const Color(0xFF8A7D9B),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    ),
  );
}

class _HtmlSection extends StatelessWidget {
  const _HtmlSection({
    required this.title,
    required this.child,
    required this.accent,
    this.onTap,
  });
  final String title;
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: onTap,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        child,
        const SizedBox(height: 14),
      ],
    ),
  );
}

List<Map<String, dynamic>> _itemsByCategory(
  List<Map<String, dynamic>> items,
  String category,
) => items.where((item) => item['category']?.toString() == category).toList();
List<Map<String, dynamic>> _ownedBadges(
  Map<String, dynamic> profile,
  Map<String, int> stats,
  List<Map<String, dynamic>> badges,
) {
  if (badges.isNotEmpty) {
    return badges
        .map(
          (badge) => {
            ...badge,
            'name': badge['name']?.toString() ?? 'وسام',
            'asset': badge['asset_path']?.toString(),
          },
        )
        .toList();
  }
  final result = <Map<String, dynamic>>[];
  final vip = (profile['vip_level'] as num? ?? 0).toInt();
  if (vip > 0)
    result.add({
      'name': 'شارة VIP $vip',
      'asset': 'assets/trace_profile/images/ic_vip_badge.png',
      'icon': Icons.workspace_premium_rounded,
    });
  if (profile['family_badge'] is Map)
    result.add({
      'name': 'عضو العائلة',
      'asset': 'assets/trace_profile/images/ic_fans_badge.png',
      'icon': Icons.groups_rounded,
    });
  if ((stats['followers'] ?? 0) > 0)
    result.add({
      'name': 'شارة المعجبين',
      'asset': 'assets/trace_profile/images/ic_fans_badge.png',
      'icon': Icons.favorite_rounded,
    });
  return result;
}

class _FamilyPreview extends StatelessWidget {
  const _FamilyPreview({required this.family, required this.accent});
  final Map<String, dynamic>? family;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: family?['avatar_url']?.toString().isNotEmpty == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    family!['avatar_url'].toString(),
                    fit: BoxFit.cover,
                  ),
                )
              : Icon(Icons.groups_rounded, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            family?['name']?.toString() ?? 'لا توجد عائلة',
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          family == null ? '' : 'المستوى ${family!['level'] ?? 1}',
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _HtmlCollectionPreview extends StatelessWidget {
  const _HtmlCollectionPreview({
    required this.items,
    required this.kind,
    required this.accent,
  });
  final List<Map<String, dynamic>> items;
  final String kind;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final visible = items.take(4).toList();
    if (visible.isEmpty)
      return _HtmlGlass(
        text: 'لا توجد عناصر مملوكة',
        icon: kind == 'gift'
            ? Icons.card_giftcard_rounded
            : Icons.inventory_2_rounded,
        accent: accent,
      );
    return SizedBox(
      height: 104,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: i < visible.length
                  ? _HtmlItemTile(item: visible[i], kind: kind, accent: accent)
                  : const SizedBox(),
            ),
        ],
      ),
    );
  }
}

class _HtmlItemTile extends StatelessWidget {
  const _HtmlItemTile({
    required this.item,
    required this.kind,
    required this.accent,
  });
  final Map<String, dynamic> item;
  final String kind;
  final Color accent;
  String get title =>
      item['name']?.toString() ??
      (kind == 'badge'
          ? 'وسام'
          : kind == 'gift'
          ? 'هدية'
          : 'عنصر');
  String? get image => item['media_url']?.toString().isNotEmpty == true
      ? item['media_url'].toString()
      : item['asset']?.toString().isNotEmpty == true
      ? item['asset'].toString()
      : null;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        children: [
          Expanded(
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: image!.startsWith('assets/')
                        ? Image.asset(
                            image!,
                            fit: BoxFit.contain,
                            width: double.infinity,
                          )
                        : Image.network(
                            image!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                  )
                : Icon(
                    item['icon'] is IconData
                        ? item['icon']
                        : (kind == 'gift'
                              ? Icons.card_giftcard_rounded
                              : kind == 'badge'
                              ? Icons.workspace_premium_rounded
                              : Icons.auto_awesome_rounded),
                    color: accent,
                    size: 30,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (kind == 'gift')
            Text(
              '×${item['received_count'] ?? 0}',
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (kind == 'badge' && item['earned_at'] != null)
            Text(
              _badgeDate(item['earned_at']),
              style: TextStyle(
                color: accent,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ),
  );
}

String _badgeDate(dynamic value) {
  final date = DateTime.tryParse(value.toString())?.toLocal();
  return date == null ? '' : '${date.day}/${date.month}/${date.year}';
}

class _HtmlCollectionPage extends StatelessWidget {
  const _HtmlCollectionPage({
    required this.title,
    required this.items,
    required this.kind,
    required this.accent,
  });
  final String title, kind;
  final List<Map<String, dynamic>> items;
  final Color accent;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF150622),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const Expanded(
                  child: Text(
                    'المجموعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(
                  kind == 'gift'
                      ? Icons.card_giftcard_rounded
                      : Icons.auto_awesome_rounded,
                  color: accent,
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد عناصر مملوكة',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 10,
                          childAspectRatio: .72,
                        ),
                    itemBuilder: (_, i) => _HtmlItemTile(
                      item: items[i],
                      kind: kind,
                      accent: accent,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _HtmlGlass extends StatelessWidget {
  const _HtmlGlass({
    required this.text,
    required this.icon,
    required this.accent,
  });
  final String text;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .05),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(Icons.chevron_left_rounded, color: Colors.white54, size: 18),
      ],
    ),
  );
}

class _HtmlMoments extends StatefulWidget {
  const _HtmlMoments({required this.posts, required this.accent});
  final List<Map<String, dynamic>> posts;
  final Color accent;
  @override
  State<_HtmlMoments> createState() => _HtmlMomentsState();
}

class _HtmlMomentsState extends State<_HtmlMoments> {
  Future<void> _comment(Map<String, dynamic> post) async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF241331),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 18,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقك',
                  hintStyle: TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                if (controller.text.trim().isEmpty) return;
                await SakiService.instance.addComment(
                  post['id'].toString(),
                  controller.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted)
                  setState(
                    () => post['_comments_count'] =
                        (post['_comments_count'] as int? ?? 0) + 1,
                  );
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: widget.accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty)
      return const Padding(
        padding: EdgeInsets.all(25),
        child: Text(
          'لا توجد لحظات بعد',
          style: TextStyle(
            color: Color(0xFFA295B3),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    return Column(
      children: widget.posts
          .map(
            (post) => _MomentCard(
              post: post,
              accent: widget.accent,
              onComment: () => _comment(post),
              onChanged: () => setState(() {}),
            ),
          )
          .toList(),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.post,
    required this.accent,
    required this.onComment,
    required this.onChanged,
  });
  final Map<String, dynamic> post;
  final Color accent;
  final VoidCallback onComment, onChanged;
  @override
  Widget build(BuildContext context) {
    final author = post['profiles'] is Map
        ? Map<String, dynamic>.from(post['profiles'])
        : <String, dynamic>{};
    final liked = post['_liked'] == true;
    final media = List<Map<String, dynamic>>.from(post['_media'] ?? const []);
    final mediaUrl = media.isEmpty
        ? null
        : SakiService.instance.postMediaUrl(
            media.first['storage_path'].toString(),
          );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SakiAvatar(
                url: author['avatar_url']?.toString(),
                label: author['username']?.toString() ?? 'مستخدم',
                radius: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  author['username']?.toString() ?? 'مستخدم',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: ((author['vip_level'] as num?)?.toInt() ?? 0) > 0
                        ? accent
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                post['created_at']?.toString().substring(0, 10) ?? '',
                style: const TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          if ((post['content']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                post['content'].toString(),
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          if (mediaUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.network(
                  mediaUrl,
                  height: 170,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await SakiService.instance.togglePostLike(
                    post['id'].toString(),
                    liked,
                  );
                  post['_liked'] = !liked;
                  post['_likes_count'] =
                      (post['_likes_count'] as int? ?? 0) + (liked ? -1 : 1);
                  onChanged();
                },
                child: Row(
                  children: [
                    Icon(
                      liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: liked ? const Color(0xFFFF6B81) : Colors.white70,
                      size: 19,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post['_likes_count'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: onComment,
                child: Row(
                  children: [
                    const Icon(
                      Icons.mode_comment_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post['_comments_count'] ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
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

class _HtmlAction extends StatelessWidget {
  const _HtmlAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext c) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .3), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileBannerCarousel extends StatefulWidget {
  const _ProfileBannerCarousel();
  @override
  State<_ProfileBannerCarousel> createState() => _ProfileBannerCarouselState();
}

class _ProfileBannerCarouselState extends State<_ProfileBannerCarousel> {
  final _service = SakiService.instance;
  final _controller = PageController();
  List<Map<String, dynamic>> _banners = [];
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final banners = await _service.roomBanners();
      if (!mounted) return;
      setState(() => _banners = banners);
      if (banners.length > 1) {
        _timer = Timer.periodic(const Duration(seconds: 3), (_) {
          if (!mounted || !_controller.hasClients) return;
          _page = (_page + 1) % _banners.length;
          _controller.animateToPage(
            _page,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open(Map<String, dynamic> banner) async {
    final type = banner['target_type']?.toString();
    if (type == 'profile' && banner['target_user_id'] != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              UserProfilePage(userId: banner['target_user_id'].toString()),
        ),
      );
      return;
    }
    if (type == 'room' && banner['target_room_id'] != null) {
      final room = await _service.bannerRoomByCode(
        banner['target_room_id'].toString(),
      );
      if (!mounted) return;
      if (room == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الغرفة غير متاحة حاليًا')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RoomDetailPage(room: room)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();
    return Container(
      color: _profileBg,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            child: PageView.builder(
              controller: _controller,
              itemCount: _banners.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (_, index) {
                final banner = _banners[index];
                return GestureDetector(
                  onTap: () => _open(banner),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      banner['image_url']?.toString() ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE5E7EB),
                        child: Center(child: Icon(Icons.image_not_supported)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_banners.length > 1) ...[
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _page ? _profileYellow : _profileMuted,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ],
        ],
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
    final country = profile['country'] as String? ?? '—';
    final gender = profile['gender'] as String? ?? '';
    final female = gender == 'female' || gender == 'أنثى';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VipNameText(profile: profile, fontSize: 20, maxLines: 1),
          const SizedBox(height: 6),
          VipTitleBadge(profile: profile),
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
              _vehicleAssetPath(vehicle['asset_key']?.toString()),
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

String _vehicleAssetPath(String? key) {
  final value = key?.trim() ?? '';
  if (value.isEmpty)
    return 'assets/trace_profile/features/bg_entrance_effect_selected.png';
  if (value.startsWith('assets/')) return value;
  return 'assets/trace_profile/features/$value';
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
