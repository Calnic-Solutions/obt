import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/sync_log.dart';

/// Where one user's work lives on this phone.
///
/// Everything downloaded or recorded for a user - the database, the
/// recordings, the scripts, the takes, the sync log - sits in a folder of
/// its own under `users/<id>`, so two people can sign in on one phone and
/// each find only their own work. Signing in points the app at that
/// person's folder; nothing of anyone else's is read, and nothing of
/// theirs is removed.
///
/// Inside it, the files live in `work` while the user is signed in and in
/// `vault`, encrypted, while they are not - see `Vault`.
class UserStore {
  UserStore._();

  static const String _usersFolder = 'users';

  /// The name of the legacy database, from when the phone held one user.
  static const String _legacyDb = 'obt_latest.db';

  /// The plain files, read by the app, while the user is signed in.
  static const String workFolder = 'work';

  /// The same files, encrypted, while they are not.
  static const String vaultFolder = 'vault';

  /// The folders a user's documents are kept in, under [workFolder].
  static const List<String> folders = [
    'audio',
    'scripts',
    'marks',
    'takes',
    'back-translations',
  ];

  static Directory? _root;
  static String? _userId;

  /// Whose session the phone held when this run started: the owner of any
  /// data a build before per-user folders left behind. Read at start-up,
  /// before a sign-in can replace the session with somebody else's.
  static String? _legacyOwner;

  /// Called once at start-up, after the session has been read.
  static void init() {
    final id = SessionService.userId;
    _legacyOwner = id == null ? null : _safe('$id');
  }

  /// Whose folder the app is pointed at, or null before a sign-in.
  static String? get userId => _userId;

  /// Points the app at [userId]'s folder, making it if need be, and lets go
  /// of anything the previous user's stores still had open.
  static Future<void> use(dynamic userId) async {
    final id = _safe('$userId');
    if (id.isEmpty) throw ArgumentError('a user id is needed');
    if (_userId == id && _root != null) return;

    // The previous user's database and folder handles must not be read
    // again under the new user's name.
    await DatabaseHelper.instance.close();
    AudioCacheService.forgetFolders();
    SyncLog.forgetFile();

    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, _usersFolder, id));
    await root.create(recursive: true);

    await _adoptLegacy(documents, root);

    _userId = id;
    _root = root;
    debugPrint('USER STORE: ${root.path}');
  }

  /// The signed-in user's folder.
  ///
  /// Before any sign-in - the first run, or a start-up probe - the folder
  /// of the last session's user is used when one is known, so a log or a
  /// probe has somewhere to write.
  static Future<Directory> root() async {
    final cached = _root;
    if (cached != null) return cached;

    final id = SessionService.userId;
    if (id != null) {
      await use(id);
      return _root!;
    }

    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, _usersFolder, 'nobody'));
    await root.create(recursive: true);
    return root;
  }

  /// The database file for the signed-in user.
  static Future<String> databasePath() async =>
      p.join((await root()).path, _legacyDb);

  /// Where the signed-in user's recordings, scripts and takes are read
  /// from and written to, as plain files.
  static Future<Directory> work() async {
    final dir = Directory(p.join((await root()).path, workFolder));
    await dir.create(recursive: true);
    return dir;
  }

  /// Where those files wait, encrypted, while the user is signed out.
  static Future<Directory> vault() async {
    final dir = Directory(p.join((await root()).path, vaultFolder));
    await dir.create(recursive: true);
    return dir;
  }

  static String _safe(String id) =>
      id.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Moves what a build before per-user folders left at the top of the
  /// documents folder into [root], once, for the user who was signed in
  /// when that build last ran.
  ///
  /// The rows name their files by absolute path, so the paths inside the
  /// moved database are rewritten to the new folder as well; without that
  /// every recording would read as never downloaded.
  static Future<void> _adoptLegacy(Directory documents, Directory root) async {
    final legacyDb = File(p.join(await getDatabasesPath(), _legacyDb));
    if (!await legacyDb.exists()) return;

    // Only the user the legacy data belonged to gets it. Anyone else
    // signing in first leaves it where it is for that user's turn.
    final owner = _legacyOwner;
    if (owner == null || owner != p.basename(root.path)) return;

    debugPrint('USER STORE: adopting legacy data into ${root.path}');
    try {
      final target = File(p.join(root.path, _legacyDb));
      if (!await target.exists()) {
        await legacyDb.rename(target.path);
        for (final suffix in const ['-journal', '-wal', '-shm']) {
          final side = File('${legacyDb.path}$suffix');
          if (await side.exists()) {
            await side.rename('${target.path}$suffix');
          }
        }
      }

      final work = Directory(p.join(root.path, workFolder));
      await work.create(recursive: true);
      for (final name in folders) {
        final from = Directory(p.join(documents.path, name));
        final to = Directory(p.join(work.path, name));
        if (await from.exists() && !await to.exists()) await from.rename(to.path);
      }
      final log = File(p.join(documents.path, SyncLog.fileName));
      final logTo = File(p.join(root.path, SyncLog.fileName));
      if (await log.exists() && !await logTo.exists()) await log.rename(logTo.path);

      final db = await openDatabase(target.path);
      try {
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        );
        for (final row in tables) {
          final table = row['name'].toString();
          final columns = await db.rawQuery('PRAGMA table_info($table)');
          for (final column in columns) {
            if (column['type'].toString().toUpperCase() != 'TEXT') continue;
            final name = column['name'].toString();
            await db.rawUpdate(
              'UPDATE $table SET $name = replace($name, ?, ?) '
              'WHERE $name LIKE ?',
              [documents.path, work.path, '%${documents.path}%'],
            );
          }
        }
      } finally {
        await db.close();
      }
    } catch (e) {
      debugPrint('USER STORE: legacy data not adopted: $e');
    }
  }
}
