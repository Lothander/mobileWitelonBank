import 'package:flutter/material.dart';

class AppTheme {
  static const _gradientStart = Color(0xFF3A7BD5); // niebieski
  static const _gradientEnd = Color(0xFF8E2DE2);   // fioletowy

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      primaryColor: _gradientStart,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      textTheme: Typography.blackCupertino,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(fontWeight: FontWeight.bold),
          backgroundColor: _gradientStart,
        ),
      ),
    );
  }

  static LinearGradient get primaryGradient => const LinearGradient(
    colors: [_gradientStart, _gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
