import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which language a Set's name is shown in.
///
/// One choice for the whole app rather than one per screen: a translator
/// scanning a queue in Urdu and then opening a Set titled in English has to
/// re-read the name to be sure it is the one they tapped. The toggle sits in
/// the app bar of every screen that names a Set, and moves all of them at
/// once.
///
/// Remembered on the device, because it is a property of who is reading
/// rather than of what they are reading.
class NameLanguage {
  NameLanguage._();

  static const String _key = 'set_name_source_language';

  static SharedPreferences? _prefs;

  /// True when Set names show in the source language. Listened to by the
  /// toggle and by every app bar that carries one.
  static final ValueNotifier<bool> showSource = ValueNotifier<bool>(false);

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    showSource.value = _prefs?.getBool(_key) ?? false;
  }

  static Future<void> set(bool source) async {
    if (showSource.value == source) return;
    showSource.value = source;

    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_key, source);
    } catch (e) {
      // A preference that will not save is not worth failing a tap over -
      // the toggle still works for this run.
      debugPrint('NAME LANGUAGE SAVE ERROR: $e');
    }
  }

  /// The name to show, given both. Falls back to English whenever there is no
  /// source-language name: a blank title tells the reader nothing at all.
  static String pick({required String english, required String source}) =>
      showSource.value && source.isNotEmpty ? source : english;

  /// [name] fenced off from the sentence around it, for a name that is put
  /// inside one - "Luke · `name` - 0 of 5 recorded".
  ///
  /// An Urdu name is a right-to-left run inside a left-to-right line, and
  /// the digits and dashes beside it have no direction of their own: the
  /// bidi algorithm pulls them into the run, and "0 of 5" came out with
  /// the 0 on the far side of the name, reading as "Luke · 0". The Unicode
  /// isolate marks (FSI ... PDI) make the name a self-contained run, so
  /// the words either side of it keep their own order whatever script it
  /// is in. Invisible, and ignored by anything that only copies the text.
  static String isolated(String name) =>
      name.isEmpty ? name : '\u2068$name\u2069';
}
