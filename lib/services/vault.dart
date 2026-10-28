import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/user_store.dart';

/// Keeps a user's files unreadable while they are not signed in.
///
/// A user's recordings, scripts and takes are plain WAV and text while they
/// are being worked on, in their `work` folder - the player, the waveform
/// reader and ffmpeg all want real files, and nothing in the app has to
/// know any different. The moment they sign out, or the app starts up
/// without them, every one of those files is encrypted into their `vault`
/// folder and the plain copy deleted. Only one of the two copies exists at
/// a time, so the phone holds each file once.
///
/// Turning them back is done a Set at a time, as each Set's screen opens
/// (see [unlockFor]): a sign-in costs nothing, and a Set never opened in a
/// session stays sealed.
///
/// The ciphering itself runs in an isolate of its own. Done on the main
/// isolate it held the screen for as long as it took - a minute of
/// recordings was a minute without a touch answered, and Android called
/// that "not responding" - where the screen now draws its progress and
/// takes its taps while the files are worked through behind it.
///
/// The key never leaves the platform keystore (Android Keystore, the iOS
/// keychain): a copy of the files, or of the whole folder, is random bytes
/// to anything but this app on this phone. The database is kept the same
/// way, by SQLCipher, under a key of its own - see `DatabaseHelper`.
class Vault {
  Vault._();

  static const FlutterSecureStorage _keystore = FlutterSecureStorage();
  static const String _fileKeyName = 'vault_file_key';
  static const String _dbKeyName = 'vault_db_key';

  static const String extension = '.enc';

  /// Files up to this size are turned back on the main isolate when asked
  /// for one at a time - a script and its stamp - rather than starting an
  /// isolate for a few hundred bytes.
  static const int _smallFile = 256 * 1024;

  static Uint8List? _fileKeyBytes;

  /// Told how far a lock or unlock has got: files done, of how many.
  static void Function(int done, int total)? onProgress;

  // ---------------------------------------------------------------- keys

  static Future<String> _keyString(String name) async {
    var value = await _keystore.read(key: name);
    if (value == null || value.isEmpty) {
      final random = Random.secure();
      final bytes = Uint8List.fromList(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      value = base64Url.encode(bytes);
      await _keystore.write(key: name, value: value);
    }
    return value;
  }

  static Future<Uint8List> _keyBytes() async => _fileKeyBytes ??=
      Uint8List.fromList(base64Url.decode(await _keyString(_fileKeyName)));

  /// The passphrase the database is opened with. Made once, kept in the
  /// keystore, and never shown.
  static Future<String> databaseKey() => _keyString(_dbKeyName);

  // ------------------------------------------------------------ the work

  /// Runs [jobs] - plain-to-sealed when [encrypt], sealed-to-plain
  /// otherwise - in an isolate, reporting through [onProgress]. Returns
  /// how many went through.
  static Future<int> _run(List<_FileJob> jobs, {required bool encrypt}) async {
    if (jobs.isEmpty) {
      onProgress?.call(0, 0);
      return 0;
    }
    final key = await _keyBytes();
    final port = ReceivePort();
    final completer = Completer<int>();
    var done = 0;
    onProgress?.call(done, jobs.length);

    port.listen((message) {
      if (message is _JobDone) {
        done++;
        if (message.error != null) {
          debugPrint(
            'VAULT ${encrypt ? 'LOCK' : 'UNLOCK'} FAILED '
            '(${p.basename(message.from)}): ${message.error}',
          );
        }
        onProgress?.call(done, jobs.length);
      } else if (message is int) {
        port.close();
        if (!completer.isCompleted) completer.complete(message);
      } else {
        // An uncaught error in the worker arrives as a list of two
        // strings: the error and its stack.
        port.close();
        if (!completer.isCompleted) {
          completer.completeError(StateError('$message'));
        }
      }
    });

    final isolate = await Isolate.spawn(
      _vaultWorker,
      _VaultWork(key: key, jobs: jobs, encrypt: encrypt, reply: port.sendPort),
      onError: port.sendPort,
      debugName: encrypt ? 'vault-lock' : 'vault-unlock',
    );
    try {
      return await completer.future;
    } finally {
      isolate.kill(priority: Isolate.immediate);
    }
  }

  static Future<List<File>> _filesUnder(Directory dir) async {
    if (!await dir.exists()) return const [];
    final files = <File>[];
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // Half-written by a run that died: thrown away, its source is still
      // whole on the other side.
      if (entity.path.endsWith('.part')) {
        try {
          await entity.delete();
        } catch (_) {}
        continue;
      }
      files.add(entity);
    }
    return files;
  }

