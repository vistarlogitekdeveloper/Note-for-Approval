import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = GoogleFonts.manropeTextTheme().apply(
      bodyColor: AppColors.txt,
      displayColor: AppColors.txt,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.violet,
        brightness: Brightness.dark,
        primary: AppColors.pink,
        secondary: AppColors.orange,
        surface: AppColors.surface,
        error: AppColors.bad,
      ),
      textTheme: base,
      fontFamily: GoogleFonts.manrope().fontFamily,

      // Cards
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line, width: 1),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.bad, width: 1.2),
        ),
        labelStyle: const TextStyle(color: AppColors.txt3, fontSize: 13),
        hintStyle: const TextStyle(color: AppColors.txt3, fontSize: 13.5),
        suffixIconColor: AppColors.txt3,
        prefixIconColor: AppColors.txt3,
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
          foregroundColor: AppColors.txt2,
          side: const BorderSide(color: AppColors.line2, width: 1),
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg2,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.txt,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surface3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line2),
        ),
        textStyle: const TextStyle(color: AppColors.txt2, fontSize: 12.5),
      ),

      // Popup menu
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface2,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line2),
        ),
        textStyle: const TextStyle(color: AppColors.txt2, fontSize: 13.5),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface2,
        labelStyle: const TextStyle(color: AppColors.txt2, fontSize: 12.5),
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line2),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.txt,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),

      // Scrollbar
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.hovered)) return AppColors.pink.withOpacity(0.6);
          return AppColors.violet.withOpacity(0.3);
        }),
        radius: const Radius.circular(6),
        thickness: WidgetStateProperty.all(4),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.pink : AppColors.txt3),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.pink.withOpacity(0.25)
                : AppColors.surface3),
      ),
    );
  }
}
