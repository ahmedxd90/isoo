import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:developer' as developer;
import 'dart:async';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/profile_post_card.dart';
import '../../shared/widgets/vip_identity.dart';
import '../messages/messages_page.dart';
import '../rooms/agora_room_page.dart';

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
  List<Map<String, dynamic>> _supporters = [];
  String _countryFlag = '🌍';
  bool _following = false;
  bool _loading = true;
  bool _actionLoading = false;
  String? _loadError;

  Future<T?> _safe<T>(Future<T> request) async {
    try {
      return await request;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final viewerId = SakiService.instance.currentUser?.id;
      if (viewerId != null && viewerId != widget.userId) {
        unawaited(
          SakiService.instance
              .recordProfileVisit(widget.userId)
              .catchError((_) {}),
        );
      }
      final results = await Future.wait<dynamic>([
        SakiService.instance.userProfile(widget.userId),
        _safe(SakiService.instance.familyBadgeForUser(widget.userId)),
        _safe(SakiService.instance.userProfileStats(widget.userId)),
        _safe(SakiService.instance.userPosts(widget.userId)),
        _safe(SakiService.instance.userReceivedGifts(widget.userId)),
        _safe(SakiService.instance.userVehicles(widget.userId)),
        _safe(SakiService.instance.isFollowing(widget.userId)),
        _safe(SakiService.instance.userBadges(widget.userId)),
        _safe(SakiService.instance.isShippingAgent(widget.userId)),
        _safe(SakiService.instance.profileCoverImages(widget.userId)),
        _safe(SakiService.instance.profileLoveRelationship(widget.userId)),
        _safe(SakiService.instance.userGiftSupporters(widget.userId)),
      ]);
      if (!mounted) return;
      var countryFlag = '🌍';
      try {
        final profileMap = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : <String, dynamic>{};
        countryFlag = profileMap['hide_country'] == true
            ? ''
            : await SakiService.instance.countryFlag(
                profileMap['country']?.toString().trim().isNotEmpty == true
                    ? profileMap['country']?.toString()
                    : profileMap['country_code']?.toString(),
              );
      } catch (_) {
        countryFlag = '🌍';
      }
      setState(() {
        final base = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        final family = results[1] is Map
            ? Map<String, dynamic>.from(results[1] as Map)
            : null;
        final community = results[10] is Map
            ? Map<String, dynamic>.from(results[10] as Map)
            : const <String, dynamic>{};
        final love = community['relationship'] ?? community['love'];
        final hiddenIdentity = base?['is_private_identity'] == true;
        _profile = base == null
            ? null
            : {
                ...base,
                'family_badge': hiddenIdentity ? null : family,
                'shipping_agent': hiddenIdentity ? false : results[8] == true,
                'cover_images': hiddenIdentity
                    ? <Map<String, dynamic>>[]
                    : results[9] is List
                    ? _mapList(results[9])
                    : <Map<String, dynamic>>[],
                'love': hiddenIdentity ? null : love,
              };
        _stats = hiddenIdentity
            ? <String, int>{}
            : results[2] is Map
            ? (results[2] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), value is num ? value.toInt() : 0),
              )
            : <String, int>{};
        _posts = hiddenIdentity
            ? <Map<String, dynamic>>[]
            : _mapList(results[3]);
        _gifts = hiddenIdentity
            ? <Map<String, dynamic>>[]
            : _mapList(results[4]);
        _vehicles = hiddenIdentity
            ? <Map<String, dynamic>>[]
            : _mapList(results[5]);
        _following = hiddenIdentity ? false : results[6] == true;
        _badges = hiddenIdentity
            ? <Map<String, dynamic>>[]
            : _mapList(results[7]);
        _countryFlag = hiddenIdentity ? '' : countryFlag;
        _supporters = hiddenIdentity
            ? <Map<String, dynamic>>[]
            : _mapList(results[11]);
      });
    } catch (error, stackTrace) {
      developer.log(
        'تعذر تحميل بروفايل المستخدم',
        name: 'SAKI_PROFILE_LOAD',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _loadError = 'تعذر تحميل بيانات المستخدم.');
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

  Future<void> _report() async {
    var category = 'spam';
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الإبلاغ عن المستخدم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'نوع البلاغ'),
                items: const [
                  DropdownMenuItem(
                    value: 'spam',
                    child: Text('إزعاج أو رسائل عشوائية'),
                  ),
                  DropdownMenuItem(
                    value: 'abuse',
                    child: Text('إساءة أو تنمر'),
                  ),
                  DropdownMenuItem(
                    value: 'fraud',
                    child: Text('احتيال أو انتحال'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('سبب آخر')),
                ],
                onChanged: (value) =>
                    setDialogState(() => category = value ?? 'other'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'التفاصيل (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إرسال البلاغ'),
            ),
          ],
        ),
      ),
    );
    if (submitted == true) {
      try {
        await SakiService.instance.reportUser(
          widget.userId,
          category,
          details: detailsController.text,
        );
        if (mounted) CustomToast.show(context, 'تم إرسال البلاغ للمراجعة');
      } catch (_) {
        if (mounted) CustomToast.show(context, 'تعذر إرسال البلاغ');
      }
    }
    detailsController.dispose();
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
      if (_loadError != null) {
        return Scaffold(
          backgroundColor: _profileBg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 54,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _loadError!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تحقق من الاتصال ثم حاول مرة أخرى.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
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
    final identityHidden = profile['is_private_identity'] == true;

    return _NativeProfileView(
      profile: profile,
      stats: _stats,
      posts: _posts,
      gifts: _gifts,
      vehicles: _vehicles,
      badges: _badges,
      supporters: _supporters,
      countryFlag: _countryFlag,
      username: username,
      avatar: avatar,
      country: country,
      gender: gender,
      isSelf: isSelf,
      identityHidden: identityHidden,
      following: _following,
      loading: _actionLoading,
      onBack: () => Navigator.maybePop(context),
      onCopy: _copyId,
      onFollow: _toggleFollow,
      onMessage: _message,
      onReport: _report,
    );
  }
}

