import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/session.dart';

/// How long the person spends on each stage, counted on the phone and
/// sent as running totals - the website's heartbeat, kept offline.
///
/// Time is counted in buckets of one user, stage, day, Set and passage,
/// the shape the website's `page_time_logs` table holds. Every twenty
/// seconds, while a stage screen is open, the app is in front and the
/// screen has been touched in the last two minutes, the open bucket grows
/// by twenty seconds. That is the website's rule: page visible, window
/// focused, the person not idle.
///
/// A bucket is sent as its total under a key this phone made up, and the
/// server keeps the larger figure - so a send that is repeated or cut off
/// can never count the same minute twice. Only buckets that have grown
/// since they were last sent are offered.
class TimeTracker with WidgetsBindingObserver {
  TimeTracker._();

  static final TimeTracker instance = TimeTracker._();

  static const String table = 'time_buckets';

  /// The stages the server accepts (`PageTimeLog::STAGE_LABELS`).
  static const Set<String> stages = {
    'drafter',
    'peer',
    'community_setup',
    'community_test',
    'community_review',
    'back_translation',
    'consultant',
  };

  static const Duration tick = Duration(seconds: 20);

  /// Untouched for this long, the person is taken to have put the phone
  /// down, and nothing more is counted until they pick it up.
  static const Duration idleAfter = Duration(minutes: 2);

  static const int maxAgeDays = 60;
  static const int maxSecondsPerDay = 86400;

  static Uri get endpoint => MainApp.buildmainUri('time-logs');

  Timer? _timer;
  bool _inFront = true;
  DateTime _lastTouch = DateTime.now();

  /// Where the person is, or null between stage screens.
  ({String stage, String setId, String leafType, String leafId})? _here;

  /// Starts counting. Called once, as the app starts.
  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(tick, (_) => _tick());
  }

  /// The screen was touched: the person is here.
  void touched() => _lastTouch = DateTime.now();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inFront = state == AppLifecycleState.resumed;
    if (_inFront) touched();
  }

  /// A stage screen has opened, or moved to another passage. [stage] is
  /// one of [stages]; anything else is not counted.
  void enter({
    required String stage,
    required String setId,
    String leafType = '',
    String leafId = '',
  }) {
    if (!stages.contains(stage)) {
      _here = null;
      return;
    }
    _here = (stage: stage, setId: setId, leafType: leafType, leafId: leafId);
    touched();
  }

  /// The stage screen has closed.
  void leave() => _here = null;

  /// The stage a Set's status is worked at, as the server names it.
  static String stageOf(String workflowStatus) => switch (workflowStatus) {
    'not_started' || 'recorded' || 'redo' => 'drafter',
    _ => workflowStatus,
  };

  Future<void> _tick() async {
    final here = _here;
    if (here == null || !_inFront) return;
    if (DateTime.now().difference(_lastTouch) > idleAfter) return;
    if (!SessionService.isLoggedIn) return;

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final key = keyFor(
        userId: SessionService.userId?.toString() ?? '0',
        stage: here.stage,
        date: date,
        setId: here.setId,
        leafType: here.leafType,
        leafId: here.leafId,
      );

      final rows = await db.query(
        table,
        where: 'client_key = ?',
        whereArgs: [key],
      );
      if (rows.isEmpty) {
        await db.insert(table, {
          'client_key': key,
          'stage_key': here.stage,
          'log_date': date,
          'obt_set_id': int.tryParse(here.setId),
          'leaf_type': here.leafType.isEmpty ? null : here.leafType,
          'leaf_id': int.tryParse(here.leafId),
          'seconds': tick.inSeconds,
          'sent_seconds': 0,
        });
      } else {
        final seconds = (rows.first['seconds'] as int) + tick.inSeconds;
        await db.update(
          table,
          {'seconds': seconds.clamp(0, maxSecondsPerDay)},
          where: 'client_key = ?',
          whereArgs: [key],
        );
      }
    } catch (e) {
      debugPrint('TIME NOT COUNTED: $e');
    }
  }

  /// One key for one bucket, the same every time it is made: the server
  /// files the total under it.
  @visibleForTesting
  static String keyFor({
    required String userId,
    required String stage,
    required String date,
    required String setId,
    required String leafType,
    required String leafId,
  }) {
    final text = '$userId|$stage|$date|$setId|$leafType|$leafId';
    // FNV-1a, 64 bits: short enough for the column, distinct enough for
    // the handful of buckets one person makes in two months.
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(text)) {
      hash = ((hash ^ unit) * 0x100000001b3) & 0xffffffffffffffff;
    }
    return 'p$userId-$date-${hash.toRadixString(16)}';
  }

  /// Sends every bucket that has grown since it was last sent. True when
  /// all of them went. Quiet on failure: they are offered again next time.
  static Future<bool> send() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final cutoff = DateTime.now().subtract(const Duration(days: maxAgeDays));
      final oldest =
          '${cutoff.year.toString().padLeft(4, '0')}-'
          '${cutoff.month.toString().padLeft(2, '0')}-'
          '${cutoff.day.toString().padLeft(2, '0')}';
      await db.delete(table, where: 'log_date < ?', whereArgs: [oldest]);

      final rows = await db.query(
        table,
        where: 'seconds > sent_seconds',
        orderBy: 'log_date ASC',
        limit: 500,
      );
      if (rows.isEmpty) return true;

      final entries = [
        for (final row in rows)
          {
            'client_key': row['client_key'],
            'stage_key': row['stage_key'],
            'log_date': row['log_date'],
            'seconds': row['seconds'],
            if (row['obt_set_id'] != null) 'obt_set_id': row['obt_set_id'],
            if (row['leaf_type'] != null) 'leaf_type': row['leaf_type'],
            if (row['leaf_id'] != null) 'leaf_id': row['leaf_id'],
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
            body: jsonEncode({'entries': entries}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('TIME SEND REFUSED: ${response.statusCode}');
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
      if (refused.isNotEmpty) debugPrint('TIME SKIPPED BY SERVER: $skipped');

      for (final row in rows) {
        final key = row['client_key'] as String;
        if (!accepted.contains(key) && !refused.contains(key)) continue;
        // What was sent is what the server has: anything counted since
        // this read is still ahead of it, and goes next time.
        await db.update(
          table,
          {'sent_seconds': row['seconds']},
          where: 'client_key = ?',
          whereArgs: [key],
        );
      }
      return accepted.length + refused.length == rows.length;
    } catch (e) {
      debugPrint('TIME SEND FAILED: $e');
      return false;
    }
  }

  /// Seconds counted and not yet on the server.
  static Future<int> pendingSeconds() async {
    try {
      final db = await DatabaseHelper.instance.database;
      return Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT SUM(seconds - sent_seconds) FROM $table '
              'WHERE seconds > sent_seconds',
            ),
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> createTable(Database db) => db.execute('''
      CREATE TABLE IF NOT EXISTS $table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_key TEXT NOT NULL UNIQUE,
        stage_key TEXT NOT NULL,
        log_date TEXT NOT NULL,
        obt_set_id INTEGER,
        leaf_type TEXT,
        leaf_id INTEGER,
        seconds INTEGER NOT NULL DEFAULT 0,
        sent_seconds INTEGER NOT NULL DEFAULT 0
      )
    ''');
}
