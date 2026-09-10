import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:developer' as developer;
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';
import 'vip_widgets.dart';
import '../messages/messages_page.dart';
import '../rooms/rooms_page.dart';

import '../../shared/widgets/custom_toast.dart';

const _profileYellow = Color(0xFFFFC107);
const _profileBg = Color(0xFFF3F4F6);
const _profileMuted = Color(0xFF9CA3AF);

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
        SakiService.instance.isHostAgencyMember(widget.userId),
        SakiService.instance.isHostAgencyOwner(widget.userId),
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
        _profile = base == null
            ? null
            : {
                ...base,
                'family_badge': family,
                'host_agency_member': results[8] == true,
                'host_agency_owner': results[9] == true,
              };
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
        CustomToast.show(context, 'تعذر تحميل بروفايل المستخدم من Supabase');
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
                CustomToast.show(dialogContext, 'تم نسخ الخطأ كاملًا');
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
      CustomToast.show(context, 'تم نسخ SAKI ID');
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
                          if (widget.profile['host_agency_member'] == true) ...[
                            const SizedBox(height: 5),
                            HostAgencyTitleBadge(
                              compact: true,
                              label: widget.profile['host_agency_owner'] == true
                                  ? 'وكيل'
                                  : 'مضيف',
                            ),
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
  if (vip > 0) {
    result.add({
      'name': 'شارة VIP $vip',
      'asset': 'assets/trace_profile/images/ic_vip_badge.png',
      'icon': Icons.workspace_premium_rounded,
    });
  }
  if (profile['family_badge'] is Map) {
    result.add({
      'name': 'عضو العائلة',
      'asset': 'assets/trace_profile/images/ic_fans_badge.png',
      'icon': Icons.groups_rounded,
    });
  }
  if ((stats['followers'] ?? 0) > 0) {
    result.add({
      'name': 'شارة المعجبين',
      'asset': 'assets/trace_profile/images/ic_fans_badge.png',
      'icon': Icons.favorite_rounded,
    });
  }
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
    if (visible.isEmpty) {
      return _HtmlGlass(
        text: 'لا توجد عناصر مملوكة',
        icon: kind == 'gift'
            ? Icons.card_giftcard_rounded
            : Icons.inventory_2_rounded,
        accent: accent,
      );
    }
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
                if (mounted) {
                  setState(
                    () => post['_comments_count'] =
                        (post['_comments_count'] as int? ?? 0) + 1,
                  );
                }
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
    if (widget.posts.isEmpty) {
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
    }
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
        CustomToast.show(context, 'الغرفة غير متاحة حاليًا');
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
