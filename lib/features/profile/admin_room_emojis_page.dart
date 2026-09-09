import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';

import '../../shared/widgets/custom_toast.dart';

const _orange = Color(0xFFF97316);
const _cyan = Color(0xFF06B6D4);
const _ink = Color(0xFF111827);

class AdminRoomEmojisPage extends StatefulWidget {
  const AdminRoomEmojisPage({super.key});
  @override
  State<AdminRoomEmojisPage> createState() => _AdminRoomEmojisState();
}

class _AdminRoomEmojisState extends State<AdminRoomEmojisPage> {
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

  void _snack(String text) => CustomToast.show(context, text);
  Future<XFile?> _pickGif() async {
    final f = await FilePicker.pickFile(type: FileType.any);
    if (f?.path == null || f?.extension?.toLowerCase() != 'gif') {
      if (f != null) _snack('اختر ملف GIF فقط');
      return null;
    }
    return XFile(f!.path!);
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final name = TextEditingController(text: item?['name']?.toString() ?? '');
    String? url = item?['gif_url']?.toString();
    XFile? file;
    bool saving = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          Future<void> save() async {
            setDialog(() => saving = true);
            try {
              if (file != null) {
                url = await SakiService.instance.adminUploadRoomEmoji(file!);
              }
              if (item == null) {
                await SakiService.instance.adminCreateRoomEmoji(
                  name: name.text.trim(),
                  gifUrl: url!,
                );
              } else {
                await SakiService.instance.adminUpdateRoomEmoji(
                  item['id'] as String,
                  name: name.text.trim(),
                  gifUrl: url,
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (e) {
              if (mounted) _snack('فشل حفظ الإيموجي: $e');
              setDialog(() => saving = false);
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF7FAFC),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item == null ? 'رفع إيموجي غرفة' : 'تعديل الإيموجي',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'يظهر GIF فوق مقعد المستخدم لمدة 4 ثوانٍ فقط',
                    style: TextStyle(color: Colors.black54, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'اسم الإيموجي',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      hintText: 'مثال: قلوب',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final selected = await _pickGif();
                      if (selected != null) setDialog(() => file = selected);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _cyan),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.gif_box_rounded,
                            color: _cyan,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              file == null
                                  ? (item == null
                                        ? 'اختيار ملف GIF'
                                        : 'تغيير ملف GIF')
                                  : 'تم اختيار ${file!.name}',
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_left_rounded, color: _ink),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap:
                        saving ||
                            name.text.trim().isEmpty ||
                            (item == null && file == null)
                        ? null
                        : save,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: saving
                            ? null
                            : const LinearGradient(colors: [_orange, _cyan]),
                        color: saving ? Colors.black12 : null,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'حفظ ونشر الإيموجي',
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
          );
        },
      ),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final yes = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'حذف',
      barrierColor: Colors.black54,
      pageBuilder: (_, _, _) => Center(
        child: Container(
          width: MediaQuery.sizeOf(context).width * .82,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'حذف الإيموجي؟',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيختفي ${item['name']} من الغرف.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, false),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFFF7FAFC),
                        child: const Text('إلغاء'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(12),
                        color: Colors.redAccent,
                        child: const Text(
                          'حذف',
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
    );
    if (yes == true) {
      await SakiService.instance.adminDeleteRoomEmoji(item['id'] as String);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const Center(child: CircularProgressIndicator(color: _orange));
    } else if (_items.isEmpty) {
      content = const Center(
        child: Text(
          'لا توجد إيموجيات بعد',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
      );
    } else {
      content = GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: .82,
        ),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      item['gif_url'] as String,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['is_active'] == true ? 'نشط في الغرف' : 'متوقف',
                        style: const TextStyle(
                          color: _cyan,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _edit(item),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: _cyan,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _delete(item),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(78),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_orange, _cyan]),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إيموجي الغرف',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'GIF فوق المقعد لمدة 4 ثوانٍ',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _edit,
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: content,
    );
  }
}
