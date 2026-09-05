import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../messages/messages_page.dart';

const _profileYellow = Color(0xFFFFC107);
const _profileBg = Color(0xFFF3F4F6);
const _profileInk = Color(0xFF111827);
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
  List<Map<String, dynamic>> _reels = [];
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
        SakiService.instance.userProfileStats(widget.userId),
        SakiService.instance.userPosts(widget.userId),
        SakiService.instance.userReels(widget.userId),
        SakiService.instance.isFollowing(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _stats = Map<String, int>.from(results[1] as Map);
        _posts = List<Map<String, dynamic>>.from(results[2] as List);
        _reels = List<Map<String, dynamic>>.from(results[3] as List);
        _following = results[4] as bool;
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح المحادثة الخاصة')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
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
                      reels: _reels,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
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
      height: 400,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (avatar != null && avatar!.isNotEmpty)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                .2126,
                .7152,
                .0722,
                0,
                0,
                .2126,
                .7152,
                .0722,
                0,
                0,
                .2126,
                .7152,
                .0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: Image.network(
                avatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF374151)),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF334155), Color(0xFF111827)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
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
            bottom: 48,
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
                            errorBuilder: (_, __, ___) => const ColoredBox(
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
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
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
                        'LV$level',
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
          Positioned(
            bottom: 10,
            right: 16,
            left: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ProfileStat(
                  value: '${stats['followers'] ?? 0}',
                  label: 'المتابعين',
                  padding: const EdgeInsets.only(left: 14),
                ),
                _ProfileStat(
                  value: '${stats['following'] ?? 0}',
                  label: 'متابعة',
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                const _ProfileStat(
                  value: '—',
                  label: 'زائر',
                  padding: EdgeInsets.only(right: 14),
                ),
              ],
            ),
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
            label: 'الصفحة الشخصية',
            selected: selected == 0,
            onTap: () => onSelect(0),
          ),
          _ProfileTab(
            label: 'المنشورات',
            selected: selected == 1,
            onTap: () => onSelect(1),
          ),
          _ProfileTab(
            label: 'الريلز',
            selected: selected == 2,
            onTap: () => onSelect(2),
          ),
          _ProfileTab(
            label: 'الهدايا',
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
    required this.reels,
  });
  final int tab;
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> reels;

  @override
  Widget build(BuildContext context) {
    if (tab == 0) {
      final bio = (profile['bio'] as String?)?.trim();
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'السيرة الذاتية',
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
    if (tab == 3) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: EmptyState(
          icon: Icons.card_giftcard_outlined,
          title: 'لا توجد هدايا بعد',
          subtitle: 'ستظهر الهدايا هنا عند استلامها.',
        ),
      );
    }
    final items = tab == 1 ? posts : reels;
    if (items.isEmpty) {
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
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemBuilder: (_, index) {
          final item = items[index];
          final url = tab == 2 ? item['video_url'] as String? : null;
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url != null)
                  Image.network(url, fit: BoxFit.cover)
                else
                  const ColoredBox(color: Color(0xFFFFF7ED)),
                Center(
                  child: FaIcon(
                    tab == 2 ? FontAwesomeIcons.play : FontAwesomeIcons.image,
                    color: _profileYellow,
                    size: 20,
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
