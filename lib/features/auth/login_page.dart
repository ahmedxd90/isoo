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

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  static const _videoUrl = 'https://f.top4top.io/m_3901fr5rd0.mp4';
  VideoPlayerController? _video;
  StreamSubscription? _authSubscription;
  bool _loading = false;
  bool _routing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _routeAfterAuth();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final error = GoRouterState.of(context)
          .uri
          .queryParameters['oauth_error'];
      if (error != null && error.isNotEmpty) {
        _showError(_friendlyOAuthError(error));
      }
    });
    _prepareVideo();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final video = _video;
    if (video == null || !video.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      video.play();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      video.pause();
    }
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
      final launched = await SakiService.instance.signInWithGoogle();
      if (!launched) throw StateError('تعذر فتح صفحة Google.');
    } catch (error) {
      if (mounted) {
        _showError(_friendlyAuthError(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _facebookLogin() async {
    setState(() => _loading = true);
    try {
      final launched = await SakiService.instance.signInWithFacebook();
      if (!launched) throw StateError('تعذر فتح صفحة Facebook.');
    } catch (error) {
      if (mounted) _showError(_friendlyAuthError(error.toString()));
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
    } catch (_) {
      if (mounted) {
        _showError(
          'تم تسجيل الدخول، لكن تعذر تحميل ملفك الشخصي. تحقق من الاتصال وحاول مرة أخرى.',
        );
      }
    } finally {
      _routing = false;
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('cancel') || normalized.contains('access_denied')) {
      return 'تم إلغاء تسجيل الدخول.';
    }
    if (normalized.contains('network') || normalized.contains('socket')) {
      return 'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';
    }
    if (normalized.contains('provider') || normalized.contains('not enabled')) {
      return 'مزود تسجيل الدخول غير مفعّل في إعدادات الخادم حاليًا.';
    }
    return message.isEmpty ? 'تعذر تسجيل الدخول.' : message;
  }

  String _friendlyOAuthError(String error) => _friendlyAuthError(error);

  Future<void> _showError(String text) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تعذر تسجيل الدخول'),
          ],
        ),
        content: Text(text, textDirection: TextDirection.rtl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
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
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.topEnd,
                    child: _languageButton(),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 20),
                        _brandHeader(),
                        const Spacer(),
                        const Text(
                          'مجتمع رائع للحفلات على الانترنت',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'تواصل، استمتع، واصنع لحظات لا تُنسى',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 5),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 340,
                          height: 60,
                          child: _googleButton(),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 340,
                          height: 60,
                          child: _facebookButton(),
                        ),
                        const SizedBox(height: 14),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'بالاستمرار، توافق على '),
                              _link('الشروط'),
                              const TextSpan(text: ' و'),
                              _link('سياسة الخصوصية'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.55,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 3),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
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

  Widget _brandHeader() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD86B), Color(0xFFFF5EA8), Color(0xFF6C63FF)],
          ),
          border: Border.all(color: Colors.white70, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99FF5EA8),
              blurRadius: 24,
              spreadRadius: 3,
            ),
            BoxShadow(color: Color(0x886C63FF), blurRadius: 38),
          ],
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
      const SizedBox(height: 14),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFFF4B0),
            Color(0xFFFFD32A),
            Color(0xFFFF72B6),
            Color(0xFF8CA7FF),
          ],
        ).createShader(bounds),
        child: const Text(
          'SAKI CHAT',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
            shadows: [
              Shadow(color: Color(0xFFFF6BBA), blurRadius: 18),
              Shadow(color: Colors.black87, blurRadius: 10),
            ],
          ),
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'SAKI • LIVE • CONNECT',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 3.2,
          shadows: [Shadow(color: Colors.black87, blurRadius: 5)],
        ),
      ),
    ],
  );

  Widget _facebookButton() => ElevatedButton(
    onPressed: _loading ? null : _facebookLogin,
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1877F2),
      foregroundColor: Colors.white,
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'f',
            style: TextStyle(
              color: Color(0xFF1877F2),
              fontSize: 30,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _loading
                ? 'جارٍ فتح تسجيل الدخول...'
                : 'المتابعة باستخدام Facebook',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 42),
      ],
    ),
  );

  Widget _googleButton() => ElevatedButton(
    onPressed: _loading ? null : _googleLogin,
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .96),
      foregroundColor: const Color(0xFF202124),
      elevation: 12,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _loading ? 'جارٍ فتح تسجيل الدخول...' : 'المتابعة باستخدام Google',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
