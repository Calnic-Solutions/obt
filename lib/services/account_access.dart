import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:livuka/login.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/device_wipe.dart';
import 'package:livuka/services/auto_send.dart';
import 'package:livuka/services/sign_out.dart';
import 'package:livuka/services/sync_service.dart';

/// The server has shut this account out of the app.
///
/// The website's `EnsureUserActive` middleware answers every download with
/// a 403 once a user is made inactive (`account_inactive`), or once their
/// "Offline app" access is switched off in Admin > Users
/// (`app_access_removed`). Nothing more comes down for them. What the
/// server still takes is the work already on this phone - the send, and
/// its time and activity logs - so the app hands that in, signs the user
/// out and empties the phone, exactly as the website expects.
class AccountLockout {
  const AccountLockout({required this.code, required this.message});

  static const String inactive = 'account_inactive';
  static const String appAccessRemoved = 'app_access_removed';

  final String code;

  /// The server's own sentence, kept for the log; the user sees the app's
  /// translated one from [notice].
  final String message;

  /// The lockout this response carries, or null when it is anything else.
  static AccountLockout? from(http.Response response) {
    if (response.statusCode != 403) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final code = decoded['code']?.toString() ?? '';
      if (code != inactive && code != appAccessRemoved) return null;
      return AccountLockout(
        code: code,
        message: decoded['message']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String get notice => code == appAccessRemoved
      ? 'The app has been switched off for your account. Your work was '
            'handed in and this phone has been cleared. Contact your '
            'administrator.'
      : 'Your account is no longer active. Your work was handed in and this '
            'phone has been cleared. Contact your administrator.';
}

/// Thrown by a fetch that was refused because of a lockout, so a caller
/// that only wanted the data can tell "no data" from "no account".
class AccountLockedOut implements Exception {
  const AccountLockedOut(this.lockout);

  final AccountLockout lockout;

  @override
  String toString() => 'AccountLockedOut(${lockout.code})';
}

/// Carries out a lockout on this phone.
class AccountAccess {
  AccountAccess._();

  static bool _running = false;

  /// Hands in whatever work is waiting, signs the user out, empties the
  /// phone and leaves them on the sign-in page with the reason.
  ///
  /// The hand-in comes first because the wipe takes the work with it.
  /// The server still accepts the send for a locked-out account, but a
  /// Set it refuses anyway - or a network that drops part way - must not
  /// cost the drafter their recordings, so what did not go is copied to
  /// the phone's Downloads folder before anything is cleared.
  static Future<void> lockOut(AccountLockout lockout) async {
    if (_running) return;
    _running = true;
    IdleLogout.instance.stop();
    AutoSend.instance.stop();

    var exported = 0;
    try {
      debugPrint('ACCOUNT LOCKED OUT: ${lockout.code} - ${lockout.message}');
      await ActivityLog.record(
        'signed_out',
        details: {'reason': lockout.code},
      );

      // Without a snapshot: the server would not give one, and the only
      // conflict it would have caught is one the server itself will now
      // refuse, which is handled below.
      try {
        final result = await SyncService.send();
        if (result.isEmpty) await SyncService.sendLogs();
      } catch (e) {
        debugPrint('LOCKOUT HAND-IN FAILED: $e');
      }

      for (final set in await SyncService.pendingBySet()) {
        exported += await SyncService.exportRecordings(set.setId);
      }
    } catch (e) {
      debugPrint('LOCKOUT ERROR: $e');
    } finally {
      await wipeDevice();
      _running = false;
    }

    Get.offAll(() => const LoginPage());
    // Only once the sign-in page has built: its controller is created in
    // its build, and a dialog opened before would be the route GetX ties
    // that controller to - and closing it would delete the controller from
    // under the page.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        AlertDialog(
          scrollable: true,
          title: Text('Signed out'.tr),
          content: Text(
            [
              lockout.notice.tr,
              if (exported > 0)
                (exported == 1
                        ? '@count recording that could not be sent was saved '
                              'to your Downloads folder.'
                        : '@count recordings that could not be sent were '
                              'saved to your Downloads folder.')
                    .trParams({'count': '$exported'}),
            ].join(' '),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('OK'.tr),
            ),
          ],
        ),
      );
    });
  }
}