  /// Encrypts everything in the signed-in user's work folder into their
  /// vault and deletes the plain copies. Safe to run again: it only ever
  /// has what is left to do.
  static Future<void> lock() async {
    final work = await UserStore.work();
    final vault = await UserStore.vault();
    final jobs = [
      for (final plain in await _filesUnder(work))
        _FileJob(
          from: plain.path,
          to: p.join(
            vault.path,
            '${p.relative(plain.path, from: work.path)}$extension',
          ),
        ),
    ];

    var done = 0;
    try {
      done = await _run(jobs, encrypt: true);
    } catch (e) {
      debugPrint('VAULT LOCK ERROR: $e');
    }

    // The faster copies and the waveform bars, read off those files, are
    // as good as the recordings themselves.
    for (final name in ['sped', 'waves']) {
      try {
        final made = Directory(
          p.join((await getTemporaryDirectory()).path, name),
        );
        if (await made.exists()) await made.delete(recursive: true);
      } catch (e) {
        debugPrint('COPIES NOT CLEARED ($name): $e');
      }
    }
    _unlockedSets.clear();
    debugPrint('VAULT LOCKED: $done files');
  }

  // ------------------------------------------------------- one at a time

  /// Where the sealed copy of the plain file at [plainPath] would be, or
  /// null when the path is not inside the signed-in user's work folder.
  static Future<String?> sealedPathFor(String plainPath) async {
    final work = await UserStore.work();
    final vault = await UserStore.vault();
    if (!p.isWithin(work.path, plainPath)) return null;
    final rel = p.relative(plainPath, from: work.path);
    return p.join(vault.path, '$rel$extension');
  }

  /// Whether the file at [plainPath] is on the phone, sealed.
  static Future<bool> hasSealed(String plainPath) async {
    final sealed = await sealedPathFor(plainPath);
    return sealed != null && await File(sealed).exists();
  }

  /// Makes the file at [plainPath] readable: nothing to do when it is
  /// plain already, a decrypt when it is sealed. False when the phone has
  /// neither.
  static Future<bool> unlockFile(String plainPath) async {
    final plain = File(plainPath);
    if (await plain.exists()) return true;
    final sealed = await sealedPathFor(plainPath);
    if (sealed == null || !await File(sealed).exists()) return false;
    try {
      if (await File(sealed).length() <= _smallFile) {
        await _decryptFile(
          AesGcm.with256bits(),
          SecretKey(await _keyBytes()),
          File(sealed),
          plain,
        );
        return true;
      }
      final done = await _run([
        _FileJob(from: sealed, to: plainPath),
      ], encrypt: false);
      return done == 1;
    } catch (e) {
      debugPrint('VAULT UNLOCK FAILED (${p.basename(plainPath)}): $e');
      return false;
    }
  }

  /// Sets whose files have been turned back this session, so a screen
  /// opened twice does not read every table twice.
  static final Set<String> _unlockedSets = {};
  static final Map<String, Future<int>> _unlocking = {};

  /// Turns back every file a Set's rows name - its source recordings and
  /// scripts, its takes, the voice comments and questions on it, its back
  /// translation - so the Set's screen finds them plain. Done while that
  /// screen is still loading, and once per Set per session. Returns how
  /// many files were decrypted.
  static Future<int> unlockFor(String setId) {
    if (_unlockedSets.contains(setId)) return Future.value(0);
    return _unlocking[setId] ??= _unlockSet(setId).whenComplete(() {
      _unlocking.remove(setId);
    });
  }

  static Future<int> _unlockSet(String setId) async {
    final work = await UserStore.work();
    final helper = DatabaseHelper.instance;

    // The Set's own rows carry its id. Its sub-passages carry only their
    // passage's, so those are found through the passages first.
    final passageIds = <String>{};
    final paths = <String>{};

    void collect(Object? value) {
      if (value is String) {
        if (p.isWithin(work.path, value)) paths.add(value);
      } else if (value is Map) {
        value.values.forEach(collect);
      } else if (value is List) {
        value.forEach(collect);
      }
    }

    for (final table in DatabaseHelper.collectionTables.values) {
      for (final row in await helper.getCollectionRows(table)) {
        final payload = row['payload'];
        if (payload is! Map) continue;
        if ('${payload['obt_set_id'] ?? ''}' != setId) continue;
        collect(payload);
        if (table == 'passages') passageIds.add('${payload['id'] ?? ''}');
      }
    }
    if (passageIds.isNotEmpty) {
      for (final row in await helper.getCollectionRows('sub_passages')) {
        final payload = row['payload'];
        if (payload is! Map) continue;
        if (!passageIds.contains('${payload['obt_passage_id'] ?? ''}')) {
          continue;
        }
        collect(payload);
      }
    }

    final jobs = <_FileJob>[];
    for (final path in paths) {
      // A script's stamp travels with it.
      for (final each in [path, '$path.stamp']) {
        if (await File(each).exists()) continue;
        final sealed = await sealedPathFor(each);
        if (sealed == null || !await File(sealed).exists()) continue;
        jobs.add(_FileJob(from: sealed, to: each));
      }
    }

    var done = 0;
    try {
      done = await _run(jobs, encrypt: false);
    } catch (e) {
      debugPrint('VAULT UNLOCK ERROR: $e');
    }
    _unlockedSets.add(setId);
    debugPrint('VAULT: set $setId ready, $done files turned back');
    return done;
  }

