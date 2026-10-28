import 'dart:io';
import 'dart:typed_data';

import 'package:livuka/Audio/wave_analyzer.dart';

/// Rewrites a WAV into the canonical layout: `RIFF`, `WAVE`, a 16-byte
/// `fmt ` chunk, then `data` - nothing in between.
///
/// The Windows recorder (Media Foundation) writes a `JUNK` chunk ahead of
/// `fmt `, and converters leave a `LIST` of metadata after it. The server
/// checks a recording's format at fixed byte offsets, and read that way
/// the padding comes out as "not 16-bit PCM", so every such take was
/// refused with "Only WAV recordings can be stored". The samples are
/// untouched; only the wrapper is rebuilt.
class WavCanonical {
  WavCanonical._();

  /// Rewrites [path] in place when its chunks are not in canonical order.
  /// Returns true when the file was changed. Anything that is not a WAV,
  /// or is already canonical, is left alone.
  static Future<bool> rewriteInPlace(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    if (bytes.length < 44 || !WavAnalyzer.isWav(bytes)) return false;

    Uint8List? fmt;
    int dataStart = -1;
    var dataSize = 0;
    var offset = 12;
    var canonical = true;

    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = WavAnalyzer.readUint32(bytes, offset + 4);
      final body = offset + 8;

      if (id == 'fmt ') {
        if (body + 16 > bytes.length) return false;
        fmt = bytes.sublist(body, body + 16);
        if (offset != 12 || size != 16) canonical = false;
      } else if (id == 'data') {
        dataStart = body;
        // A size the recorder never filled in, or one past the end of the
        // file: what is on disk is the better witness.
        final available = bytes.length - body;
        dataSize = (size <= 0 || size > available) ? available : size;
        if (offset != 36) canonical = false;
        break;
      } else {
        canonical = false;
      }

      offset = body + size + (size.isOdd ? 1 : 0);
    }

    if (fmt == null || dataStart < 0) return false;
    if (canonical && dataSize == WavAnalyzer.readUint32(bytes, 40)) {
      return false;
    }

    final out = BytesBuilder(copy: false)
      ..add(_ascii('RIFF'))
      ..add(_u32(36 + dataSize))
      ..add(_ascii('WAVE'))
      ..add(_ascii('fmt '))
      ..add(_u32(16))
      ..add(fmt)
      ..add(_ascii('data'))
      ..add(_u32(dataSize))
      ..add(Uint8List.sublistView(bytes, dataStart, dataStart + dataSize));

    // Written beside the original and swapped in, so a failure part way
    // leaves the recording as it was.
    final temp = File('$path.tmp');
    await temp.writeAsBytes(out.takeBytes(), flush: true);
    await temp.rename(path);
    return true;
  }

  /// Below this a 16-bit sample is no volume at all. An input that is
  /// switched off does not always read exact zero: the emulator's flickers
  /// between 0 and 2, its last bit and no more. From 3 up it is sound,
  /// however faint - the quietest room is sound - and is never trimmed.
  static const int deadCeiling = 3;

  /// Drops the stretches of no volume at the two ends of the canonical
  /// 16-bit WAV at [path] - every frame below [deadCeiling], up to the
  /// first that is not and after the last - and rewrites the file in
  /// place. Nothing between the two is touched, and nothing that has any
  /// volume, so what is left is the recording from its first sound to its
  /// last. Returns how many frames went from each end.
  static Future<({int head, int tail})> trimDeadEdges(String path) async {
    const untouched = (head: 0, tail: 0);
    final file = File(path);
    if (!await file.exists()) return untouched;

    final bytes = await file.readAsBytes();
    if (bytes.length < 44 || !WavAnalyzer.isWav(bytes)) return untouched;
    if (String.fromCharCodes(bytes.sublist(36, 40)) != 'data') {
      return untouched;
    }
    final frameBytes = WavAnalyzer.readUint16(bytes, 32);
    if (WavAnalyzer.readUint16(bytes, 34) != 16 || frameBytes < 2) {
      return untouched;
    }

    const dataStart = 44;
    final dataEnd = bytes.length - (bytes.length - dataStart) % frameBytes;

    // A frame is dead when every channel of it is.
    bool dead(int frame) {
      for (var at = frame; at < frame + frameBytes; at += 2) {
        var v = bytes[at] | (bytes[at + 1] << 8);
        if (v >= 0x8000) v -= 0x10000;
        if (v.abs() >= deadCeiling) return false;
      }
      return true;
    }

    var first = dataStart;
    while (first < dataEnd && dead(first)) {
      first += frameBytes;
    }
    var last = dataEnd;
    while (last > first && dead(last - frameBytes)) {
      last -= frameBytes;
    }
    if (first == dataStart && last == dataEnd) return untouched;

    final dataSize = last - first;
    final out = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(bytes, 0, 4))
      ..add(_u32(36 + dataSize))
      ..add(Uint8List.sublistView(bytes, 8, 40))
      ..add(_u32(dataSize))
      ..add(Uint8List.sublistView(bytes, first, last));

    final temp = File('$path.tmp');
    await temp.writeAsBytes(out.takeBytes(), flush: true);
    await temp.rename(path);
    return (
      head: (first - dataStart) ~/ frameBytes,
      tail: (dataEnd - last) ~/ frameBytes,
    );
  }

  static Uint8List _ascii(String s) => Uint8List.fromList(s.codeUnits);

  static Uint8List _u32(int value) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);
}
