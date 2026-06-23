import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class LocalizationService {
  static const _localeKey = 'app_locale';

  static const supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
  ];

  static const fallbackLocale = Locale('tr', 'TR');

  static Future<Locale?> getSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == null) return null;

    return supportedLocales.firstWhere(
      (locale) => locale.toString() == code,
      orElse: () => fallbackLocale,
    );
  }

  static Future<void> changeLocale(BuildContext context, Locale locale) async {
    await context.setLocale(locale);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.toString());
  }
}
