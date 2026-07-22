import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences, loaded once in main() before runApp and injected here.
/// Overridden in the root ProviderScope; reading it without that override is a
/// programming error, so it throws rather than silently returning a default.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// The user's light/dark/system choice, persisted across sessions.
///
/// Defaults to [ThemeMode.system] so first launch follows the OS. Because prefs
/// are loaded synchronously before runApp, the saved value is available at
/// construction — there is no async gap and therefore no flash of the wrong
/// theme on startup.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPreferencesProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _prefs.setString(_key, mode.name);
  }

  /// Convenience for a single toggle control. Resolves the *effective*
  /// brightness first (so toggling from "system" flips to the opposite of what
  /// is currently on screen, which is what a user expects), then picks the
  /// explicit opposite.
  Future<void> toggle(Brightness current) =>
      set(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
}
