import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:flutter/foundation.dart';

import 'package:livuka/Audio/recording_config.dart';
import 'package:livuka/Audio/wav_canonical.dart';

/// Records a take: 16-bit PCM WAV, 44.1 kHz, mono, whatever the platform.
///
/// `audio_waveforms` sits behind this: it is what every take so far was
/// made with and what the live waveform strip is built around. The screens
/// do not see it: they start, pause, resume and stop, and are handed a
/// path.
///
/// Both wait, once capture is requested, until the file holds real signal
/// before the take counts as started, and both drop what has no volume at
/// the two ends when the file is closed: phones and the emulator alike
/// hand back a second or two of nothing - exact zeros, or the flicker of
/// a last bit - while the capture path wakes up, and that stretch is not
/// part of the take. Anything with volume, however little, is.
abstract class TakeRecorder {
  factory TakeRecorder() => _PhoneRecorder();

  /// The `audio_waveforms` controller, for the live strip.
  aw.RecorderController get waveformController;

  bool get isRecording;
  bool get isPaused;

  /// Starts a new file at [path], or - with no path - resumes the one that
  /// was paused. Returns once the microphone is delivering signal, so the
  /// clock a screen starts afterwards matches what is on disk.
  Future<void> record({String? path});
  Future<void> pause();

  /// Stops, and returns the path of the file written, or null when there
  /// was nothing to keep.
  Future<String?> stop();
  void dispose();
}

/// Waits, up to three seconds, for the WAV at [path] to hold real signal -
/// a sample at or above [WavCanonical.deadCeiling] in the newest 60 ms,
/// since the head may be the dead stretch being waited out. True once it
/// does; [live] lets the wait stop early when recording was called off.
Future<bool> _awaitSignal(String path, {required bool Function() live}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  final file = File(path);
  while (DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!live()) return false;
    try {
      if (!await file.exists()) continue;
      final length = await file.length();
      if (length <= 44) continue;
      const slice = 5292;
      final from = (length - slice).clamp(44, length);
      final raf = await file.open();
      try {
        await raf.setPosition(from);
        final bytes = await raf.read(length - from);
        for (var i = 0; i + 1 < bytes.length; i += 2) {
          var v = bytes[i] | (bytes[i + 1] << 8);
          if (v >= 0x8000) v -= 0x10000;
          if (v.abs() >= WavCanonical.deadCeiling) return true;
        }
      } finally {
        await raf.close();
      }
    } catch (e) {
      debugPrint('REC: signal check failed: $e');
    }
  }
  return false;
}

/// The file as the take: canonical layout, and no stretch of no volume at
/// either end. Null when nothing beyond the header is left - a recording
/// with no volume anywhere is nothing recorded.
Future<String?> _finishFile(String path) async {
  final file = File(path);
  if (!await file.exists() || await file.length() <= 44) return null;
  // Media Foundation pads the header with a JUNK chunk the server does
  // not expect; the file is rewritten in the plain layout it does.
  await WavCanonical.rewriteInPlace(path);
  // Done here, before anything grades the file: what the capture path
  // wrote before it woke up, and after it shut, is not part of the take.
  // Only no volume goes. A quiet room is sound, and stays.
  final dropped = await WavCanonical.trimDeadEdges(path);
  if (dropped.head > 0 || dropped.tail > 0) {
    debugPrint(
      'REC: dropped ${dropped.head} dead samples at head, '
      '${dropped.tail} at tail',
    );
  }
  if (await file.length() <= 44) return null;
  return path;
}

class _PhoneRecorder implements TakeRecorder {
  final aw.RecorderController _c = aw.RecorderController();
  String? _path;

  @override
  aw.RecorderController get waveformController => _c;

  @override
  bool get isRecording => _c.isRecording;

  @override
  bool get isPaused => _c.recorderState == aw.RecorderState.paused;

  @override
  Future<void> record({String? path}) async {
    if (path == null) {
      await _c.record();
      return;
    }
    _path = path;
    await _c.record(path: path, recorderSettings: kObtRecorderSettings);
    final live = await _awaitSignal(path, live: () => _c.isRecording);
    debugPrint(live ? 'REC: microphone live' : 'REC: no signal yet, going on');
  }

  @override
  Future<void> pause() => _c.pause();

  @override
  Future<String?> stop() async {
    // Paused first: the plugin closes the file before its capture thread
    // has finished writing, and a write that lands after the close takes
    // the whole app down. Paused, the thread writes nothing.
    if (_c.isRecording) {
      try {
        await _c.pause();
      } catch (e) {
        debugPrint('REC: pause before stop failed: $e');
      }
    }
    final path = await _c.stop();
    final out = path ?? _path;
    if (out == null) return null;
    return _finishFile(out);
  }

  @override
  void dispose() => _c.dispose();
}
