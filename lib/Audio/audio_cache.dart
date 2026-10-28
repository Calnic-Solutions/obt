import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart' show Trans;
import 'package:livuka/Audio/audio_converter.dart';
import 'package:livuka/Audio/waveform_cache.dart';
import 'package:http/http.dart' as http;
import 'package:livuka/main.dart';
import 'package:livuka/services/media_session.dart';
import 'package:livuka/services/workflow_stages.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:livuka/services/user_store.dart';
import 'package:livuka/services/vault.dart';

/// Decides which recordings this device actually has to hold.
///
/// A Set carries every take ever recorded for it, but only the drafter works
/// through takes - everyone downstream hears the one that was made final. On
/// a Set with a dozen rejected attempts that is the difference between
/// downloading the whole history and downloading the reading, which matters
/// on a phone that may be on a hotspot for ten minutes a week.
class AudioNeeds {
  AudioNeeds.from(Map<String, dynamic> json)
    : _finalTakeIds = _idsOf(json['finalTakes'], 'take_id'),
      _rolesBySet = _rolesPerSet(json['SetAssigned']),
      _setOfPassage = _passageSets(json['Passage']),
      _actionableSetIds = _actionable(json);

  /// Which Set each passage belongs to. A sub-passage row names its passage
  /// and not its Set, so this is how its Set - and with it, whether anybody
  /// here will play its audio - is found.
  final Map<String, String> _setOfPassage;

  static Map<String, String> _passageSets(Object? rows) => {
    if (rows is List)
      for (final row in rows)
        if (row is Map) _str(row['id']): _str(row['obt_set_id']),
  };

  final Set<String> _finalTakeIds;
  final Map<String, Set<String>> _rolesBySet;

  /// Sets whose current stage belongs to a role this user holds on them.
  ///
  /// An assignment is not the same as a turn. A consultant is named on every
  /// Set in a project from the day it starts, but only hears the handful that
  /// have reached them - the rest are still being drafted, and their audio is
  /// not something this device can show anyone.
  final Set<String> _actionableSetIds;

  /// Roles that read a passage's own recordings - the source to translate
  /// from, and the target recorded against the passage rather than as a
  /// take. The consultant checks the back translation against them too. A
  /// back translator works from the finished reading alone, so for them
  /// this is a download with nothing to play it.
  static const Set<String> _sourceAudioRoles = {
    'drafter',
    'peer',
    'consultant',
  };

  /// Whether this row's audio is worth fetching.
  bool wants(String table, Map<String, dynamic> row) {
    final setId = table == 'sub_passages'
        ? _setOfPassage[_str(row['obt_passage_id'])] ?? ''
        : _str(row['obt_set_id']);
    if (setId.isNotEmpty && !_actionableSetIds.contains(setId)) return false;

    switch (table) {
      case 'takes':
        // The take that became final is what every later stage plays.
        if (_finalTakeIds.contains(_str(row['id']))) return true;
        // The drafter is the only one who compares takes against each other.
        return _rolesFor(_str(row['obt_set_id'])).contains('drafter');

      // A sub-passage carries source material exactly as a passage does,
      // and is wanted by exactly the same people.
      case 'passages':
      case 'sub_passages':
        return _rolesFor(setId).any(_sourceAudioRoles.contains);

      // A back translator or consultant works from the finished reading
      // and the consultant's remarks on the back translation. The
      // community's questions, answers and verdicts, and the peer's
      // comments, are the drafter's and the peer's to hear.
      case 'take_comments':
        final roles = _rolesFor(setId);
        if (roles.contains('drafter') || roles.contains('peer')) return true;
        return const {
          'consultant',
          'back_translation',
        }.contains(_str(row['stage_key']));

      default:
        return true;
    }
  }

  Set<String> _rolesFor(String setId) => _rolesBySet[setId] ?? const {};

  /// How many files the load will actually fetch, so the progress bar counts
  /// towards what happens rather than towards everything that exists.
  int count(Map<String, dynamic> json, Map<String, String> tables) {
    final unique = <String>{};

    for (final entry in tables.entries) {
      final rows = json[entry.key];
      if (rows is! List) continue;

      for (final row in rows) {
        if (row is! Map) continue;
        final map = Map<String, dynamic>.from(row);
        if (!wants(entry.value, map)) continue;
        unique.addAll(AudioCacheService.audioFileNames(map));
      }
    }

    return unique.length;
  }

