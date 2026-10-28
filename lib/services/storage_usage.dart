import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';

/// How much of the phone this app is using, and on what.
///
/// A field phone fills up, and when it does the person holding it needs to
/// know whether it is the app - and which part of the app - before they
/// start deleting photos. Measured on request, never in the background:
/// walking every file is a second or two on a phone with a big Set.
class StorageUsage {
  const StorageUsage({
    required this.recordings,
    required this.takes,
    required this.scripts,
    required this.database,
    required this.other,
  });

  /// Source audio, final takes and other recordings fetched from the server.
  final int recordings;

  /// Takes, answers and comments recorded on this phone.
  final int takes;
  final int scripts;
  final int database;
  final int other;

  int get total => recordings + takes + scripts + database + other;

  static Future<StorageUsage> measure() async {
    // The signed-in user's folder: what their work takes, not the phone's.
    // The files are read from `work` while signed in; the database sits
    // beside it.
    final userRoot = await UserStore.root();
    final documents = await UserStore.work();

    Future<int> sizeOf(Directory dir) async {
      if (!await dir.exists()) return 0;
      var bytes = 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            bytes += await entity.length();
          } catch (_) {}
        }
      }
      return bytes;
    }

    final recordings = await sizeOf(Directory(p.join(documents.path, 'audio')));
    final scripts = await sizeOf(Directory(p.join(documents.path, 'scripts')));
    var takes = 0;
    for (final name in const ['takes', 'back-translations', 'marks']) {
      takes += await sizeOf(Directory(p.join(documents.path, name)));
    }

    // The database file and its journal.
    var database = 0;
    final dbDir = userRoot;
    if (await dbDir.exists()) {
      await for (final entity in dbDir.list()) {
        if (entity is File && p.basename(entity.path).startsWith('obt')) {
          try {
            database += await entity.length();
          } catch (_) {}
        }
      }
    }

    final everything = await sizeOf(userRoot);
    final other = (everything - recordings - scripts - takes - database)
        .clamp(0, 1 << 62)
        .toInt();

    return StorageUsage(
      recordings: recordings,
      takes: takes,
      scripts: scripts,
      database: database,
      other: other,
    );
  }

  /// "1.4 GB", "312 MB", "48 KB".
  static String format(int bytes) {
    if (bytes >= 1 << 30) {
      return '${(bytes / (1 << 30)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1 << 20) {
      return '${(bytes / (1 << 20)).toStringAsFixed(bytes >= 100 << 20 ? 0 : 1)} MB';
    }
    if (bytes >= 1 << 10) return '${(bytes / (1 << 10)).round()} KB';
    return '$bytes B';
  }
}
