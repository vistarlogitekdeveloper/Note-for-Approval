import 'package:flutter/material.dart';

/// Brand constants — identical in every theme.
///
/// The Vistar ribbon and its member hues are the brand signature and do NOT
/// change between light and dark. Anything that DOES change with the theme
/// (surfaces, lines, text, semantic colours) lives on [AppPalette] and is read
/// through `context.c`, never from here.
class AppColors {
  AppColors._();

  // ── Vistar Brand Ribbon ──────────────────────────────────────────────────
  static const purple = Color(0xFF7A1FB0);
  static const violet = Color(0xFF9B30C9);
  static const magenta = Color(0xFFC018C0);
  static const pink = Color(0xFFE0218A);
  static const red = Color(0xFFC8102E);
  static const orangeRed = Color(0xFFF0480C);
  static const orange = Color(0xFFF06000);
  static const amber = Color(0xFFF0C000);
  static const yellow = Color(0xFFF0E060);
  static const cream = Color(0xFFFFF6CC);

  // ── Gradients (brand, theme-independent) ─────────────────────────────────
  static const ribbonColors = [
    purple, violet, magenta, pink, red, orangeRed, orange, amber,
  ];
  static const ribbonStops = [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 1.0];

  static const ribbon = LinearGradient(
    begin: Alignment(-1, -0.3),
    end: Alignment(1, 0.3),
    colors: ribbonColors,
    stops: ribbonStops,
  );

  static const ribbonDiag = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, magenta, orange, amber],
  );

  // ── Legacy dark aliases ──────────────────────────────────────────────────
  // A handful of call sites reference a fixed dark surface directly (e.g. the
  // splash, which renders before a theme is mounted). These keep the original
  // dark values so nothing that genuinely wants "the dark brand canvas"
  // silently turns white. Prefer `context.c.*` for anything inside the themed
  // widget tree.
  static const darkBg = Color(0xFF070611);
  static const darkSurface = Color(0xFF110F1E);
}

/// Every colour that differs between light and dark themes.
///
/// Registered as a [ThemeExtension] on both [ThemeData]s, so a widget reads the
/// right variant for the active theme via `context.c` and Flutter animates the
/// crossfade through [lerp] on a theme change. Kept as an extension (rather than
/// runtime-swapped globals) on purpose: a call site that forgets `context`, or
/// tries to use a token in a `const`, fails to COMPILE instead of silently
/// painting the wrong colour at runtime.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.line,
    required this.line2,
    required this.txt,
    required this.txt2,
    required this.txt3,
    required this.ok,
    required this.warn,
    required this.bad,
    required this.info,
  });

  /// Lets a widget branch on the theme without a `Theme.of` round-trip
  /// (e.g. the ambient background chooses its own treatment per brightness).
  final Brightness brightness;
  bool get isDark => brightness == Brightness.dark;

  // Surfaces, back-to-front.
  final Color bg; // page canvas
  final Color bg2; // app bar / sidebar
  final Color surface; // cards
  final Color surface2; // raised / hovered
  final Color surface3; // chips / inputs

  // Hairlines.
  final Color line;
  final Color line2;

  // Text, most to least prominent.
  final Color txt;
  final Color txt2;
  final Color txt3;

  // Semantic.
  final Color ok;
  final Color warn;
  final Color bad;
  final Color info;

  /// The current dark theme, unchanged from the original design.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    bg: Color(0xFF070611),
    bg2: Color(0xFF0B0A18),
    surface: Color(0xFF110F1E),
    surface2: Color(0xFF16142A),
    surface3: Color(0xFF1D1A33),
    line: Color(0x14FFFFFF), // white @ 8%
    line2: Color(0x21FFFFFF), // white @ 13%
    txt: Color(0xFFF2EEFB),
    txt2: Color(0xFFB9B2D6),
    txt3: Color(0xFF7E769B),
    ok: Color(0xFF34D399),
    warn: Color(0xFFFBBF24),
    bad: Color(0xFFFB6F84),
    info: Color(0xFF5BA8FF),
  );

  /// Clean functional light: off-white surfaces, near-black violet-tinted text,
  /// soft black hairlines, and semantic hues darkened so they stay legible on
  /// white (the bright dark-mode greens/ambers wash out on a light canvas).
  static const light = AppPalette(
    brightness: Brightness.light,
    bg: Color(0xFFF6F5FB), // faint lavender page
    bg2: Color(0xFFFFFFFF), // app bar / sidebar
    surface: Color(0xFFFFFFFF), // cards
    surface2: Color(0xFFF1EFF8), // raised / hovered
    surface3: Color(0xFFE9E6F3), // chips / inputs
    line: Color(0x14000000), // black @ 8%
    line2: Color(0x24000000), // black @ 14%
    txt: Color(0xFF1A1726), // near-black, violet undertone
    txt2: Color(0xFF4A4562), // secondary
    txt3: Color(0xFF6E6885), // muted — ~4.7:1 on white
    ok: Color(0xFF059669), // emerald-600
    warn: Color(0xFFB45309), // amber-700 (dark enough to read on white)
    bad: Color(0xFFDC2626), // red-600
    info: Color(0xFF2563EB), // blue-600
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? bg,
    Color? bg2,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? line,
    Color? line2,
    Color? txt,
    Color? txt2,
    Color? txt3,
    Color? ok,
    Color? warn,
    Color? bad,
    Color? info,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      txt: txt ?? this.txt,
      txt2: txt2 ?? this.txt2,
      txt3: txt3 ?? this.txt3,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      bad: bad ?? this.bad,
      info: info ?? this.info,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      // Brightness cannot be interpolated — snap at the midpoint so anything
      // that branches on it flips cleanly rather than reading a wrong value.
      brightness: t < 0.5 ? brightness : other.brightness,
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      txt: Color.lerp(txt, other.txt, t)!,
      txt2: Color.lerp(txt2, other.txt2, t)!,
      txt3: Color.lerp(txt3, other.txt3, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

/// `context.c.surface` — the one accessor every widget uses to read a
/// theme-aware colour. Falls back to the dark palette if (and only if) no
/// theme is mounted above the caller, which keeps pre-theme/edge renders from
/// throwing a null.
extension BuildContextColors on BuildContext {
  AppPalette get c =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
