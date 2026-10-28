import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/services/Database/db.dart';

/// What a file is, to the person waiting for it.
enum MediaKind {
  sourceAudio(
    'Source audio',
    'The recording the Drafter and the Peer listen to for this passage.',
  ),
  sourceScript(
    'Source script',
    'The text of this passage in the source language.',
  ),
  targetScript(
    'Target script',
    'The text of this passage in the target language.',
  ),
  take(
    'Take recording',
    'A recording of this passage. Without it the take cannot be played.',
  ),
  comment('Voice comment', "A reviewer's spoken comment on a recording."),
  question('Question recording', 'A community question or its answer, spoken.'),
  backTranslation(
    'Back translation recording',
    'The spoken back translation of this Set.',
  ),
  other('Recording', 'A recording this Set refers to.');

  const MediaKind(this.label, this.use);

  /// What it is called.
  final String label;

  /// What it is for.
  final String use;
}

/// One file the data load wants on the phone.
class MediaFile {
  MediaFile({
    required this.kind,
    required this.remote,
    required this.isScript,
    required this.setName,
    required this.passageName,
    this.updatedAt = '',
  });

  final MediaKind kind;

  /// The value its row holds for it: a path or an address on the server.
  final String remote;
  final bool isScript;

  /// A script's `..._updated_at`, which says which version is wanted.
  final String updatedAt;

  final String setName;
  final String passageName;

  /// Why it did not arrive, once it has been tried and has not.
  String? failure;

  String get fileName => AudioCacheService.fileNameOf(remote);
}

/// Asked when files did not arrive: which of [failed] to try again. The
/// rest are skipped.
typedef AskAboutFailed = Future<List<MediaFile>> Function(
  List<MediaFile> failed,
);

/// Brings down the files a data load wants, several at a time, before its
/// rows are written.
///
/// The rows used to fetch their own files as they were stored, one after
/// another: a passage's source audio, then its two scripts, then the next
/// passage's. Eighty files came to twenty minutes of a screen that could
/// not be left. Here they are gathered first and fetched six abreast;
/// the rows, written afterwards, find every file already on the phone.
///
/// A file that does not arrive is not passed over in silence. Whoever is
/// waiting is told which it is - what it is for, which Set and passage -
/// and chooses, file by file, to try again or to go on without it.
class MediaPrefetch {
  MediaPrefetch._();

  /// How many files come down at once.
  static const int abreast = 6;

  static Future<void> run(
    Map<String, dynamic> json, {
    AskAboutFailed? askAboutFailed,
  }) async {
    AudioCacheService.beginLoad();

    var wanted = await _missing(json);
    if (wanted.isEmpty) return;
    debugPrint('PREFETCH: ${wanted.length} files to fetch');

    while (wanted.isNotEmpty) {
      _unreached = 0;

      // The first on its own: it is the one that signs in to the website,
      // and the rest then go with the session it opened.
      await _fetch(wanted.first);
      await _abreast(wanted.skip(1).toList());

      final failed = [
        for (final file in wanted)
          if (file.failure != null) file,
      ];
      if (failed.isEmpty) return;
      debugPrint('PREFETCH: ${failed.length} files did not arrive');

      final again = askAboutFailed == null
          ? const <MediaFile>[]
          : await askAboutFailed(failed);

      for (final file in failed) {
        if (!again.contains(file)) AudioCacheService.giveUpOn(file.remote);
      }
      wanted = again;
    }
  }

  static Future<void> _abreast(List<MediaFile> files) async {
    var next = 0;

    Future<void> worker() async {
      while (next < files.length) {
        await _fetch(files[next++]);
      }
    }

    await Future.wait([for (var i = 0; i < abreast; i++) worker()]);
  }

  /// How many files in a row have failed for want of a connection.
  static int _unreached = 0;

  /// After this many, the connection is taken to be gone and the rest are
  /// not tried: each would take a minute to say the same thing, and the
  /// question - wait for a signal and try again, or go on without - is
  /// better asked now than after eighty of them.
  static const int _unreachedLimit = 3;

  static Future<void> _fetch(MediaFile file) async {
    if (_unreached >= _unreachedLimit) {
      file.failure = AudioCacheService.noConnection;
      return;
    }

    await _attempt(file);

    if (file.failure == null) {
      _unreached = 0;
    } else if (AudioCacheService.isConnectionFailure(file.failure)) {
      _unreached++;
    }
  }

  static Future<void> _attempt(MediaFile file) async {
    try {
      file.failure = file.isScript
          ? await AudioCacheService.fetchScript(file.remote, file.updatedAt)
          : await AudioCacheService.fetchAudio(file.remote);
    } catch (e) {
      debugPrint('PREFETCH FAILED (${file.fileName}): $e');
      file.failure = '$e';
    }
  }

