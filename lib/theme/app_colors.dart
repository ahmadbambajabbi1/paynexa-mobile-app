import 'package:flutter/material.dart';

/// Gambian palette from [escrow_web/app/globals.css] @theme.
abstract final class AppColors {
  static const Color gambianRed = Color(0xFFCE1126);
  // The gambian blue is now black here is the blue context was there 0xFF0C1C8C
 static const Color gambianBlue = Color(0xFF000000);
  static const Color gambianGreen = Color(0xFF3A7728);
  static const Color gambianGold = Color(0xFFFFD700);
  static const Color gambianSand = Color(0xFFF4E4C1);
  static const Color gambianEarth = Color(0xFF8B4513);

  /// Neutral app canvas (scaffold + `pageBackground`). Single place to tune the “light gray” look app-wide.
  static const Color pageGradientStart = Color(0xFFF4F6FA);
  static const Color pageGradientEnd = Color(0xFFF4F6FA);

  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pageGradientStart, pageGradientEnd],
  );

  static const LinearGradient heroIconGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gambianRed, gambianBlue, gambianGreen],
  );
}
