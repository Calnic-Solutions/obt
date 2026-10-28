import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:livuka/main.dart';
import 'package:livuka/services/session.dart';

/// How the phone fetches the files the web app serves: source audio,
/// scripts and recordings under its `/media/...`.
///
/// Each one is asked for at `/api/media/...` with the API's own bearer
/// token, the one every other request carries. The website's `/media/...`
/// sits behind its session login, and the device used to sign in there the
/// way a browser does; that form now has an "I'm not a robot" check, which
/// no app can pass, so every file came back as the sign-in page.
///
/// The old way stays behind it, for a server without the API route (a 404)
/// or a token it no longer accepts (a 401): the device signs in to the form,
/// with the same credentials used at login, and keeps the cookies.
class MediaSession {
  MediaSession._();

  static String? _email;
  static String? _password;
  static final Map<String, String> _cookies = {};

  static bool get hasCredentials =>
      (_email ?? '').isNotEmpty && (_password ?? '').isNotEmpty;

  /// Whether a file behind the web app can be asked for at all: with the
  /// API token, or failing that with a password to sign in with.
  static bool get canFetch =>
      (SessionService.token ?? '').isNotEmpty || hasCredentials;

  /// The address of the last sign-in kept on this phone, once [restore] has
  /// run: what the sign-in page offers first.
  static String? get email => _email;

  /// Where the sign-in is kept between runs: the platform's own keystore
  /// (Android Keystore, the iOS keychain), encrypted at rest.
  ///
  /// The recordings and scripts are served by the website behind ITS login,
  /// not by the API behind the token - so fetching them needs the password,
  /// and needs it on every "Check for updates", days after sign-in. Held in
  /// memory only, as it was, every refresh after the first found nothing to
  /// sign in with, was handed the login page instead of each file, and kept
  /// whatever it had: a script corrected on the website never reached the
  /// phone. Kept plainly in preferences it would be readable off a rooted
  /// phone, which is why it goes here and nowhere else.
  static const FlutterSecureStorage _vault = FlutterSecureStorage();
  static const String _emailKey = 'media_email';
  static const String _passwordKey = 'media_password';

  /// One password per address, so each person who has signed in on this
  /// phone can sign in again without the server.
  static String _passwordKeyFor(String email) =>
      '$_passwordKey:${email.trim().toLowerCase()}';

  static Future<void> useCredentials({
    required String email,
    required String password,
  }) async {
    _email = email;
    _password = password;
    _cookies.clear();
    try {
      await _vault.write(key: _emailKey, value: email);
      await _vault.write(key: _passwordKey, value: password);
      await _vault.write(key: _passwordKeyFor(email), value: password);
    } catch (e) {
      // Without the keystore the sign-in lasts this run only, as before.
      debugPrint('MEDIA CREDENTIALS NOT KEPT: $e');
    }
  }

  /// Brings the last sign-in back at start-up, so a refresh can fetch files.
  static Future<void> restore() async {
    if (hasCredentials) return;
    try {
      _email = await _vault.read(key: _emailKey);
      _password = await _vault.read(key: _passwordKey);
    } catch (e) {
      debugPrint('MEDIA CREDENTIALS NOT READ: $e');
    }
  }

  /// Whether [email] and [password] are a pair the server has accepted on
  /// this phone. This is the sign-in the phone can do by itself, out of
  /// signal: the server checked these once and the keystore has held them
  /// since. A match makes them the pair the media downloads use.
  static Future<bool> matches({
    required String email,
    required String password,
  }) async {
    String? kept;
    try {
      kept = await _vault.read(key: _passwordKeyFor(email));
    } catch (e) {
      debugPrint('MEDIA CREDENTIALS NOT READ: $e');
    }
    if (kept == null || kept != password) return false;

    _email = email.trim();
    _password = password;
    _cookies.clear();
    return true;
  }

  /// Forgets the current user's password; the others stay.
  static Future<void> clear() async {
    final email = _email;
    _email = null;
    _password = null;
    _cookies.clear();
    try {
      await _vault.delete(key: _emailKey);
      await _vault.delete(key: _passwordKey);
      if (email != null) await _vault.delete(key: _passwordKeyFor(email));
    } catch (e) {
      debugPrint('MEDIA CREDENTIALS NOT CLEARED: $e');
    }
  }