  static Set<String> _idsOf(Object? rows, String field) {
    if (rows is! List) return {};
    return {
      for (final row in rows)
        if (row is Map) _str(row[field]),
    }..removeWhere((id) => id.isEmpty);
  }

  /// Every role this user holds on each Set. A person can be both drafter
  /// and peer across a project, so the question is never "what is my role"
  /// but "what am I to this Set".
  static Map<String, Set<String>> _rolesPerSet(Object? rows) {
    final result = <String, Set<String>>{};
    if (rows is! List) return result;

    for (final row in rows) {
      if (row is! Map) continue;
      final setId = _str(row['obt_set_id']);
      final role = _str(row['role_key']);
      if (setId.isEmpty || role.isEmpty) continue;
      result.putIfAbsent(setId, () => <String>{}).add(role);
    }

    return result;
  }

  static Set<String> _actionable(Map<String, dynamic> json) {
    final roles = _rolesPerSet(json['SetAssigned']);
    final sets = json['sets'];
    if (sets is! List) return {};

    return {
      for (final row in sets)
        if (row is Map)
          if (kStageRoles[_str(row['workflow_status'])] case final String owner)
            if ((roles[_str(row['id'])] ?? const {}).contains(owner))
              _str(row['id']),
    }..removeWhere((id) => id.isEmpty);
  }

  static String _str(Object? value) => value?.toString().trim() ?? '';
}

class AudioCacheService {
  static int downloadedCount = 0;

  static final Set<String> _downloadedFiles = <String>{};

  /// Fired with the running total each time a new file is cached, so the
  /// loading screen can update while downloads are still in flight.
  static void Function(int downloaded)? onProgress;

  /// Fired as each NEW file is fetched over the network, with its name and
  /// how many have come so far - so a refresh can say what it is doing
  /// while it does it, file by file.
  static void Function(int fetched, String name)? onFetched;

  /// Files actually fetched over the network on this run, as opposed to the
  /// ones already on the phone. A refresh reports this: "nothing new" and
  /// "forty recordings" are different pieces of news.
  static int downloadedNow = 0;

  static void resetDownloadStats() {
    downloadedCount = 0;
    downloadedNow = 0;
    _downloadedFiles.clear();
  }

  /// Why each file that did not arrive did not, by the value its row
  /// holds for it. Said to whoever is waiting, so in their language.
  static final Map<String, String> _failures = {};

  /// Files given up on for this load: asked about, and skipped. The rows
  /// that name them are stored with the server's path, and are not made
  /// to wait on a download that has already been refused.
  static final Set<String> _givenUp = {};

  /// Scripts fetched during this load, by the value their row holds, so
  /// the row is not made to fetch what was fetched a moment ago.
  static final Map<String, String> _scriptsThisLoad = {};

  /// Starts a load with nothing held against any file.
  static void beginLoad() {
    _failures.clear();
    _givenUp.clear();
    _scriptsThisLoad.clear();
  }

  static void giveUpOn(String remoteValue) => _givenUp
    ..add(remoteValue)
    ..add(remoteValue.trim());

  /// Fetches one recording. Null when it is on the phone afterwards;
  /// otherwise why it is not.
  static Future<String?> fetchAudio(String remoteValue) async {
    final name = _fileNameFromValue(remoteValue.trim());
    if (name.isEmpty) return null;

    _givenUp.remove(remoteValue);
    _failures.remove(remoteValue.trim());
    final stored = await _cacheFile(
      remoteValue: remoteValue.trim(),
      originalName: name,
    );
    if (stored != remoteValue.trim()) return null;
    return _failures[remoteValue.trim()] ??
        'The file could not be downloaded.'.tr;
  }

  /// Fetches one script. Null when its text is on the phone afterwards;
  /// otherwise why it is not.
  static Future<String?> fetchScript(String value, String updatedAt) async {
    _givenUp.remove(value);
    _failures.remove(value.trim());
    final text = await _cacheScript(value, updatedAt);
    if (text != value) {
      _scriptsThisLoad[value] = text;
      return null;
    }
    return _failures[value.trim()] ?? 'The file could not be downloaded.'.tr;
  }

