import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_approval/core/theme/app_colors.dart';
import 'package:note_approval/core/theme/app_theme.dart';
import 'package:note_approval/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio between two opaque colours (1..21).
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppPalette', () {
    test('light and dark carry the right brightness', () {
      expect(AppPalette.dark.isDark, isTrue);
      expect(AppPalette.light.isDark, isFalse);
      expect(AppPalette.dark.brightness, Brightness.dark);
      expect(AppPalette.light.brightness, Brightness.light);
    });

    test('the two palettes are genuinely different, not one theme twice', () {
      // If the migration had left a surface dark-only, these would be equal.
      expect(AppPalette.light.bg, isNot(AppPalette.dark.bg));
      expect(AppPalette.light.surface, isNot(AppPalette.dark.surface));
      expect(AppPalette.light.txt, isNot(AppPalette.dark.txt));
    });

    test('lerp midpoint is a valid palette that snaps brightness', () {
      final mid = AppPalette.dark.lerp(AppPalette.light, 0.5);
      // At exactly 0.5 brightness snaps to the target (other) palette.
      expect(mid.brightness, Brightness.light);
      // Colours interpolate to something between the two ends.
      expect(mid.bg, isNot(AppPalette.dark.bg));
      expect(mid.bg, isNot(AppPalette.light.bg));
    });

    test('copyWith overrides only what is passed', () {
      final p = AppPalette.dark.copyWith(bg: const Color(0xFF123456));
      expect(p.bg, const Color(0xFF123456));
      expect(p.surface, AppPalette.dark.surface); // untouched
    });
  });

  group('readability (the "no unreadable text" guard)', () {
    // Primary text on the page must clear WCAG AA for normal text (4.5:1) in
    // BOTH themes — this is what a bad light palette would fail.
    for (final entry in {
      'dark': AppPalette.dark,
      'light': AppPalette.light,
    }.entries) {
      test('primary text on bg is AA in ${entry.key}', () {
        expect(_contrast(entry.value.txt, entry.value.bg),
            greaterThanOrEqualTo(4.5));
      });
      test('primary text on surface is AA in ${entry.key}', () {
        expect(_contrast(entry.value.txt, entry.value.surface),
            greaterThanOrEqualTo(4.5));
      });
      test('muted text (txt3) on surface is at least AA-large in ${entry.key}',
          () {
        // Muted labels are small-but-secondary; hold them to 3:1 (AA large).
        expect(_contrast(entry.value.txt3, entry.value.surface),
            greaterThanOrEqualTo(3.0));
      });
      test('semantic colours are legible on surface in ${entry.key}', () {
        for (final c in [
          entry.value.ok,
          entry.value.bad,
          entry.value.warn,
          entry.value.info,
        ]) {
          expect(_contrast(c, entry.value.surface), greaterThanOrEqualTo(3.0));
        }
      });
    }
  });

  group('ThemeData wiring', () {
    testWidgets('both themes register AppPalette and context.c resolves it',
        (tester) async {
      // Apply each ThemeData directly via Theme (not MaterialApp's
      // light/dark/system selection, which is Flutter's job, not ours) so the
      // contract under test is unambiguous: the theme AppTheme builds makes
      // context.c resolve to the matching palette.
      for (final (theme, wantDark) in [
        (AppTheme.dark(), true),
        (AppTheme.light(), false),
      ]) {
        expect(theme.extension<AppPalette>(), isNotNull,
            reason: 'palette not registered on the theme');

        late AppPalette seen;
        late Color scaffoldBg;
        await tester.pumpWidget(MaterialApp(
          home: Theme(
            data: theme,
            child: Builder(builder: (context) {
              seen = context.c;
              scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
              return const SizedBox();
            }),
          ),
        ));
        expect(seen.isDark, wantDark);
        // The ThemeData and the extension must agree on the canvas colour.
        expect(scaffoldBg, seen.bg);
      }
    });

    testWidgets('MaterialApp switches palette with themeMode', (tester) async {
      // The real app path: theme + darkTheme + themeMode, exactly as main.dart
      // wires it. Forcing themeMode proves the switch flips the palette.
      Future<AppPalette> paletteFor(ThemeMode mode) async {
        late AppPalette seen;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: Builder(builder: (context) {
            seen = context.c;
            return const SizedBox();
          }),
        ));
        // MaterialApp animates theme changes via AnimatedTheme (the crossfade
        // our lerp powers); settle it so the palette lands on the target.
        await tester.pumpAndSettle();
        return seen;
      }

      expect((await paletteFor(ThemeMode.light)).isDark, isFalse);
      expect((await paletteFor(ThemeMode.dark)).isDark, isTrue);
    });

    testWidgets('context.c falls back to dark when no theme is mounted',
        (tester) async {
      // Guards the pre-theme/edge render path.
      late AppPalette seen;
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(builder: (context) {
          seen = context.c;
          return const SizedBox();
        }),
      ));
      expect(seen.isDark, isTrue);
    });
  });

  group('ThemeModeController', () {
    test('defaults to system, then toggles and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.system);

      // From an effectively-dark screen, toggle → explicit light.
      await container.read(themeModeProvider.notifier).toggle(Brightness.dark);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(prefs.getString('theme_mode'), 'light');

      // And back.
      await container.read(themeModeProvider.notifier).toggle(Brightness.light);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('reads a persisted choice on construction', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
