import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../shared/navigation/main_navigation.dart';

class SplashPage extends StatefulWidget {
  static const _assetPath = 'assets/logo@4x.png';
  static const double _logoWidth = 160.0;

  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the logo so it renders instantly
    precacheImage(const AssetImage(SplashPage._assetPath), context);
  }

  Future<void> _initialize() async {
    final stopwatch = Stopwatch()..start();

    // TODO: Add any async initialization here (auth restore, data loading, etc.)

    // Enforce minimum 500ms splash so the transition feels intentional
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 500) {
      await Future.delayed(Duration(milliseconds: 500 - elapsed));
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainNavigation(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: SizedBox(
            width: SplashPage._logoWidth,
            child: Image.asset(SplashPage._assetPath),
          ),
        ),
      ),
    );
  }
}
