import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/number_formatter.dart';

class LocaleNotifier extends Notifier<Locale> {
  LocaleNotifier({this._initialLocale = const Locale('ar')});

  final Locale _initialLocale;
  static const String prefsLocaleKey = 'app_locale_code';

  @override
  Locale build() {
    NumberFormatter.currentLocaleCode = _initialLocale.languageCode;
    return _initialLocale;
  }

  static Future<Locale> loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(prefsLocaleKey);
      if (code == 'en') {
        NumberFormatter.currentLocaleCode = 'en';
        return const Locale('en');
      }
    } catch (_) {}
    NumberFormatter.currentLocaleCode = 'ar';
    return const Locale('ar');
  }

  Future<void> setLocale(Locale newLocale) async {
    state = newLocale;
    NumberFormatter.currentLocaleCode = newLocale.languageCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsLocaleKey, newLocale.languageCode);
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
