import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/device_label.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/session.dart';

/// What the person did in the app, kept on the phone and sent with the
/// next send - the website's Admin > Activity log, from a phone.
///
/// Each event carries a key this phone made up, so a send that is retried
/// stores nothing twice: the server acknowledges a key it already holds.
/// Events the server will never take (a Set that was never this user's, a
/// date too far back) come back as skipped, and are dropped here so they
/// are not offered again.
///
/// Recorded where the thing happens - in the repository that saves a take,
/// the hand-off that moves a Set - rather than on the screens, so every
/// route to the same action is logged once.
class ActivityLog {
  ActivityLog._();

  static const String table = 'activity_events';

  /// The events the server accepts (`ActivityLog::EVENT_LABELS`).
  static const Set<String> events = {
    'signed_in',
    'signed_out',
    // The idle sign-out, under the name the dashboard lists it by:
    // "Locked after 15 minutes idle".
    'locked_idle',
    'data_downloaded',
    'sync_sent',
    'sync_failed',
    'take_recorded',
    'take_final',
    'take_deleted',
    'stage_moved',
    'sent_back',
    'comment_added',
    'reply_added',
    'question_added',
    'answer_added',
    'review_verdict',
    'back_translation_saved',
  };

  /// Older than this the server refuses them; they are dropped unsent.
  static const int maxAgeDays = 60;

  static const int batch = 500;

  static Uri get endpoint => MainApp.buildmainUri('activity-logs');

  /// Writes one event. Never throws: a log that could stop the thing it
  /// logs is worse than a gap in the log.
  static Future<void> record(
    String event, {
    String? setId,
    Map<String, dynamic>? details,
  }) async {
    assert(events.contains(event), 'unknown activity event: $event');
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      await db.insert(table, {
        'client_key': _key(now),
        'event': event,
        'occurred_at': now.toUtc().toIso8601String(),
        'obt_set_id': (setId ?? '').isEmpty || setId!.startsWith('local-')
            ? null
            : int.tryParse(setId),
        'details': details == null ? null : jsonEncode(details),
        'sent': 0,
      });
    } catch (e) {
      debugPrint('ACTIVITY NOT RECORDED ($event): $e');
    }
  }

  /// A key nobody else will make: this user, this instant, a counter.
  static int _counter = 0;
  static String _key(DateTime now) =>
      'p${SessionService.userId ?? 0}-${now.microsecondsSinceEpoch}-'
      '${(_counter++) % 1000}';

  /// How many events are waiting to go.
  static Future<int> pendingCount() async {
    try {
      final db = await DatabaseHelper.instance.database;
      return Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $table WHERE sent = 0'),
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// Sends everything waiting, in batches. True when nothing is left
  /// waiting afterwards. Quiet on failure: the events stay for next time.
  static Future<bool> send() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Too old to be accepted: gone, or they would be offered for ever.
      final cutoff = DateTime.now()
          .subtract(const Duration(days: maxAgeDays))
          .toUtc()
          .toIso8601String();
      await db.delete(
        table,
        where: 'sent = 0 AND occurred_at < ?',
        whereArgs: [cutoff],
      );

      while (true) {
        final rows = await db.query(
          table,
          where: 'sent = 0',
          orderBy: 'occurred_at ASC',
          limit: batch,
        );
        if (rows.isEmpty) return true;

        final entries = [
          for (final row in rows)
            {
              'client_key': row['client_key'],
              'event': row['event'],
              'occurred_at': row['occurred_at'],
              if (row['obt_set_id'] != null) 'obt_set_id': row['obt_set_id'],
              if (row['details'] != null)
                'details': jsonDecode(row['details'] as String),
            },
        ];

        final response = await http
            .post(
              endpoint,
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${SessionService.token}',
              },
              body: jsonEncode({
                'app_version': MainApp.appVersion,
                // The same name the sign-in was filed under, so an
                // offline sign-in reported from here lines up with the
                // online ones.
                'device': deviceLabel(appVersion: MainApp.appVersion),
                'entries': entries,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode < 200 || response.statusCode >= 300) {
          debugPrint('ACTIVITY SEND REFUSED: ${response.statusCode}');
          return false;
        }

        final body = jsonDecode(response.body);
        if (body is! Map) return false;
        final accepted = <String>{
          for (final key in (body['accepted'] as List? ?? const []))
            key.toString(),
        };
        final skipped = body['skipped'];
        final refused = <String>{
          if (skipped is Map)
            for (final key in skipped.keys) key.toString(),
        };

        // Sent, or refused for good: neither is offered again.
        final done = [...accepted, ...refused];
        if (done.isEmpty) return false;
        for (final key in done) {
          await db.update(
            table,
            {'sent': 1},
            where: 'client_key = ?',
            whereArgs: [key],
          );
        }
        if (refused.isNotEmpty) {
          debugPrint('ACTIVITY SKIPPED BY SERVER: $skipped');
        }
        // Whatever the server said nothing about stays for next time,
        // and this round stops rather than asking again at once.
        if (rows.length > done.length) return false;
      }
    } catch (e) {
      debugPrint('ACTIVITY SEND FAILED: $e');
      return false;
    }
  }

  /// The table, made or kept.
  static Future<void> createTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS $table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_key TEXT NOT NULL UNIQUE,
        event TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        obt_set_id INTEGER,
        details TEXT,
        sent INTEGER NOT NULL DEFAULT 0
      )
    ''');
}
