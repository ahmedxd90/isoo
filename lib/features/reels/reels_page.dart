import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../profile/user_profile_page.dart';

const _reelTeal = Color(0xFF2DD4BF);
const _reelBg = Color(0xFF0D1117);

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});
  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  List<Map<String, dynamic>> _reels = [];
  bool _followingOnly = false;
  bool _loading = true;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SakiService.instance.reels(
        followingOnly: _followingOnly,
      );
      if (mounted)
        setState(() {
          _reels = data;
          _activeIndex = 0;
        });
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل الريلز من Supabase')),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateReelSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _reelTeal),
                  )
                : _reels.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.video_library_outlined,
                      title: 'لا توجد ريلز بعد',
                      subtitle: 'ارفع أول فيديو قصير إلى SAKI.',
                    ),
                  )
                : PageView.builder(
                    scrollDirection: Axis.vertical,
                    itemCount: _reels.length,
                    onPageChanged: (index) =>
                        setState(() => _activeIndex = index),
                    itemBuilder: (_, index) => ReelCard(
                      reel: _reels[index],
                      active: index == _activeIndex,
                    ),
                  ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ReelHeader(
                followingOnly: _followingOnly,
                onFollowing: () {
                  setState(() => _followingOnly = true);
                  _load();
                },
                onAll: () {
                  setState(() => _followingOnly = false);
                  _load();
                },
                onCreate: _create,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelHeader extends StatelessWidget {
  const _ReelHeader({
    required this.followingOnly,
    required this.onFollowing,
    required this.onAll,
    required this.onCreate,
  });
  final bool followingOnly;
  final VoidCallback onFollowing;
  final VoidCallback onAll;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xDD000000), Color(0x55000000), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    child: SafeArea(
      top: true,
      bottom: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Saki',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _ReelTab(
                label: 'متابعين',
                active: followingOnly,
                onTap: onFollowing,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '|',
                  style: TextStyle(color: Colors.white30, fontSize: 12),
                ),
              ),
              _ReelTab(label: 'الكل', active: !followingOnly, onTap: onAll),
            ],
          ),
          GestureDetector(
            onTap: onCreate,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: _reelTeal,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 9)],
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.plus,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ReelTab extends StatelessWidget {
  const _ReelTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: active ? _reelTeal : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.white60,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class ReelCard extends StatefulWidget {
  const ReelCard({super.key, required this.reel, required this.active});
  final Map<String, dynamic> reel;
  final bool active;
  @override
  State<ReelCard> createState() => _ReelCardState();
}

class _ReelCardState extends State<ReelCard> {
  VideoPlayerController? _controller;
  bool _liked = false;
  int _likes = 0;
  bool _loading = true;
  bool _showPlay = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel['_liked'] as bool? ?? false;
    _likes = widget.reel['_likes_count'] as int? ?? 0;
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.reel['video_url'] as String?;
    if (url == null || url.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    await controller.initialize();
    await controller.setLooping(true);
    if (widget.active) await controller.play();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(covariant ReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (widget.active) {
      _controller!.play();
    } else {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      setState(() => _showPlay = true);
    } else {
      await controller.play();
      setState(() => _showPlay = false);
    }
  }

  Future<void> _like() async {
    final old = _liked;
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      await SakiService.instance.toggleReelLike(
        widget.reel['id'] as String,
        old,
      );
    } catch (_) {
      if (mounted)
        setState(() {
          _liked = old;
          _likes += old ? 1 : -1;
        });
    }
  }

  Future<void> _comments() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'تعليقات الريلز',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: SakiService.instance.reelComments(
                  widget.reel['id'] as String,
                ),
                builder: (_, snapshot) => SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: snapshot.data?.length ?? 0,
                    itemBuilder: (_, index) {
                      final row = snapshot.data![index];
                      final profile = Map<String, dynamic>.from(
                        row['profiles'] ?? const {},
                      );
                      return ListTile(
                        leading: SakiAvatar(
                          url: profile['avatar_url'] as String?,
                          label: profile['username'] as String?,
                        ),
                        title: Text(profile['username'] as String? ?? 'عضو'),
                        subtitle: Text(row['content'] as String? ?? ''),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: 'اكتب تعليقًا...',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        await SakiService.instance.addReelComment(
                          widget.reel['id'] as String,
                          controller.text,
                        );
                        controller.clear();
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.paperPlane,
                        color: _reelTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _share() async {
    try {
      await SakiService.instance.shareReel(widget.reel['id'] as String);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تسجيل مشاركة الريلز')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر تسجيل المشاركة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      widget.reel['profiles'] ?? const {},
    );
    final username = profile['username'] as String? ?? 'عضو SAKI';
    final description = widget.reel['description'] as String? ?? '';
    final commentCount = widget.reel['_comments_count'] as int? ?? 0;
    final shareCount = widget.reel['_shares_count'] as int? ?? 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            color: const Color(0xFF111827),
            alignment: Alignment.center,
            child: _loading
                ? const CircularProgressIndicator(color: _reelTeal)
                : _controller == null
                ? const EmptyState(
                    icon: Icons.video_file_outlined,
                    title: 'الفيديو غير متاح',
                    subtitle: 'لم يعد رابط الفيديو صالحًا.',
                  )
                : FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0x33111111),
                  Colors.transparent,
                  Color(0xDD000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        if (_showPlay)
          const Center(
            child: IgnorePointer(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Color(0x88000000),
                child: FaIcon(
                  FontAwesomeIcons.play,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          bottom: 92,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UserProfilePage(
                      userId: widget.reel['author_id'] as String,
                    ),
                  ),
                ),
                child: SakiAvatar(
                  url: profile['avatar_url'] as String?,
                  label: username,
                  radius: 22,
                ),
              ),
              const SizedBox(height: 16),
              _ReelAction(
                icon: FontAwesomeIcons.fire,
                value: _likes,
                active: _liked,
                onTap: _like,
              ),
              const SizedBox(height: 15),
              _ReelAction(
                icon: FontAwesomeIcons.commentDots,
                value: commentCount,
                onTap: _comments,
              ),
              const SizedBox(height: 15),
              _ReelAction(
                icon: FontAwesomeIcons.shareNodes,
                value: shareCount,
                onTap: _share,
              ),
              const SizedBox(height: 18),
              _Disc(image: profile['avatar_url'] as String?),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 76,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  VipUsername(
                    profile: {...profile, 'username': '@$username'},
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.reel['_following'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _reelTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'مُتابَع',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  FaIcon(FontAwesomeIcons.music, color: _reelTeal, size: 12),
                  SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      'الصوت الأصلي - Saki 🎵',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _reelTeal,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReelAction extends StatelessWidget {
  const _ReelAction({
    required this.icon,
    required this.value,
    required this.onTap,
    this.active = false,
  });
  final FaIconData icon;
  final int value;
  final VoidCallback onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .45),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: FaIcon(
              icon,
              color: active ? const Color(0xFFFF4500) : Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _compact(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black, blurRadius: 3)],
          ),
        ),
      ],
    ),
  );
  String _compact(int number) =>
      number >= 1000 ? '${(number / 1000).toStringAsFixed(1)}k' : '$number';
}

class _Disc extends StatefulWidget {
  const _Disc({this.image});
  final String? image;
  @override
  State<_Disc> createState() => _DiscState();
}

class _DiscState extends State<_Disc> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white54, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            widget.image ?? '',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: _reelTeal,
              child: Icon(Icons.music_note, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateReelSheet extends StatefulWidget {
  const CreateReelSheet({super.key});

  @override
  State<CreateReelSheet> createState() => _CreateReelSheetState();
}

class _CreateReelSheetState extends State<CreateReelSheet> {
  final _description = TextEditingController();
  final _picker = ImagePicker();
  XFile? _video;
  String _visibility = 'public';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null && mounted) setState(() => _video = video);
  }

  Future<void> _publish() async {
    if (_video == null) {
      setState(() => _error = 'اختر فيديو أولاً.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SakiService.instance.createReel(
        video: _video!,
        description: _description.text,
        visibility: _visibility,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر رفع الفيديو إلى Supabase.');
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              'رفع Reel',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(
                _video == null ? 'اختيار فيديو' : 'تم اختيار الفيديو',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'وصف الريلز...'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('الخصوصية'),
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
                        'نشر الريلز',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