  /// Every file the load wants that is not on the phone, each once.
  @visibleForTesting
  static List<MediaFile> wantedBy(Map<String, dynamic> json) {
    final needs = AudioNeeds.from(json);

    final setNames = <String, String>{
      for (final row in _rows(json['sets'])) _str(row['id']): _str(row['name']),
    };
    final passages = <String, Map<String, dynamic>>{
      for (final row in _rows(json['Passage'])) _str(row['id']): row,
    };
    final subPassages = <String, Map<String, dynamic>>{
      for (final row in _rows(json['subPassage'])) _str(row['id']): row,
    };

    String passageName(String type, String id) {
      if (id.isEmpty) return '';
      if (type == 'sub_passage' || type == 'subpassage') {
        final sub = subPassages[id];
        final parent = passages[_str(sub?['obt_passage_id'])];
        return [
          _str(parent?['name']),
          _str(sub?['name']),
        ].where((part) => part.isNotEmpty).join(' - ');
      }
      return _str(passages[id]?['name']);
    }

    final seen = <String>{};
    final files = <MediaFile>[];

    for (final entry in DatabaseHelper.collectionTables.entries) {
      final table = entry.value;

      for (final row in _rows(json[entry.key])) {
        if (!needs.wants(table, row)) continue;

        final String setId;
        final String passage;
        switch (table) {
          case 'passages':
            setId = _str(row['obt_set_id']);
            passage = _str(row['name']);
          case 'sub_passages':
            final parent = passages[_str(row['obt_passage_id'])];
            setId = _str(parent?['obt_set_id']);
            passage = [
              _str(parent?['name']),
              _str(row['name']),
            ].where((part) => part.isNotEmpty).join(' - ');
          default:
            setId = _str(row['obt_set_id']);
            passage = passageName(_str(row['leaf_type']), _str(row['leaf_id']));
        }

        for (final field in row.entries) {
          final value = field.value;
          if (value is! String || value.trim().isEmpty) continue;
          final key = field.key;

          final isScript =
              AudioCacheService.isScriptKey(key) &&
              AudioCacheService.isScriptFile(value);
          final isAudio =
              !isScript &&
              AudioCacheService.isAudioKey(key) &&
              AudioCacheService.isValidAudioReference(value);
          if (!isScript && !isAudio) continue;

          // A recording is kept under its file name, so two rows naming
          // the same file are one download.
          final name = AudioCacheService.fileNameOf(value);
          if (name.isEmpty || !seen.add('${isScript ? 's' : 'a'}|$name')) {
            continue;
          }

          files.add(
            MediaFile(
              kind: _kindOf(table, key, row),
              remote: value,
              isScript: isScript,
              updatedAt: isScript ? _str(row['${key}_updated_at']) : '',
              setName: setNames[setId] ?? '',
              passageName: passage,
            ),
          );
        }
      }
    }

    return files;
  }

  /// Deletes every downloaded file the load has no use for. Run after the
  /// rows are written, so that a file is never removed from under a row
  /// still pointing at it.
  static Future<int> prune(Map<String, dynamic> json) async {
    final files = wantedBy(json);
    try {
      return await AudioCacheService.pruneTo(
        audioNames: {
          for (final file in files)
            if (!file.isScript) file.fileName,
        },
        scriptNames: {
          for (final file in files)
            if (file.isScript) file.fileName,
        },
      );
    } catch (e) {
      debugPrint('PRUNE FAILED: $e');
      return 0;
    }
  }

  static Future<List<MediaFile>> _missing(Map<String, dynamic> json) async {
    final missing = <MediaFile>[];
    for (final file in wantedBy(json)) {
      final here = file.isScript
          ? await AudioCacheService.hasScript(file.remote, file.updatedAt)
          : await AudioCacheService.hasAudio(file.remote);
      if (!here) missing.add(file);
    }
    return missing;
  }

  static MediaKind _kindOf(String table, String key, Map<String, dynamic> row) {
    final field = key.toLowerCase();

    switch (table) {
      case 'passages':
      case 'sub_passages':
        if (field == 'source_script') return MediaKind.sourceScript;
        if (field == 'target_script') return MediaKind.targetScript;
        if (field == 'source_audio_path') return MediaKind.sourceAudio;
        return MediaKind.other;
      case 'takes':
        return MediaKind.take;
      case 'take_comments':
        return _str(row['type']) == 'comment'
            ? MediaKind.comment
            : MediaKind.question;
      case 'back_translations':
        return MediaKind.backTranslation;
      default:
        return MediaKind.other;
    }
  }

  static Iterable<Map<String, dynamic>> _rows(Object? value) sync* {
    if (value is! List) return;
    for (final row in value) {
      if (row is Map) yield Map<String, dynamic>.from(row);
    }
  }

  static String _str(Object? value) => value?.toString().trim() ?? '';
}
