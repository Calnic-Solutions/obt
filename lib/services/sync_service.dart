import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show IntExtension, RxInt, Trans;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/downloads_export.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/vault.dart';
import 'package:livuka/services/sync_log.dart';
import 'package:livuka/services/work_queue.dart';
import 'package:livuka/Audio/wav_canonical.dart';

/// What a send attempt came to.
class SyncResult {
  const SyncResult({
    required this.sent,
    required this.rows,
    required this.files,
    this.message = '',
    this.failedSets = 0,
  });

  const SyncResult.nothingToSend()
    : sent = true,
      rows = 0,
      files = 0,
      message = '',
      failedSets = 0;

  /// Whether everything that was waiting went. False when any Set was
  /// refused, even if others got through.
  final bool sent;

  /// How many changed rows and recordings the server accepted.
  final int rows;
  final int files;

  /// Why it failed, when it did.
  final String message;

  /// Sets the server refused. Their work is still on the phone.
  final int failedSets;

  bool get isEmpty => rows == 0 && files == 0 && failedSets == 0;
}

/// Why one Set's work did not go, kept until it does.
class SyncProblem {
  const SyncProblem({
    required this.setId,
    required this.message,
    required this.fatal,
    required this.at,
  });

  final String setId;
  final String message;

  /// Retrying will not help: the Set has been reassigned, closed, or moved
  /// on by somebody else. The work stays on the phone all the same.
  final bool fatal;
  final String at;

  Map<String, dynamic> toJson() => {
    'setId': setId,
    'message': message,
    'fatal': fatal,
    'at': at,
  };

  static SyncProblem fromJson(Map<String, dynamic> json) => SyncProblem(
    setId: json['setId']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    fatal: json['fatal'] == true,
    at: json['at']?.toString() ?? '',
  );
}

/// What is waiting to go for one Set.
class PendingSet {
  PendingSet(this.setId);

  final String setId;
  String name = '';
  int recordings = 0;
  int comments = 0;
  int other = 0;

  /// The stage the Set was handed to, when a hand-off is waiting.
  String? movedTo;

  SyncProblem? problem;

  int get total => recordings + comments + other + (movedTo == null ? 0 : 1);
}

/// Sends what this device has done back to the server.
///
/// Everything a user does lands in sqflite first and is marked as changed;
/// this reads those marks. That makes the database itself the queue: it
/// survives the app being killed, the phone restarting and an upload cut off
/// half way, because nothing is unmarked until the server has said yes to it.
///
/// The work goes ONE SET AT A TIME. Only one person holds a Set, so a Set's
/// changes are a story with one author - record, comment, hand on - and the
/// server applies each batch in that order and all-or-nothing. If it refuses
/// a batch, that Set stops there with its reason kept, nothing of it is
/// skipped or half-applied, and the other Sets still go.
class SyncService {
  SyncService._();

  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// The tables a user can change on this device, in the order the server
  /// has to apply them: a comment or a final take is meaningless until the
  /// take it points at exists.
  static const List<String> writtenTables = [
    'takes',
    'final_takes',
    'take_comments',
    'back_translations',
    'sets',
  ];

  static const String _problemsKey = 'sync_problems';
  static const String _lastSyncKey = 'sync_last_ok';

  static Uri get endpoint => MainApp.buildmainUri('data-sync');

  /// One row as the server's own table holds it.
  ///
  /// Anything beginning `__` is this device's bookkeeping and is not a
  /// column anywhere. And `qc_results` is a JSON column: the web writes it as
  /// encoded text, so a report made here goes the same way rather than as a
  /// nested object the far end has to guess the type of.
  static Map<String, dynamic> _forServer(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row)
      ..removeWhere((key, _) => key.startsWith('__'));

    final report = out['qc_results'];
    if (report is Map || report is List) {
      out['qc_results'] = jsonEncode(report);
    }

    // A recording made here is named to the server by its file name alone.
    // The server matches a row to its upload by basename - and on Linux a
    // Windows path (`C:\Users\...\take-1.wav`) has no separators it
    // recognises, so the whole path was taken for the name, nothing
    // matched, and every Set with a new take was refused as "a new take
    // arrived without its recording". The local path stays in the row on
    // this device; only what goes over the wire is shortened.
    for (final entry in row.entries) {
      final key = entry.key.toLowerCase();
      if (!key.contains('audio') || !key.endsWith('path')) continue;
      final value = entry.value?.toString() ?? '';
      if (value.isEmpty || value.startsWith('http')) continue;
      out[entry.key] = p.basename(value);
    }

