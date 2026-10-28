import 'package:shared_preferences/shared_preferences.dart';

import 'package:livuka/services/session.dart';

/// Remembers which recordings have been played to the end.
///
/// Several buttons wait on a recording having been heard right through. That
/// used to live in the screen's own memory, so leaving the page - to take a
/// call, to check a passage - threw it away and the listener had to sit
/// through the whole Set again. It is kept on the device instead.
///
/// The key carries the Set's `workflow_updated_at`. Every hand-off stamps a
/// new one, so a Set that comes round a second time is a recording nobody
/// has heard yet, without anything having to go back and clear the old
/// marks: they simply stop matching.
class ListenGate {
  ListenGate._();

  static const String _prefix = 'heard|';

  /// What was listened to. One Set can hold several at once - a peer hears
  /// the source and the merged draft, and only both together open the gate.
  static const String source = 'source';
  static const String merged = 'merged';
  static const String backTranslation = 'bt';

  /// The source recording of one passage, for the drafter's first take.
  static String sourceOf(String leafId) => 'source:$leafId';

  /// The drafter's "I have read" on a passage's source and target scripts:
  /// the same one-way, per-round confirmation as a listen, and kept the
  /// same way.
  static String readSource(String leafId) => 'read-source:$leafId';
  static String readTarget(String leafId) => 'read-target:$leafId';

  static String _key({
    required String setId,
    required String round,
    required String what,
  }) => '$_prefix${SessionService.userId ?? ''}|$setId|$round|$what';

  static Future<bool> isHeard({
    required String setId,
    required String round,
    required String what,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(setId: setId, round: round, what: what)) ?? false;
  }

  static Future<void> markHeard({
    required String setId,
    required String round,
    required String what,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(setId: setId, round: round, what: what), true);

    // Marks from earlier rounds of the same recording can never match again.
    // Dropped here, where one is being written anyway, so they do not pile
    // up over the months a phone stays signed in.
    final stale = prefs.getKeys().where((key) {
      if (!key.startsWith(_prefix)) return false;
      final parts = key.split('|');
      return parts.length >= 5 &&
          parts[2] == setId &&
          parts[3] != round &&
          parts.sublist(4).join('|') == what;
    }).toList();
    for (final key in stale) {
      await prefs.remove(key);
    }
  }

  /// Forgets everything, for a sign-out.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }
}
