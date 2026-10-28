import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/user_store.dart';
import 'package:livuka/services/vault.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  /// The open under way, so that two callers arriving together share it.
  /// Each used to start its own: two connections keyed the same file at
  /// once, and the one-time conversion to an encrypted file ran twice over
  /// itself and never finished.
  static Future<Database>? _opening;

  Future<Database> get database {
    final open = _database;
    if (open != null) return Future.value(open);
    return _opening ??= _initDatabase()
        .then((db) {
          _database = db;
          return db;
        })
        .whenComplete(() => _opening = null);
  }

  /// Lets go of the open database, so the next read opens the signed-in
  /// user's. Called when the app is pointed at another user's folder.
  Future<void> close() async {
    // An open still under way finishes first, so it is not left pointing
    // at a file that is about to belong to someone else.
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {}
    }
    final open = _database;
    _database = null;
    await open?.close();
  }

  static const int _version = 5;

  Future<Database> _initDatabase() async {
    // The signed-in user's own file, in their folder, readable only under
    // the key in this phone's keystore: the scripts are in these rows.
    final path = await UserStore.databasePath();
    final key = await Vault.databaseKey();

    await _encryptIfPlain(path, key);

    return openDatabase(
      path,
      password: key,
      version: _version,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  /// A database written by a build before encryption is plain SQLite, and
  /// SQLCipher would refuse it as corrupt. Found by its header - an
  /// encrypted file starts with random bytes - and copied once into an
  /// encrypted file that takes its place.
  Future<void> _encryptIfPlain(String path, String key) async {
    final file = File(path);
    if (!await file.exists()) return;

    const header = 'SQLite format 3';
    final List<int> head;
    try {
      final reader = await file.open();
      try {
        head = await reader.read(header.length);
      } finally {
        await reader.close();
      }
    } catch (_) {
      return;
    }
    if (String.fromCharCodes(head) != header) return;

    debugPrint('DB: encrypting the plain database');
    final encryptedPath = '$path.enc';
    try {
      await deleteDatabase(encryptedPath);
      final plain = await openDatabase(path);
      final int version;
      try {
        version =
            Sqflite.firstIntValue(await plain.rawQuery('PRAGMA user_version')) ??
            0;
        final quotedPath = encryptedPath.replaceAll("'", "''");
        final quotedKey = key.replaceAll("'", "''");
        await plain.execute(
          "ATTACH DATABASE '$quotedPath' AS encrypted KEY '$quotedKey'",
        );
        await plain.rawQuery("SELECT sqlcipher_export('encrypted')");
        await plain.execute('DETACH DATABASE encrypted');
      } finally {
        await plain.close();
      }

      // The export carries the tables, not the schema version.
      final encrypted = await openDatabase(encryptedPath, password: key);
      try {
        await encrypted.execute('PRAGMA user_version = $version');
      } finally {
        await encrypted.close();
      }

      await deleteDatabase(path);
      await File(encryptedPath).rename(path);
      for (final suffix in const ['-journal', '-wal', '-shm']) {
        final side = File('$path$suffix');
        if (await side.exists()) await side.delete();
      }
    } catch (e) {
      debugPrint('DB: plain database not encrypted: $e');
    }
  }

  /// Maps a key in the data-collection response to the table that stores it.
  /// Every one of these tables has the same `payload`/`createdAt` shape, so
  /// adding a collection means adding one line here and nothing else.
  static const Map<String, String> collectionTables = {
    'SetAssigned': 'set_assignment',
    'allAssignments': 'all_assignments',
    'sets': 'sets',
    'bookData': 'books',
    'bookLinks': 'book_links',
    'Passage': 'passages',
    'subPassage': 'sub_passages',
    'takes': 'takes',
    'finalTakes': 'final_takes',
    'takeCmt': 'take_comments',
    'backTranslation': 'back_translations',
    'workflowSteps': 'workflow_steps',
    'users': 'users',
  };

  /// Told as each table is about to be written, with how many rows.
  static void Function(String table, int rows)? onTable;

  /// What a table is called to a person.
  static String tableLabel(String table) => switch (table) {
    'set_assignment' => 'assignments',
    'all_assignments' => 'assignments',
    'sets' => 'Sets',
    'books' => 'books',
    'book_links' => 'books',
    'passages' => 'passages',
    'sub_passages' => 'sub-passages',
    'takes' => 'takes',
    'final_takes' => 'final takes',
    'take_comments' => 'comments and questions',
    'back_translations' => 'back translations',
    'workflow_steps' => 'workflow',
    'users' => 'users',
    _ => table,
  };

  static String _collectionSchema(String table) =>
      '''
      CREATE TABLE IF NOT EXISTS $table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payload TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''';

  /// Creates any collection table that doesn't exist yet. Both the fresh
  /// install and the upgrade path run this, so a new entry in
  /// [collectionTables] reaches existing devices without another migration.
  Future<void> _createCollectionTables(Database db) async {
    for (final table in collectionTables.values) {
      await db.execute(_collectionSchema(table));
    }
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // v2 added `sets`; v3 added sub_passages, final_takes, back_translations,
    // book_links, workflow_steps, users and all_assignments; v5 the time
    // and activity logs.
    await _createCollectionTables(db);
    await TimeTracker.createTable(db);
    await ActivityLog.createTable(db);
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE data_load_results(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        userId INTEGER NOT NULL,
        responseBody TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await _createCollectionTables(db);
    await TimeTracker.createTable(db);
    await ActivityLog.createTable(db);
  }

  /// Deletes the database outright, so the next user starts from nothing.
  ///
  /// Emptying the tables would leave the file, its schema version and any
  /// half-migrated state behind; deleting it means the next sign-in builds
  /// the database the same way a fresh install does.
  Future<void> wipe() async {
    await close();

    final path = await UserStore.databasePath();
    await deleteDatabase(path);
  }

  Future<int> insertDataLoad({
    required String type,
    required int userId,
    required Map<String, dynamic> json,
  }) async {
    final db = await database;

    // The response is stored as it arrived. It used to be run through the
    // audio cache first, which downloaded every file in it before
    // saveCollectionData had a chance to decide which were needed - so the
    // role filter below never prevented a single download, and the progress
    // bar counted past its own total.
    final record = {
      'type': type,
      'userId': userId,
      'responseBody': jsonEncode(json),
      'createdAt': DateTime.now().toIso8601String(),
    };

    final id = await db.insert(
      'data_load_results',
      record,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await saveCollectionData(db: db, json: json);
    return id;
  }

  Future<void> saveCollectionData({
    required Database db,
    required Map<String, dynamic> json,
  }) async {
    final now = DateTime.now().toIso8601String();

    // Worked out once for the whole load: which recordings this user's role
    // actually gives them to play.
    final needs = AudioNeeds.from(json);

    for (final entry in collectionTables.entries) {
      final key = entry.key;
      final table = entry.value;
      final rawValue = json[key];

      // Each data load is a full snapshot, so replace the table rather than
      // appending — otherwise every login duplicates the previous rows.
      //
      // Two kinds of row are held back and put straight in again. One is the
      // row this device created offline, which the server has never seen:
      // wiping it would throw away a recording the drafter has made. The
      // other is a row that came from the server and has been changed here
      // since - a take finalized, a QC verdict - which the snapshot would
      // otherwise quietly roll back to the server's older copy. Both are
      // exactly the rows a send is waiting to carry.
      List<Map<String, Object?>> heldRows = const [];
      final heldIds = <String>{};
      final heldLeaves = <String>{};

      // What the table held before, by id, with the server's own fields
      // remembered beside the cached row. A row the server sends again
      // unchanged is put back exactly as it was - its audio already
      // resolved to a file on this phone, its script already fetched -
      // without a single file or network call. That is most rows on most
      // refreshes, and it is what made "Check for updates" take minutes
      // when there was nothing to update.
      final previous =
          <
            String,
            ({String payload, String source, Map<String, dynamic> cached})
          >{};

      if (rawValue != null) {
        for (final row in await db.query(table)) {
          final raw = row['payload'] as String? ?? '';
          final id = _payloadId(raw);
          if (id == null) continue;
          try {
            final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
            final source = decoded.remove(AudioCacheService.sourceFlag);
            if (source is String) {
              previous[id] = (payload: raw, source: source, cached: decoded);
            }
          } catch (_) {}
        }

        heldRows = await db.query(
          table,
          where: 'payload LIKE ? OR payload LIKE ? OR payload LIKE ?',
          whereArgs: [
            '%"$localFlag":true%',
            '%"$dirtyFlag":true%',
            '%"$keepLocalFlag":true%',
          ],
        );

        for (final row in heldRows) {
          final id = _payloadId(row['payload']);
          if (id != null) heldIds.add(id);
          // A final take is one per passage, not one per id: the Final
          // chosen here and not yet sent must not be joined by the
          // server's older choice for the same passage, which - stored
          // newer - would be the one every screen read and played.
          final leaf = _leafKey(row['payload']);
          if (table == 'final_takes' && leaf != null) heldLeaves.add(leaf);
        }

        await db.delete(table);
      }

      for (final row in heldRows) {
        await db.insert(table, {
          'payload': row['payload'],
          'createdAt': row['createdAt'],
        });
      }

      // Each row is guarded on its own. The tables are written in map order,
      // so anything thrown here would take every table after this one down
      // with it — losing data the row that failed has nothing to do with.
      if (rawValue is List) {
        onTable?.call(table, rawValue.length);
        for (final item in rawValue) {
          if (item is Map) {
            try {
              final row = Map<String, dynamic>.from(item);
              // Held above because this device has changed it and not sent
              // it yet. Storing the server's copy as well would leave two
              // rows under one id, and whichever was read first would win.
              if (heldIds.contains(row['id']?.toString())) continue;
              if (table == 'final_takes' &&
                  heldLeaves.contains(_leafKey(jsonEncode(row)))) {
                continue;
              }

              // Unchanged since last time: back in as it was - unless a
              // file of its is wanted and never arrived, which is a row
              // still to be finished, not one to be put back.
              final source = jsonEncode(row);
              final known = previous[row['id']?.toString() ?? ''];
              final wanted = needs.wants(table, row);
              if (known != null &&
                  known.source == source &&
                  !(wanted &&
                      AudioCacheService.hasUnfetched(row, known.cached))) {
                await db.insert(table, {
                  'payload': known.payload,
                  'createdAt': now,
                });
                continue;
              }

              // Rows always store; only their audio is conditional, so a
              // take the consultant will never play still shows in a list
              // with its path intact.
              final cachedItem = wanted
                  ? await AudioCacheService.cacheAudioFields(row)
                  : row;
              await db.insert(table, {
                'payload': jsonEncode({
                  ...cachedItem,
                  AudioCacheService.sourceFlag: source,
                }),
                'createdAt': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            } catch (e) {
              debugPrint('COLLECTION ROW SKIPPED ($table): $e');
            }
          }
        }
      } else if (rawValue is Map) {
        try {
          final cachedItem = await AudioCacheService.cacheAudioFields(
            Map<String, dynamic>.from(rawValue),
          );
          await db.insert(table, {
            'payload': jsonEncode(cachedItem),
            'createdAt': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } catch (e) {
          debugPrint('COLLECTION ROW SKIPPED ($table): $e');
        }
      }
    }
  }

  /// The passage a stored `final_takes` payload is for, as `type|id`.
  static String? _leafKey(Object? rawPayload) {
    if (rawPayload is! String) return null;
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return null;
      final type = decoded['leaf_type']?.toString() ?? '';
      final id = decoded['leaf_id']?.toString() ?? '';
      if (type.isEmpty || id.isEmpty) return null;
      return '$type|$id';
    } catch (_) {
      return null;
    }
  }

  /// The `id` inside a stored payload, for matching a held row against the
  /// server's copy of it.
  static String? _payloadId(Object? rawPayload) {
    if (rawPayload is! String) return null;

    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return null;
      return decoded['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCollectionRows(String tableName) async {
    final db = await database;
    final rows = await db.query(tableName, orderBy: 'createdAt DESC');

    return rows.map((row) {
      final raw = row['payload'] as String? ?? '{}';
      return {
        'id': row['id'],
        'payload': jsonDecode(raw),
        'createdAt': row['createdAt'],
      };
    }).toList();
  }

  /// Marks a payload as created on this device and not yet acknowledged by
  /// the server, so a data load preserves it instead of wiping it.
  static const String localFlag = '__local';

  /// Marks a payload this device has changed since the last data load.
  ///
  /// A new take is obvious - it carries [localFlag] and a `local-` id. An
  /// edit to a take that came from the server is not: finalizing one, running
  /// QC on it or throwing it away all leave a row that looks exactly like the
  /// one that came down. This is what tells them apart when the changes are
  /// sent.
  static const String dirtyFlag = '__dirty';

  /// Marks a server row whose copy HERE must outlive a data load, though
  /// there is nothing about it to send. A row this device has withdrawn and
  /// the server has no way to be told about would otherwise be handed back,
  /// whole, by the next snapshot.
  static const String keepLocalFlag = '__keep_local';

  /// Marks a server row this device has withdrawn. Hidden from every read
  /// here; the row itself stays so the change can be sent.
  static const String deletedFlag = '__deleted';

  /// A project setting, from the last data load's `settings` block if the
  /// server sent one. Null when it did not.
  Future<Object?> setting(String key) async {
    final db = await database;
    final rows = await db.query(
      'data_load_results',
      columns: ['responseBody'],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    try {
      final decoded = jsonDecode(rows.first['responseBody'] as String? ?? '');
      if (decoded is! Map) return null;
      for (final block in const ['settings', 'Settings', 'projectSettings']) {
        final settings = decoded[block];
        if (settings is Map && settings.containsKey(key)) return settings[key];
      }
      return decoded[key];
    } catch (_) {
      return null;
    }
  }

  /// Writes a row into a collection table immediately, so the screen shows the
  /// change straight away. It carries [localFlag] and its own `local-` id,
  /// which is what marks it as work this device has done and nowhere else
  /// holds.
  Future<String> insertLocalRow({
    required String table,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';

    await db.insert(table, {
      'payload': jsonEncode({...payload, 'id': localId, localFlag: true}),
      'createdAt': DateTime.now().toIso8601String(),
    });

    return localId;
  }

  /// Replaces the first row in [table] whose payload `id` matches [id].
  Future<void> updateRowById({
    required String table,
    required String id,
    required Map<String, dynamic> Function(Map<String, dynamic>) update,

    /// Whether this is a change the server has to hear about. False for
    /// bookkeeping that only means something on this phone - where a
    /// downloaded file was put - which would otherwise be sent up as though
    /// the user had edited the row.
    bool markDirty = true,
  }) async {
    final db = await database;
    final rows = await db.query(table, orderBy: 'id DESC');

    for (final row in rows) {
      final raw = row['payload'] as String? ?? '{}';
      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }

      if (payload['id']?.toString() != id) continue;

      // Nothing changed, nothing to send. An update that hands the row
      // back as it found it - a take saved on a Set already past its first
      // - used to mark the row changed all the same, and a Set marked
      // changed is sent as a stage move: the phone's idea of the Set's
      // status, written over the server's with nothing to check it
      // against, every time a take was synced.
      final updated = update(Map<String, dynamic>.from(payload));
      if (jsonEncode(updated) == jsonEncode(payload)) return;

      await db.update(
        table,
        {
          'payload': jsonEncode({...updated, if (markDirty) dirtyFlag: true}),
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      return;
    }
  }

  /// Every row of [table] this device wrote or changed.
  Future<List<Map<String, dynamic>>> changedRows(String table) async {
    final rows = await getCollectionRows(table);

    return [
      for (final row in rows)
        if (row['payload'] is Map)
          if (row['payload'][localFlag] == true ||
              row['payload'][dirtyFlag] == true)
            Map<String, dynamic>.from(row['payload'] as Map),
    ];
  }

  /// Clears the change marks on the rows the server has taken.
  ///
  /// Scoped to the ids that were actually in the request. A send takes
  /// minutes with audio attached, and a take finalized while it was in
  /// flight is a change the server has never seen - clearing the whole
  /// table's marks would drop it silently, and no later send would carry it.
  ///
  /// The `local-` ids are left alone: until the next data load hands back
  /// server ids, they are still what this device's own rows point at.
  Future<void> clearChangeFlags(Map<String, Set<String>> sentIdsByTable) async {
    final db = await database;

    for (final entry in sentIdsByTable.entries) {
      final table = entry.key;
      final sentIds = entry.value;
      if (sentIds.isEmpty) continue;

      final rows = await db.query(table);

      for (final row in rows) {
        final raw = row['payload'] as String? ?? '{}';
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map) continue;
          payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          continue;
        }

        if (payload[localFlag] != true && payload[dirtyFlag] != true) continue;
        if (!sentIds.contains(payload['id']?.toString())) continue;

        payload.remove(dirtyFlag);
        payload.remove(localFlag);
        payload.remove(fromStatusFlag);

        await db.update(
          table,
          {'payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// What a Set's stage was believed to be when this device first moved it,
  /// kept on the changed `sets` row so a send can tell whether the server
  /// still agrees before it overwrites the stage with ours.
  static const String fromStatusFlag = '__from_status';

  /// Swaps this device's `local-` ids for the real ones the server has just
  /// issued, everywhere they appear: the row's own id, and every row that
  /// points at it.
  Future<void> adoptServerIds(Map<dynamic, dynamic> idsByTable) async {
    final db = await database;

    String? real(String table, Object? value) {
      final map = idsByTable[table];
      if (map is! Map || value == null) return null;
      return map[value.toString()]?.toString();
    }

    // Which columns point at which table.
    const references = {
      'takes': {'id': 'takes'},
      'final_takes': {'take_id': 'takes'},
      'take_comments': {
        'id': 'take_comments',
        'take_id': 'takes',
        'parent_id': 'take_comments',
      },
      'back_translations': {'id': 'back_translations'},
    };

    for (final entry in references.entries) {
      for (final row in await db.query(entry.key)) {
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(row['payload'] as String? ?? '{}');
          if (decoded is! Map) continue;
          payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          continue;
        }

        var changed = false;
        for (final column in entry.value.entries) {
          final swap = real(column.value, payload[column.key]);
          if (swap == null) continue;
          payload[column.key] = swap;
          changed = true;
        }
        if (!changed) continue;

        await db.update(
          entry.key,
          {'payload': jsonEncode(payload)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  /// Forgets the listed unsent changes: rows made here are removed, rows
  /// from the server merely lose their mark and are put right by the next
  /// data load. Recordings on disk are not touched.
  Future<void> dropChanges(Map<String, Set<String>> idsByTable) async {
    final db = await database;

    for (final entry in idsByTable.entries) {
      for (final row in await db.query(entry.key)) {
        Map<String, dynamic> payload;
        try {
          final decoded = jsonDecode(row['payload'] as String? ?? '{}');
          if (decoded is! Map) continue;
          payload = Map<String, dynamic>.from(decoded);
        } catch (_) {
          continue;
        }
        if (!entry.value.contains(payload['id']?.toString())) continue;

        if (payload[localFlag] == true) {
          await db.delete(entry.key, where: 'id = ?', whereArgs: [row['id']]);
        } else {
          payload.removeWhere((key, _) => key.startsWith('__'));
          await db.update(
            entry.key,
            {'payload': jsonEncode(payload)},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }
  }

  Future<void> deleteRowById({
    required String table,
    required String id,
  }) async {
    final db = await database;
    final rows = await db.query(table);

    for (final row in rows) {
      final raw = row['payload'] as String? ?? '{}';
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['id']?.toString() == id) {
          await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
          return;
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Deletes every row in [table] whose payload has [field] equal to [value].
  /// `final_takes` is addressed by `take_id` rather than its own id, so
  /// [deleteRowById] cannot unfinalize a take.
  Future<void> deleteWhereField({
    required String table,
    required String field,
    required String value,
    String? alsoField,
    String? alsoValue,
  }) async {
    final db = await database;
    final rows = await db.query(table);

    for (final row in rows) {
      final raw = row['payload'] as String? ?? '{}';
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map &&
            decoded[field]?.toString() == value &&
            (alsoField == null ||
                decoded[alsoField]?.toString() == alsoValue)) {
          await db.delete(table, where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (_) {
        continue;
      }
    }
  }
}
