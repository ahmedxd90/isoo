import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../core/data/saki_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _videoUrl = 'https://f.top4top.io/m_3901fr5rd0.mp4';
  StreamSubscription<AuthState>? _authSubscription;
  VideoPlayerController? _video;
  bool _loading = false;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      event,
    ) {
      if (event.session != null) _routeAfterAuth();
    });
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _video = controller);
    } catch (_) {
      await controller.dispose();
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.saki://login-callback/',
      );
    } on AuthException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('تعذر فتح تسجيل الدخول عبر Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _routeAfterAuth() async {
    if (_routing || !mounted) return;
    _routing = true;
    try {
      final profile = await SakiService.instance.myProfile();
      final username = profile?['username']?.toString() ?? '';
      final complete =
          username.isNotEmpty &&
          !username.startsWith('user_') &&
          profile?['country'] != null &&
          profile?['gender'] != null;
      if (mounted) context.go(complete ? '/home' : '/complete-profile');
    } finally {
      _routing = false;
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  void dispose() {
    _authSubscription?.cancel();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B34),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_video?.value.isInitialized == true)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _video!.value.size.width,
                height: _video!.value.size.height,
                child: VideoPlayer(_video!),
              ),
            )
          else
            Image.asset('assets/saki_login_background.jpg', fit: BoxFit.cover),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x66070B34),
                    const Color(0x33000000),
                    const Color(0xEE070B34),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: _languageButton(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFF3B0),
                              Color(0xFFFFD700),
                              Color(0xFFF5A623),
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'SAKI CHAT',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 43,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'تراسلوا و احتفلوا و استمتعوا سويا',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'سجل الدخول لتجربة المزيد من الميزات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(width: 320, height: 56, child: _googleButton()),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _loading ? null : () => context.go('/register'),
                    child: const Text(
                      'إنشاء حساب جديد',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'بالاستمرار، فإنك تؤكد أنك تبلغ 18 عاماً أو أكثر، وتوافق على ',
                        ),
                        _link('شروط'),
                        const TextSpan(text: '\n'),
                        _link('استخدام ساكي شات'),
                        const TextSpan(text: ' و'),
                        _link('سياسة الخصوصية'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.55,
                      shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageButton() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .25),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white24),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'اللغة العربية',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        SizedBox(width: 8),
        Icon(Icons.chevron_left_rounded, color: Colors.white70, size: 15),
        SizedBox(width: 4),
        Icon(Icons.language_rounded, color: Colors.white, size: 17),
      ],
    ),
  );

  Widget _googleButton() => ElevatedButton(
    onPressed: _loading ? null : _googleLogin,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .96),
      foregroundColor: const Color(0xFF202124),
      elevation: 10,
      shadowColor: Colors.black54,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 9),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _loading ? 'جارٍ فتح تسجيل الدخول...' : 'الاستمرار ب جوجل',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
          ),
          child: const Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );

  InlineSpan _link(String value) => TextSpan(
    text: value,
    style: const TextStyle(
      color: Color(0xFF9CCBFF),
      decoration: TextDecoration.underline,
    ),
  );
}