class _NativeProfileView extends StatefulWidget {
  const _NativeProfileView({
    required this.profile,
    required this.stats,
    required this.posts,
    required this.gifts,
    required this.vehicles,
    required this.badges,
    required this.supporters,
    required this.countryFlag,
    required this.username,
    required this.avatar,
    required this.country,
    required this.gender,
    required this.isSelf,
    required this.identityHidden,
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
  final List<Map<String, dynamic>> supporters;
  final String countryFlag;
  final String username;
  final String? avatar, country;
  final String gender;
  final bool isSelf, identityHidden, following, loading;
  final VoidCallback onBack, onCopy, onFollow, onMessage, onReport;

  @override
  State<_NativeProfileView> createState() => _NativeProfileViewState();
}

class _NativeProfileViewState extends State<_NativeProfileView> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return _SakiPremiumUserProfile(
      profile: widget.profile,
      stats: widget.stats,
      posts: widget.posts,
      gifts: widget.gifts,
      supporters: widget.supporters,
      badges: widget.badges,
      username: widget.username,
      avatar: widget.avatar,
      countryFlag: widget.countryFlag,
      gender: widget.gender,
      isSelf: widget.isSelf,
      identityHidden: widget.identityHidden,
      following: widget.following,
      loading: widget.loading,
      onBack: widget.onBack,
      onCopy: widget.onCopy,
      onFollow: widget.onFollow,
      onMessage: widget.onMessage,
      onReport: widget.onReport,
    );
  }
}