  /// Decrypts everything in the signed-in user's vault back into their
  /// work folder, where the app reads it, and deletes the encrypted
  /// copies.
  static Future<void> unlock() async {
    final work = await UserStore.work();
    final vault = await UserStore.vault();
    final jobs = <_FileJob>[];
    for (final sealed in await _filesUnder(vault)) {
      final rel = p.relative(sealed.path, from: vault.path);
      final plainRel = rel.endsWith(extension)
          ? rel.substring(0, rel.length - extension.length)
          : rel;
      jobs.add(_FileJob(from: sealed.path, to: p.join(work.path, plainRel)));
    }
    var done = 0;
    try {
      done = await _run(jobs, encrypt: false);
    } catch (e) {
      debugPrint('VAULT UNLOCK ERROR: $e');
    }
    debugPrint('VAULT UNLOCKED: $done files');
  }
}

// ------------------------------------------------------------ the format

/// What an encrypted file starts with, so one is never read as a WAV.
final Uint8List _magic = Uint8List.fromList('OBTVAULT1'.codeUnits);

/// Plain bytes per chunk. A chunk at a time keeps a long recording from
/// being held in memory twice over, and lets a crash lose at most one.
const int _chunk = 1 << 20;

Uint8List _nonceFor(Uint8List base, int index) {
  final nonce = Uint8List.fromList(base);
  nonce[8] ^= (index >> 24) & 0xff;
  nonce[9] ^= (index >> 16) & 0xff;
  nonce[10] ^= (index >> 8) & 0xff;
  nonce[11] ^= index & 0xff;
  return nonce;
}

Uint8List _u32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value);

/// Writes [plain] encrypted to [encrypted], then deletes [plain].
Future<void> _encryptFile(
  AesGcm aes,
  SecretKey key,
  File plain,
  File encrypted,
) async {
  final random = Random.secure();
  final base = Uint8List.fromList(
    List<int>.generate(12, (_) => random.nextInt(256)),
  );

  await encrypted.parent.create(recursive: true);
  final part = File('${encrypted.path}.part');
  final sink = part.openWrite();
  try {
    sink.add(_magic);
    sink.add(base);

    final reader = await plain.open();
    try {
      var index = 0;
      while (true) {
        final bytes = await reader.read(_chunk);
        if (bytes.isEmpty) break;
        final box = await aes.encrypt(
          bytes,
          secretKey: key,
          nonce: _nonceFor(base, index),
          aad: _u32(index),
        );
        sink.add(_u32(box.cipherText.length));
        sink.add(box.cipherText);
        sink.add(box.mac.bytes);
        index++;
      }
    } finally {
      await reader.close();
    }
  } finally {
    await sink.close();
  }
  await part.rename(encrypted.path);
  await plain.delete();
}

/// Writes [encrypted] decrypted to [plain], then deletes [encrypted].
Future<void> _decryptFile(
  AesGcm aes,
  SecretKey key,
  File encrypted,
  File plain,
) async {
  await plain.parent.create(recursive: true);
  final part = File('${plain.path}.part');
  final sink = part.openWrite();
  try {
    final reader = await encrypted.open();
    try {
      final head = await reader.read(_magic.length + 12);
      if (head.length < _magic.length + 12 ||
          !listEquals(head.sublist(0, _magic.length), _magic)) {
        throw const FormatException('not a vault file');
      }
      final base = Uint8List.fromList(head.sublist(_magic.length));

      var index = 0;
      while (true) {
        final lengthBytes = await reader.read(4);
        if (lengthBytes.isEmpty) break;
        final length = ByteData.sublistView(lengthBytes).getUint32(0);
        final cipherText = await reader.read(length);
        final mac = await reader.read(16);
        final bytes = await aes.decrypt(
          SecretBox(cipherText, nonce: _nonceFor(base, index), mac: Mac(mac)),
          secretKey: key,
          aad: _u32(index),
        );
        sink.add(bytes);
        index++;
      }
    } finally {
      await reader.close();
    }
  } finally {
    await sink.close();
  }
  await part.rename(plain.path);
  await encrypted.delete();
}

// ----------------------------------------------------------- the isolate

class _FileJob {
  const _FileJob({required this.from, required this.to});

  final String from;
  final String to;
}

class _JobDone {
  const _JobDone(this.from, this.error);

  final String from;
  final String? error;
}

class _VaultWork {
  const _VaultWork({
    required this.key,
    required this.jobs,
    required this.encrypt,
    required this.reply,
  });

  final Uint8List key;
  final List<_FileJob> jobs;
  final bool encrypt;
  final SendPort reply;
}

/// The isolate's whole life: each job in turn, a word back after each,
/// and the count at the end. Pure Dart AES here - the platform's own is
/// only reachable from the main isolate, and would hold that isolate's
/// thread just the same.
Future<void> _vaultWorker(_VaultWork work) async {
  final aes = AesGcm.with256bits();
  final key = SecretKey(work.key);
  var done = 0;
  for (final job in work.jobs) {
    try {
      if (work.encrypt) {
        await _encryptFile(aes, key, File(job.from), File(job.to));
      } else {
        await _decryptFile(aes, key, File(job.from), File(job.to));
      }
      done++;
      work.reply.send(_JobDone(job.from, null));
    } catch (e) {
      work.reply.send(_JobDone(job.from, '$e'));
    }
  }
  work.reply.send(done);
}
