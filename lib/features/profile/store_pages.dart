import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';

const _storeOrange = Color(0xFF9B27B0);
const _storeCyan = Color(0xFF6A1B9A);
const _storeGold = Color(0xFFFFC107);
const _storeInk = Color(0xFF111827);
const _storeSurface = Color(0xFFF8FAFC);

class _StoreMediaImage extends StatelessWidget {
  const _StoreMediaImage({
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => path.startsWith('assets/')
      ? Image.asset(path, width: width, height: height, fit: fit)
      : Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: Color(0xFFE0F2FE),
            child: Icon(Icons.image_not_supported, color: _storeCyan),
          ),
        );
}

class StoreEntranceOverlay extends StatefulWidget {
  const StoreEntranceOverlay({
    super.key,
    required this.product,
    required this.profile,
    required this.onDone,
  });
  final Map<String, dynamic> product;
  final Map<String, dynamic> profile;
  final VoidCallback onDone;
  @override
  State<StoreEntranceOverlay> createState() => _StoreEntranceOverlayState();
}

class _StoreEntranceOverlayState extends State<StoreEntranceOverlay>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _video;
  late final SVGAAnimationController _svga;
  bool _visible = true;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _svga = SVGAAnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _start();
  }

  Future<void> _start() async {
    final type = (widget.product['media_type'] as String? ?? '').toLowerCase();
    final url = widget.product['media_url'] as String?;
    if (url == null || url.isEmpty) return _finishAfterFallback();
    if (type == 'svga') {
      try {
        final movie = await SVGAParser.shared.decodeFromURL(url);
        if (!mounted) return;
        _svga.videoItem = movie;
        setState(() {});
        _svga.forward(from: 0);
      } catch (_) {
        _finishAfterFallback();
      }
      return;
    }
    if (type != 'mp4') return _finishAfterFallback();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await c.initialize();
      await c.setLooping(false);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
      c.addListener(() {
        if (c.value.isInitialized && c.value.position >= c.value.duration) {
          _finish();
        }
      });
    } catch (_) {
      await c.dispose();
      _finishAfterFallback();
    }
  }

  void _finishAfterFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 6), _finish);
  }

  void _finish() {
    if (!mounted || !_visible) return;
    setState(() => _visible = false);
    widget.onDone();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _video?.dispose();
    _svga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final type = widget.product['media_type'];
    final media = _svga.videoItem != null
        ? SVGAImage(_svga, fit: BoxFit.contain)
        : type == 'mp4' && _video?.value.isInitialized == true
        ? FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _video!.value.size.width,
              height: _video!.value.size.height,
              child: VideoPlayer(_video!),
            ),
          )
        : Image.network(
            widget.product['media_url'] as String,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          );
    final avatar = widget.profile['avatar_url'] as String?;
    final username = widget.profile['username'] ?? 'مستخدم';
    return Positioned.fill(
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: media),
              Positioned(
                top: 34,
                left: 0,
                right: 0,
                child: _EntranceFlyingBanner(
                  avatarUrl: avatar,
                  username: username.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntranceFlyingBanner extends StatelessWidget {
  const _EntranceFlyingBanner({
    required this.avatarUrl,
    required this.username,
  });
  final String? avatarUrl;
  final String username;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Offset>(
    tween: Tween(begin: const Offset(-1.2, 0), end: Offset.zero),
    duration: const Duration(milliseconds: 1100),
    builder: (_, offset, child) =>
        FractionalTranslation(translation: offset, child: child),
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xCC6A1B9A), Color(0xCCF97316)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white70, width: 1.4),
          boxShadow: const [BoxShadow(color: Colors.white54, blurRadius: 18)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl!.startsWith('http'))
              ClipOval(
                child: Image.network(
                  avatarUrl!,
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              )
            else
              const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 9),
            Text(
              '$username انضم إلى الغرفة',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _storeGold, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  String _category = 'frame';
  bool _isAdmin = false;
  Map<String, dynamic>? _selectedProduct;
  bool _buying = false;
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
    SakiService.instance.isCurrentUserSuperAdmin().then((value) {
      if (mounted) setState(() => _isAdmin = value);
    });
  }

  void _reload() =>
      _future = SakiService.instance.storeProducts(category: _category);

  Future<void> _buySelected() async {
    final product = _selectedProduct;
    if (product == null || _buying) return;
    setState(() => _buying = true);
    try {
      await SakiService.instance.storeBuy(product['id'] as String);
      if (!mounted) return;
      setState(() => _selectedProduct = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الشراء وإضافة المنتج إلى الحقيبة')),
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  Future<void> _confirmBuy() async {
    final product = _selectedProduct;
    if (product == null || _buying) return;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'تأكيد الشراء',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.sizeOf(context).width * .84,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تأكيد الشراء',
                  style: TextStyle(
                    color: _storeInk,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'هل تريد شراء هذا المنتج؟',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    product['thumbnail_url'] as String,
                    width: 108,
                    height: 92,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _storeInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      color: _storeGold,
                      size: 19,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${product['discounted_price'] ?? product['price']} عملة ذهبية',
                      style: const TextStyle(
                        color: _storeOrange,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _storeSurface,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              color: _storeInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_storeGold, Color(0xFFFF8F00)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(13)),
                          ),
                          child: const Text(
                            'تأكيد الشراء',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      transitionBuilder: (_, animation, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: child,
      ),
    );
    if (confirmed == true && mounted) await _buySelected();
  }

  void _sendSelected() {
    if (_selectedProduct == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('حدد غرفة أو مستخدماً لإرسال المنتج')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _storeSurface,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(116),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFA823DA), Color(0xFF8E1DBA), Color(0xFF600C88)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'متجر',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (_isAdmin)
                    _HeaderPill(
                      icon: Icons.add,
                      label: 'إضافة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminStorePage(),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  _HeaderPill(
                    icon: Icons.shopping_bag_outlined,
                    label: 'خاص بي',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BagPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    'إطلالتك داخل الغرفة',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const Spacer(),
                  Text(
                    'SAKI',
                    style: TextStyle(
                      color: _storeGold,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _categoryTab(
                  'frame',
                  Icons.crop_square_rounded,
                  'الإطارات',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _categoryTab(
                  'entrance',
                  Icons.auto_awesome_rounded,
                  'الدخوليات',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _categoryTab(
                  'bubble',
                  Icons.chat_bubble_rounded,
                  'فقاعات',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (_, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: _storeOrange),
                );
              }
              if (snap.hasError) {
                return Center(child: Text('تعذر تحميل المتجر: ${snap.error}'));
              }
              final items = snap.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.storefront_rounded,
                        size: 58,
                        color: _storeCyan,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'لا توجد منتجات متاحة حاليًا',
                        style: TextStyle(
                          color: _storeInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: _storeOrange,
                onRefresh: () async => setState(_reload),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: .66,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => ProductCard(
                    product: items[i],
                    selected: _selectedProduct?['id'] == items[i]['id'],
                    onSelected: () =>
                        setState(() => _selectedProduct = items[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
    bottomNavigationBar: _selectedProduct == null
        ? null
        : _StoreBottomBar(
            product: _selectedProduct!,
            buying: _buying,
            onSend: _sendSelected,
            onBuy: _confirmBuy,
          ),
  );

  Widget _categoryTab(String value, IconData icon, String label) {
    final selected = _category == value;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        _category = value;
        _reload();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_storeOrange, _storeCyan])
              : null,
          color: selected ? null : _storeSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : Colors.black12,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : _storeInk, size: 20),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _storeInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreBottomBar extends StatelessWidget {
  const _StoreBottomBar({
    required this.product,
    required this.buying,
    required this.onSend,
    required this.onBuy,
  });
  final Map<String, dynamic> product;
  final bool buying;
  final VoidCallback onSend;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 18,
          offset: Offset(0, -5),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${product['discounted_price'] ?? product['price']}',
                style: const TextStyle(
                  color: _storeOrange,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'عملات ذهبية',
                style: TextStyle(color: Colors.black54, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: _storeSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              '${product['duration_days'] ?? 7} أيام',
              style: const TextStyle(
                color: _storeInk,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: onSend,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _storeGold, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'إرسال',
                  style: TextStyle(
                    color: Color(0xFFD99B00),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: buying ? null : onBuy,
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_storeGold, Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: buying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'شراء',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.selected,
    required this.onSelected,
  });
  final Map<String, dynamic> product;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: selected ? _storeGold : Colors.black.withValues(alpha: .06),
        width: selected ? 2 : 1,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _StoreMediaImage(
                path: product['thumbnail_url'] as String,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .9),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    product['category'] == 'frame'
                        ? 'إطار'
                        : product['category'] == 'bubble'
                        ? 'فقاعة دردشة'
                        : 'دخولية',
                    style: const TextStyle(
                      color: _storeInk,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
          child: Text(
            product['name'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              const Icon(Icons.monetization_on, color: _storeGold, size: 17),
              const SizedBox(width: 4),
              Text(
                '${product['discounted_price'] ?? product['price']}',
                style: const TextStyle(
                  color: _storeInk,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if ((product['discount_percent'] as num? ?? 0) > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '${product['price']}',
                  style: const TextStyle(
                    color: Colors.black38,
                    fontSize: 10,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: onSelected,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_storeGold, Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Text(
                    'اختيار',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: _storeCyan, size: 14),
              const SizedBox(width: 4),
              Text(
                '${product['duration_days'] ?? 7} أيام',
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
              if ((product['discount_percent'] as num? ?? 0) > 0) ...[
                const Spacer(),
                Text(
                  'خصم ${product['discount_percent']}%',
                  style: const TextStyle(
                    color: _storeGold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class BagPage extends StatefulWidget {
  const BagPage({super.key});
  @override
  State<BagPage> createState() => _BagPageState();
}

class _BagPageState extends State<BagPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SakiService.instance.storeInventory();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _storeSurface,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFA823DA), Color(0xFF600C88)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        child: const SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(Icons.arrow_back_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'خاص بي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Spacer(),
              Icon(Icons.shopping_bag_rounded, color: _storeGold),
            ],
          ),
        ),
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(14),
          children: ['frame', 'entrance', 'bubble'].map((category) {
            final rows = all
                .where((r) => (r['product'] as Map)['category'] == category)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category == 'frame'
                      ? 'الإطارات'
                      : category == 'bubble'
                      ? 'فقاعات الدردشة'
                      : 'الدخوليات',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: Text('لا توجد منتجات'),
                  ),
                ...rows.map(
                  (row) => BagRow(row: row, onChanged: () => setState(_reload)),
                ),
              ],
            );
          }).toList(),
        );
      },
    ),
  );
}

class BagRow extends StatelessWidget {
  const BagRow({super.key, required this.row, required this.onChanged});
  final Map<String, dynamic> row;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final product = Map<String, dynamic>.from(row['product'] as Map);
    final equipped = row['equipped'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: equipped ? _storeGold : Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _StoreMediaImage(
              path: product['thumbnail_url'] as String,
              width: 62,
              height: 62,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] as String,
                  style: const TextStyle(
                    color: _storeInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '7 أيام • ${equipped ? 'مفعّل الآن' : 'غير مفعّل'}',
                  style: const TextStyle(color: Colors.black54, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              await SakiService.instance.storeEquip(
                product['id'] as String,
                !equipped,
              );
              onChanged();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                gradient: equipped
                    ? null
                    : const LinearGradient(
                        colors: [_storeGold, Color(0xFFFF8F00)],
                      ),
                color: equipped ? Colors.white : null,
                border: Border.all(color: _storeGold),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                equipped ? 'إلغاء' : 'تفعيل',
                style: TextStyle(
                  color: equipped ? _storeInk : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminLabel extends StatelessWidget {
  const _AdminLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _storeInk,
      fontSize: 12,
      fontWeight: FontWeight.w900,
    ),
  );
}

class _AdminInput extends StatelessWidget {
  const _AdminInput({
    required this.label,
    required this.controller,
    required this.hint,
    this.numeric = false,
  });
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool numeric;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _AdminLabel(text: label),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    ],
  );
}

class _AdminChoice extends StatelessWidget {
  const _AdminChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(colors: [_storeOrange, _storeCyan])
            : null,
        color: selected ? null : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? Colors.transparent : Colors.black12,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _storeInk,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _AdminFileTile extends StatelessWidget {
  const _AdminFileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.gold = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: gold ? const Color(0xFFFFF8E1) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold ? _storeGold : _storeOrange),
      ),
      child: Row(
        children: [
          Icon(icon, color: gold ? _storeGold : _storeOrange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _storeInk,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: _storeInk),
        ],
      ),
    ),
  );
}

class AdminStorePage extends StatefulWidget {
  const AdminStorePage({super.key});
  @override
  State<AdminStorePage> createState() => _AdminStorePageState();
}

class _AdminStorePageState extends State<AdminStorePage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  bool _authorized = false;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _authorizeAndLoad();
  }

  Future<void> _authorizeAndLoad() async {
    final allowed = await SakiService.instance.isCurrentUserSuperAdmin();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _authorized = false;
        _loading = false;
      });
      return;
    }
    setState(() => _authorized = true);
    await _load();
  }

  Future<void> _load() async {
    try {
      _products = await SakiService.instance.adminStoreProducts();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<XFile?> _pick(String extension) async {
    final result = await FilePicker.pickFile(type: FileType.any);
    final path = result?.path;
    if (path == null || result?.extension?.toLowerCase() != extension) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('اختر ملف .$extension فقط')));
      }
      return null;
    }
    return XFile(path);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final price = TextEditingController();
    String category = 'frame';
    String mediaType = 'mp4';
    XFile? media;
    XFile? thumbnail;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => Container(
          padding: EdgeInsets.fromLTRB(
            18,
            14,
            18,
            MediaQuery.of(context).viewInsets.bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: _storeSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'رفع منتج جديد',
                  style: TextStyle(
                    color: _storeInk,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'سيظهر المنتج مباشرة في متجر SAKI',
                  style: TextStyle(color: Colors.black54, fontSize: 11),
                ),
                const SizedBox(height: 16),
                _AdminInput(
                  label: 'اسم المنتج',
                  controller: name,
                  hint: 'مثال: سيارة الحب',
                ),
                const SizedBox(height: 10),
                _AdminInput(
                  label: 'السعر بالعملات الذهبية',
                  controller: price,
                  hint: '99999',
                  numeric: true,
                ),
                const SizedBox(height: 12),
                const _AdminLabel(text: 'فئة المنتج'),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _AdminChoice(
                      label: 'إطارات',
                      selected: category == 'frame',
                      onTap: () => setDialog(() => category = 'frame'),
                    ),
                    _AdminChoice(
                      label: 'دخوليات',
                      selected: category == 'entrance',
                      onTap: () => setDialog(() => category = 'entrance'),
                    ),
                    _AdminChoice(
                      label: 'فقاعة دردشة',
                      selected: category == 'bubble',
                      onTap: () => setDialog(() => category = 'bubble'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _AdminLabel(text: 'مدة المنتج'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _storeGold),
                  ),
                  child: const Text(
                    '7 أيام فقط (محددة تلقائياً)',
                    style: TextStyle(
                      color: _storeOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _AdminLabel(text: 'نوع ملف المنتج'),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final type in ['mp4', 'svga', 'gif'])
                      _AdminChoice(
                        label: type.toUpperCase(),
                        selected: mediaType == type,
                        onTap: () => setDialog(() {
                          mediaType = type;
                          media = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdminFileTile(
                  icon: Icons.movie_creation_outlined,
                  label: media == null
                      ? 'اختيار ملف الحركة .$mediaType'
                      : 'تم اختيار ${media!.name}',
                  onTap: () async {
                    final f = await _pick(mediaType);
                    if (f != null) setDialog(() => media = f);
                  },
                ),
                const SizedBox(height: 8),
                _AdminFileTile(
                  icon: Icons.image_outlined,
                  label: thumbnail == null
                      ? 'اختيار الصورة المصغرة PNG'
                      : 'تم اختيار ${thumbnail!.name}',
                  gold: true,
                  onTap: () async {
                    final f = await _pick('png');
                    if (f != null) setDialog(() => thumbnail = f);
                  },
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: media == null || thumbnail == null
                      ? null
                      : () async {
                          final parsedPrice = int.tryParse(price.text.trim());
                          if (name.text.trim().isEmpty ||
                              parsedPrice == null ||
                              parsedPrice <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('أدخل اسم المنتج وسعراً صحيحاً'),
                              ),
                            );
                            return;
                          }
                          setDialog(() => _saving = true);
                          try {
                            final mediaUrl = await SakiService.instance
                                .adminUploadStoreFile(media!);
                            final thumbUrl = await SakiService.instance
                                .adminUploadStoreFile(thumbnail!);
                            await SakiService.instance.adminCreateStoreProduct(
                              category: category,
                              name: name.text,
                              price: parsedPrice,
                              durationDays: 7,
                              discountPercent: 0,
                              mediaType: mediaType,
                              mediaUrl: mediaUrl,
                              thumbnailUrl: thumbUrl,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم رفع المنتج ونشره بنجاح'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('فشل رفع المنتج: $e')),
                              );
                            }
                            setDialog(() => _saving = false);
                          }
                        },
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: (media == null || thumbnail == null)
                          ? null
                          : const LinearGradient(
                              colors: [_storeOrange, _storeCyan],
                            ),
                      color: (media == null || thumbnail == null)
                          ? Colors.black12
                          : null,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'حفظ ونشر المنتج',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _storeSurface,
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFA823DA), Color(0xFF600C88)],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.arrow_back_rounded, color: Colors.white),
              const SizedBox(width: 10),
              const Text(
                'رفع منتج جديد',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (_authorized)
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _storeGold,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, color: _storeInk, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'إضافة',
                          style: TextStyle(
                            color: _storeInk,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    body: !_authorized
        ? const Center(
            child: Text(
              'هذه الصفحة متاحة للسوبر أدمن فقط',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          )
        : _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _products.length,
            itemBuilder: (_, i) {
              final p = _products[i];
              return ListTile(
                leading: Image.network(
                  p['thumbnail_url'] as String,
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
                title: Text(p['name'] as String),
                subtitle: Text(
                  '${p['category']} • ${p['discounted_price'] ?? p['price']} ذهب '
                  '• ${p['duration_days'] ?? 7} أيام • خصم ${p['discount_percent'] ?? 0}% '
                  '• ${p['media_type']}',
                ),
              );
            },
          ),
  );
}
