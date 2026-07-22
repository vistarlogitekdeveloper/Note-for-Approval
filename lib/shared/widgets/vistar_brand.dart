import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The Vistar "S" treatments, in one place.
///
/// The design system places the mark in five specific spots and nowhere else:
/// the splash orbit loader, the route-change overlay, a faint full-page
/// watermark, a card's bottom-right corner, and the sidebar brand glyph. The
/// wordmark is reserved for the splash and login screens.
///
/// Keeping them here stops the mark drifting into arbitrary places, which is
/// what makes a brand look accidental.
class VistarAssets {
  VistarAssets._();

  /// 360px source — loaders and anything rendered large.
  static const mark = 'assets/images/mark.png';

  /// 140px source — small UI spots, so a 24px glyph isn't decoding 360px.
  static const markSmall = 'assets/images/mark_sm.png';

  static const wordmark = 'assets/images/wordmark.png';
}

/// The S mark at [size], picking the cheaper asset when it is small enough.
class VistarMark extends StatelessWidget {
  const VistarMark({super.key, required this.size, this.opacity = 1.0, this.glow});

  final double size;
  final double opacity;

  /// Drop shadow behind the mark. The loaders use a pink glow.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      size <= 70 ? VistarAssets.markSmall : VistarAssets.mark,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (glow != null) {
      image = DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: glow!, blurRadius: size * 0.28)],
        ),
        child: image,
      );
    }

    return opacity >= 1 ? image : Opacity(opacity: opacity, child: image);
  }
}

