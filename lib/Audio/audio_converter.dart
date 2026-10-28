import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';

/// Turns whatever the server holds into the one format this app works in.
///
/// Recordings arrive in three shapes: WAV from this app, WebM/Opus from the
/// browser, and MP3 for source audio. Only PCM WAV can be QC'd on the device,
/// and iOS will not play WebM at all - so everything is decoded to the same
/// PCM the recorder produces.
///
/// This used to be a server endpoint, which meant every phone had to reach
/// the machine holding ffmpeg. On a hotspot, or anywhere off that LAN, the
/// request simply timed out and the audio never arrived. Converting here
/// costs the decode once per file per device and needs nothing but the file.
class AudioConverter {
  AudioConverter._();

  /// 16-bit signed PCM, 44.1 kHz, mono - what the recorder writes and what
  /// `WavAnalyzer` expects to find in the header.
  static const List<String> _wavArguments = [
    '-vn',
    '-acodec',
    'pcm_s16le',
    '-ar',
    '44100',
    '-ac',
    '1',
  ];

  /// Decodes [source] into a WAV at [destination].
  ///
  /// Returns false rather than throwing: a file that will not decode is a
  /// clip that plays in its original format, not a failed data load.
  static Future<bool> toWav({
    required String source,
    required String destination,
  }) async {
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-y',
        '-i',
        source,
        ..._wavArguments,
        destination,
      ]);

      final code = await session.getReturnCode();
      if (ReturnCode.isSuccess(code)) {
        final output = File(destination);
        // A WAV header alone is 44 bytes, so anything at or under that
        // decoded to silence and is not worth keeping.
        if (await output.exists() && await output.length() > 44) return true;
      }

      debugPrint(
        'AUDIO CONVERT FAILED ($source): ${await session.getFailStackTrace() ?? code}',
      );
    } catch (e) {
      debugPrint('AUDIO CONVERT ERROR ($source): $e');
    }

    // Never leave a half-written file behind for the next run to trust.
    final partial = File(destination);
    if (await partial.exists()) await partial.delete();
    return false;
  }
}
