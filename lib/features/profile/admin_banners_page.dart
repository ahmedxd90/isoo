import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';

class AdminBannersPage extends StatefulWidget {
  const AdminBannersPage({super.key});
  @override
  State<AdminBannersPage> createState() => _AdminBannersPageState();
}

class _AdminBannersPageState extends State<AdminBannersPage> {
  final _service = SakiService.instance;
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.adminBanners();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل البنرات: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BannerForm(onSaved: _service.createAdminBanner),
    );
    if (created == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> item) async {
    await _service.updateAdminBanner(item['id'].toString(), {
      'is_active': item['is_active'] != true,
    });
    _load();
  }

  Future<void> _delete(String id) async {
    await _service.deleteAdminBanner(id);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAFC),
    appBar: AppBar(
      title: const Text('إدارة البنرات'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        IconButton(
          onPressed: _add,
          icon: const Icon(Icons.add_photo_alternate_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('إضافة بنر'),
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
                ? const Center(child: Text('لا توجد بنرات بعد'))
                : ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final item = _items[index];
                      final type = item['target_type']?.toString() ?? 'none';
                      final destination = type == 'profile'
                          ? 'بروفايل: ${item['target_user_id']}'
                          : type == 'room'
                          ? 'غرفة: ${item['target_room_id']}'
                          : 'بدون وجهة';
                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              child: Image.network(
                                item['image_url']?.toString() ?? '',
                                height: 145,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  height: 145,
                                  child: Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                item['title']?.toString().isNotEmpty == true
                                    ? item['title'].toString()
                                    : 'بنر بلا عنوان',
                              ),
                              subtitle: Text(
                                '$destination • الترتيب ${item['sort_order'] ?? 0}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'toggle') _toggle(item);
                                  if (value == 'delete') {
                                    _delete(item['id'].toString());
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(
                                      item['is_active'] == true
                                          ? 'إيقاف'
                                          : 'تفعيل',
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف'),
                                  ),
                                ],
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

class _BannerForm extends StatefulWidget {
  const _BannerForm({required this.onSaved});
  final Future<void> Function(Map<String, dynamic>) onSaved;
  @override
  State<_BannerForm> createState() => _BannerFormState();
}

class _BannerFormState extends State<_BannerForm> {
  final _title = TextEditingController();
  final _order = TextEditingController(text: '0');
  final _target = TextEditingController();
  XFile? _image;
  String _type = 'none';
  bool _saving = false;

  Future<void> _save() async {
    if (_image == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اختر صورة البنر أولًا')));
      return;
    }
    setState(() => _saving = true);
    try {
      final service = SakiService.instance;
      final imageUrl = await service.uploadBannerImage(_image!);
      String? userId;
      String? roomId;
      if (_type == 'profile') {
        final profile = await service.bannerProfileBySakiId(_target.text);
        if (profile == null) throw Exception('SAKI ID غير موجود');
        userId = profile['id']?.toString();
      } else if (_type == 'room') {
        final room = await service.bannerRoomByCode(_target.text);
        if (room == null) {
          throw Exception('Room ID غير موجود أو الغرفة غير فعالة');
        }
        roomId = room['id']?.toString();
      }
      await widget.onSaved({
        'image_url': imageUrl,
        'title': _title.text.trim(),
        'sort_order': int.tryParse(_order.text) ?? 0,
        'is_active': true,
        'target_type': _type,
        'target_user_id': userId,
        'target_room_id': roomId,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة بنر حقيقي',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                        );
                        if (mounted && picked != null) {
                          setState(() => _image = picked);
                        }
                      },
                icon: const Icon(Icons.image),
                label: Text(
                  _image == null ? 'اختيار صورة' : 'تم اختيار الصورة',
                ),
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                ),
              ),
              TextField(
                controller: _order,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الترتيب'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'وجهة البنر'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('بدون وجهة')),
                  DropdownMenuItem(
                    value: 'profile',
                    child: Text('بروفايل عبر SAKI ID'),
                  ),
                  DropdownMenuItem(
                    value: 'room',
                    child: Text('غرفة عبر Room ID'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _type = value ?? 'none';
                  _target.clear();
                }),
              ),
              if (_type != 'none')
                TextField(
                  controller: _target,
                  keyboardType: _type == 'profile'
                      ? TextInputType.number
                      : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: _type == 'profile' ? 'SAKI ID' : 'Room ID',
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish),
                label: const Text('نشر البنر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
