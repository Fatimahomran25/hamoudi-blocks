import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Hamoudi Blocks" visual identity: a blocky world with bold colors,
/// thick black borders, and a hard box shadow (no blur) instead of a soft
/// one — an original, independent design (see the "logo and name" section
/// of the original prompt).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF1B1B22);
  static const Color surface = Color(0xFF25252F);
  static const Color surfaceLight = Color(0xFF33333F);

  static const Color red = Color(0xFFE2231A);
  static const Color blue = Color(0xFF2E86FF);
  static const Color yellow = Color(0xFFFFD23F);
  static const Color green = Color(0xFF34C759);
  static const Color purple = Color(0xFF9B5DE5);
  static const Color orange = Color(0xFFFF8A3D);

  static const Color ink = Color(0xFF14141A);
  static const Color textLight = Color(0xFFF6F6F9);
  static const Color textMuted = Color(0xFFB6B6C4);
}

class AppTheme {
  AppTheme._();

  /// A thick, rounded cartoon font that supports both Arabic and English in the same style.
  static TextTheme _textTheme(TextTheme base) {
    return GoogleFonts.balooBhaijaan2TextTheme(base).apply(
      bodyColor: AppColors.textLight,
      displayColor: AppColors.textLight,
    );
  }

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.red,
        secondary: AppColors.blue,
        surface: AppColors.surface,
      ),
      textTheme: _textTheme(base.textTheme),
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}

/// Thick black borders + a bold box shadow (no blur) — the recurring
/// visual element on every card and button in the app.
class NeoBox extends StatelessWidget {
  const NeoBox({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor = AppColors.ink,
    this.shadowColor = AppColors.ink,
    this.borderRadius = 20,
    this.borderWidth = 3,
    this.shadowOffset = const Offset(0, 6),
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final double borderRadius;
  final double borderWidth;
  final Offset shadowOffset;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }
}
