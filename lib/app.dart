import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'src/features/splash/presentation/pages/splash_page.dart';

class MedCheckApp extends StatelessWidget {
  const MedCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aegis',
      theme: AppTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}
