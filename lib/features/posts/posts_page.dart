import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../notifications/notifications_page.dart';
import '../profile/user_profile_page.dart';
import '../search/search_page.dart';

const _brand = Color(0xFFF97316);
const _brandDark = Color(0xFFEA580C);
const _brandSoft = Color(0xFFFFF7ED);
const _pageBg = Color(0xFFF8FAFC);
const _slate = Color(0xFF1E293B);
const _slateMuted = Color(0xFF94A3B8);
const _border = Color(0xFFF1F5F9);

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  bool _followingOnly = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await _service.feed(followingOnly: _followingOnly);
      if (mounted) setState(() => _posts = posts);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تحميل المنشورات من Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPost() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePostSheet(),
    );
    if (created == true) _load();
  }

  void _setFeed(bool following) {
    setState(() => _followingOnly = following);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .94),
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            _FeedTab(
              label: 'الكل',
              selected: !_followingOnly,
              onTap: () => _setFeed(false),
            ),
            const SizedBox(width: 22),
            _FeedTab(
              label: 'متابعة',
              selected: _followingOnly,
              onTap: () => _setFeed(true),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchPage())),
            icon: const FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 17,
              color: _slate,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            icon: const FaIcon(FontAwesomeIcons.bell, size: 17, color: _slate),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12, start: 3),
            child: GestureDetector(
              onTap: _createPost,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_brand, _brandDark],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55F97316),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.penNib,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : _error != null
          ? EmptyState(
              icon: Icons.cloud_off_rounded,
              title: _error!,
              subtitle: 'تحقق من اتصال الإنترنت وحاول مرة أخرى.',
            )
          : RefreshIndicator(
              color: _brand,
              onRefresh: _load,
              child: _posts.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        EmptyState(
                          icon: Icons.dynamic_feed_outlined,
                          title: 'لا توجد منشورات بعد',
                          subtitle: 'كن أول من يشارك شيئًا مع مجتمع SAKI.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
                      itemCount: _posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 20),
                      itemBuilder: (_, index) =>
                          HtmlPostCard(post: _posts[index], onChanged: _load),
                    ),
            ),
    );
  }
}