  /// Fetches [url]: a file under the web app's `/media/` through the API
  /// with the token, and otherwise - or when the API turns it away -
  /// as before, signing in first if the server asks for it.
  ///
  /// Anything not behind the web app - S3, the API host - never triggers a
  /// sign-in, because it never answers with the login page.
  static Future<http.Response> get(Uri url) async {
    final api = _apiFor(url);
    final token = SessionService.token ?? '';
    if (api != null && token.isNotEmpty) {
      final response = await _send(
        api,
        headers: {
          'Authorization': 'Bearer $token',
          // Without it Laravel answers a missing or expired token with a
          // redirect to the website's sign-in page - a 200 carrying HTML -
          // rather than the 401 that sends this down the old way.
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 401 && response.statusCode != 404) {
        return response;
      }
      debugPrint(
        'MEDIA API ${response.statusCode} (${api.path}): '
        'trying the website sign-in',
      );
    }

    var response = await _send(url);
    if (!_isSignInPage(response)) return response;

    if (await _signedIn()) {
      response = await _send(url);
    }
    return response;
  }

  /// The sign-in under way, if there is one.
  ///
  /// Files come down several at a time, and the first few all meet the
  /// sign-in page together. Each signing in on its own would have them
  /// taking the session cookie out of one another's hands; they wait on
  /// the one sign-in instead.
  static Future<bool>? _signingIn;

  static Future<bool> _signedIn() =>
      _signingIn ??= _signIn().whenComplete(() => _signingIn = null);

  /// How long a download may go without a byte arriving before it is
  /// given up. Not how long it may take: a long recording on a slow
  /// connection is still arriving, and is left to. It is the one that has
  /// stopped - the signal gone part way through - that would otherwise
  /// hold the data load open for good.
  static const Duration _patience = Duration(seconds: 30);

  /// The API address of a file under the web app's `/media/`, or null for
  /// anything else.
  static Uri? _apiFor(Uri url) {
    final web = MainApp.buildWebUri('');
    if (url.host != web.host || !url.path.startsWith('/media/')) return null;
    return url.replace(scheme: 'https', path: '/api${url.path}');
  }

  static Future<http.Response> _send(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', url);
      if (headers != null) {
        request.headers.addAll(headers);
      } else if (_cookies.isNotEmpty) {
        request.headers.addAll(_header());
      }

      final streamed = await client.send(request).timeout(_patience);
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream.timeout(_patience)) {
        bytes.add(chunk);
      }

      return http.Response.bytes(
        bytes.takeBytes(),
        streamed.statusCode,
        headers: streamed.headers,
        request: streamed.request,
        isRedirect: streamed.isRedirect,
        reasonPhrase: streamed.reasonPhrase,
      );
    } finally {
      client.close();
    }
  }

  /// The web app answers an unauthenticated request with a redirect to the
  /// sign-in page, which the client follows - so what comes back is a 200
  /// carrying HTML where a file was asked for.
  static bool _isSignInPage(http.Response response) {
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    return type.contains('text/html');
  }

  static Map<String, String> _header() => {
    'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
  };

  static Future<bool> _signIn() async {
    if (!hasCredentials) {
      debugPrint('MEDIA SIGN-IN SKIPPED: no credentials for this run');
      return false;
    }

    final client = http.Client();
    try {
      // The form's CSRF token and the session cookie it belongs to have to
      // come from the same request, so the page is fetched before posting.
      final page = await client.get(MainApp.buildWebUri('login'));
      _absorb(page);

      final token =
          RegExp(r'name="csrf-token" content="([^"]+)"')
              .firstMatch(page.body)
              ?.group(1) ??
          RegExp(r'name="_token"[^>]*value="([^"]+)"')
              .firstMatch(page.body)
              ?.group(1);

      if (token == null) {
        debugPrint('MEDIA SIGN-IN FAILED: no CSRF token on the sign-in page');
        return false;
      }

      // Redirects are not followed: a successful sign-in *is* the redirect,
      // and following it would drop the cookies that came with it.
      final request = http.Request('POST', MainApp.buildWebUri('login'))
        ..followRedirects = false
        ..headers.addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          ..._header(),
        })
        ..bodyFields = {
          '_token': token,
          'email': _email!,
          'password': _password!,
        };

      final response = await http.Response.fromStream(
        await client.send(request),
      );
      _absorb(response);

      final location = response.headers['location'] ?? '';
      final signedIn =
          response.statusCode == 302 && !location.contains('/login');

      debugPrint(
        signedIn
            ? 'MEDIA SIGN-IN OK'
            : 'MEDIA SIGN-IN FAILED: ${response.statusCode} -> $location',
      );
      return signedIn;
    } catch (e) {
      debugPrint('MEDIA SIGN-IN ERROR: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Keeps the cookies a response sets.
  ///
  /// `dart:io` folds several Set-Cookie headers into one comma-joined string,
  /// and an Expires date carries its own comma - so the split looks for the
  /// comma that starts a new `name=value` pair rather than every comma.
  static void _absorb(http.Response response) {
    final header = response.headers['set-cookie'];
    if (header == null || header.isEmpty) return;

    for (final cookie in header.split(RegExp(r',(?=\s*[A-Za-z0-9_\-]+=)'))) {
      final pair = cookie.split(';').first.trim();
      final split = pair.indexOf('=');
      if (split <= 0) continue;

      final name = pair.substring(0, split).trim();
      final value = pair.substring(split + 1).trim();
      if (value.isEmpty || value == 'deleted') {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }
}
