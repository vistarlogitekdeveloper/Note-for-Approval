// One-off asset preparation, run with:
//   dart run tool/prepare_logos.dart --inspect
//   dart run tool/prepare_logos.dart --write
//
// The source logos are 1536x1024 RGBA screenshots at ~2.1 MB each, with the
// artwork floating in a dark field. Shipping those verbatim would put 4 MB of
// mostly-empty pixels into the web bundle and render the mark inside a visible
// dark box on every surface it appears on.
//
// This trims the background to transparent, crops to the artwork, and writes
// the sizes the design system actually asks for.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _srcDir = 'assets/images';

class _Spec {
  const _Spec(this.src, this.out, this.width);
  final String src;
  final String out;
  final int width;
}

const _specs = [
  // The S mark: loaders, watermark, card corner, sidebar glyph.
  _Spec('logo.png', 'mark.png', 360),
  _Spec('logo.png', 'mark_sm.png', 140),
  // The wordmark: splash + login only.
  _Spec('logo_name.png', 'wordmark.png', 486),
];

void main(List<String> args) {
  final write = args.contains('--write');

  for (final f in ['logo.png', 'logo_name.png']) {
    final src = img.decodePng(File('$_srcDir/$f').readAsBytesSync());
    if (src == null) {
      stderr.writeln('could not decode $f');
      exitCode = 1;
      return;
    }
    _describe(f, src);
  }

  if (!write) {
    stdout.writeln('\n(inspect only — pass --write to emit processed assets)');
    return;
  }

  for (final spec in _specs) {
    final src = img.decodePng(File('$_srcDir/${spec.src}').readAsBytesSync())!;
    // The supplied files already carry an alpha channel with the backdrop
    // removed. Keying them again would eat the desaturated cream core of the
    // S, so it only runs on a source that is actually still opaque.
    final cleaned = _alreadyKeyed(src) ? src : _keyOutBackground(src);
    final cropped = _autocrop(cleaned);
    final scale = spec.width / cropped.width;
    final resized = img.copyResize(
      cropped,
      width: spec.width,
      height: math.max(1, (cropped.height * scale).round()),
      interpolation: img.Interpolation.cubic,
    );
    final bytes = img.encodePng(resized, level: 9);
    File('$_srcDir/${spec.out}').writeAsBytesSync(bytes);
    stdout.writeln(
      'wrote $_srcDir/${spec.out}  ${resized.width}x${resized.height}  '
      '${(bytes.length / 1024).toStringAsFixed(1)} KB',
    );
  }
}

void _describe(String name, img.Image im) {
  final corners = <String>[];
  for (final p in [
    [0, 0],
    [im.width - 1, 0],
    [0, im.height - 1],
    [im.width - 1, im.height - 1],
  ]) {
    final px = im.getPixel(p[0], p[1]);
    corners.add('(${px.r.toInt()},${px.g.toInt()},${px.b.toInt()},${px.a.toInt()})');
  }

  var transparent = 0;
  var sampled = 0;
  var maxLuma = 0.0;
  for (var y = 0; y < im.height; y += 7) {
    for (var x = 0; x < im.width; x += 7) {
      final px = im.getPixel(x, y);
      sampled++;
      if (px.a < 8) transparent++;
      final luma = 0.2126 * px.r + 0.7152 * px.g + 0.0722 * px.b;
      maxLuma = math.max(maxLuma, luma.toDouble());
    }
  }
  stdout.writeln(
    '$name  ${im.width}x${im.height}\n'
    '  corners RGBA: ${corners.join(' ')}\n'
    '  fully transparent: ${(transparent / sampled * 100).toStringAsFixed(1)}% '
    'of sampled pixels\n'
    '  brightest pixel luma: ${maxLuma.toStringAsFixed(0)}',
  );
}

/// True when the source already has a keyed-out backdrop.
///
/// A screenshot-style source is fully opaque everywhere; a prepared asset has
/// a large transparent margin. Sampling the border is enough to tell them
/// apart without walking every pixel.
bool _alreadyKeyed(img.Image src) {
  var clear = 0, sampled = 0;
  for (var x = 0; x < src.width; x += 5) {
    for (final y in [0, src.height - 1]) {
      sampled++;
      if (src.getPixel(x, y).a < 8) clear++;
    }
  }
  for (var y = 0; y < src.height; y += 5) {
    for (final x in [0, src.width - 1]) {
      sampled++;
      if (src.getPixel(x, y).a < 8) clear++;
    }
  }
  return clear / sampled > 0.9;
}

/// Turns the flat backdrop transparent.
///
/// The backdrop is not pure black — it is a soft grey/violet vignette — so a
/// simple "is it #000" test leaves a halo. Instead alpha is driven by
/// saturation and brightness together: the artwork is vivid and bright, the
/// backdrop is desaturated and dim, and the ramp between them keeps the glow
/// edges soft rather than cutting a hard outline.
img.Image _keyOutBackground(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final px = src.getPixel(x, y);
      final r = px.r.toDouble(), g = px.g.toDouble(), b = px.b.toDouble();
      final mx = math.max(r, math.max(g, b));
      final mn = math.min(r, math.min(g, b));
      final sat = mx <= 0 ? 0.0 : (mx - mn) / mx;

      // Vivid pixels are artwork whatever their brightness; near-grey pixels
      // are backdrop unless they are very bright (the cream core of the S).
      final byColour = ((sat - 0.18) / 0.22).clamp(0.0, 1.0);
      final byLight = ((mx - 110) / 90).clamp(0.0, 1.0);
      final keep = math.max(byColour, byLight);

      out.setPixelRgba(x, y, px.r.toInt(), px.g.toInt(), px.b.toInt(),
          (keep * 255).round());
    }
  }
  return out;
}

/// Crops to the non-transparent bounding box, so the mark fills its box and
/// sizing is predictable wherever it is placed.
img.Image _autocrop(img.Image src, {int threshold = 10}) {
  var top = src.height, left = src.width, right = -1, bottom = -1;
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a >= threshold) {
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        if (x < left) left = x;
        if (x > right) right = x;
      }
    }
  }
  if (right < 0) return src; // nothing found; leave it alone
  return img.copyCrop(src,
      x: left, y: top, width: right - left + 1, height: bottom - top + 1);
}
