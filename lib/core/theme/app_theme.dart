import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark);
  static ThemeData light() => _build(AppPalette.light);

  /// One recipe, both themes. Every surface/line/text/semantic value comes from
  /// [p]; only the brand ribbon hues (pink/violet/orange) are constant. The
  /// palette is also registered as a [ThemeExtension] so `context.c` resolves
  /// inside the themed tree.
  static ThemeData _build(AppPalette p) {
    final base = GoogleFonts.manropeTextTheme().apply(
      bodyColor: p.txt,
      displayColor: p.txt,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      extensions: [p],
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: p.brightness,
        primary: AppColors.pink,
        secondary: AppColors.orange,
        surface: p.surface,
        error: p.bad,
      ),
      textTheme: base,
      fontFamily: GoogleFonts.manrope().fontFamily,

      // Cards
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.line, width: 1),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: p.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: p.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide(color: p.bad, width: 1.2),
        ),
        labelStyle: TextStyle(color: p.txt3, fontSize: 13),
        hintStyle: TextStyle(color: p.txt3, fontSize: 13.5),
        suffixIconColor: p.txt3,
        prefixIconColor: p.txt3,
      ),

      // Elevated buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.pink,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // Outlined buttons
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.txt2,
          side: BorderSide(color: p.line2, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.pink,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.txt,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: p.line,
        space: 1,
        thickness: 1,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.line2),
        ),
        textStyle: TextStyle(color: p.txt2, fontSize: 12.5),
      ),

      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: p.line2),
        ),
        textStyle: TextStyle(color: p.txt2, fontSize: 13.5),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: p.surface2,
        labelStyle: TextStyle(color: p.txt2, fontSize: 12.5),
        side: BorderSide(color: p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line2),
        ),
        titleTextStyle: TextStyle(
          color: p.txt,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.hovered)) return AppColors.pink.withValues(alpha: 0.6);
          return AppColors.violet.withValues(alpha: 0.3);
        }),
        radius: const Radius.circular(6),
        thickness: WidgetStateProperty.all(4),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.pink : p.txt3),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.pink.withValues(alpha: 0.25)
                : p.surface3),
      ),
    );
  }
}
