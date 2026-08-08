import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'theme_mode';

/// Mod tema app — binary (light/dark), padanan `Switch.adaptive` di
/// Profile page. Default: ikut brightness sistem semasa app pertama
/// dibuka (bukan hardcode light), lepas tu user punya pilihan eksplisit
/// disimpan dan diguna semula setiap kali app dibuka.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_load());
    return _systemBrightnessThemeMode();
  }

  ThemeMode _systemBrightnessThemeMode() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == 'dark') {
      state = ThemeMode.dark;
    } else if (saved == 'light') {
      state = ThemeMode.light;
    }
    // Kalau tiada saved preference, kekal `_systemBrightnessThemeMode()`
    // yang dah di-set masa `build()` — elak "flash" ke default lain
    // sementara SharedPreferences baru dibaca.
  }

  Future<void> setDark(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, isDark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
