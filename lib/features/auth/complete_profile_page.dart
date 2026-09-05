import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});
  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _service = SakiService.instance;
  final _username = TextEditingController();
  List<Map<String, dynamic>> _countries = [];
  Map<String, dynamic>? _country;
  XFile? _avatar;
  String? _gender;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.myProfile();
      final countries = await _service.countries();
      if (mounted) {
        setState(() {
          _countries = countries;
          final existing = profile?['username']?.toString() ?? '';
          _username.text = existing.startsWith('user_') ? '' : existing;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
    );
    if (image != null && mounted) setState(() => _avatar = image);
  }

  Future<void> _save() async {
    if (_username.text.trim().length < 3 ||
        _country == null ||
        _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أكمل الاسم والدولة والجنس أولًا.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.completeProfile(
        username: _username.text,
        country: _country!['name_ar'] as String,
        gender: _gender!,
        avatar: _avatar,
      );
      if (mounted) context.go('/home');
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ معلوماتك. حاول مرة أخرى.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF0891B2)),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE0F2FE)),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBFC),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'أكمل معلوماتك',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      centerTitle: true,
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFF97316)),
          )
        : SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
              children: [
                const Text(
                  'مرحبًا بك في SAKI Chat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0891B2),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'أضف معلومات بسيطة لنجهّز ملفك للمجتمع',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 28),
                Center(
                  child: GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 58,
                          backgroundColor: const Color(0xFFE0F2FE),
                          backgroundImage: _avatar == null
                              ? null
                              : FileImage(File(_avatar!.path)),
                          child: _avatar == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 58,
                                  color: Color(0xFF0891B2),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF97316),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'الصورة اختيارية',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 25),
                TextField(
                  controller: _username,
                  decoration: _decoration(
                    'اسم المستخدم',
                    Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _country,
                  isExpanded: true,
                  decoration: _decoration('الدولة', Icons.public_rounded),
                  items: _countries
                      .map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c['flag'] ?? '🌍'}  ${c['name_ar']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _country = v),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: _decoration('الجنس', Icons.wc_rounded),
                  items: const [
                    DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                    DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'دخول إلى SAKI Chat',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
  );
}
