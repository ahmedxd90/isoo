import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _countries = [];
  String? _countryCode;
  String? _gender;
  XFile? _avatar;
  bool _loading = false;
  bool _loadingCountries = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final data = await Supabase.instance.client
          .from('countries')
          .select('code,name_ar,flag')
          .order('name_ar');
      if (mounted)
        setState(() => _countries = List<Map<String, dynamic>>.from(data));
    } catch (_) {
      if (mounted)
        setState(() => _error = 'تعذر تحميل قائمة الدول من Supabase.');
    } finally {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1200,
    );
    if (image != null && mounted) setState(() => _avatar = image);
  }

  Future<void> _register() async {
    if (_username.text.trim().length < 3 ||
        !_email.text.contains('@') ||
        _password.text.length < 6 ||
        _countryCode == null ||
        _gender == null) {
      setState(
        () => _error = 'أكمل الحقول المطلوبة، وكلمة المرور ستة أحرف على الأقل.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = _countries.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['code'] == _countryCode,
        orElse: () => null,
      );
      final countryName = selected?['name_ar'] as String?;
      final response = await Supabase.instance.client.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'username': _username.text.trim(),
          'display_name': _username.text.trim(),
          'country': countryName,
          'gender': _gender,
        },
      );
      final user = response.user;
      if (user != null && _avatar != null && response.session != null) {
        final bytes = await File(_avatar!.path).readAsBytes();
        final path =
            '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('avatars')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        final avatarUrl = Supabase.instance.client.storage
            .from('avatars')
            .getPublicUrl(path);
        await Supabase.instance.client
            .from('profiles')
            .update({'avatar_url': avatarUrl})
            .eq('id', user.id);
      }
      if (!mounted) return;
      if (response.session == null) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تحقق من بريدك'),
            content: const Text(
              'تم إنشاء الحساب في Supabase. افتح بريدك الإلكتروني لتأكيد الحساب ثم سجّل الدخول.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسنًا'),
              ),
            ],
          ),
        );
        if (mounted) context.go('/login');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(
        () => _error = 'تعذر إنشاء الحساب الآن. تحقق من الاتصال وحاول مجددًا.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء حساب'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: SakiColors.card,
                        backgroundImage: _avatar == null
                            ? null
                            : FileImage(File(_avatar!.path)),
                        child: _avatar == null
                            ? const Icon(Icons.add_a_photo_outlined, size: 28)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _username,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _countryCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الدولة',
                      prefixIcon: Icon(Icons.public_rounded),
                    ),
                    hint: Text(
                      _loadingCountries ? 'جاري تحميل الدول...' : 'اختر الدولة',
                    ),
                    items: _countries
                        .map(
                          (country) => DropdownMenuItem<String>(
                            value: country['code'] as String,
                            child: Text(
                              '${country['flag']}  ${country['name_ar']}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _loadingCountries
                        ? null
                        : (value) => setState(() => _countryCode = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الجنس',
                      prefixIcon: Icon(Icons.wc_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'male', child: Text('ذكر')),
                      DropdownMenuItem(value: 'female', child: Text('أنثى')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                  const SizedBox(height: 22),
                  _RegisterGradientButton(
                    label: 'إنشاء الحساب',
                    loading: _loading,
                    onPressed: _loading ? null : _register,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterGradientButton extends StatelessWidget {
  const _RegisterGradientButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? const LinearGradient(colors: [Colors.grey, Colors.grey])
            : SakiTheme.gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 17),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
