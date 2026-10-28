import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the signed-in session, and the sessions of everyone who has
/// signed in on this phone.
///
/// The current user's token, record and roles sit under their own keys, as
/// they always did. Beside them, every account the server has accepted is
/// kept by email, so that a sign-in with no server to ask can be answered
/// from the phone - and so a second person signing in does not cost the
/// first their session, only the turn.
class SessionService {
  SessionService._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _rolesKey = 'auth_roles';
  static const String _loadingKey = 'data_load_in_progress';
  static const String _accountsKey = 'auth_accounts';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static bool get isLoggedIn => (token ?? '').isNotEmpty;

  /// Whether a data load was running the last time this app was alive.
  ///
  /// Set before the download starts and cleared only when it finishes. If it
  /// is still set at start-up, the app was closed part way through - and a
  /// half-loaded device is worse than an empty one: the tables are written
  /// table by table and the recordings arrive one at a time, so what is left
  /// is a Set with some of its passages, or passages with no audio, and
  /// nothing on the screen says which.
  static bool get dataLoadInterrupted => _prefs?.getBool(_loadingKey) ?? false;

  static Future<void> markDataLoadStarted() async {
    await init();
    await _prefs!.setBool(_loadingKey, true);
  }

  static Future<void> markDataLoadFinished() async {
    await init();
    await _prefs!.remove(_loadingKey);
  }

  static String? get token => _prefs?.getString(_tokenKey);

  /// Cleaned as they are read, not only as they are saved: a phone that
  /// loaded its roles under an earlier build holds `[drafter` and `peer]`
  /// - a JSON list split on commas - and shows them so until the next data
  /// load replaces them.
  static List<String> get roles => [
    for (final role in _prefs?.getStringList(_rolesKey) ?? const <String>[])
      if (_clean(role).isNotEmpty) _clean(role),
  ];

  static String _clean(String role) =>
      role.replaceAll(RegExp(r'''[\[\]"' ]'''), '');

  static Map<String, dynamic>? get user {
    final raw = _prefs?.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (e) {
      debugPrint('SESSION USER DECODE ERROR: $e');
      return null;
    }
  }

  /// The id the data-collection endpoint expects, matching the key fallback
  /// used at login time.
  static dynamic get userId {
    final data = user;
    return data?['id'] ?? data?['UserID'];
  }

  /// The email the current user signed in with, lower-cased: the key their
  /// account is kept under.
  static String? get email => _emailOf(user);

  static String? _emailOf(Map<String, dynamic>? data) {
    final raw = data?['email'] ?? data?['Email'] ?? data?['EmailID'];
    final email = raw?.toString().trim().toLowerCase() ?? '';
    return email.isEmpty ? null : email;
  }

  /// Every account that has signed in with the server on this phone, by
  /// lower-cased email.
  static Map<String, Map<String, dynamic>> get accounts {
    final raw = _prefs?.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is Map)
            entry.key.toString(): Map<String, dynamic>.from(entry.value),
      };
    } catch (e) {
      debugPrint('SESSION ACCOUNTS DECODE ERROR: $e');
      return {};
    }
  }

  /// The account kept for [email], or null when nobody by that address has
  /// signed in with the server on this phone.
  static Map<String, dynamic>? accountFor(String email) =>
      accounts[email.trim().toLowerCase()];

  static Future<void> _writeAccounts(
    Map<String, Map<String, dynamic>> all,
  ) async {
    await _prefs!.setString(_accountsKey, jsonEncode(all));
  }

  /// Makes [user] the current session and remembers the account beside the
  /// others, so the next sign-in by this email can be answered offline.
  static Future<void> save({
    required String token,
    Map<String, dynamic>? user,
    List<String> roles = const [],

    /// The address typed at sign-in, for a user record that carries none.
    String? email,
  }) async {
    await init();
    await _prefs!.setString(_tokenKey, token);
    await _prefs!.setStringList(_rolesKey, roles);

    if (user != null) {
      await _prefs!.setString(_userKey, jsonEncode(user));
    } else {
      await _prefs!.remove(_userKey);
    }

    final key = _emailOf(user) ?? email?.trim().toLowerCase();
    if (key != null && key.isNotEmpty) {
      final all = accounts;
      all[key] = {'token': token, 'user': user, 'roles': roles};
      await _writeAccounts(all);
    }
  }

  /// Makes the account kept for [email] the current session. False when
  /// there is none.
  static Future<bool> switchTo(String email) async {
    await init();
    final account = accountFor(email);
    if (account == null) return false;

    final token = account['token']?.toString() ?? '';
    final user = account['user'];
    if (token.isEmpty || user is! Map) return false;

    await _prefs!.setString(_tokenKey, token);
    await _prefs!.setString(_userKey, jsonEncode(user));
    await _prefs!.setStringList(_rolesKey, [
      for (final role in (account['roles'] as List? ?? const []))
        role.toString(),
    ]);
    return true;
  }

  /// Roles arrive with the data-collection response, which runs after login,
  /// so they are stored separately once known.
  static Future<void> saveRoles(List<String> roles) async {
    await init();
    await _prefs!.setStringList(_rolesKey, roles);

    final email = SessionService.email;
    if (email != null) {
      final all = accounts;
      final account = all[email];
      if (account != null) {
        account['roles'] = roles;
        await _writeAccounts(all);
      }
    }
  }

  /// Forgets the current user: their session, and their place among the
  /// accounts this phone can sign in by itself. Everyone else's stays.
  static Future<void> clear() async {
    await init();
    final email = SessionService.email;
    if (email != null) {
      final all = accounts..remove(email);
      await _writeAccounts(all);
    }
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userKey);
    await _prefs!.remove(_rolesKey);
    await _prefs!.remove(_loadingKey);
  }
}
