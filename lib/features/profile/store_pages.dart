import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';

const _storeOrange = Color(0xFF9B27B0);
const _storeCyan = Color(0xFF6A1B9A);
const _storeGold = Color(0xFFFFC107);
const _storeInk = Color(0xFF111827);
const _storeSurface = Color(0xFFF8FAFC);

class StoreEntranceOverlay extends StatefulWidget {
  const StoreEntranceOverlay({
    super.key,
    required this.product,
    required this.onDone,
  });
  final Map<String, dynamic> product;
  final VoidCallback onDone;
  @override
  State<StoreEntranceOverlay> createState() => _StoreEntranceOverlayState();
}

class _StoreEntranceOverlayState extends State<StoreEntranceOverlay> {
  VideoPlayerController? _video;
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (widget.product['media_type'] != 'mp4') return;
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.product['media_url'] as String),
    );
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
        if (c.value.isInitialized && c.value.position >= c.value.duration)
          widget.onDone();
      });
    } catch (_) {
      await c.dispose();
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.product['media_type'];
    Widget media;
    if (type == 'mp4' && _video?.value.isInitialized == true) {
      media = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    } else {
      media = Image.network(
        widget.product['media_url'] as String,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    }
    return Positioned.fill(
      child: IgnorePointer(
        child: Material(color: Colors.transparent, child: media),
      ),
    );
  }
}

class StorePage extends StatefulWidget {
  const StorePage({super.key});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  String _category = 'frame';
  bool _isAdmin = false;
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
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _storeSurface,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'متجر SAKI',
            style: TextStyle(color: _storeInk, fontWeight: FontWeight.w900),
          ),
          Text(
            'اختَر إطلالتك داخل الغرفة',
            style: TextStyle(color: Colors.black54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        if (_isAdmin)
          IconButton(
            tooltip: 'إضافة منتج',
            icon: const Icon(Icons.add_business_rounded, color: _storeInk),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminStorePage()),
            ),
          ),
        Container(
          margin: const EdgeInsetsDirectional.only(end: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_storeOrange, _storeCyan]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x3322A6C8), blurRadius: 8),
            ],
          ),
          child: IconButton(
            tooltip: 'حقيبتي',
            color: Colors.white,
            icon: const Icon(Icons.shopping_bag_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BagPage()),
            ),
          ),
        ),
      ],
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
              if (snap.hasError)
                return Center(child: Text('تعذر تحميل المتجر: ${snap.error}'));
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
                  itemBuilder: (_, i) =>
                      ProductCard(product: items[i], onBought: _reload),
                ),
              );
            },
          ),
        ),
      ],
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

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onBought});
  final Map<String, dynamic> product;
  final VoidCallback onBought;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.black.withValues(alpha: .06)),
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
              Image.network(
                product['thumbnail_url'] as String,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const ColoredBox(
                  color: Color(0xFFE0F2FE),
                  child: Icon(
                    Icons.image_not_supported,
                    size: 50,
                    color: _storeCyan,
                  ),
                ),
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
              FilledButton(
                onPressed: () async {
                  try {
                    await SakiService.instance.storeBuy(
                      product['id'] as String,
                    );
                    onBought();
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم الشراء وإضافة المنتج إلى الحقيبة'),
                        ),
                      );
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceFirst('Exception: ', ''),
                          ),
                        ),
                      );
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: _storeGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text(
                  'شراء',
                  style: TextStyle(fontWeight: FontWeight.w900),
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
    appBar: AppBar(title: const Text('حقيبتي')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
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
    return Card(
      child: ListTile(
        leading: Image.network(
          product['thumbnail_url'] as String,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
        ),
        title: Text(
          product['name'] as String,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'الكمية: ${row['quantity']} • ${equipped ? 'مفعّل' : 'غير مفعّل'}\n'
          'ينتهي: ${row['expires_at'] ?? 'بعد 7 أيام'}',
        ),
        trailing: FilledButton(
          onPressed: () async {
            await SakiService.instance.storeEquip(
              product['id'] as String,
              !equipped,
            );
            onChanged();
          },
          child: Text(equipped ? 'إلغاء' : 'تفعيل'),
        ),
      ),
    );
  }
}

class AdminStorePage extends StatefulWidget {
  const AdminStorePage({super.key});
  @override
  State<AdminStorePage> createState() => _AdminStorePageState();
}

class _AdminStorePageState extends State<AdminStorePage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _products = await SakiService.instance.adminStoreProducts();
    if (mounted) setState(() => _loading = false);
  }

  Future<XFile?> _pick(String ext) async {
    final result = await FilePicker.pickFile(type: FileType.any);
    final path = result?.path;
    if (path == null || result?.extension?.toLowerCase() != ext) return null;
    return XFile(path);
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final price = TextEditingController();
    final duration = TextEditingController(text: '7');
    final discount = TextEditingController(text: '0');
    String category = 'frame';
    String mediaType = 'mp4';
    XFile? media;
    XFile? thumbnail;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          insetPadding: EdgeInsets.zero,
          title: const Text('إضافة منتج إلى المتجر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم المنتج'),
                ),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'السعر بالذهب'),
                ),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المدة بالأيام (7 أيام)',
                  ),
                ),
                TextField(
                  controller: discount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'الخصم %'),
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'الفئة'),
                  items: const [
                    DropdownMenuItem(value: 'frame', child: Text('إطارات')),
                    DropdownMenuItem(value: 'entrance', child: Text('دخوليات')),
                    DropdownMenuItem(
                      value: 'bubble',
                      child: Text('فقاعة دردشة'),
                    ),
                  ],
                  onChanged: (v) => setDialog(() => category = v!),
                ),
                DropdownButtonFormField<String>(
                  value: mediaType,
                  decoration: const InputDecoration(labelText: 'نوع الملف'),
                  items: const [
                    DropdownMenuItem(value: 'mp4', child: Text('MP4')),
                    DropdownMenuItem(value: 'svga', child: Text('SVGA')),
                    DropdownMenuItem(value: 'gif', child: Text('GIF')),
                  ],
                  onChanged: (v) => setDialog(() => mediaType = v!),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await _pick(mediaType);
                    if (f != null) setDialog(() => media = f);
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    media == null ? 'اختيار ملف المنتج' : 'تم اختيار الملف',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final f = await _pick('png');
                    if (f != null) setDialog(() => thumbnail = f);
                  },
                  icon: const Icon(Icons.image),
                  label: Text(
                    thumbnail == null
                        ? 'اختيار صورة مصغرة PNG'
                        : 'تم اختيار الصورة',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: media == null || thumbnail == null
                  ? null
                  : () async {
                      final mediaUrl = await SakiService.instance
                          .adminUploadStoreFile(media!);
                      final thumbUrl = await SakiService.instance
                          .adminUploadStoreFile(thumbnail!);
                      await SakiService.instance.adminCreateStoreProduct(
                        category: category,
                        name: name.text,
                        price: int.tryParse(price.text) ?? 0,
                        durationDays: int.tryParse(duration.text) ?? 7,
                        discountPercent: double.tryParse(discount.text) ?? 0,
                        mediaType: mediaType,
                        mediaUrl: mediaUrl,
                        thumbnailUrl: thumbUrl,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('حفظ ونشر'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('إدارة متجر SAKI'),
      actions: [
        IconButton(
          onPressed: _add,
          icon: const Icon(Icons.add_business_rounded),
        ),
      ],
    ),
    body: _loading
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
