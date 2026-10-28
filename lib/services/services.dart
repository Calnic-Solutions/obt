import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';

import 'package:http/http.dart' as http;

import 'package:livuka/main.dart';
import 'package:livuka/services/account_access.dart';
import 'package:livuka/services/session.dart';

/// A short message at the top of the screen.
///
/// The phones' own toast where there is one; otherwise a snackbar -
/// Flutter's own, drawn over whatever screen is showing.
void toaster(String message) {
  // Translated here, once, for the plain sentences. One with a number or
  // a name in it is put together by its caller, which translates it first.
  final text = message.tr;

  if (Platform.isAndroid || Platform.isIOS) {
    Fluttertoast.showToast(
      msg: text,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.TOP,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey.shade300,
      textColor: Colors.black,
      fontSize: 12.0,
    );
    return;
  }

  final messenger = Get.key.currentContext == null
      ? null
      : ScaffoldMessenger.maybeOf(Get.key.currentContext!);
  if (messenger == null) {
    debugPrint('TOAST (no screen yet): $text');
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 13)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        width: 420,
      ),
    );
}

/// Whether the server this app works against can actually be reached.
///
/// Asked of the server, not of the internet at large. This used to look up
/// google.com, which answers a different question: a phone that can reach the
/// server but not the wider internet was refused a sign-in it could have
/// completed, and - worse the other way round - a phone that could reach
/// google while the server was unreachable was waved through to a request
/// that then failed with something less helpful.
///
/// A real HTTP request over the same client the app uses everywhere else, so
/// the answer cannot disagree with what the next call is about to find out.
/// Any reply at all proves the server is there: 401 and 404 are answers, and
/// only a socket that never opens is not.
///
/// Signed in, the probe is the account itself (`auth/me`, with the token):
/// every connection to the server then doubles as the check the website
/// makes on every request - a user made inactive, or whose app access was
/// switched off, is caught the moment the app next reaches the server, not
/// only when a download is tried. On that answer the work is handed in, the
/// user signed out and the phone emptied (see [AccountAccess.lockOut]), and
/// this returns false: there is no longer anyone to connect for. A caller
/// that would say "no connection" should look at [SessionService.isLoggedIn]
/// first.
Future<bool> canReachServer() async {
  final signedIn = SessionService.isLoggedIn;
  final probe = MainApp.buildmainUri(signedIn ? 'auth/me' : '');

  final http.Response response;
  try {
    response = signedIn
        ? await http
              .get(
                probe,
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer ${SessionService.token}',
                },
              )
              .timeout(const Duration(seconds: 8))
        : await http.head(probe).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('SERVER UNREACHABLE ($probe): $e');
    return false;
  }

  final lockout = AccountLockout.from(response);
  if (lockout != null) {
    await AccountAccess.lockOut(lockout);
    return false;
  }
  return true;
}

/// Kept as the older name, which reads better at the call sites that are
/// really asking "can this be done now, or does it wait for a signal?".
Future<bool> hasInternet() => canReachServer();