    return out;
  }

  // ------------------------------------------------------------ what waits

  /// How much is waiting to go, for the button to say so.
  static Future<int> pendingCount() async {
    var count = 0;
    for (final table in writtenTables) {
      count += (await _db.changedRows(table)).length;
    }
    return count;
  }

  /// Every changed row, filed under the Set it belongs to.
  static Future<Map<String, Map<String, List<Map<String, dynamic>>>>>
  _changesBySet() async {
    // A final take names its take, not its Set.
    final setOfTake = <String, String>{};
    for (final row in await _db.getCollectionRows('takes')) {
      final take = row['payload'];
      if (take is! Map) continue;
      setOfTake[take['id']?.toString() ?? ''] =
          take['obt_set_id']?.toString() ?? '';
    }

    final bySet = <String, Map<String, List<Map<String, dynamic>>>>{};

    for (final table in writtenTables) {
      for (final row in await _db.changedRows(table)) {
        final setId = switch (table) {
          'sets' => row['id']?.toString() ?? '',
          'final_takes' => setOfTake[row['take_id']?.toString() ?? ''] ?? '',
          _ => row['obt_set_id']?.toString() ?? '',
        };

        bySet
            .putIfAbsent(setId, () => {})
            .putIfAbsent(table, () => [])
            .add(row);
      }
    }

    // Oldest first inside each table, so the server meets a question before
    // its answer and an answer before the verdict on it.
    for (final tables in bySet.values) {
      for (final rows in tables.values) {
        rows.sort(
          (a, b) => _localOrder(a['id']).compareTo(_localOrder(b['id'])),
        );
      }
    }

    return bySet;
  }

  /// `local-<microseconds>` sorts by when it was made; a server id sorts
  /// before any of them, having existed first.
  static int _localOrder(Object? id) {
    final text = id?.toString() ?? '';
    if (!text.startsWith('local-')) return 0;
    return int.tryParse(text.substring(6)) ?? 0;
  }

  /// What is waiting, Set by Set, with whatever went wrong last time.
  static Future<List<PendingSet>> pendingBySet() async {
    final names = <String, String>{};
    for (final row in await _db.getCollectionRows('sets')) {
      final set = row['payload'];
      if (set is! Map) continue;
      names[set['id']?.toString() ?? ''] = set['name']?.toString() ?? '';
    }

    final known = {for (final p in await problems()) p.setId: p};
    final result = <PendingSet>[];

    for (final entry in (await _changesBySet()).entries) {
      final pending = PendingSet(entry.key)
        ..name = names[entry.key] ?? ''
        ..problem = known[entry.key];
      for (final table in entry.value.entries) {
        for (final row in table.value) {
          final hasAudio = _localAudio(row) != null;
          switch (table.key) {
            case 'sets':
              pending.movedTo = row['workflow_status']?.toString();
            case 'take_comments':
              pending.comments++;
            case _ when hasAudio:
              pending.recordings++;
            default:
              pending.other++;
          }
        }
      }
      result.add(pending);
    }

    return result;
  }

  /// The recording a row names, when it is one only this phone has.
  static String? _localAudio(Map<String, dynamic> row) {
    for (final entry in row.entries) {
      final key = entry.key.toLowerCase();
      if (!key.contains('audio') || !key.endsWith('path')) continue;

      final value = entry.value?.toString() ?? '';
      if (value.isEmpty || value.startsWith('http')) continue;
      return value;
    }
    return null;
  }

  // -------------------------------------------------------------- problems

  static Future<List<SyncProblem>> problems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_problemsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      return [
        for (final item in jsonDecode(raw) as List)
          if (item is Map)
            SyncProblem.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _setProblem(String setId, SyncProblem? problem) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = [
      for (final existing in await problems())
        if (existing.setId != setId) existing,
      ?problem,
    ];
    await prefs.setString(
      _problemsKey,
      jsonEncode([for (final p in kept) p.toJson()]),
    );
    _changed();
  }

  static Future<String?> lastSyncedAt() async =>
      (await SharedPreferences.getInstance()).getString(_lastSyncKey);

  static Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_problemsKey);
    await prefs.remove(_lastSyncKey);
    // Left by a build that re-sent a Consultant's comments after the
    // server had deleted them; the server keeps them now.
    await prefs.remove('sync_round_checks');
  }

  // ------------------------------------------------------------------ send

  /// Sends the time counted and the events recorded since they last
  /// went. Called after every send and every check for updates, and by
  /// nothing else: the logs go when the person sends, as the work does.
  static Future<void> sendLogs() async {
    if (!SessionService.isLoggedIn) return;
    await TimeTracker.send();
    await ActivityLog.send();
  }

  static bool _running = false;

  /// Bumped whenever what is waiting, or what went wrong, changes: after a
  /// send, a discard, a problem recorded or cleared. A screen that shows
  /// the sync's state watches this rather than reading once as it opens -
  /// a send can finish behind it, from the workbench, a hand-off or the
  /// five-minute try, and it used to go on showing work as still waiting.
  static final RxInt version = 0.obs;

  static void _changed() => version.value++;

  /// Sends every Set's waiting work, one Set at a time.
  ///
  /// [serverSnapshot] is the data-collection response fetched just before,
  /// when the caller has one: it is what lets a Set that was reassigned or
  /// moved on while this phone was offline be caught BEFORE its hand-off is
  /// sent over the top of somebody else's.
  static Future<SyncResult> send({
    Map<String, dynamic>? serverSnapshot,
    void Function(String label)? onProgress,

    /// Only Sets that have been handed on - sent to the next role, sent
    /// back, approved - with everything that belongs to them. A Set still
    /// being worked on stays on the phone: its takes are not the next
    /// person's business until the drafter says the Set is done. The
    /// workbench control sends everything; the automatic sends pass this.
    bool onlyHandedOn = false,
  }) async {
    if (_running) {
      return const SyncResult(
        sent: false,
        rows: 0,
        files: 0,
        message: 'A send is already running.',
      );
    }
    _running = true;

    try {
      var bySet = await _changesBySet();
      if (onlyHandedOn) {
        bySet = {
          for (final entry in bySet.entries)
            if (_handedOn(entry.value)) entry.key: entry.value,
        };
      }
      if (bySet.isEmpty) return const SyncResult.nothingToSend();

      var rows = 0;
      var files = 0;
      var failed = 0;
      var lastMessage = '';
      var index = 0;

      for (final entry in bySet.entries) {
        index++;
        onProgress?.call(
          'Sending Set @index of @total...'.trParams({
            'index': '$index',
            'total': '${bySet.length}',
          }),
        );

        final conflict = _conflict(entry.key, entry.value, serverSnapshot);
        if (conflict != null) {
          await _setProblem(entry.key, conflict);
          failed++;
          lastMessage = conflict.message;
          continue;
        }

        final outcome = await _sendSet(
          entry.key,
          entry.value,
          onProgress: (label) => onProgress?.call(
            'Set @index of @total - @what'.trParams({
              'index': '$index',
              'total': '${bySet.length}',
              'what': label,
            }),
          ),
        );

        if (outcome.unreachable) {
          // No point knocking again for the next Set. Nothing is recorded
          // against this one: being out of signal is not a fault of the work.
          return SyncResult(
            sent: false,
            rows: rows,
            files: files,
            failedSets: failed,
            message: outcome.message,
          );
        }

        if (outcome.ok) {
          rows += outcome.rows;
          files += outcome.files;
          await _setProblem(entry.key, null);
        } else {
          failed++;
          lastMessage = outcome.message;
          await _setProblem(
            entry.key,
            SyncProblem(
              setId: entry.key,
              message: outcome.message,
              fatal: outcome.fatal,
              at: DateTime.now().toIso8601String(),
            ),
          );
        }
      }

      if (failed == 0) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      }

      await ActivityLog.record(
        failed == 0 ? 'sync_sent' : 'sync_failed',
        details: {
          'rows': rows,
          'files': files,
          'failed_sets': failed,
          if (lastMessage.isNotEmpty) 'message': lastMessage,
        },
      );
      // The logs ride behind the work, never ahead of it, and a failure
      // here is not a failure of the send: they wait for the next one.
      await sendLogs();

      return SyncResult(
        sent: failed == 0,
        rows: rows,
        files: files,
        failedSets: failed,
        message: lastMessage,
      );
    } finally {
      _running = false;
      _changed();
    }
  }

  /// Whether a Set's waiting changes include its stage move: the row that
  /// says it was sent on, sent back or approved.
  static bool _handedOn(Map<String, List<Map<String, dynamic>>> changes) =>
      (changes['sets'] ?? const []).isNotEmpty;

  /// Whether any Set that has been handed on is waiting to go.
  static Future<bool> hasHandedOnWork() async {
    for (final changes in (await _changesBySet()).values) {
      if (_handedOn(changes)) return true;
    }
    return false;
  }

  /// Whether the server's picture of [setId] has moved out from under what
  /// this phone is about to send.
  static SyncProblem? _conflict(
    String setId,
    Map<String, List<Map<String, dynamic>>> changes,
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null || setId.isEmpty) return null;

    SyncProblem problem(String message) => SyncProblem(
      setId: setId,
      message: message,
      fatal: true,
      at: DateTime.now().toIso8601String(),
    );

    final sets = snapshot['sets'];
    Map? serverSet;
    if (sets is List) {
      for (final set in sets) {
        if (set is Map && set['id']?.toString() == setId) serverSet = set;
      }
    }
    if (serverSet == null) {
      return problem(
        'This Set is no longer assigned to you. Your work on it is still on '
        'this phone - ask your manager before it is removed.',
      );
    }

    final move = changes['sets']?.firstOrNull;
    if (move == null) return null;

    final believed = move[DatabaseHelper.fromStatusFlag]?.toString() ?? '';
    final serverStatus = serverSet['workflow_status']?.toString() ?? '';
    final mine = move['workflow_status']?.toString() ?? '';

    if (believed.isEmpty || serverStatus == believed || serverStatus == mine) {
      return null;
    }

    // The stage by the name the workbench gives it, where it has one.
    final stage = WorkQueue.labelForStatus(serverStatus);

    return problem(
      'This Set was changed somewhere else while you were offline - it is '
              'now at "@stage". Your hand-off was not sent, and your work is '
              'still on this phone.'
          .trParams({
            'stage': stage.isEmpty
                ? serverStatus.replaceAll('_', ' ')
                : stage.tr,
          }),
    );
  }

  static Future<_Outcome> _sendSet(
    String setId,
    Map<String, List<Map<String, dynamic>>> tables, {
    void Function(String label)? onProgress,
  }) async {
    final changes = {
      for (final entry in tables.entries)
        entry.key: [for (final row in entry.value) _forServer(row)],
    };

    // Recordings made here exist nowhere else, so they travel with the rows
    // that describe them.
    final files = <File>[];
    final missing = <String>[];
    for (final rows in tables.values) {
      for (final row in rows) {
        final path = _localAudio(row);
        if (path == null) continue;
        // Only a row the server has never seen brings its recording. One it
        // already holds is being edited, and its audio is already there.
        if (!(row['id']?.toString() ?? '').startsWith('local-')) continue;

        final file = File(path);
        // Sealed in the vault - a send from the closed app, or of a Set
        // not opened this session - is turned back for the upload.
        if (!await file.exists()) await Vault.unlockFile(path);
        if (await file.exists()) {
          // A take recorded before the header rewrite existed still has
          // its recorder's padding; brought into the plain layout here so
          // it is not refused again.
          await WavCanonical.rewriteInPlace(path);
          files.add(file);
        } else {
          missing.add(p.basename(path));
        }
      }
    }

    // A row whose recording has gone from the disk would be refused by the
    // server for the whole Set anyway. Said here in words a user can act on.
    if (missing.isNotEmpty) {
      return _Outcome.refused(
        'A recording is missing from this phone (@file). Record it again, or '
                'remove that take.'
            .trParams({'file': missing.first}),
      );
    }

    final rowCount = changes.values.fold<int>(0, (sum, r) => sum + r.length);
    final userId = SessionService.userId?.toString() ?? '';
    final sentAt = DateTime.now().toUtc().toIso8601String();

    // Written before the attempt, not after it: a send that never comes back
    // is exactly the one worth having a record of.
    await SyncLog.request(
      userId: userId,
      sentAt: sentAt,
      changes: changes,
      fileNames: [for (final file in files) p.basename(file.path)],
      endpoint: endpoint,
    );

    try {
      final request = http.MultipartRequest('POST', endpoint)
        ..headers['Authorization'] = 'Bearer ${SessionService.token}'
        ..headers['Accept'] = 'application/json'
        ..fields['user_id'] = userId
        ..fields['sent_at'] = sentAt
        ..fields['changes'] = jsonEncode(changes);

      for (final file in files) {
        onProgress?.call(
          'Attaching recording @index of @total'.trParams({
            'index': '${files.indexOf(file) + 1}',
            'total': '${files.length}',
          }),
        );
        request.files.add(
          // Named by file, because that is how the rows refer to them: a row
          // says `audio_path`, and this is the file at that path.
          await http.MultipartFile.fromPath('files[]', file.path),
        );
      }

      onProgress?.call(
        files.isEmpty
            ? 'Sending @count changes...'.trParams({'count': '$rowCount'})
            : 'Uploading @count recordings...'.trParams({
                'count': '${files.length}',
              }),
      );
      final response = await http.Response.fromStream(await request.send())
          .timeout(const Duration(minutes: 15));

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } catch (_) {}

      final accepted =
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body?['status'] != false;

      if (!accepted) {
        // The server's own words. It refuses for reasons a user can act on -
        // a Set reassigned, a recording that is not a WAV - and a bare status
        // code tells them none of that.
        final said = body?['message']?.toString() ?? '';
        final message = said.isNotEmpty
            ? said
            : 'The server refused it (@code).'.trParams({
                'code': '${response.statusCode}',
              });

        debugPrint('SEND FAILED: ${response.statusCode} ${response.body}');
        await SyncLog.response(
          status: response.statusCode,
          body: response.body,
          message: message,
        );
        await SyncLog.export();

        // A sign-in that has lapsed is the phone's problem, not the Set's.
        if (response.statusCode == 401) {
          return const _Outcome.unreachable(
            'Your sign-in has expired. Sign in again to send your work - it '
            'stays on this phone until then.',
          );
        }
        if (response.statusCode >= 500) {
          return _Outcome.unreachable(
            'The server had a problem (@code). Your work stays on this phone '
                    '- try again later.'
                .trParams({'code': '${response.statusCode}'}),
          );
        }

        return _Outcome.refused(message, fatal: body?['fatal'] == true);
      }

      await SyncLog.response(
        status: response.statusCode,
        body: response.body,
        message: '',
      );
      await SyncLog.export();

      // The server's real ids, in place of the names only this phone knew.
      // Without this a take sent once and then edited - finalized, thrown
      // away - would go up a second time under its `local-` id and be stored
      // as a second take.
      final ids = body?['ids'];
      if (ids is Map) await _db.adoptServerIds(ids);

      // Only now, and only the rows that were in this request: a change made
      // while it was in flight has not reached the server, and must keep its
      // mark or the next send would leave it behind for good.
      await _db.clearChangeFlags({
        for (final entry in changes.entries)
          entry.key: {
            for (final row in entry.value)
              if (row['id'] != null) _adopted(ids, entry.key, row['id']),
          },
      });

      return _Outcome.ok(rowCount, files.length);
    } on TimeoutException {
      await SyncLog.failure(error: 'timeout', message: 'Timed out.');
      return const _Outcome.unreachable(
        'The connection was too slow to finish. Your work stays on this '
        'phone - try again where the signal is better.',
      );
    } catch (e) {
      const message = 'Could not reach the server.';
      debugPrint('SEND ERROR: $e');
      await SyncLog.failure(error: e, message: message);
      await SyncLog.export();
      return const _Outcome.unreachable(message);
    }
  }

  static String _adopted(Object? ids, String table, Object? id) {
    final text = id.toString();
    if (ids is Map && ids[table] is Map) {
      final real = (ids[table] as Map)[text];
      if (real != null) return real.toString();
    }
    return text;
  }

  // ----------------------------------------------------- keeping the audio

  /// Copies every unsent recording of [setId] to the phone's Downloads
  /// folder. For a Set the server will no longer take: the work must be
  /// able to leave the app some other way before anybody clears it.
  static Future<int> exportRecordings(String setId) async {
    final tables = (await _changesBySet())[setId] ?? const {};
    var saved = 0;

    for (final rows in tables.values) {
      for (final row in rows) {
        final path = _localAudio(row);
        if (path == null || !await File(path).exists()) continue;

        final out = await DownloadsExport.save(
          sourcePath: path,
          fileName: 'OBT unsent - Set $setId - ${p.basename(path)}',
        );
        if (out != null) saved++;
      }
    }
    return saved;
  }

  /// Gives up on [setId]'s unsent work. Only ever on an explicit yes from
  /// the user, and only offered once the server has said it will never take
  /// it. The recordings themselves are left on disk.
  static Future<void> discard(String setId) async {
    final tables = (await _changesBySet())[setId] ?? const {};
    await _db.dropChanges({
      for (final entry in tables.entries)
        entry.key: {for (final row in entry.value) row['id'].toString()},
    });
    await _setProblem(setId, null);
    _changed();
  }
}

class _Outcome {
  const _Outcome._({
    required this.ok,
    this.rows = 0,
    this.files = 0,
    this.message = '',
    this.fatal = false,
    this.unreachable = false,
  });

  const _Outcome.ok(int rows, int files)
    : this._(ok: true, rows: rows, files: files);

  const _Outcome.refused(String message, {bool fatal = false})
    : this._(ok: false, message: message, fatal: fatal);

  /// Nothing wrong with the Set: the server could not be asked.
  const _Outcome.unreachable(String message)
    : this._(ok: false, message: message, unreachable: true);

  final bool ok;
  final int rows;
  final int files;
  final String message;
  final bool fatal;
  final bool unreachable;
}
