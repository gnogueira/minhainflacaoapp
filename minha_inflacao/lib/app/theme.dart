import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1976D2);
  static const _successColor = Color(0xFF22C55E);
  static const _errorColor = Color(0xFFEF4444);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      );

  static Color get success => _successColor;
  static Color get error => _errorColor;
}