  /// Whether the recording a row names is on this phone already.
  static Future<bool> hasAudio(String remoteValue) async {
    final name = _fileNameFromValue(remoteValue.trim());
    if (name.isEmpty) return true;

    final folder = await _folder('audio');
    final wav = File(
      path.join(folder.path, '${path.basenameWithoutExtension(name)}.wav'),
    );
    final original = File(path.join(folder.path, name));
    // Sealed in the vault is on the phone too: it is turned back when its
    // Set's screen opens, and must not be fetched again meanwhile.
    return await wav.exists() ||
        await original.exists() ||
        await Vault.hasSealed(wav.path) ||
        await Vault.hasSealed(original.path);
  }

  /// Whether the script a row names is on this phone already, and is the
  /// version the row speaks of.
  static Future<bool> hasScript(String value, String updatedAt) async {
    final folder = await _folder('scripts');
    final file = File(path.join(folder.path, _fileNameFromValue(value.trim())));
    // Small, and read for its text below: turned back from the vault here
    // rather than counted as missing and fetched again.
    await Vault.unlockFile(file.path);
    await Vault.unlockFile('${file.path}.stamp');
    if (!await file.exists()) return false;
    if (updatedAt.isEmpty) return true;

    try {
      final stamp = File('${file.path}.stamp');
      return await stamp.exists() && await stamp.readAsString() == updatedAt;
    } catch (_) {
      return false;
    }
  }

  /// A file's name, as the server filed it.
  static String fileNameOf(String value) => _fileNameFromValue(value.trim());

  static bool isAudioKey(String key) => _isAudioKey(key);
  static bool isScriptKey(String key) => _isScriptKey(key);

  /// How many files are decoded at once. It is the phone's processor
  /// that does it, so more than a couple only take turns at being slow -
  /// but one at a time held every download up behind it.
  static const int _decodingAtOnce = 2;
  static int _decodingNow = 0;
  static final List<Completer<void>> _waitingToDecode = [];

  static Future<bool> _toWav(String source, String destination) async {
    if (_decodingNow >= _decodingAtOnce) {
      final turn = Completer<void>();
      _waitingToDecode.add(turn);
      await turn.future;
    }
    _decodingNow++;
    try {
      return await AudioConverter.toWav(
        source: source,
        destination: destination,
      );
    } finally {
      _decodingNow--;
      if (_waitingToDecode.isNotEmpty) {
        _waitingToDecode.removeAt(0).complete();
      }
    }
  }

  /// What is said of a file that was not tried, or failed, for want of a
  /// connection.
  static String get noConnection => 'No connection to the server.'.tr;

  static String get _stalled =>
      'The download stopped part way and was given up.'.tr;

  /// Whether [reason] is the connection's fault rather than the file's.
  static bool isConnectionFailure(String? reason) =>
      reason == noConnection || reason == _stalled;

  static String _reasonFor(Object error) {
    if (error is TimeoutException) return _stalled;
    if (error is SocketException || error is http.ClientException) {
      return noConnection;
    }
    if (error is FileSystemException) {
      return 'The file could not be saved on this phone.'.tr;
    }
    return 'The file could not be downloaded.'.tr;
  }

  /// Deletes every downloaded recording and script.
  ///
  /// The files are named after the server's, so one user's cache would be
  /// read straight back as the next user's - a passage they were never
  /// assigned, playing from a phone that should hold nothing of theirs.
  static Future<void> clearCache() async {
    resetDownloadStats();

    // The folders are about to go, so the note that they were made goes
    // with them. Left standing, the next sign-in in the same run skipped
    // making them again and every download failed for want of somewhere
    // to be written: "Cannot open file ... No such file or directory".
    _madeDirs.clear();

    final documents = await _docs();
    for (final name in ['audio', 'scripts', 'marks']) {
      final directory = Directory(path.join(documents.path, name));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }

    // The faster copies of those recordings are theirs too (see SpedCopy),
    // and the bars read off them (see WaveformCache).
    for (final name in ['sped', 'waves']) {
      try {
        final made = Directory(
          path.join((await getTemporaryDirectory()).path, name),
        );
        if (await made.exists()) await made.delete(recursive: true);
      } catch (e) {
        debugPrint('COPIES NOT CLEARED ($name): $e');
      }
    }
  }

  /// The row exactly as the server sent it, kept beside the cached one so
  /// the next data load can tell an unchanged row without redoing its
  /// files. Bookkeeping, like every `__` key: never sent, never shown.
  static const String sourceFlag = '__source';

