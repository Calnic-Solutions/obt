import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language the interface is in: English, Urdu or Hindi.
///
/// Chosen in the app rather than taken from the phone. A field phone is
/// usually set to English whoever is holding it, and the person recording a
/// translation should not need the phone's settings to read the app.
///
/// This is the interface only. What a Set is CALLED is a separate choice
/// (`NameLanguage`), because a drafter may well want Urdu buttons over
/// English Set names, or the other way round.
class AppLocale {
  AppLocale._();

  static const String _key = 'app_locale';

  static const Locale english = Locale('en');
  static const Locale urdu = Locale('ur');
  static const Locale hindi = Locale('hi');

  static const List<Locale> supported = [english, urdu, hindi];

  /// Each language named in itself, so it can be found by somebody who
  /// cannot read the one currently showing.
  static const Map<String, String> names = {
    'en': 'English',
    'ur': 'اردو',
    'hi': 'हिन्दी',
  };

  static Locale _current = english;

  static Locale get current => _current;

  /// Whether the language is written right to left. The LAYOUT does not
  /// mirror for it - see the app's `builder` - so this is only for the few
  /// things that depend on the script itself, such as letter spacing, which
  /// pulls joined Urdu letters apart.
  static bool get isRtl => _current.languageCode == 'ur';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    _current = supported.firstWhere(
      (locale) => locale.languageCode == code,
      orElse: () => english,
    );
  }

  static Future<void> set(Locale locale) async {
    _current = locale;
    await Get.updateLocale(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}
