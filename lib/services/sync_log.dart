import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';
import 'package:livuka/services/downloads_export.dart';

/// A running record of every data-sync attempt: what went up, and what came
/// back.
///
/// Appended to, never rewritten. A sync that went wrong is usually only
/// interesting later - after a take turns up missing on the website - and by
/// then the console output that would have explained it is long gone. The
/// whole history stays on the phone so it can be read after the fact.
///
/// It grows without limit by design. Nothing prunes it, so if it ever needs
/// clearing that is [clear], called deliberately.
class SyncLog {
  SyncLog._();

  /// The working copy, inside the app's own storage.
  static const String fileName = 'data-sync-log.txt';

  /// What the copy in Downloads is called: one file per day.
  ///
  /// Dated rather than a single name, because the working copy goes with the
  /// app when it is uninstalled and a fresh install starts an empty one. A
  /// single name would then be overwritten by that empty log and the history
  /// would be gone. Dated files accumulate instead, and the phone's Downloads
  /// folder is outside the app's storage, so they outlive it.
  static String exportName(DateTime day) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'data-sync-log-${day.year}-${two(day.month)}-${two(day.day)}.txt';
  }

  /// Indented, because the point of keeping this is to read it.
  static const JsonEncoder _pretty = JsonEncoder.withIndent('  ');

  static File? _file;

  /// Forgets the open log: the app has been pointed at another user's
  /// folder, whose log is a different file.
  static void forgetFile() => _file = null;

  static Future<File> _open() async {
    final existing = _file;
    if (existing != null) return existing;

    final directory = await UserStore.root();
    final file = File(p.join(directory.path, fileName));

    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString(
        'OBT data-sync log\n'
        'Every attempt is appended below, oldest first.\n'
        '================================================================\n\n',
        flush: true,
      );
    }

    // Printed once per run so the path is in the console when someone goes
    // looking for the file.
    debugPrint('SYNC LOG: ${file.path}');

    _file = file;
    return file;
  }

  /// Where the log lives on this device, for pulling it off.
  static Future<String> path() async => (await _open()).path;

  /// What this device is about to send.
  static Future<void> request({
    required String userId,
    required String sentAt,
    required Map<String, List<Map<String, dynamic>>> changes,
    required List<String> fileNames,
    required Uri endpoint,
  }) async {
    final rows = changes.values.fold<int>(0, (sum, r) => sum + r.length);

    await _append(
      'REQUEST  ${DateTime.now().toUtc().toIso8601String()}\n'
      'POST $endpoint\n'
      'user_id: $userId\n'
      'sent_at: $sentAt\n'
      'rows: $rows in ${changes.length} table(s)\n'
      'files[]: ${fileNames.isEmpty ? '(none)' : fileNames.join(', ')}\n'
      'changes:\n${_encode(changes)}\n',
    );
  }

  /// What the server answered. [message] is what the app made of it - the
  /// same sentence the user was shown.
  static Future<void> response({
    required int status,
    required String body,
    required String message,
  }) async {
    await _append(
      'RESPONSE ${DateTime.now().toUtc().toIso8601String()}\n'
      'status: $status\n'
      'message: ${message.isEmpty ? '(accepted)' : message}\n'
      'body:\n${body.isEmpty ? '(empty)' : body}\n',
    );
  }

  /// No answer at all - a timeout, a dropped connection, a refused host.
  static Future<void> failure({
    required Object error,
    required String message,
  }) async {
    await _append(
      'NO RESPONSE ${DateTime.now().toUtc().toIso8601String()}\n'
      'message: $message\n'
      'error: $error\n',
    );
  }

  /// Puts a copy where a person can reach it, and where it will still be
  /// after the app is gone.
  ///
  /// The working copy lives in the app's own storage, which Android deletes
  /// with the app - so a record kept only there is lost on the first
  /// uninstall, which is exactly when somebody wants to read it. This copy
  /// goes to the phone's Downloads folder: outside the sandbox, visible to
  /// any file manager, and one dated file per day so a reinstall adds to the
  /// history rather than replacing it.
  ///
  /// The project folder is not an option: this runs on a phone, which has no
  /// route to the development machine's disk.
  static Future<String?> export() async {
    try {
      final file = await _open();
      final saved = await DownloadsExport.save(
        sourcePath: file.path,
        fileName: exportName(DateTime.now()),
      );
      if (saved != null) debugPrint('SYNC LOG COPIED TO: $saved');
      return saved;
    } catch (e) {
      debugPrint('SYNC LOG EXPORT FAILED: $e');
      return null;
    }
  }

  static Future<void> clear() async {
    final file = await _open();
    await file.delete();
    _file = null;
    await _open();
  }

  static Future<void> _append(String entry) async {
    try {
      final file = await _open();
      await file.writeAsString(
        '$entry'
        '----------------------------------------------------------------\n\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      // Logging must never be the thing that breaks a sync.
      debugPrint('SYNC LOG WRITE FAILED: $e');
    }
  }

  static String _encode(Object? value) {
    try {
      return _pretty.convert(value);
    } catch (e) {
      return '(could not encode: $e)';
    }
  }
}
