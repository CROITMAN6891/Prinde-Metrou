import 'package:flutter/material.dart';

class MetroTheme {
  MetroTheme._();

  static const background = Color(0xFF0D1B2A);
  static const gridLine = Color(0xFF1B2A3D);
  static const trainHead = Color(0xFFE63946);
  static const trainBody = Color(0xFFF1FAEE);
  static const wagonColor = Color(0xFFFFD166);
  static const scoreText = Color(0xFFF1FAEE);

  static ThemeData get theme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        primary: trainHead,
        secondary: wagonColor,
      ),
    );
  }
}
