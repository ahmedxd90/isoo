import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:developer' as developer;
import 'dart:async';
import 'dart:ui' show ImageFilter;

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
const _brandOrange = Color(0xFFF97316);
const _brandCyan = Color(0xFF06B6D4);
const _familyGreen = Color(0xFF4ADE80);
const _referenceCoverImages = [
  'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?auto=format&fit=crop&q=80&w=1000',
  'https://images.unsplash.com/photo-1557682250-33bd709cbe85?auto=format&fit=crop&q=80&w=1000',
  'https://images.unsplash.com/photo-1557683316-973673baf926?auto=format&fit=crop&q=80&w=1000',
];

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
        SakiService.instance.familyBadgeForUser(widget.userId),
        SakiService.instance.userProfileStats(widget.userId),
        SakiService.instance.userPosts(widget.userId),
        SakiService.instance.userReceivedGifts(widget.userId),
        SakiService.instance.userVehicles(widget.userId),
        SakiService.instance.isFollowing(widget.userId),
        SakiService.instance.userBadges(widget.userId),
        SakiService.instance.isShippingAgent(widget.userId),
      ]);
      if (!mounted) return;
      var countryFlag = '🌍';
      try {
        final profileMap = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : <String, dynamic>{};
        countryFlag = await SakiService.instance.countryFlag(
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
        _profile = base == null
            ? null
            : {
                ...base,
                'family_badge': family,
                'shipping_agent': results[8] == true,
              };
        _stats = results[2] is Map
            ? Map<String, int>.from(
                (results[2] as Map).map(
                  (key, value) =>
                      MapEntry(key.toString(), (value as num).toInt()),
                ),
              )
            : <String, int>{};
        _posts = results[3] is List
            ? List<Map<String, dynamic>>.from(results[3] as List)
            : [];
        _gifts = results[4] is List
            ? List<Map<String, dynamic>>.from(results[4] as List)
            : [];
        _vehicles = results[5] is List
            ? List<Map<String, dynamic>>.from(results[5] as List)
            : [];
        _following = results[6] == true;
        _badges = results[7] is List
            ? List<Map<String, dynamic>>.from(results[7] as List)
            : [];
        _countryFlag = countryFlag;
      });
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, 'تعذر تحميل بروفايل المستخدم: $error');
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
      coverImages: _profileCoverImages(profile),
      country: country,
      gender: gender,
      isSelf: isSelf,
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
    required this.coverImages,
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
  final List<String> coverImages;
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
    final accent = _brandOrange;
    final family = widget.profile['family_badge'] is Map
        ? Map<String, dynamic>.from(widget.profile['family_badge'] as Map)
        : null;
    final ownedBadges = _ownedBadges(
      widget.profile,
      widget.stats,
      widget.badges,
    );

    return Scaffold(
      backgroundColor: _profileBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: SizedBox.expand(
              child: Stack(
                children: [
                  Container(color: Colors.white),
                  CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _ReferenceProfileHero(
                          username: widget.username,
                          avatar: widget.avatar,
                          coverImages: widget.coverImages,
                          gender: widget.gender,
                          countryFlag: widget.countryFlag,
                          country: widget.country,
                          profile: widget.profile,
                          onCopy: widget.onCopy,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                          child: Column(
                            children: [
                              _ReferenceFamilyCard(family: family),
                              const SizedBox(height: 22),
                              Row(
                                children: [
                                  _ReferenceTab(
                                    icon: Icons.person_outline_rounded,
                                    label: 'الأساسي',
                                    active: tab == 0,
                                    accent: accent,
                                    iconColor: accent,
                                    onTap: () => setState(() => tab = 0),
                                  ),
                                  _ReferenceTab(
                                    icon: Icons.workspace_premium_outlined,
                                    label: 'الأوسمة',
                                    active: tab == 1,
                                    accent: accent,
                                    iconColor: const Color(0xFFF59E0B),
                                    onTap: () => setState(() => tab = 1),
                                  ),
                                  _ReferenceTab(
                                    icon: Icons.photo_outlined,
                                    label: 'اللحظات',
                                    active: tab == 2,
                                    accent: accent,
                                    iconColor: _brandCyan,
                                    onTap: () => setState(() => tab = 2),
                                  ),
                                  _ReferenceTab(
                                    icon: Icons.card_giftcard_rounded,
                                    label: 'الهدايا',
                                    active: tab == 3,
                                    accent: accent,
                                    iconColor: const Color(0xFFEC4899),
                                    onTap: () => setState(() => tab = 3),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                child: switch (tab) {
                                  1 => _ReferenceCollection(
                                    key: const ValueKey('badges'),
                                    title: 'الأوسمة المكتسبة',
                                    items: ownedBadges,
                                    kind: 'badge',
                                    accent: accent,
                                  ),
                                  2 => _HtmlMoments(
                                    key: const ValueKey('moments'),
                                    posts: widget.posts,
                                    accent: accent,
                                  ),
                                  3 => _ReferenceCollection(
                                    key: const ValueKey('gifts'),
                                    title: 'الهدايا المستلمة',
                                    items: widget.gifts,
                                    kind: 'gift',
                                    accent: accent,
                                  ),
                                  _ => Column(
                                    key: const ValueKey('profile'),
                                    children: [
                                      _ReferenceAbout(
                                        bio:
                                            widget.profile['bio']?.toString() ??
                                            '',
                                        isSelf: widget.isSelf,
                                        accent: _brandCyan,
                                      ),
                                      const SizedBox(height: 18),
                                      _ReferenceStatsGrid(
                                        profile: widget.profile,
                                        stats: widget.stats,
                                      ),
                                      if (widget.vehicles.isNotEmpty) ...[
                                        const SizedBox(height: 20),
                                        _ReferenceVehicles(
                                          vehicles: widget.vehicles,
                                          accent: accent,
                                        ),
                                      ],
                                      const SizedBox(height: 20),
                                      _ReferenceSection(
                                        title: 'CP',
                                        child: const _ReferenceCpCard(),
                                      ),
                                    ],
                                  ),
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _ReferenceTopBar(
                      onBack: widget.onBack,
                      onMenu: widget.onReport,
                    ),
                  ),
                  if (!widget.isSelf)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: _ReferenceAction(
                              label: 'رسالة',
                              icon: Icons.chat_bubble_rounded,
                              color: _brandCyan,
                              loading: widget.loading,
                              onTap: widget.onMessage,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ReferenceAction(
                              label: widget.following ? 'متابَع' : 'متابعة',
                              icon: widget.following
                                  ? Icons.check_rounded
                                  : Icons.person_add_alt_1_rounded,
                              color: accent,
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
          ),
        ),
      ),
    );
  }
}

class _ReferenceProfileHero extends StatefulWidget {
  const _ReferenceProfileHero({
    required this.username,
    required this.avatar,
    required this.coverImages,
    required this.gender,
    required this.countryFlag,
    required this.country,
    required this.profile,
    required this.onCopy,
  });

  final String username;
  final String? avatar, country;
  final List<String> coverImages;
  final String gender, countryFlag;
  final Map<String, dynamic> profile;
  final VoidCallback onCopy;

  @override
  State<_ReferenceProfileHero> createState() => _ReferenceProfileHeroState();
}

class _ReferenceProfileHeroState extends State<_ReferenceProfileHero> {
  final PageController _coverController = PageController();
  Timer? _coverTimer;
  int _activeCover = 0;

  @override
  void initState() {
    super.initState();
    if (widget.coverImages.length > 1) {
      _coverTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_coverController.hasClients) return;
        final next = (_activeCover + 1) % widget.coverImages.length;
        _coverController.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _coverTimer?.cancel();
    _coverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuperAdmin =
        widget.profile['is_super_admin'] == true ||
        widget.profile['admin_role']?.toString() == 'super_admin';
    final isFemale =
        widget.gender.toLowerCase().contains('أنثى') ||
        widget.gender.toLowerCase().contains('female');

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _coverController,
                itemCount: widget.coverImages.length,
                onPageChanged: (index) => setState(() => _activeCover = index),
                itemBuilder: (_, index) => Image.network(
                  widget.coverImages[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFD6B2), Color(0xFFB6F0F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.coverImages.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 15,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.coverImages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: index == _activeCover ? 1 : .5,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          height: 190,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -64,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 14,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: SakiAvatar(
                            url: widget.avatar,
                            label: widget.username,
                            radius: 60,
                            profile: widget.profile,
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: VipNameText(
                        profile: {
                          ...widget.profile,
                          'display_name': widget.username,
                        },
                        fontSize: 24,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isSuperAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Super Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${widget.profile['saki_id'] ?? '—'}',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: widget.onCopy,
                            child: const Icon(
                              Icons.copy_rounded,
                              color: _brandCyan,
                              size: 16,
                            ),
                          ),
                          _profilePillDivider(),
                          Tooltip(
                            message: widget.country ?? '',
                            child: Text(
                              widget.countryFlag,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          _profilePillDivider(),
                          Icon(
                            isFemale
                                ? Icons.female_rounded
                                : Icons.male_rounded,
                            size: 17,
                            color: isFemale
                                ? const Color(0xFFEC4899)
                                : const Color(0xFF3B82F6),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _profilePillDivider() => Container(
  height: 15,
  width: 1,
  margin: const EdgeInsets.symmetric(horizontal: 8),
  color: const Color(0xFFD1D5DB),
);

class _ReferenceTopBar extends StatelessWidget {
  const _ReferenceTopBar({required this.onBack, required this.onMenu});
  final VoidCallback onBack, onMenu;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .82),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: IconButton(
                onPressed: onMenu,
                tooltip: 'خيارات المستخدم',
                icon: const Icon(Icons.more_vert_rounded),
                color: const Color(0xFF374151),
              ),
            ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: IconButton(
                onPressed: onBack,
                tooltip: 'رجوع',
                icon: const Icon(Icons.chevron_right_rounded),
                color: const Color(0xFF374151),
                iconSize: 30,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReferenceTab extends StatelessWidget {
  const _ReferenceTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final Color accent, iconColor;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 9),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? accent : const Color(0xFFE5E7EB),
              width: active ? 2 : 1,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: active ? accent : iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? accent : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReferenceAbout extends StatelessWidget {
  const _ReferenceAbout({
    required this.bio,
    required this.isSelf,
    required this.accent,
  });
  final String bio;
  final bool isSelf;
  final Color accent;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(width: 4, height: 19, color: accent),
          const SizedBox(width: 8),
          const Text(
            'نبذة عني',
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF3F4F6)),
        ),
        child: Text(
          bio.isEmpty
              ? (isSelf
                    ? 'أضف نبذة قصيرة ليعرفك الآخرون أكثر.'
                    : 'لا توجد نبذة مضافة حتى الآن.')
              : bio,
          textDirection: TextDirection.rtl,
          style: const TextStyle(
            color: Color(0xFF4B5563),
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _ReferenceStatsGrid extends StatelessWidget {
  const _ReferenceStatsGrid({required this.profile, required this.stats});
  final Map<String, dynamic> profile;
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final level = (profile['wealth_level'] as num?)?.toInt() ?? 0;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.25,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ReferenceStatCard(
          label: 'المستوى',
          value: 'Lv. $level',
          icon: Icons.local_fire_department_rounded,
          accent: _brandOrange,
          background: const Color(0xFFFFF7ED),
          border: const Color(0xFFFFEDD5),
        ),
        _ReferenceStatCard(
          label: 'المتابعون',
          value: '${stats['followers'] ?? 0}',
          icon: Icons.people_alt_rounded,
          accent: _brandCyan,
          background: const Color(0xFFECFEFF),
          border: const Color(0xFFCFFAFE),
        ),
        _ReferenceStatCard(
          label: 'الذين تتابعهم',
          value: '${stats['following'] ?? 0}',
          icon: Icons.person_add_alt_1_rounded,
          accent: const Color(0xFF16A34A),
          background: const Color(0xFFF0FDF4),
          border: const Color(0xFFDCFCE7),
        ),
        _ReferenceStatCard(
          label: 'اللحظات',
          value: '${stats['posts'] ?? 0}',
          icon: Icons.photo_library_rounded,
          accent: const Color(0xFF8B5CF6),
          background: const Color(0xFFF5F3FF),
          border: const Color(0xFFEDE9FE),
        ),
      ],
    );
  }
}

class _ReferenceStatCard extends StatelessWidget {
  const _ReferenceStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.background,
    required this.border,
  });

  final String label, value;
  final IconData icon;
  final Color accent, background, border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 14,
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

class _ReferenceVehicles extends StatelessWidget {
  const _ReferenceVehicles({required this.vehicles, required this.accent});
  final List<Map<String, dynamic>> vehicles;
  final Color accent;

  @override
  Widget build(BuildContext context) => _ReferenceSection(
    title: 'المركبات',
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: vehicles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: .95,
      ),
      itemBuilder: (_, index) {
        final vehicle = vehicles[index];
        final asset = vehicle['asset_key']?.toString();
        return Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: asset != null && asset.startsWith('assets/')
                    ? Image.asset(
                        asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.directions_car_filled_rounded,
                          color: accent,
                          size: 35,
                        ),
                      )
                    : Icon(
                        Icons.directions_car_filled_rounded,
                        color: accent,
                        size: 35,
                      ),
              ),
              const SizedBox(height: 5),
              Text(
                vehicle['name']?.toString() ?? 'مركبة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
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
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _ReferenceFamilyCard extends StatelessWidget {
  const _ReferenceFamilyCard({required this.family});
  final Map<String, dynamic>? family;

  @override
  Widget build(BuildContext context) {
    final hasFamily = family != null;
    final familyAvatar = family?['avatar_url']?.toString();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFA3D9A5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 7,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -26,
            top: -30,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .38),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: familyAvatar == null || familyAvatar.isEmpty
                        ? Container(
                            color: _familyGreen,
                            child: const Icon(
                              Icons.groups_rounded,
                              color: Colors.white,
                            ),
                          )
                        : Image.network(
                            familyAvatar,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: _familyGreen,
                              child: Icon(
                                Icons.groups_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFamily
                            ? family!['name']?.toString() ?? 'عائلتي'
                            : 'لا توجد عائلة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasFamily
                            ? 'المستوى ${family!['level'] ?? 0}  •  ${family!['role'] ?? 'عضو'}'
                            : 'انضم إلى مجتمع عائلي في SAKI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .58),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF15803D),
                    size: 19,
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

class _ReferenceCpCard extends StatelessWidget {
  const _ReferenceCpCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B020D), Color(0xFFB91C1C), Color(0xFF4C0519)],
      ),
      borderRadius: BorderRadius.circular(18),
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

class _ReferenceAction extends StatelessWidget {
  const _ReferenceAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.loading,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: loading ? null : onTap,
    icon: loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icon, size: 17),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
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

List<String> _profileCoverImages(Map<String, dynamic> profile) {
  final rawImages = profile['cover_images'];
  final customImages = rawImages is List
      ? rawImages
            .map((image) => image?.toString().trim() ?? '')
            .where((image) => image.isNotEmpty)
            .toList()
      : <String>[];
  final singleCover =
      profile['cover_url']?.toString().trim() ??
      profile['cover_image_url']?.toString().trim() ??
      '';
  if (customImages.isNotEmpty) return customImages.take(6).toList();
  return [if (singleCover.isNotEmpty) singleCover, ..._referenceCoverImages];
}

// ignore: unused_element, used by the optional legacy badge renderer.
String _badgeDate(dynamic value) {
  final date = DateTime.tryParse(value.toString())?.toLocal();
  return date == null ? '' : '${date.day}/${date.month}/${date.year}';
}

class _HtmlMoments extends StatefulWidget {
  const _HtmlMoments({super.key, required this.posts, required this.accent});
  final List<Map<String, dynamic>> posts;
  final Color accent;
  @override
  State<_HtmlMoments> createState() => _HtmlMomentsState();
}

class _HtmlMomentsState extends State<_HtmlMoments> {
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
