import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A recording made again at another speed, to be played at its own.
///
/// Asking an Android phone to play a file faster is asking its maker's
/// player, and they do not all agree to: some refuse a long recording
/// outright (`setPlaybackParams: IllegalArgumentException`), some take the
/// setting and play on at the pace they were at. Nothing above the player
/// can tell which phone it is on until it has failed.
///
/// So the phone is not asked. The recording is run through the decoder
/// this app already carries, which shortens it without raising the voice -
/// the same reader, reading faster - and the copy is played as any file
/// is. What a phone does with playback speed no longer comes into it.
class SpedCopy {
  SpedCopy._();

  /// Renders in flight, so two players asking for the same copy at once
  /// wait on one.
  static final Map<String, Future<String?>> _making = {};

  static bool _swept = false;

  /// The filter that gives [speed]. Each step is kept to a doubling at
  /// most: asked for more in one go, the stretch starts dropping pieces of
  /// the words to keep up.
  @visibleForTesting
  static String filterFor(double speed) {
    final steps = <String>[];
    var left = speed;
    while (left > 2.0 + 1e-9) {
      steps.add('atempo=2.0');
      left /= 2;
    }
    steps.add('atempo=${left.toStringAsFixed(4)}');
    return steps.join(',');
  }

  /// The copy of [path] at [speed], made if it has not been. Null when it
  /// cannot be made - the caller then has the original, and whatever the
  /// phone will do with it.
  static Future<String?> of(String path, double speed) async {
    try {
      final source = File(path);
      if (!await source.exists()) return null;

      final stat = await source.stat();
      final folder = Directory(
        p.join((await getTemporaryDirectory()).path, 'sped'),
      );
      await folder.create(recursive: true);
      await _sweep(folder);

      // Named for the file as it is now: one recorded over under the same
      // name is a different recording, and must not be handed the old
      // one's copy.
      final name =
          '${p.basenameWithoutExtension(path)}'
          '-${stat.size}-${stat.modified.millisecondsSinceEpoch}'
          '-${speed.toStringAsFixed(2)}x.wav';
      final destination = p.join(folder.path, name);

      return await _making.putIfAbsent(
        destination,
        () => _make(path, destination, speed),
      );
    } catch (e) {
      debugPrint('SPED COPY ERROR ($path at ${speed}x): $e');
      return null;
    }
  }

  static Future<String?> _make(
    String source,
    String destination,
    double speed,
  ) async {
    try {
      final made = File(destination);
      if (await made.exists() && await made.length() > 44) return destination;

      // Written beside its name and moved onto it, so a copy cut short by
      // the app closing is never taken for a whole one.
      final partial = '$destination.part';
      final started = DateTime.now();
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        source,
        '-vn',
        '-filter:a',
        filterFor(speed),
        '-acodec',
        'pcm_s16le',
        '-ar',
        '44100',
        '-ac',
        '1',
        '-f',
        'wav',
        partial,
      ]);

      final code = await session.getReturnCode();
      final written = File(partial);
      if (ReturnCode.isSuccess(code) &&
          await written.exists() &&
          await written.length() > 44) {
        await written.rename(destination);
        debugPrint(
          'SPED COPY MADE (${speed}x, '
          '${DateTime.now().difference(started).inMilliseconds} ms): '
          '$destination',
        );
        return destination;
      }

      debugPrint(
        'SPED COPY FAILED ($source at ${speed}x): '
        '${await session.getFailStackTrace() ?? code}',
      );
      if (await written.exists()) await written.delete();
      return null;
    } catch (e) {
      debugPrint('SPED COPY ERROR ($source at ${speed}x): $e');
      return null;
    } finally {
      // A copy that failed is tried again the next time it is asked for.
      _making.remove(destination);
    }
  }

  /// Once a run: copies more than a day old are thrown out. They are
  /// quick to make again, and nothing else ever clears them.
  static Future<void> _sweep(Directory folder) async {
    if (_swept) return;
    _swept = true;
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entry in folder.list(followLinks: false)) {
        if (entry is! File) continue;
        if ((await entry.stat()).modified.isBefore(cutoff)) {
          await entry.delete();
        }
      }
    } catch (e) {
      debugPrint('SPED COPY SWEEP SKIPPED: $e');
    }
  }
}