class _SakiPremiumUserProfile extends StatefulWidget {
  const _SakiPremiumUserProfile({
    required this.profile,
    required this.stats,
    required this.posts,
    required this.gifts,
    required this.supporters,
    required this.badges,
    required this.username,
    required this.avatar,
    required this.countryFlag,
    required this.gender,
    required this.isSelf,
    required this.identityHidden,
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
  final List<Map<String, dynamic>> posts, gifts, supporters, badges;
  final String username;
  final String? avatar;
  final String countryFlag, gender;
  final bool isSelf, identityHidden, following, loading;
  final VoidCallback onBack, onCopy, onFollow, onMessage, onReport;

  @override
  State<_SakiPremiumUserProfile> createState() =>
      _SakiPremiumUserProfileState();
}

class _SakiPremiumUserProfileState extends State<_SakiPremiumUserProfile> {
  int _tab = 0;

  List<String> _covers() {
    final raw = widget.profile['cover_images'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) =>
              (row['image_url'] ?? row['cover_url'] ?? row['url'])
                  ?.toString() ??
              '',
        )
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final vip = (widget.profile['vip_level'] as num? ?? 0).toInt().clamp(0, 11);
    final accent = vip > 0 ? vipAccent(vip) : const Color(0xFF7C3AED);
    final family = widget.profile['family_badge'] is Map
        ? Map<String, dynamic>.from(widget.profile['family_badge'] as Map)
        : null;
    final ownedBadges = _ownedBadges(
      widget.profile,
      widget.stats,
      widget.badges,
    );
    final covers = _covers();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FB),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _PremiumProfileHero(
                    profile: widget.profile,
                    username: widget.username,
                    avatar: widget.avatar,
                    covers: covers,
                    countryFlag: widget.countryFlag,
                    stats: widget.stats,
                    accent: accent,
                    onBack: widget.onBack,
                    onReport: widget.onReport,
                    onCopy: widget.onCopy,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -22),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 122),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _PremiumTab(
                                label: 'الرئيسية',
                                active: _tab == 0,
                                accent: accent,
                                onTap: () => setState(() => _tab = 0),
                              ),
                              _PremiumTab(
                                label: 'اللحظات',
                                active: _tab == 1,
                                accent: accent,
                                onTap: () => setState(() => _tab = 1),
                              ),
                              _PremiumTab(
                                label: 'الأوسمة',
                                active: _tab == 2,
                                accent: accent,
                                onTap: () => setState(() => _tab = 2),
                              ),
                              _PremiumTab(
                                label: 'الهدايا',
                                active: _tab == 3,
                                accent: accent,
                                onTap: () => setState(() => _tab = 3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: switch (_tab) {
                              1 => _NativeMoments(
                                posts: widget.posts,
                                accent: accent,
                              ),
                              2 => _ReferenceCollection(
                                key: const ValueKey('badges'),
                                title: 'الأوسمة والامتيازات',
                                items: ownedBadges,
                                kind: 'badge',
                                accent: accent,
                              ),
                              3 => _ReferenceCollection(
                                key: const ValueKey('gifts'),
                                title: 'جدار الهدايا',
                                items: widget.gifts,
                                kind: 'gift',
                                accent: accent,
                              ),
                              _ => Column(
                                key: const ValueKey('home'),
                                children: [
                                  _PremiumAboutCard(
                                    profile: widget.profile,
                                    countryFlag: widget.countryFlag,
                                    gender: widget.gender,
                                    stats: widget.stats,
                                    onCopy: widget.onCopy,
                                  ),
                                  const SizedBox(height: 16),
                                  _PremiumExcellenceCard(
                                    profile: widget.profile,
                                    badges: ownedBadges,
                                  ),
                                  const SizedBox(height: 16),
                                  _PremiumSupporters(
                                    supporters: widget.supporters,
                                    compact: true,
                                  ),
                                  const SizedBox(height: 16),
                                  _PremiumGiftWall(gifts: widget.gifts),
                                  const SizedBox(height: 16),
                                  _PremiumCommunityCards(
                                    family: family,
                                    love: widget.profile['love'] is Map
                                        ? Map<String, dynamic>.from(
                                            widget.profile['love'] as Map,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.isSelf && !widget.identityHidden)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: _PremiumActionButton(
                        label: 'رسالة',
                        asset: 'assets/profile_ui/profile_message.png',
                        color: const Color(0xFF6D28D9),
                        loading: widget.loading,
                        onTap: widget.onMessage,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PremiumActionButton(
                        label: widget.following ? 'متابَع' : 'متابعة',
                        asset: widget.following
                            ? 'assets/profile_ui/profile_unfollow.png'
                            : 'assets/profile_ui/profile_follow.png',
                        color: widget.following
                            ? const Color(0xFF4338CA)
                            : const Color(0xFFE9B949),
                        loading: widget.loading,
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

class _PremiumProfileHero extends StatelessWidget {
  const _PremiumProfileHero({
    required this.profile,
    required this.username,
    required this.avatar,
    required this.covers,
    required this.countryFlag,
    required this.stats,
    required this.accent,
    required this.onBack,
    required this.onReport,
    required this.onCopy,
  });
  final Map<String, dynamic> profile;
  final String username, countryFlag;
  final String? avatar;
  final List<String> covers;
  final Map<String, int> stats;
  final Color accent;
  final VoidCallback onBack, onReport, onCopy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 382,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (covers.isNotEmpty)
            Image.network(
              covers.first,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _ProfileCoverFallback(),
            )
          else
            const _ProfileCoverFallback(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x661E0B4B), Color(0xEE160B2F)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: onReport,
                      icon: const Icon(Icons.more_horiz_rounded),
                      color: Colors.white,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD166),
                        accent,
                        const Color(0xFFFF7AC8),
                      ],
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xAA000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF21133C),
                      shape: BoxShape.circle,
                    ),
                    child: SakiAvatar(
                      url: avatar,
                      label: username,
                      radius: 46,
                      profile: profile,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (countryFlag.isNotEmpty) ...[
                      Text(countryFlag, style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                    ],
                    VipNameText(
                      profile: {...profile, 'display_name': username},
                      fontSize: 20,
                    ),
                    const SizedBox(width: 6),
                    WealthVipLabels(
                      profile: {...profile, 'display_name': username},
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile['bio']?.toString().trim().isNotEmpty == true
                      ? profile['bio'].toString()
                      : 'عضو مميز في مجتمع SAKI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PremiumStat(
                      value: '${stats['followers'] ?? 0}',
                      label: 'متابعون',
                    ),
                    _PremiumStat(
                      value: '${stats['following'] ?? 0}',
                      label: 'يتابع',
                    ),
                    _PremiumStat(
                      value: '${stats['posts'] ?? 0}',
                      label: 'لحظات',
                    ),
                    _PremiumStat(
                      value: 'LV.${profile['wealth_level'] ?? 0}',
                      label: 'المستوى',
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

class _PremiumStat extends StatelessWidget {
  const _PremiumStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
    ],
  );
}

class _PremiumTab extends StatelessWidget {
  const _PremiumTab({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? accent : const Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: active ? 30 : 7,
            height: 3,
            decoration: BoxDecoration(
              color: active ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PremiumAboutCard extends StatelessWidget {
  const _PremiumAboutCard({
    required this.profile,
    required this.countryFlag,
    required this.gender,
    required this.stats,
    required this.onCopy,
  });
  final Map<String, dynamic> profile;
  final String countryFlag, gender;
  final Map<String, int> stats;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) => _PremiumCard(
    title: 'عن المستخدم',
    icon: Icons.auto_awesome_rounded,
    child: Column(
      children: [
        if ((profile['bio']?.toString() ?? '').trim().isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              profile['bio'].toString(),
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF4B5563), height: 1.5),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PremiumInfo(
              icon: Icons.person_outline_rounded,
              text: gender.isEmpty ? 'غير محدد' : gender,
            ),
            _PremiumInfo(
              icon: Icons.public_rounded,
              text: '$countryFlag ${profile['country'] ?? 'غير محدد'}',
            ),
            _PremiumInfo(
              icon: Icons.people_alt_outlined,
              text: '${stats['followers'] ?? 0} متابع',
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onCopy,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 7),
                Text(
                  'SAKI ID: ${profile['saki_id'] ?? '—'}',
                  style: const TextStyle(
                    color: Color(0xFF5B21B6),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                const Text(
                  'نسخ',
                  style: TextStyle(
                    color: Color(0xFF7C3AED),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

class _PremiumInfo extends StatelessWidget {
  const _PremiumInfo({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PremiumExcellenceCard extends StatelessWidget {
  const _PremiumExcellenceCard({required this.profile, required this.badges});
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> badges;

  @override
  Widget build(BuildContext context) {
    final level =
        (profile['wealth_level'] as num? ?? profile['level'] as num? ?? 0)
            .toInt();
    final excellence =
        (profile['excellence'] as num? ??
                profile['excellence_stars'] as num? ??
                badges.length)
            .toInt();
    final shown = badges.take(8).toList();
    return _PremiumCard(
      title: 'الامتياز',
      icon: Icons.stars_rounded,
      trailing: '$excellence نجمة',
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD166), Color(0xFFF59E0B)],
              ),
            ),
            child: Center(
              child: Text(
                'LV.$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 62,
              child: shown.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد أوسمة امتياز بعد',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                        ),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final item = shown[index];
                        final asset = item['asset']?.toString();
                        return Container(
                          width: 54,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: asset != null && asset.startsWith('assets/')
                              ? Image.asset(asset, fit: BoxFit.contain)
                              : Icon(
                                  item['icon'] is IconData
                                      ? item['icon'] as IconData
                                      : Icons.workspace_premium_rounded,
                                  color: const Color(0xFFD97706),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumSupporters extends StatelessWidget {
  const _PremiumSupporters({required this.supporters, required this.compact});
  final List<Map<String, dynamic>> supporters;
  final bool compact;
  String _name(Map<String, dynamic> p) =>
      p['display_name']?.toString().trim().isNotEmpty == true
      ? p['display_name'].toString()
      : p['username']?.toString() ?? 'مستخدم';

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'الأصدقاء المقربون',
      icon: Icons.workspace_premium_rounded,
      trailing: 'أعلى مرسلي الهدايا',
      child: supporters.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'لا توجد هدايا مستلمة بعد',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            )
          : SizedBox(
              height: compact ? 116 : 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: supporters
                    .take(compact ? 5 : supporters.length)
                    .length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = supporters[index];
                  final p = item['profile'] is Map
                      ? Map<String, dynamic>.from(item['profile'] as Map)
                      : <String, dynamic>{};
                  return SizedBox(
                    width: compact ? 82 : 100,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFFD166),
                                    Color(0xFFF472B6),
                                  ],
                                ),
                              ),
                              child: SakiAvatar(
                                url: p['avatar_url']?.toString(),
                                label: _name(p),
                                radius: compact ? 28 : 34,
                                profile: p,
                              ),
                            ),
                            Container(
                              width: 21,
                              height: 21,
                              decoration: const BoxDecoration(
                                color: Color(0xFF7C3AED),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _name(p),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF374151),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _compact(item['gift_value']),
                          style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _compact(dynamic value) {
    final n = (value as num?)?.toDouble() ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toInt().toString();
  }
}

class _PremiumGiftWall extends StatelessWidget {
  const _PremiumGiftWall({required this.gifts});
  final List<Map<String, dynamic>> gifts;

  @override
  Widget build(BuildContext context) {
    return _PremiumCard(
      title: 'جدار الهدايا',
      icon: Icons.card_giftcard_rounded,
      trailing: '${gifts.length} نوع',
      child: gifts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'لم يستلم هذا المستخدم هدايا بعد',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            )
          : GridView.builder(
              itemCount: gifts.take(8).length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: .78,
              ),
              itemBuilder: (_, index) {
                final gift = gifts[index];
                final icon = gift['icon']?.toString() ?? '🎁';
                final media = icon.startsWith('http') ? icon : null;
                return Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: media == null
                            ? Center(
                                child: Text(
                                  icon,
                                  style: const TextStyle(fontSize: 27),
                                ),
                              )
                            : Image.network(
                                media,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.card_giftcard_rounded,
                                  color: Color(0xFFD97706),
                                  size: 27,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'x${gift['received_count'] ?? 0}',
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        gift['name']?.toString() ?? 'هدية',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _PremiumCommunityCards extends StatelessWidget {
  const _PremiumCommunityCards({required this.family, required this.love});
  final Map<String, dynamic>? family;
  final Map<String, dynamic>? love;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (family != null)
        _PremiumCard(
          title: 'العائلة',
          icon: Icons.groups_rounded,
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                  ),
                ),
                child: ClipOval(
                  child: family!['avatar_url']?.toString().isNotEmpty == true
                      ? Image.network(
                          family!['avatar_url'].toString(),
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.groups_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      family!['name']?.toString() ?? 'عائلة SAKI',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'LV.${family!['level'] ?? 0} • ${family!['role'] ?? 'عضو'}',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      if (love != null) ...[
        const SizedBox(height: 12),
        _PremiumCard(
          title: 'CP وبيت الحب',
          icon: Icons.favorite_rounded,
          child: const Text(
            'علاقة CP موجودة • افتح بيت الحب لمزيد من التفاصيل',
            style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
          ),
        ),
      ],
    ],
  );
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget child;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0ECF7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120F172A),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: const Color(0xFF7C3AED), size: 17),
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

class _PremiumActionButton extends StatelessWidget {
  const _PremiumActionButton({
    required this.label,
    required this.asset,
    required this.color,
    required this.loading,
    required this.onTap,
  });
  final String label, asset;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 10,
      shadowColor: color.withValues(alpha: .35),
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    ),
    child: loading
        ? const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                asset,
                width: 27,
                height: 27,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.auto_awesome_rounded, size: 20),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
  );
}

class _ProfileCoverFallback extends StatelessWidget {
  const _ProfileCoverFallback();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E3A8A), Color(0xFF312E81), Color(0xFF111827)],
      ),
    ),
  );
}

class _ReferenceCpCard extends StatefulWidget {
  const _ReferenceCpCard({required this.profile, required this.love});
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? love;

  @override
  State<_ReferenceCpCard> createState() => _ReferenceCpCardState();
}

class _ReferenceCpCardState extends State<_ReferenceCpCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _name(Map<String, dynamic> value) =>
      value['display_name']?.toString().trim().isNotEmpty == true
      ? value['display_name'].toString()
      : value['username']?.toString() ?? 'مستخدم';

  @override
  Widget build(BuildContext context) {
    final relationship = _map(widget.love?['relationship'] ?? widget.love);
    final partner = _map(widget.love?['partner']);
    final hasPartner = partner.isNotEmpty;
    final me = widget.profile;
    final started = DateTime.tryParse(
      relationship['started_at']?.toString() ?? '',
    );
    final days = started == null
        ? 0
        : math.max(1, DateTime.now().difference(started).inDays + 1);
    // The current Love House schema does not expose a separate CP level.
    // Keep the label honest and derive a stable display level from the
    // relationship age rather than inventing a database value.
    final cpLevel = days == 0 ? 0 : math.min(99, 1 + (days ~/ 30));

    if (!hasPartner) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B020D), Color(0xFFB91C1C), Color(0xFF172554)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x66FB7185)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, color: Color(0xFFF43F5E), size: 30),
            SizedBox(width: 10),
            Text(
              'لا يوجد ارتباط CP حاليًا',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B0618), Color(0xFFC2185B), Color(0xFF123B78)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x99FF9DB8), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553F0A2F),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFFD1DC),
                size: 17,
              ),
              const SizedBox(width: 6),
              const Text(
                'CP وبيت الحب',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xAA0B1B4D),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x99A5D8FF)),
                ),
                child: Text(
                  'LV CP $cpLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 124,
            child: Row(
              children: [
                Expanded(
                  child: _CpPerson(profile: me, name: _name(me)),
                ),
                SizedBox(
                  width: 76,
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (_, _) => Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: 16 - (_animation.value * 9),
                          child: Opacity(
                            opacity: .45 + (_animation.value * .55),
                            child: const Text(
                              '♥  ♥',
                              style: TextStyle(
                                color: Color(0xFFFFB3C7),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: .91 + (_animation.value * .12),
                          child: Image.asset(
                            'assets/love_house/royal_couple_ring.webp',
                            width: 58,
                            height: 68,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.favorite,
                              color: Color(0xFFFFD77A),
                              size: 44,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 7 + (_animation.value * 6),
                          child: const Text(
                            '♥  ♥  ♥',
                            style: TextStyle(
                              color: Color(0xFFFFD1DC),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _CpPerson(profile: partner, name: _name(partner)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            days > 0
                ? 'مرتبطان منذ $days يومًا • خاتم بيت الحب الملكي'
                : 'خاتم بيت الحب الملكي',
            style: const TextStyle(
              color: Color(0xFFFFE3EC),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CpPerson extends StatelessWidget {
  const _CpPerson({required this.profile, required this.name});
  final Map<String, dynamic> profile;
  final String name;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 82,
        height: 82,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SakiAvatar(
              url: profile['avatar_url']?.toString(),
              label: name,
              radius: 27,
              profile: profile,
            ),
            Image.asset(
              'assets/love_house/royal_avatar_frame.webp',
              width: 82,
              height: 82,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 3),
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ReferenceMiniItem extends StatelessWidget {
  const _ReferenceMiniItem({
    required this.item,
    required this.kind,
    required this.accent,
  });
  final Map<String, dynamic> item;
  final String kind;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final asset = item['asset']?.toString();
    final media = item['media_url']?.toString();
    final image = media != null && media.isNotEmpty ? media : asset;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Expanded(
            child: kind == 'gift' && (image == null || image.isEmpty)
                ? Text(
                    item['icon']?.toString() ?? '🎁',
                    style: const TextStyle(fontSize: 29),
                  )
                : image == null
                ? Icon(
                    kind == 'gift'
                        ? Icons.card_giftcard_rounded
                        : Icons.workspace_premium_rounded,
                    color: accent,
                    size: 29,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: image.startsWith('assets/')
                        ? Image.asset(image, fit: BoxFit.contain)
                        : Image.network(image, fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            item['name']?.toString() ?? (kind == 'gift' ? 'هدية' : 'وسام'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (kind == 'gift')
            Text(
              item['room_name']?.toString() ?? 'غرفة SAKI',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}

class _ReferenceCollection extends StatelessWidget {
  const _ReferenceCollection({
    super.key,
    required this.title,
    required this.items,
    required this.kind,
    required this.accent,
  });
  final String title, kind;
  final List<Map<String, dynamic>> items;
  final Color accent;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      items.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 45),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                kind == 'gift'
                    ? 'لم يتم تلقي أي هدايا حتى الآن.'
                    : 'لم يتم الحصول على أي أوسمة بعد.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 9,
                childAspectRatio: .78,
              ),
              itemBuilder: (_, i) => _ReferenceMiniItem(
                item: items[i],
                kind: kind,
                accent: accent,
              ),
            ),
    ],
  );
}

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

// ignore: unused_element, used by the optional legacy badge renderer.
String _badgeDate(dynamic value) {
  final date = DateTime.tryParse(value.toString())?.toLocal();
  return date == null ? '' : '${date.day}/${date.month}/${date.year}';
}

class _NativeMoments extends StatefulWidget {
  const _NativeMoments({required this.posts, required this.accent});
  final List<Map<String, dynamic>> posts;
  final Color accent;
  @override
  State<_NativeMoments> createState() => _NativeMomentsState();
}

class _NativeMomentsState extends State<_NativeMoments> {
  // ignore: unused_element, retained for the optional legacy comments sheet.
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
          .map((post) => ProfilePostCard(post: post))
          .toList(),
    );
  }
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
        MaterialPageRoute(builder: (_) => agoraRoomPageFor(room)),
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