  /// Whether [cached] - a row as it was stored - still names a file of
  /// [source], the row as the server sent it, that never reached this
  /// phone: a recording or a script whose column holds the server's path
  /// yet, where a fetched one holds a file here or the text itself.
  ///
  /// Such a row is not finished, however unchanged the server's copy is.
  /// Put back as it stood, the download that failed once - no signal, no
  /// folder to write to - would never be tried again.
  static bool hasUnfetched(Map source, Map cached) {
    for (final entry in source.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      final held = cached[key];

      if (value is Map) {
        if (held is! Map || hasUnfetched(value, held)) return true;
      } else if (value is List) {
        if (held is! List || held.length != value.length) return true;
        for (var i = 0; i < value.length; i++) {
          final item = value[i];
          if (item is! Map) continue;
          final heldItem = held[i];
          if (heldItem is! Map || hasUnfetched(item, heldItem)) return true;
        }
      } else if (value is String && held == value) {
        if (_isScriptKey(key)) {
          if (isScriptFile(value)) return true;
        } else if (_isAudioKey(key) && isValidAudioReference(value)) {
          return true;
        }
      }
    }
    return false;
  }

  /// The app's documents folder, looked up once. It never changes while
  /// the app runs, and asking the platform for it again for every field of
  /// every row was most of what a refresh spent its time on.
  static Directory? _documents;

  static Future<Directory> _docs() async =>
      _documents ??= await UserStore.work();

  /// Folders already made this run, so `create` is not asked again.
  static final Set<String> _madeDirs = {};

  /// Forgets which folder the files live in and which have been made: the
  /// app has been pointed at another user's folder.
  static void forgetFolders() {
    _documents = null;
    _madeDirs.clear();
  }

  /// The downloaded files this user no longer has any use for - every
  /// recording and script in the cache that no wanted row names - are
  /// deleted. A Set that has moved on to somebody else, or been taken off
  /// this user, otherwise leaves its recordings on the phone for as long
  /// as the sign-in lasts. Returns how many were removed.
  static Future<int> pruneTo({
    required Set<String> audioNames,
    required Set<String> scriptNames,
  }) async {
    var removed = 0;

    Future<void> sweep(String folder, Set<String> keep) async {
      // The plain files and the sealed ones alike: a Set that has moved on
      // is let go of wherever its recordings are.
      final sealedDir = Directory(
        path.join((await UserStore.vault()).path, folder),
      );
      for (final dir in [await _folder(folder), sealedDir]) {
        if (!await dir.exists()) continue;
        await for (final entry in dir.list()) {
          if (entry is! File) continue;
          var name = path.basename(entry.path);
          if (name.endsWith(Vault.extension)) {
            name = name.substring(0, name.length - Vault.extension.length);
          }
          // A script's stamp goes with its script.
          final bare = name.endsWith('.stamp')
              ? name.substring(0, name.length - 6)
              : name;
          if (keep.contains(bare)) continue;
          try {
            await entry.delete();
            removed++;
          } catch (e) {
            debugPrint('CACHE NOT PRUNED ($name): $e');
          }
        }
      }
    }

    // A recording is kept under its own name or, decoded, under the
    // same name as a WAV.
    await sweep('audio', {
      for (final name in audioNames) ...[
        name,
        '${path.basenameWithoutExtension(name)}.wav',
      ],
    });
    await sweep('scripts', scriptNames);

    if (removed > 0) debugPrint('CACHE PRUNED: $removed files');
    return removed;
  }

  static Future<Directory> _folder(String name) async {
    final dir = Directory(path.join((await _docs()).path, name));
    if (_madeDirs.add(dir.path)) await dir.create(recursive: true);
    return dir;
  }

