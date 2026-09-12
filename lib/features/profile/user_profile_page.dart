import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:developer' as developer;
import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';
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
        SakiService.instance.isShippingAgent(widget.userId),
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
                'shipping_agent': results[8] == true,
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
                value: category,
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
    final accent = vip > 0 ? vipAccent(vip) : const Color(0xFF10B981);
    final family = widget.profile['family_badge'] is Map
        ? Map<String, dynamic>.from(widget.profile['family_badge'] as Map)
        : null;
    final ownedBadges = _ownedBadges(
      widget.profile,
      widget.stats,
      widget.badges,
    );
    final cover = widget.avatar;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _ReferenceProfileHero(
                    username: widget.username,
                    avatar: widget.avatar,
                    cover: cover,
                    gender: widget.gender,
                    countryFlag: widget.countryFlag,
                    profile: widget.profile,
                    stats: widget.stats,
                    onBack: widget.onBack,
                    onMenu: widget.onReport,
                    onCopy: widget.onCopy,
                    accent: accent,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _ReferenceTab(
                                label: 'ملف التعريف',
                                active: tab == 0,
                                accent: accent,
                                onTap: () => setState(() => tab = 0),
                              ),
                              _ReferenceTab(
                                label: 'اللحظات',
                                active: tab == 1,
                                accent: accent,
                                onTap: () => setState(() => tab = 1),
                              ),
                              _ReferenceTab(
                                label: 'الأوسمة',
                                active: tab == 2,
                                accent: accent,
                                onTap: () => setState(() => tab = 2),
                              ),
                              _ReferenceTab(
                                label: 'الهدايا',
                                active: tab == 3,
                                accent: accent,
                                onTap: () => setState(() => tab = 3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: switch (tab) {
                              1 => _HtmlMoments(
                                posts: widget.posts,
                                accent: accent,
                              ),
                              2 => _ReferenceCollection(
                                key: const ValueKey('badges'),
                                title: 'الأوسمة المكتسبة',
                                items: ownedBadges,
                                kind: 'badge',
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
                                        widget.profile['bio']?.toString() ?? '',
                                    isSelf: widget.isSelf,
                                    accent: accent,
                                  ),
                                  _ReferenceSection(
                                    title: 'عائلة',
                                    child: _ReferenceFamilyCard(
                                      family: family,
                                      accent: accent,
                                    ),
                                  ),
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
                ),
              ],
            ),
            if (!widget.isSelf)
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Row(
                  children: [
                    Expanded(
                      child: _ReferenceAction(
                        label: 'رسالة',
                        icon: Icons.chat_bubble_rounded,
                        color: const Color(0xFF2563EB),
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
    );
  }
}

enum _WealthTier { plain, cyan, violet, gold, rainbow, grand, royal }

class _WealthTitleBadge extends StatelessWidget {
  const _WealthTitleBadge({required this.level});
  final int level;

  _WealthTier get tier {
    if (level < 20) return _WealthTier.plain;
    if (level < 40) return _WealthTier.cyan;
    if (level < 60) return _WealthTier.violet;
    if (level < 80) return _WealthTier.gold;
    if (level <= 100) return _WealthTier.rainbow;
    if (level <= 120) return _WealthTier.grand;
    return _WealthTier.royal;
  }

  @override
  Widget build(BuildContext context) {
    final t = tier;
    final plain = t == _WealthTier.plain;
    final large = t.index >= _WealthTier.grand.index;
    final colors = switch (t) {
      _WealthTier.plain => const [Color(0xFF4B5563), Color(0xFF9CA3AF)],
      _WealthTier.cyan => const [
        Color(0xFF0891B2),
        Color(0xFF67E8F9),
        Color(0xFF2563EB),
      ],
      _WealthTier.violet => const [
        Color(0xFF7C3AED),
        Color(0xFFF0ABFC),
        Color(0xFFDB2777),
      ],
      _WealthTier.gold => const [
        Color(0xFFB45309),
        Color(0xFFFDE68A),
        Color(0xFFF59E0B),
      ],
      _WealthTier.rainbow => const [
        Color(0xFF2563EB),
        Color(0xFF22D3EE),
        Color(0xFFA855F7),
        Color(0xFFF43F5E),
      ],
      _WealthTier.grand => const [
        Color(0xFF0E7490),
        Color(0xFF67E8F9),
        Color(0xFF8B5CF6),
        Color(0xFFFDE68A),
      ],
      _WealthTier.royal => const [
        Color(0xFF312E81),
        Color(0xFFC084FC),
        Color(0xFFFDE68A),
        Color(0xFFF9A8D4),
      ],
    };
    final height = large ? 58.0 : 46.0;
    final badgeSize = large ? 50.0 : 38.0;
    return Container(
      height: height,
      constraints: BoxConstraints(minWidth: large ? 178 : 145, maxWidth: 270),
      padding: EdgeInsets.only(left: large ? 6 : 4, right: large ? 18 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(large ? 18 : 14),
        border: Border.all(
          color: Colors.white.withValues(alpha: plain ? .32 : .8),
          width: large ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: plain ? .18 : .55),
            blurRadius: large ? 24 : 12,
            spreadRadius: large ? 2 : 0,
          ),
          if (!plain)
            BoxShadow(
              color: colors.first.withValues(alpha: .35),
              blurRadius: 5,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: badgeSize,
            height: badgeSize,
            child: CustomPaint(
              painter: _WealthEmblemPainter(colors: colors, tier: t),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'LV$level',
            style: TextStyle(
              color: plain ? Colors.white : Colors.white,
              fontSize: large ? 23 : 18,
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
              shadows: [
                if (!plain) const Shadow(color: Colors.white70, blurRadius: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WealthEmblemPainter extends CustomPainter {
  const _WealthEmblemPainter({required this.colors, required this.tier});
  final List<Color> colors;
  final _WealthTier tier;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * .42;
    final ring = Paint()
      ..shader = SweepGradient(colors: [...colors, colors.first])
          .createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .085;
    canvas.drawCircle(center, radius, ring);
    final shield = Path()
      ..moveTo(center.dx, center.dy - radius * .62)
      ..lineTo(center.dx + radius * .62, center.dy - radius * .24)
      ..lineTo(center.dx + radius * .43, center.dy + radius * .52)
      ..lineTo(center.dx, center.dy + radius * .82)
      ..lineTo(center.dx - radius * .43, center.dy + radius * .52)
      ..lineTo(center.dx - radius * .62, center.dy - radius * .24)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(colors: colors.reversed.toList())
          .createShader(Offset.zero & size);
    canvas.drawPath(shield, fill);
    final star = Paint()
      ..color = Colors.white.withValues(
        alpha: tier == _WealthTier.plain ? .75 : .95,
      );
    final points = <Offset>[];
    for (var i = 0; i < 10; i++) {
      final a = -3.14159 / 2 + i * 3.14159 / 5;
      final r = i.isEven ? radius * .34 : radius * .15;
      points.add(center + Offset(math.cos(a) * r, math.sin(a) * r));
    }
    final starPath = Path()..addPolygon(points, true);
    canvas.drawPath(starPath, star);
  }

  @override
  bool shouldRepaint(covariant _WealthEmblemPainter oldDelegate) =>
      oldDelegate.tier != tier || oldDelegate.colors != colors;
}

class _ReferenceProfileHero extends StatelessWidget {
  const _ReferenceProfileHero({
    required this.username,
    required this.avatar,
    required this.cover,
    required this.gender,
    required this.countryFlag,
    required this.profile,
    required this.stats,
    required this.onBack,
    required this.onMenu,
    required this.onCopy,
    required this.accent,
  });
  final String username;
  final String? avatar, cover;
  final String gender, countryFlag;
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final VoidCallback onBack, onMenu, onCopy;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final image = cover == null || cover!.isEmpty ? null : NetworkImage(cover!);
    return Container(
      constraints: const BoxConstraints(minHeight: 330),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        image: image == null
            ? null
            : DecorationImage(
                image: image,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .42),
                  BlendMode.darken,
                ),
              ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: onMenu,
                    icon: const Icon(Icons.more_vert_rounded),
                    color: Colors.white,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: Colors.white,
                    iconSize: 30,
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .5)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 14),
                  ],
                ),
                child: SakiAvatar(url: avatar, label: username, radius: 36),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(countryFlag, style: const TextStyle(fontSize: 17)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: VipNameText(
                      profile: {...profile, 'display_name': username},
                      fontSize: 18,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(width: 5),
                  WealthVipLabels(
                    profile: {...profile, 'display_name': username},
                    compact: true,
                  ),
                  if (gender.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        gender,
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
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    'ID: ${profile['saki_id'] ?? '—'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  IconButton(
                    onPressed: onCopy,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _WealthTitleBadge(
                level: (profile['wealth_level'] as num? ?? 0).toInt(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ReferenceHeroStat(
                    value: '${stats['followers'] ?? 0}',
                    label: 'المتابعون',
                  ),
                  _ReferenceHeroDivider(),
                  _ReferenceHeroStat(
                    value: '${stats['following'] ?? 0}',
                    label: 'الذين تتابعهم',
                  ),
                  _ReferenceHeroDivider(),
                  _ReferenceHeroStat(
                    value: '${stats['posts'] ?? 0}',
                    label: 'اللحظات',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceHeroStat extends StatelessWidget {
  const _ReferenceHeroStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _ReferenceHeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 28, width: 1, color: Colors.white38);
}

class _ReferenceTab extends StatelessWidget {
  const _ReferenceTab({
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
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? accent : const Color(0xFFE5E7EB),
              width: active ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? const Color(0xFF111827) : const Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
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
  Widget build(BuildContext context) => _ReferenceSection(
    title: 'عني',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        bio.isEmpty ? 'لا توجد نبذة مضافة حتى الآن.' : bio,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  const _ReferenceFamilyCard({required this.family, required this.accent});
  final Map<String, dynamic>? family;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final hasFamily = family != null;
    final familyAvatar = family?['avatar_url']?.toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071739), Color(0xFF1868D9), Color(0xFF0A2552)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: .35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x441868D9),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
              ),
            ),
            child: ClipOval(
              child: familyAvatar == null || familyAvatar.isEmpty
                  ? const Icon(Icons.groups_rounded, color: Colors.white)
                  : Image.network(familyAvatar, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFamily
                      ? family!['name']?.toString() ?? 'عائلتي'
                      : 'لا توجد عائلة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFamily
                      ? 'Lv.${family!['level'] ?? 0}  •  ${family!['role'] ?? 'عضو'}'
                      : 'يمكن الانضمام إلى عائلة من صفحة العائلات',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_rounded, color: Color(0xFFFBBF24)),
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

class _ReferenceCollectionPreview extends StatelessWidget {
  const _ReferenceCollectionPreview({
    required this.items,
    required this.kind,
    required this.accent,
  });
  final List<Map<String, dynamic>> items;
  final String kind;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty)
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          kind == 'gift'
              ? 'لم يتم تلقي أي هدايا حتى الآن.'
              : 'لا توجد عناصر مسجلة حتى الآن.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    final visible = items.take(4).toList();
    return SizedBox(
      height: 105,
      child: Row(
        children: [
          for (final item in visible)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _ReferenceMiniItem(
                  item: item,
                  kind: kind,
                  accent: accent,
                ),
              ),
            ),
        ],
      ),
    );
  }
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
            child: image == null
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