/// Full-page ambient backdrop: aurora glows, a faint oversized S, and grain.
///
/// This is what keeps the canvas from reading as flat black. It sits behind
/// everything and never intercepts input.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, this.child, this.showWatermark = true});

  final Widget? child;
  final bool showWatermark;

  @override
  Widget build(BuildContext context) {
    final p = context.c;
    // In light mode the aurora glows are pulled right down to a faint pastel
    // wash rather than the neon-on-black bloom — the same pools, a third of the
    // intensity — and the grain flips from white speckle (invisible on white)
    // to a barely-there dark speckle. This is the "clean functional light"
    // treatment: the brand canvas stays recognisable without trying to glow.
    final dim = p.isDark ? 1.0 : 0.32;
    final grainColor = p.isDark ? Colors.white : Colors.black;
    final grainOpacity = p.isDark ? 0.045 : 0.02;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: p.bg)),

        // Three aurora pools, matching the CSS radial-gradient stack.
        _Aurora(
          alignment: const Alignment(-0.76, -1.16),
          size: const Size(800, 600),
          color: AppColors.purple,
          opacity: 0.22 * dim,
        ),
        _Aurora(
          alignment: const Alignment(1.1, -0.84),
          size: const Size(700, 600),
          color: AppColors.pink,
          opacity: 0.16 * dim,
        ),
        _Aurora(
          alignment: const Alignment(0.6, 1.2),
          size: const Size(900, 700),
          color: AppColors.orange,
          opacity: 0.12 * dim,
        ),

        if (showWatermark)
          Positioned(
            right: -MediaQuery.sizeOf(context).shortestSide * 0.12,
            top: 0,
            bottom: 0,
            child: Center(
              child: Transform.rotate(
                angle: 4 * math.pi / 180,
                child: VistarMark(
                  // 62vmax in the CSS.
                  size: MediaQuery.sizeOf(context).shortestSide * 0.62,
                  opacity: p.isDark ? 0.05 : 0.04,
                ),
              ),
            ),
          ),

        Positioned.fill(
          child: IgnorePointer(
            child: _Grain(opacity: grainOpacity, color: grainColor),
          ),
        ),

        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class _Aurora extends StatelessWidget {
  const _Aurora({
    required this.alignment,
    required this.size,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final Size size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [color.withValues(alpha: opacity), Colors.transparent],
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Film grain. The CSS uses an SVG feTurbulence; this paints an equivalent
/// deterministic speckle once into a tile, so it costs nothing to repeat.
class _Grain extends StatelessWidget {
  const _Grain({required this.opacity, this.color = Colors.white});
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _GrainPainter(opacity, color),
      isComplex: true,
      willChange: false);
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.opacity, this.color);
  final double opacity;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Fixed seed: grain that reshuffles on every rebuild reads as flicker.
    final rand = math.Random(42);
    final paint = Paint();
    final count = (size.width * size.height / 900).clamp(0, 12000).toInt();
    for (var i = 0; i < count; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      paint.color = color.withValues(alpha: opacity * rand.nextDouble());
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.opacity != opacity || old.color != color;
}

/// Splash loader: two counter-spinning rings around a breathing S, with the
/// wordmark and a ribbon progress bar beneath.
class SplashOrbitLoader extends StatefulWidget {
  const SplashOrbitLoader({super.key, this.tagline = 'NOTE FOR APPROVAL'});
  final String tagline;

  @override
  State<SplashOrbitLoader> createState() => _SplashOrbitLoaderState();
}

class _SplashOrbitLoaderState extends State<SplashOrbitLoader>
    with TickerProviderStateMixin {
  late final _outer =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();
  late final _inner =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat();
  late final _breathe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
        ..repeat(reverse: true);
  late final _bar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();

  @override
  void dispose() {
    _outer.dispose();
    _inner.dispose();
    _breathe.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring — clockwise.
              RotationTransition(
                turns: _outer,
                child: const _ArcRing(
                  inset: 0,
                  colors: [AppColors.pink, AppColors.orange],
                ),
              ),
              // Inner ring — counter-clockwise, hence the reversed tween.
              RotationTransition(
                turns: Tween<double>(begin: 1, end: 0).animate(_inner),
                child: const _ArcRing(
                  inset: 22,
                  colors: [AppColors.violet, AppColors.amber],
                  startAngle: math.pi,
                ),
              ),
              AnimatedBuilder(
                animation: _breathe,
                builder: (_, child) {
                  final t = Curves.easeInOut.transform(_breathe.value);
                  return Transform.translate(
                    offset: Offset(0, 2 - 4 * t),
                    child: Transform.scale(scale: 0.92 + 0.12 * t, child: child),
                  );
                },
                child: VistarMark(
                  size: 96,
                  glow: AppColors.pink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Image.asset(VistarAssets.wordmark, width: 220, fit: BoxFit.contain),
        const SizedBox(height: 14),
        Text(
          widget.tagline,
          style: TextStyle(
            color: context.c.txt3,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 26),
        // Ribbon progress bar — a 40%-wide segment sweeping across.
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 200,
            height: 4,
            child: ColoredBox(
              color: (context.c.isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.07),
              child: AnimatedBuilder(
                animation: _bar,
                builder: (_, __) {
                  final t = Curves.easeInOut.transform(_bar.value);
                  return Align(
                    // -110% .. 360% of the segment width, as in the CSS.
                    alignment: Alignment(-1.1 + 3.6 * t, 0),
                    child: Container(
                      width: 80,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: AppColors.ribbon,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One ring of the orbit: a circle with only two of its four sides tinted, so
/// rotation is legible.
class _ArcRing extends StatelessWidget {
  const _ArcRing({
    required this.inset,
    required this.colors,
    this.startAngle = 0,
  });

  final double inset;
  final List<Color> colors;
  final double startAngle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(inset),
      child: CustomPaint(
        painter: _ArcRingPainter(colors, startAngle),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArcRingPainter extends CustomPainter {
  _ArcRingPainter(this.colors, this.startAngle);
  final List<Color> colors;
  final double startAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.sweep(
        rect.center,
        [
          colors[0].withValues(alpha: 0.65),
          colors[1].withValues(alpha: 0.42),
          Colors.transparent,
          Colors.transparent,
        ],
        const [0.0, 0.28, 0.5, 1.0],
        TileMode.clamp,
        startAngle,
        startAngle + 2 * math.pi,
      );
    canvas.drawArc(rect.deflate(1), startAngle, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_ArcRingPainter old) =>
      old.colors != colors || old.startAngle != startAngle;
}

/// Breathing S over a blurred scrim — the route-change overlay.
class RouteLoader extends StatefulWidget {
  const RouteLoader({super.key, this.size = 64});
  final double size;

  @override
  State<RouteLoader> createState() => _RouteLoaderState();
}

class _RouteLoaderState extends State<RouteLoader>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 1))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.c.bg.withValues(alpha: 0.55),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final t = Curves.easeInOut.transform(_c.value);
              return Transform.scale(scale: 0.92 + 0.12 * t, child: child);
            },
            child: VistarMark(
              size: widget.size,
              glow: AppColors.pink.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// The faint S tucked into a card's bottom-right corner.
///
/// Drop it into a Stack inside a card that clips its overflow.
class CardCornerMark extends StatelessWidget {
  const CardCornerMark({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: -size * 0.22,
      bottom: -size * 0.25,
      child: IgnorePointer(child: VistarMark(size: size, opacity: 0.05)),
    );
  }
}

/// The sidebar / login brand glyph: the S on a subtly tinted rounded square.
class VistarBrandGlyph extends StatelessWidget {
  const VistarBrandGlyph({super.key, this.size = 38, this.radius = 11});
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.22)),
      ),
      alignment: Alignment.center,
      child: VistarMark(size: size * 0.62),
    );
  }
}
