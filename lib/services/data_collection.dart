import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Trans;
import 'package:http/http.dart' as http;

import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/Audio/media_prefetch.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/account_access.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/session.dart';

/// What a refresh brought down.
class DataRefresh {
  const DataRefresh({required this.ok, this.newFiles = 0, this.message = ''})
    : lockout = null;

  const DataRefresh.failed(String reason)
    : ok = false,
      newFiles = 0,
      message = reason,
      lockout = null;

  /// The server would give nothing because the account is shut out of the
  /// app. The caller signs the user out; see [AccountAccess.lockOut].
  const DataRefresh.lockedOut(AccountLockout this.lockout)
    : ok = false,
      newFiles = 0,
      message = '';

  final bool ok;

  final AccountLockout? lockout;

  /// Recordings and scripts fetched this time. Anything already on the phone
  /// is reused, so this counts what is genuinely new.
  final int newFiles;

  final String message;
}

/// Pulls the server's picture of this user's work and writes it into sqflite.
///
/// The same endpoint and the same save as the load at sign-in, so there is
/// one definition of what "the data" is. It is safe to run repeatedly: the
/// tables are replaced from the snapshot, except for rows this device has
/// changed and not yet sent, which are held back; and a recording already on
/// the phone is kept rather than fetched again, so a refresh costs only what
/// has actually appeared since the last one.
class DataCollection {
  DataCollection._();

  static Uri get endpoint => MainApp.buildmainUri('data-collection');

  /// The server's picture as it stands, without writing any of it down.
  ///
  /// A send asks for this first: it is how a Set that was reassigned or
  /// moved on while the phone was offline gets noticed before this phone's
  /// version of events is sent over the top of it.
  ///
  /// Throws [AccountLockedOut] when the server refuses because the account
  /// is no longer allowed the app - that is not "no data", and the caller
  /// has to act on it.
  static Future<Map<String, dynamic>?> fetch() async {
    final http.Response response;
    try {
      response = await http
          .get(
            endpoint,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer ${SessionService.token}',
            },
          )
          .timeout(const Duration(minutes: 2));
    } catch (e) {
      debugPrint('SNAPSHOT FETCH ERROR: $e');
      return null;
    }

    final lockout = AccountLockout.from(response);
    if (lockout != null) throw AccountLockedOut(lockout);

    try {
      if (response.statusCode < 200 || response.statusCode >= 300) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['status'] == false) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('SNAPSHOT FETCH ERROR: $e');
      return null;
    }
  }

  static Future<DataRefresh> refresh({
    /// Told what is happening as it happens: the request, each table as it
    /// is written, each new file as it comes down.
    void Function(String label)? onProgress,

    /// Asked when files did not arrive: which to try again.
    AskAboutFailed? askAboutFailed,
  }) async {
    try {
      // Translated here: the labels handed on are shown as they are.
      onProgress?.call('Asking the server what is new...'.tr);
      final response = await http
          .get(
            endpoint,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Bearer ${SessionService.token}',
            },
          )
          .timeout(const Duration(minutes: 2));

      final lockout = AccountLockout.from(response);
      if (lockout != null) return DataRefresh.lockedOut(lockout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('REFRESH FAILED: ${response.statusCode}');
        return DataRefresh.failed(
          'The server refused the refresh (@code).'.trParams({
            'code': '${response.statusCode}',
          }),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const DataRefresh.failed('The server sent something unusable.');
      }

      // Counted across the save, which is where the caching happens.
      AudioCacheService.resetDownloadStats();
      // Counted, not named. A file is called what the server filed it
      // under - a string of letters and digits that tells whoever is
      // waiting nothing, and reads as something having gone wrong. The
      // name is in the log for whoever needs it.
      AudioCacheService.onFetched = (fetched, name) => onProgress?.call(
        'Downloading file @count...'.trParams({'count': '$fetched'}),
      );
      DatabaseHelper.onTable = (table, rows) => onProgress?.call(
        'Updating @table (@count)'.trParams({
          'table': DatabaseHelper.tableLabel(table).tr,
          'count': '$rows',
        }),
      );

      final json = Map<String, dynamic>.from(decoded);

      // What is new comes down first, several files at a time.
      await MediaPrefetch.run(json, askAboutFailed: askAboutFailed);

      await DatabaseHelper.instance.insertDataLoad(
        type: 'CollectData',
        userId: int.tryParse(SessionService.userId?.toString() ?? '') ?? 0,
        json: json,
      );

      // A Set that has moved on, or been taken off this user, takes its
      // recordings and scripts with it.
      await MediaPrefetch.prune(json);

      await ActivityLog.record(
        'data_downloaded',
        details: {'files': AudioCacheService.downloadedNow},
      );
      return DataRefresh(ok: true, newFiles: AudioCacheService.downloadedNow);
    } catch (e) {
      debugPrint('REFRESH ERROR: $e');
      return const DataRefresh.failed('Could not reach the server.');
    } finally {
      AudioCacheService.onFetched = null;
      DatabaseHelper.onTable = null;
    }
  }
}
