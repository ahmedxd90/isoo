import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';

class AdminRoomEmojisPage extends StatefulWidget {
  const AdminRoomEmojisPage({super.key});
  @override
  State<AdminRoomEmojisPage> createState() => _AdminRoomEmojisPageState();
}

class _AdminRoomEmojisPageState extends State<AdminRoomEmojisPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = await SakiService.instance.roomEmojis(admin: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<XFile?> _pickGif() async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file?.path == null || file?.extension?.toLowerCase() != 'gif') {
      if (mounted && file != null) _snack('يجب اختيار ملف GIF فقط');
      return null;
    }
    return XFile(file!.path!);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    String? gifUrl = item?['gif_url']?.toString();
    XFile? file;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          title: Text(item == null ? 'إضافة إيموجي غرفة' : 'تعديل الإيموجي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الإيموجي'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final selected = await _pickGif();
                  if (selected != null) setDialog(() => file = selected);
                },
                icon: const Icon(Icons.gif_box_rounded),
                label: Text(
                  file == null
                      ? (item == null ? 'اختيار ملف GIF' : 'تغيير ملف GIF')
                      : 'تم اختيار ملف GIF',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed:
                  name.text.trim().isEmpty || (item == null && file == null)
                  ? null
                  : () async {
                      if (file != null)
                        gifUrl = await SakiService.instance
                            .adminUploadRoomEmoji(file!);
                      if (item == null) {
                        await SakiService.instance.adminCreateRoomEmoji(
                          name: name.text,
                          gifUrl: gifUrl!,
                        );
                      } else {
                        await SakiService.instance.adminUpdateRoomEmoji(
                          item['id'] as String,
                          name: name.text,
                          gifUrl: gifUrl,
                        );
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف الإيموجي؟'),
        content: Text('سيختفي ${item['name']} من الغرف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await SakiService.instance.adminDeleteRoomEmoji(item['id'] as String);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAFC),
    appBar: AppBar(
      title: const Text(
        'إدارة إيموجي الغرفة',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
      ),
      backgroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        IconButton(
          onPressed: _edit,
          icon: const Icon(Icons.add_circle_rounded, color: Color(0xFFF97316)),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _items.isEmpty
        ? const Center(child: Text('أضف أول إيموجي GIF للغرف'))
        : ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item['gif_url'] as String,
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    item['name'] as String,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    item['is_active'] == true ? 'نشط في الغرف' : 'متوقف',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Wrap(
                    children: [
                      IconButton(
                        onPressed: () => _edit(item),
                        icon: const Icon(
                          Icons.edit_rounded,
                          color: Color(0xFF06B6D4),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _delete(item),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
