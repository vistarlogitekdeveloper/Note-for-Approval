import 'package:flutter/material.dart';

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

  // ── Dark Surfaces ─────────────────────────────────────────────────────────
  static const bg = Color(0xFF070611);
  static const bg2 = Color(0xFF0B0A18);
  static const surface = Color(0xFF110F1E);
  static const surface2 = Color(0xFF16142A);
  static const surface3 = Color(0xFF1D1A33);

  // ── Lines ─────────────────────────────────────────────────────────────────
  static const line = Color(0x14FFFFFF);   // rgba(255,255,255,0.08)
  static const line2 = Color(0x21FFFFFF);  // rgba(255,255,255,0.13)

  // ── Text ──────────────────────────────────────────────────────────────────
  static const txt = Color(0xFFF2EEFB);
  static const txt2 = Color(0xFFB9B2D6);
  static const txt3 = Color(0xFF7E769B);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const ok = Color(0xFF34D399);
  static const warn = Color(0xFFFBBF24);
  static const bad = Color(0xFFFB6F84);
  static const info = Color(0xFF5BA8FF);

  // ── Gradients ─────────────────────────────────────────────────────────────
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

  static const heroGradient = RadialGradient(
    center: Alignment(-0.6, -0.6),
    radius: 1.2,
    colors: [violet, surface],
    stops: [0.0, 1.0],
  );
}