  static Future<Map<String, dynamic>> cacheAudioFields(
    Map<String, dynamic> source,
  ) async {
    final result = <String, dynamic>{};

    for (final entry in source.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is Map) {
        result[key] = await cacheAudioFields(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = await _cacheList(value);
      } else if (_isScriptKey(key) && value is String) {
        // Whether this column held a script *file* is worth keeping, because
        // once the text is fetched the value looks like any other text. Some
        // rows carry a one-line description typed straight into the column
        // instead - that is a label for the passage, not the passage, and
        // nothing should put it on screen as though it were.
        final fromFile = isScriptFile(value);
        result[scriptFileFlag(key)] = fromFile;
        result[key] = fromFile
            ? await _cacheScript(
                value,
                source['${key}_updated_at']?.toString() ?? '',
              )
            : value;
        debugPrint(
          fromFile
              ? 'SCRIPT FROM FILE ($key): $value'
              : 'SCRIPT IS PLAIN TEXT, NOT SHOWN ($key)',
        );
      } else if (_isAudioKey(key) && value is String) {
        final remoteValue = value.trim();
        if (remoteValue.isNotEmpty) {
          final originalName = _fileNameFromValue(remoteValue);
          if (originalName.isNotEmpty) {
            result[key] = await _cacheFile(
              remoteValue: remoteValue,
              originalName: originalName,
            );
            continue;
          }
        }
        result[key] = value;
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  static Future<List<dynamic>> _cacheList(List<dynamic> values) async {
    final result = <dynamic>[];
    for (final value in values) {
      if (value is Map) {
        result.add(await cacheAudioFields(Map<String, dynamic>.from(value)));
      } else if (value is List) {
        result.add(await _cacheList(value));
      } else {
        result.add(value);
      }
    }
    return result;
  }

  /// True only for a column that names an audio *file*.
  ///
  /// Matching every column containing "audio" swept in flags and timestamps
  /// (`is_audio`, `audio_recorded_at`), which were then run through the
  /// downloader and rejected one by one. They were never going to be files,
  /// so requiring the name to end in "path" keeps them out entirely rather
  /// than discovering it per row.
  ///
  /// `target_audio_path` is excluded outright: the app no longer shows the
  /// passage's own recorded translation anywhere, and downloading a file
  /// nothing plays costs the phone bandwidth and storage for nothing.
  static bool _isAudioKey(String key) {
    final normalized = key.toLowerCase();
    if (normalized == 'target_audio_path') return false;
    return normalized.contains('audio') && normalized.endsWith('path');
  }

  static bool isValidAudioReference(String value) {
    final text = value.trim();
    if (text.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(text)) return false;
    if (text.contains(' ') && !text.contains('/')) return false;

    final uri = Uri.tryParse(text);
    if (uri == null) return false;

    final hasPath =
        (uri.path.isNotEmpty && uri.path != '/') || text.contains('/');
    final hasExtension =
        text.contains('.') ||
        uri.path.toLowerCase().endsWith('.wav') ||
        uri.path.toLowerCase().endsWith('.webm') ||
        uri.path.toLowerCase().endsWith('.mp3');
    return hasPath && hasExtension;
  }

  /// The audio files one row refers to, by file name.
  static Set<String> audioFileNames(dynamic value) {
    final unique = <String>{};

    void walk(dynamic item) {
      if (item is Map) {
        for (final entry in item.entries) {
          final key = entry.key.toString();
          final raw = entry.value;

          if (raw is String && _isAudioKey(key) && isValidAudioReference(raw)) {
            unique.add(_fileNameFromValue(raw));
          } else {
            walk(raw);
          }
        }
      } else if (item is List) {
        for (final child in item) {
          walk(child);
        }
      }
    }

    walk(value);
    return unique;
  }

  /// Downloads one recording on demand and returns where it landed, or null
  /// if it could not be fetched.
  ///
  /// The data load caches what a user's current work needs; this is for audio
  /// they ask for later, which is the whole point of the finished list.
  static Future<String?> download(String remoteValue) async {
    final name = _fileNameFromValue(remoteValue);
    if (name.isEmpty) return null;

    final stored = await _cacheFile(
      remoteValue: remoteValue,
      originalName: name,
    );
    return stored == remoteValue ? null : stored;
  }

  static Future<String> _cacheFile({
    required String remoteValue,
    required String originalName,
  }) async {
    if (_isInvalidAudioReference(remoteValue)) {
      debugPrint('SKIP INVALID AUDIO: $remoteValue');
      return remoteValue;
    }
    if (_givenUp.contains(remoteValue)) return remoteValue;

    final audioDirectory = await _folder('audio');

    // Everything is stored as WAV, whatever the server holds. A take
    // recorded in the browser arrives as WebM/Opus, which cannot be QC'd on
    // the device and will not play at all on iOS, so it is downloaded as it
    // stands and decoded here under the same name with a .wav extension.
    final wavFile = File(
      path.join(
        audioDirectory.path,
        '${path.basenameWithoutExtension(originalName)}.wav',
      ),
    );
    final originalFile = File(path.join(audioDirectory.path, originalName));

    var localFile = wavFile;

    // Whether this call went to the network, as opposed to finding the file
    // already here. Only used for the log line at the end, which otherwise
    // reads as though every refresh re-downloaded the whole Set.
    var fetched = false;
    final clock = Stopwatch()..start();
    var downloadMs = 0;

    // Sealed in the vault is on the phone: the row keeps its path, and the
    // file is turned back when the Set's screen opens.
    if (!await wavFile.exists() && await Vault.hasSealed(wavFile.path)) {
      debugPrint('AUDIO SEALED ON DEVICE: ${wavFile.path}');
      return wavFile.path;
    }
    if (!await originalFile.exists() &&
        originalFile.path != wavFile.path &&
        await Vault.hasSealed(originalFile.path)) {
      debugPrint('AUDIO SEALED ON DEVICE: ${originalFile.path}');
      return originalFile.path;
    }

    if (!await wavFile.exists()) {
      // One unreachable file must never abort the data load. This used to
      // throw, and because the exception unwound the whole save loop, a
      // single missing recording silently cost the device every table that
      // came after `takes` - final_takes and comments included. The URL is
      // handed back untouched instead, so the row still stores and only that
      // one clip reports itself as unavailable offline.
      try {
        if (!await originalFile.exists()) {
          final response = await MediaSession.get(_audioUri(remoteValue));
          if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
            debugPrint(
              'AUDIO DOWNLOAD FAILED ($originalName): ${response.statusCode}',
            );
            _failures[remoteValue] = response.statusCode == 200
                ? 'The server sent an empty file.'.tr
                : 'The server did not send the file (error @code).'.trParams({
                    'code': '${response.statusCode}',
                  });
            return remoteValue;
          }

          // A file behind a login answers 200 with the sign-in page. Written
          // out under an audio name it would look downloaded and fail to
          // play, so it is refused here where the reason is still visible.
          if (_isWebPage(response)) {
            debugPrint(
              'AUDIO DOWNLOAD BLOCKED ($originalName): '
              'server answered a web page, not a file',
            );
            _failures[remoteValue] =
                'The server asked for a sign-in instead of sending the file.'
                    .tr;
            return remoteValue;
          }
          await originalFile.writeAsBytes(response.bodyBytes, flush: true);
          downloadMs = clock.elapsedMilliseconds;
          downloadedNow++;
          fetched = true;
          onFetched?.call(downloadedNow, originalName);
        }

        // A file that is already WAV is the destination - decoding it would
        // mean ffmpeg reading and writing the same path, which fails and
        // takes the downloaded file with it.
        if (originalFile.path != wavFile.path) {
          // The decode happens on this device. If the file will not decode,
          // the original stays and still plays - it just cannot be QC'd, and
          // it keeps its real extension, so nothing downstream is told it is
          // a WAV when it is not.
          final converted = await _toWav(originalFile.path, wavFile.path);

          if (converted) {
            await originalFile.delete();
          } else {
            localFile = originalFile;
          }
        }
      } catch (e) {
        debugPrint('AUDIO DOWNLOAD ERROR ($originalName): $e');
        _failures[remoteValue] = _reasonFor(e);
        return remoteValue;
      }
    }

    // Its waveform read now, while the loading screen is still up, and
    // kept: read on first sight instead, a long recording stands as a
    // flat rule for a second in front of whoever opened it.
    if (fetched) {
      try {
        await WaveformCache.load(localFile.path);
      } catch (e) {
        debugPrint('WAVEFORM NOT READ AHEAD ($originalName): $e');
      }
    }

    if (_downloadedFiles.add(localFile.path)) {
      downloadedCount = _downloadedFiles.length;
      onProgress?.call(downloadedCount);
    }

    debugPrint(
      fetched
          ? 'AUDIO DOWNLOADED (fetched in $downloadMs ms, ready in '
                '${clock.elapsedMilliseconds} ms): ${localFile.path}'
          : 'AUDIO ALREADY ON DEVICE: ${localFile.path}',
    );
    return localFile.path;
  }

  /// True for a column holding a passage's script.
  ///
  /// The timestamp and author columns beside it (`source_script_updated_at`,
  /// `..._updated_by`) end in something else, so requiring the name to end in
  /// "script" keeps them out.
  static bool _isScriptKey(String key) => key.toLowerCase().endsWith('script');

  /// The companion key recording that `<name>_script` came from a file.
  static String scriptFileFlag(String key) => '${key}_is_file';

  /// True when a script column names a text file this app can fetch, rather
  /// than holding text of its own.
  static bool isScriptFile(String value) {
    final trimmed = value.trim().toLowerCase();
    return trimmed.endsWith('.txt') && _isMediaPath(trimmed);
  }

  /// Replaces a stored script path with the text it points at.
  ///
  /// Scripts are held as files on the web app, so a row carries a path where
  /// the passage should be - and a drafter shown a path has nothing to read.
  /// The text is fetched once, kept on the device, and put in the row itself,
  /// so every screen reads it offline with no idea it was ever a file.
  static Future<String> _cacheScript(String value, String updatedAt) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !_isMediaPath(trimmed)) return value;

    final fetchedAlready = _scriptsThisLoad[value];
    if (fetchedAlready != null) return fetchedAlready;

    final scriptsDirectory = await _folder('scripts');

    final file = File(
      path.join(scriptsDirectory.path, _fileNameFromValue(trimmed)),
    );

    // Fetched again only when the row says the file has changed. A script
    // can be corrected in place under the same name - the row carries
    // `source_script_updated_at` for exactly that - so a copy taken on
    // first sight would quietly disagree with the website from then on.
    // But the row's timestamp is the signal, and re-reading every script on
    // every refresh regardless was a network round trip per passage for
    // nothing: caller passes the timestamp, and a copy on disk stamped
    // with the same one is the answer.
    final stamp = File('${file.path}.stamp');
    await Vault.unlockFile(file.path);
    await Vault.unlockFile(stamp.path);

    // With neither a token nor a password, every fetch would come back as
    // the login page - one round trip per passage for a guaranteed no. The
    // copy on disk is the answer until the next sign-in. The same for a
    // file that has been asked about and skipped.
    if (!MediaSession.canFetch || _givenUp.contains(value)) {
      try {
        if (await file.exists()) return await file.readAsString();
      } catch (_) {}
      return value;
    }

    if (updatedAt.isNotEmpty) {
      try {
        if (await file.exists() &&
            await stamp.exists() &&
            await stamp.readAsString() == updatedAt) {
          return await file.readAsString();
        }
      } catch (_) {}
    }

    try {
      final response = await MediaSession.get(MainApp.buildMediaUri(trimmed));

      if (response.statusCode == 200 && !_isWebPage(response)) {
        final text = utf8.decode(response.bodyBytes, allowMalformed: true);
        await file.writeAsString(text, flush: true);
        if (updatedAt.isNotEmpty) await stamp.writeAsString(updatedAt);
        downloadedNow++;
        onFetched?.call(downloadedNow, path.basename(file.path));
        return text;
      }

      debugPrint('SCRIPT DOWNLOAD BLOCKED ($trimmed): ${response.statusCode}');
      _failures[trimmed] = response.statusCode == 200
          ? 'The server asked for a sign-in instead of sending the file.'.tr
          : 'The server did not send the file (error @code).'.trParams({
              'code': '${response.statusCode}',
            });
    } catch (e) {
      debugPrint('SCRIPT DOWNLOAD ERROR ($trimmed): $e');
      _failures[trimmed] = _reasonFor(e);
    }

    try {
      if (await file.exists()) return await file.readAsString();
    } catch (e) {
      debugPrint('SCRIPT READ ERROR ($trimmed): $e');
    }

    return value;
  }

  /// The sign-in page, or any other HTML, where a file was asked for.
  static bool _isWebPage(http.Response response) {
    final type = response.headers['content-type']?.toLowerCase() ?? '';
    return type.contains('text/html');
  }

  static bool _isInvalidAudioReference(String value) {
    return !isValidAudioReference(value);
  }

  static String _fileNameFromValue(String value) {
    final uri = Uri.tryParse(value);
    return path.basename(Uri.decodeComponent(uri?.path ?? value));
  }

  /// Source material stored as a path relative to the web app's media root.
  static bool _isMediaPath(String value) {
    final normalized = value
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceFirst(RegExp(r'^media/', caseSensitive: false), '')
        .toLowerCase();
    return normalized.startsWith('source-content/');
  }

  static Uri _audioUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme) return uri;
    if (_isMediaPath(value)) return MainApp.buildMediaUri(value);

    // Anything else relative hangs off the web app itself, which is where
    // these files live. It used to be built against a LAN address that only
    // ever resolved on one developer machine, so every such download failed
    // anywhere else.
    return MainApp.buildWebUri(value);
  }
}
