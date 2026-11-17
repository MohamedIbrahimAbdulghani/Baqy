import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

const String _kThemePreferenceKey = 'app_theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return AppColors.isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void toggleTheme() {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(nextMode);
  }

  void setThemeMode(ThemeMode mode) {
    final bool isDark = (mode == ThemeMode.dark);
    AppColors.isDark = isDark;
    state = mode; // Instantly and synchronously notifies all listeners
    _persistTheme(isDark);
  }

  Future<void> _persistTheme(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemePreferenceKey, isDark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