class _FeedTab extends StatelessWidget {
  const _FeedTab({
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
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? _brandDark : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _brandDark : _slateMuted,
            fontSize: 16,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class HtmlPostCard extends StatefulWidget {
  const HtmlPostCard({super.key, required this.post, required this.onChanged});
  final Map<String, dynamic> post;
  final VoidCallback onChanged;

  @override
  State<HtmlPostCard> createState() => _HtmlPostCardState();
}

class _HtmlPostCardState extends State<HtmlPostCard> {
  final _service = SakiService.instance;
  late bool _liked = widget.post['_liked'] as bool? ?? false;
  late int _likes = widget.post['_likes_count'] as int? ?? 0;
  late int _shares = widget.post['_shares_count'] as int? ?? 0;
  bool _following = false;
  bool _followLoading = false;
  bool _likeLoading = false;
  int _page = 0;

  Map<String, dynamic> get profile =>
      Map<String, dynamic>.from(widget.post['profiles'] ?? const {});
  List<Map<String, dynamic>> get media =>
      List<Map<String, dynamic>>.from(widget.post['_media'] ?? const []);

  @override
  void initState() {
    super.initState();
    final authorId = profile['id'] as String?;
    if (authorId != null && authorId != _service.uid) _checkFollowing(authorId);
  }

  Future<void> _checkFollowing(String authorId) async {
    try {
      final result = await _service.isFollowing(authorId);
      if (mounted) setState(() => _following = result);
    } catch (_) {}
  }

  Future<void> _toggleFollow() async {
    final authorId = profile['id'] as String?;
    if (authorId == null || authorId == _service.uid || _followLoading) return;
    final old = _following;
    setState(() {
      _followLoading = true;
      _following = !old;
    });
    try {
      await _service.toggleFollow(authorId, old);
    } catch (_) {
      if (mounted) setState(() => _following = old);
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_likeLoading) return;
    final old = _liked;
    setState(() {
      _likeLoading = true;
      _liked = !old;
      _likes += _liked ? 1 : -1;
    });
    try {
      await _service.togglePostLike(widget.post['id'] as String, old);
    } catch (_) {
      if (mounted)
        setState(() {
          _liked = old;
          _likes += old ? 1 : -1;
        });
    } finally {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _share() async {
    try {
      await _service.sharePost(widget.post['id'] as String);
      if (mounted) setState(() => _shares += 1);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل المشاركة في Supabase')),
        );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر تسجيل المشاركة')));
    }
  }

  Future<void> _comments() async {
    final postId = widget.post['id'] as String;
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(sheetContext).size.height * .64,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: SafeArea(
            child: StatefulBuilder(
              builder: (context, setModalState) => Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'التعليقات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _slate,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _service.comments(postId),
                      builder: (_, snapshot) {
                        final comments = snapshot.data ?? [];
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                            child: CircularProgressIndicator(color: _brand),
                          );
                        if (comments.isEmpty)
                          return const EmptyState(
                            icon: Icons.chat_bubble_outline,
                            title: 'لا توجد تعليقات',
                            subtitle: 'ابدأ الحوار الآن.',
                          );
                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (_, index) {
                            final comment = comments[index];
                            final p = Map<String, dynamic>.from(
                              comment['profiles'] ?? const {},
                            );
                            return ListTile(
                              leading: SakiAvatar(
                                url: p['avatar_url'] as String?,
                                label: p['username'] as String?,
                              ),
                              title: Text(
                                p['username'] as String? ?? 'عضو',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                comment['content'] as String? ?? '',
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'اكتب تعليقًا...',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;
                            await _service.addComment(postId, controller.text);
                            controller.clear();
                            setModalState(() {});
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.paperPlane,
                            color: _brand,
                            size: 17,
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
    controller.dispose();
  }

  Future<void> _menu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              ListTile(
                leading: const FaIcon(
                  FontAwesomeIcons.triangleExclamation,
                  color: Colors.redAccent,
                ),
                title: const Text(
                  'إبلاغ عن المنشور',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال البلاغ للمراجعة')),
                  );
                },
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.link, color: _brand),
                title: const Text(
                  'نسخ رابط المنشور',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تجهيز رابط المنشور')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final author = profile['username'] as String? ?? 'عضو SAKI';
    final content = widget.post['content'] as String? ?? '';
    final mediaUrls = media
        .map(
          (item) => _service.client.storage
              .from('posts')
              .getPublicUrl(item['storage_path'] as String),
        )
        .toList();
    final comments = widget.post['_comments_count'] as int? ?? 0;
    final location = profile['country'] as String? ?? 'SAKI';
    return GestureDetector(
      onDoubleTap: _toggleLike,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserProfilePage(
                              userId: widget.post['author_id'] as String,
                            ),
                          ),
                        ),
                        child: SakiAvatar(
                          url: profile['avatar_url'] as String?,
                          label: author,
                          radius: 25,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              author,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: _slate,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFFF59E0B), _brandDark],
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(6),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FaIcon(
                                    FontAwesomeIcons.star,
                                    color: Colors.white,
                                    size: 9,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                            TextButton.icon(
                              onPressed: _toggleFollow,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: _following
                                    ? const Color(0xFFF1F5F9)
                                    : _brandSoft,
                                foregroundColor: _following
                                    ? _slateMuted
                                    : _brandDark,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _following
                                        ? _border
                                        : const Color(0xFFFED7AA),
                                  ),
                                ),
                              ),
                              icon: FaIcon(
                                _following
                                    ? FontAwesomeIcons.check
                                    : FontAwesomeIcons.plus,
                                size: 9,
                              ),
                              label: Text(
                                _following ? 'متابعة' : 'متابعة',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'منذ لحظات • $location',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _slateMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _menu,
                    icon: const FaIcon(
                      FontAwesomeIcons.ellipsisVertical,
                      size: 18,
                      color: _slateMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      TextSpan(text: content),
                      const TextSpan(
                        text: '\n#تصميم  #ابداع',
                        style: TextStyle(
                          color: _brandDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (mediaUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SizedBox(
                  height: 270,
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: PageView.builder(
                          itemCount: mediaUrls.length,
                          onPageChanged: (page) => setState(() => _page = page),
                          itemBuilder: (_, index) => CachedNetworkImage(
                            imageUrl: mediaUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(color: _brand),
                            ),
                            errorWidget: (_, __, ___) => const ColoredBox(
                              color: _brandSoft,
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.image,
                                  color: _brand,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (mediaUrls.length > 1)
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              mediaUrls.length,
                              (index) => Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index == _page
                                      ? Colors.white
                                      : Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.fire,
                    size: 14,
                    color: _liked ? _brand : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$_likes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _slateMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _comments,
                    child: Text(
                      '$comments تعليق',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _slateMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$_shares مشاركات',
                    style: const TextStyle(
                      fontSize: 12,
                      color: _slateMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _PostAction(
                      icon: FontAwesomeIcons.fire,
                      label: 'شعلة',
                      active: _liked,
                      onTap: _toggleLike,
                    ),
                  ),
                  Expanded(
                    child: _PostAction(
                      icon: FontAwesomeIcons.comment,
                      label: 'تعليق',
                      onTap: _comments,
                    ),
                  ),
                  Expanded(
                    child: _PostAction(
                      icon: FontAwesomeIcons.share,
                      label: 'مشاركة',
                      onTap: _share,
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

class _PostAction extends StatelessWidget {
  const _PostAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final FaIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 14, color: active ? _brandDark : _slateMuted),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? _brandDark : _slateMuted,
            ),
          ),
        ],
      ),
    ),
  );
}

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final _content = TextEditingController();
  final _picker = ImagePicker();
  List<XFile> _images = [];
  String _visibility = 'public';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      imageQuality: 84,
      maxWidth: 1600,
    );
    if (mounted) setState(() => _images = picked.take(10).toList());
  }

  Future<void> _publish() async {
    if (_content.text.trim().isEmpty && _images.isEmpty) {
      setState(() => _error = 'أضف نصًا أو صورة واحدة على الأقل.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SakiService.instance.createPost(
        content: _content.text,
        images: _images,
        visibility: _visibility,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر نشر المنشور.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SakiColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'إنشاء منشور',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _content,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'شارك ما يدور في بالك...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_images[index].path),
                            width: 86,
                            height: 86,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: IconButton(
                            onPressed: () =>
                                setState(() => _images.removeAt(index)),
                            icon: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black87,
                              child: Icon(Icons.close, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_images.isNotEmpty) const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _pickImages,
                    icon: const Icon(
                      Icons.photo_library_outlined,
                      color: SakiColors.cyan,
                    ),
                  ),
                  const Text('حتى 10 صور'),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _visibility,
                    items: const [
                      DropdownMenuItem(value: 'public', child: Text('الجميع')),
                      DropdownMenuItem(
                        value: 'followers',
                        child: Text('المتابعون'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _visibility = value ?? 'public'),
                  ),
                ],
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: SakiTheme.gradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _publish,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'نشر المنشور',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
