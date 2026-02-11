import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextThemes {
  static TextTheme get textTheme {
    return GoogleFonts.poppinsTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(

          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(

          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(

          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.25,
        ),
        titleLarge: TextStyle(

          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(

          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(

          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(

          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(

          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
        ),
        bodySmall: TextStyle(

          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
        ),
        labelLarge: TextStyle(

          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(

          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(

          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
