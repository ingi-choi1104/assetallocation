import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Sophisticated forest green palette
  static const Color primary      = Color(0xFF1A5C38); // deep forest green
  static const Color primaryLight = Color(0xFF4CAF50); // medium green
  static const Color primaryDark  = Color(0xFF0D3D22); // very dark green

  static const Color secondary      = Color(0xFF4A7C59); // sage green
  static const Color secondaryLight = Color(0xFF7DAE8A);
  static const Color secondaryDark  = Color(0xFF1F4D32);

  static const Color surface    = Color(0xFFF6FBF7); // cool white with green tint
  static const Color background = Color(0xFFEDF4EF); // soft green-grey
  static const Color error      = Color(0xFFB71C1C);

  static const Color positive = Color(0xFF1B6B3A);
  static const Color negative = Color(0xFFC62828);
  static const Color neutral  = Color(0xFF4A5E52); // green-grey neutral

  // Chart colors — distinct, clean
  static const List<Color> chartColors = [
    Color(0xFF1A5C38), // forest green (primary)
    Color(0xFF1565C0), // blue
    Color(0xFFEF6C00), // orange
    Color(0xFF6A1B9A), // purple
    Color(0xFFAD1457), // pink
    Color(0xFF00838F), // teal
    Color(0xFFF9A825), // amber
    Color(0xFFC62828), // red
  ];
}
