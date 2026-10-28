import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:livuka/services/take_repository.dart';

/// Gets back a take that was being recorded when the app died.
///
/// A recording is a file filling up on disk and, until it is stopped and
/// saved, nothing else: no row points at it. If the phone runs out of
/// battery, the app is swiped away or the system kills it for memory, the
/// audio is all there and the app has no idea it exists.
///
/// So a note is written the moment recording starts - which file, which
/// passage - and torn up once the take is safely in the database. A note
/// still there at the next start-up is a recording that never got that far.
/// Its header is repaired (the recorder only fills in the lengths when it
/// stops) and it is filed as an ordinary take, ungraded, for the drafter to
/// listen to and keep or remove like any other.
class RecordingRescue {
  RecordingRescue._();

  static const String _key = 'recording_in_progress';

  /// What the recorder writes: 44.1 kHz, mono, 16-bit. Only used when the
  /// file's own header cannot say.
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;

  static Future<void> began({
    required String path,
    required String setId,
    required String leafType,
    required String leafId,
    required String leafLabel,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'path': path,
        'setId': setId,
        'leafType': leafType,
        'leafId': leafId,
        'leafLabel': leafLabel,
        'startedAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  /// The take is saved, or was deliberately thrown away: nothing to rescue.
  static Future<void> finished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Run once at start-up. Returns the passage a take was recovered for, or
  /// null when there was nothing to recover.
  static Future<String?> recover() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;

    try {
      final note = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final path = note['path']?.toString() ?? '';
      final file = File(path);

      if (path.isEmpty || !await file.exists()) return null;

      final seconds = await repairWavHeader(file);
      // The same floor as a take stopped by hand. Under it there was never a
      // reading to lose - and the file is left where it is regardless.
      if (seconds == null || seconds < 5) return null;

      await TakeRepository.saveTake(
        setId: note['setId'].toString(),
        leafType: note['leafType'].toString(),
        leafId: note['leafId'].toString(),
        filePath: path,
        durationMs: (seconds * 1000).round(),
        recordedAt: DateTime.tryParse(note['startedAt']?.toString() ?? ''),
      );

      return note['leafLabel']?.toString() ?? '';
    } catch (e) {
      debugPrint('RECORDING RESCUE FAILED: $e');
      return null;
    } finally {
      // Whatever happened, once only: a note that cannot be acted on must
      // not be retried at every launch for ever.
      await prefs.remove(_key);
    }
  }

  /// Makes [file] a well-formed 16-bit PCM WAV and returns its length in
  /// seconds, or null when it is not something this can repair.
  ///
  /// The recorder reserves 44 bytes for the header and only writes the real
  /// one when it stops, so an interrupted file is either blank there or
  /// carries lengths of zero. Either way the audio after byte 44 is intact,
  /// and the lengths are simply what the file size says they are.
  @visibleForTesting
  static Future<double?> repairWavHeader(File file) async {
    final length = await file.length();
    if (length <= 44) return null;

    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.setPosition(0);
      final head = await raf.read(44);

      final tag = String.fromCharCodes(head.sublist(0, 4));
      final blank = head.every((byte) => byte == 0);
      if (tag != 'RIFF' && !blank) return null;

      var sampleRate = _sampleRate;
      var channels = _channels;

      final view = ByteData.sublistView(head);
      if (tag == 'RIFF' &&
          String.fromCharCodes(head.sublist(12, 16)) == 'fmt ') {
        final statedData = view.getUint32(40, Endian.little);
        // Already whole - stopped properly, and only the save was missed.
        if (statedData == length - 44) {
          final rate = view.getUint32(24, Endian.little);
          final count = view.getUint16(22, Endian.little);
          final bytesPerSecond = rate * count * 2;
          return bytesPerSecond == 0 ? null : (length - 44) / bytesPerSecond;
        }

        final rate = view.getUint32(24, Endian.little);
        final count = view.getUint16(22, Endian.little);
        if (rate > 0) sampleRate = rate;
        if (count > 0) channels = count;
      }

      final dataBytes = length - 44;
      final blockAlign = channels * _bitsPerSample ~/ 8;
      final byteRate = sampleRate * blockAlign;

      final header = ByteData(44);
      void ascii(int at, String text) {
        for (var i = 0; i < text.length; i++) {
          header.setUint8(at + i, text.codeUnitAt(i));
        }
      }

      ascii(0, 'RIFF');
      header.setUint32(4, 36 + dataBytes, Endian.little);
      ascii(8, 'WAVE');
      ascii(12, 'fmt ');
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little); // PCM
      header.setUint16(22, channels, Endian.little);
      header.setUint32(24, sampleRate, Endian.little);
      header.setUint32(28, byteRate, Endian.little);
      header.setUint16(32, blockAlign, Endian.little);
      header.setUint16(34, _bitsPerSample, Endian.little);
      ascii(36, 'data');
      header.setUint32(40, dataBytes, Endian.little);

      await raf.setPosition(0);
      await raf.writeFrom(header.buffer.asUint8List());
      await raf.flush();

      return dataBytes / byteRate;
    } finally {
      await raf.close();
    }
  }
}
