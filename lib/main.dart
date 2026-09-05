import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/auth/complete_profile_page.dart';
import 'features/home/home_page.dart';
import 'core/data/saki_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const SakiApp());
}

class SakiApp extends StatelessWidget {
  const SakiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/splash',
      redirect: (context, state) {
        final uri = state.uri;
        if (uri.scheme == 'io.supabase.saki' || uri.host == 'login-callback') {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashPage()),
        GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
        GoRoute(
          path: '/complete-profile',
          builder: (_, __) => const CompleteProfilePage(),
        ),
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/banned', builder: (_, __) => const AppBannedPage()),
      ],
    );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SAKI',
      theme: SakiTheme.light(),
      darkTheme: SakiTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: router,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        context.go('/login');
        return;
      }
      try {
        final ban = await SakiService.instance.activeAppBan();
        final expires = DateTime.tryParse(ban?['expires_at']?.toString() ?? '');
        if (ban != null &&
            (expires == null || expires.isAfter(DateTime.now()))) {
          if (mounted) context.go('/banned');
          return;
        }
      } catch (_) {}
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakiColors.dark,
      body: Center(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: .86, end: 1).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
            ),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  SakiTheme.gradient.createShader(bounds),
              child: const Text(
                'SAKI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBannedPage extends StatelessWidget {
  const AppBannedPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SakiColors.dark,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block_rounded, color: Colors.redAccent, size: 72),
            const SizedBox(height: 18),
            const Text(
              'تم حظرك من تطبيق SAKI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'لا يمكنك استخدام التطبيق حتى انتهاء مدة الحظر.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    ),
  );
}
