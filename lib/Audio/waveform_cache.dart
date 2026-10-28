import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:livuka/Audio/audio_backend.dart';
import 'package:livuka/Audio/audio_converter.dart';
import 'package:flutter/foundation.dart';

import 'package:livuka/Audio/wave_analyzer.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A file's bar heights and its length.
class ClipAudio {
  const ClipAudio({required this.bars, required this.duration});

  final List<double> bars;
  final Duration duration;

  static const ClipAudio empty = ClipAudio(bars: [], duration: Duration.zero);
}

/// Remembers what has already been read off each audio file.
/// Extracting a waveform decodes the whole recording, which is far too much
/// work to repeat casually — and a list does exactly that: scrolling a clip
/// out of view disposes it, and scrolling back builds it again from scratch.
/// Keyed by path and held for the session, so every file is decoded once no
/// matter how often its widget comes and goes.
class WaveformCache {
  WaveformCache._();

  /// Bars are extracted at one resolution and resampled by whoever draws
  /// them, so two widgets wanting different bar counts still share one read.
  static const int barCount = 240;

  static final Map<String, Future<ClipAudio>> _cache = {};

  /// What has been read already, to be had without waiting for anything.
  static final Map<String, ClipAudio> _ready = {};

  /// The bars and length of [path] if they have been read before - this
  /// session or an earlier one - there and then. A clip draws them in its
  /// first frame, where asking [load], however quick the answer, costs it
  /// a frame of the flat rule first: and a good many frames on a screen
  /// that is still opening, where every answer waits its turn behind the
  /// screen itself.
  static ClipAudio? peek(String path) {
    final known = _ready[path];
    if (known != null) return known;

    final kept = _WaveStore.readNow(path);
    if (kept != null) _ready[path] = kept;
    return kept;
  }

  /// Finds where the bars are kept, so that [peek] can look there. Asked
  /// for once, as the app starts.
  static Future<void> prepare() => _WaveStore.prepare();

  /// How long a WAV runs, by its header, there and then - or null when
  /// the file is not one. Four kilobytes off the front of the file.
  static Duration? lengthNow(String path) {
    RandomAccessFile? file;
    try {
      file = File(path).openSync();
      final layout = _WavLayout.of(file.readSync(4096), file.lengthSync());
      if (layout == null) return null;

      return Duration(milliseconds: layout.frames * 1000 ~/ layout.sampleRate);
    } catch (_) {
      return null;
    } finally {
      try {
        file?.closeSync();
      } catch (_) {}
    }
  }

  /// Reads by the phones' native extractor run one after another, however
  /// many ask at once.
  ///
  /// That extractor is a single native codec: asked to work on two
  /// files at the same time it releases the codec out from under the first
  /// and throws `codec is released already`. A screen with several clips on
  /// it, or a merged player measuring a Set, would do exactly that.
  ///
  /// Only that extractor waits here. A WAV is read in Dart and has no
  /// codec to share: standing every recording in the one line meant a
  /// single read that never answered left every strip after it flat for
  /// the rest of the session.
  static Future<void> _queue = Future<void>.value();

  /// How long the native extractor is given before the line moves on
  /// without it.
  static const Duration _codecPatience = Duration(seconds: 30);

  /// A WAV up to this size - eleven seconds or so - is read where it is
  /// asked for and in one go, which is a few thousandths of a second.
  /// Anything that has to be waited for waits its turn behind the screen
  /// that is opening, and that turn is what took the time: the reading
  /// never did.
  static const int _readHereLimit = 1024 * 1024;

  /// How long an isolate is given to answer before the file is read here
  /// instead. Under a debugger a fresh isolate can be left paused and
  /// never answer at all.
  static const Duration _isolatePatience = Duration(seconds: 6);

  static final Map<String, Future<Duration>> _durations = {};

  /// How long a file runs, without reading its waveform.
  ///
  /// Far cheaper than [load]: a WAV says its length in its header, and
  /// anything else is opened by the player and asked, which prepares a
  /// decoder but does not push every sample through one. A screen that only
  /// needs a timeline - which is every screen, before the bars are drawn -
  /// can have it almost at once.
  static Future<Duration> duration(String path) {
    final known = _cache[path];
    if (known != null) return known.then((audio) => audio.duration);

    return _durations.putIfAbsent(path, () async {
      try {
        final fromHeader = await _headerDuration(path);
        if (fromHeader != null && fromHeader > Duration.zero) return fromHeader;

        return await _probeDuration(path) ?? Duration.zero;
      } catch (e) {
        debugPrint('DURATION READ FAILED ($path): $e');
        _durations.remove(path);
        return Duration.zero;
      }
    });
  }

  static Future<ClipAudio> load(String path) {
    final pending = _cache[path];
    if (pending != null) return pending;

    // The future itself is cached, not just its result, so several clips of
    // the same file opening at once share a single decode.
    final future = _read(path);
    _cache[path] = future;
    return future;
  }

  /// Forgets everything read this session. For tests.
  @visibleForTesting
  static void debugForget() {
    _cache.clear();
    _ready.clear();
    _durations.clear();
    _details.clear();
  }

  @visibleForTesting
  static Future<Float32List?> debugReadHere(String path, int barsPerSecond) =>
      _wavDetailHere(path, barsPerSecond);

  @visibleForTesting
  static Float32List? debugReadApart(String path, int barsPerSecond) =>
      _wavDetail((path, barsPerSecond));

  static Future<ClipAudio> _read(String path) async {
    final started = DateTime.now();
    int spent() => DateTime.now().difference(started).inMilliseconds;

    try {
      // Read on an earlier day: the bars are a kilobyte on the disk, and
      // the recording they were read from may be a quarter of an hour.
      final kept = peek(path) ?? await _WaveStore.read(path);
      if (kept != null) {
        debugPrint('WAVEFORM: kept, in ${spent()} ms (${p.basename(path)})');
        return _ready[path] = kept;
      }

      var audio = await _ownRead(path);

      if (audio == null) {
        Object? fault;
        try {
          audio = await _next(() => _foreignRead(path).timeout(_codecPatience));
        } catch (e) {
          fault = e;
          debugPrint('NATIVE WAVEFORM FAILED ($path): $e');
        }

        // The extractor is fussier than the player, and gives some files
        // no bars at all. Decoded to a WAV, the file is read like any
        // other.
        if (audio == null || audio.bars.isEmpty) {
          final decoded = await _decodedRead(path);
          if (decoded != null) {
            audio = ClipAudio(
              bars: decoded.bars,
              duration: audio != null && audio.duration > Duration.zero
                  ? audio.duration
                  : decoded.duration,
            );
          }
        }

        if (audio == null) throw fault ?? Exception('No waveform');
      }

      if (audio.bars.isEmpty) {
        // Not an answer worth remembering: the next to ask tries again.
        unawaited(_cache.remove(path));
        return audio;
      }

      debugPrint('WAVEFORM: read in ${spent()} ms (${p.basename(path)})');
      _ready[path] = audio;
      unawaited(_WaveStore.write(path, audio));
      return audio;
    } catch (e) {
      // A failure must not be remembered as the answer, or the file could
      // never be read again this session.
      unawaited(_cache.remove(path));
      debugPrint('WAVEFORM READ FAILED ($path): $e');
      rethrow;
    }
  }

  /// A WAV's bars and length, read in Dart, or null when the file is not
  /// a 16-bit PCM WAV.
  static Future<ClipAudio?> _ownRead(String path) async {
    final fine = await _fine(path, 40);
    if (fine == null || fine.isEmpty) return null;

    var duration = await _headerDuration(path) ?? Duration.zero;
    if (duration <= Duration.zero) {
      // A header that was never filled in. What was read is the witness.
      duration = Duration(milliseconds: fine.length * 1000 ~/ 40);
    }
    return ClipAudio(bars: _fold(fine, barCount), duration: duration);
  }

  /// The loudness of a WAV slice by slice, by whichever way is quicker
  /// for a file its size: a short one here and now, a long one on an
  /// isolate - and that one here too, a piece at a time, if the isolate
  /// does not answer.
  static Future<Float32List?> _fine(String path, int barsPerSecond) async {
    var size = 0;
    try {
      size = File(path).lengthSync();
    } catch (_) {
      return null;
    }

    if (size <= _readHereLimit) return _wavDetail((path, barsPerSecond));

    try {
      return await compute(_wavDetail, (
        path,
        barsPerSecond,
      )).timeout(_isolatePatience);
    } catch (e) {
      debugPrint('WAVEFORM ISOLATE DID NOT ANSWER ($path): $e');
    }
    return _wavDetailHere(path, barsPerSecond);
  }

  /// Decodes a file that is not a WAV to one, and reads that.
  static Future<ClipAudio?> _decodedRead(String path) async {
    File? wav;
    try {
      final folder = Directory(
        p.join((await getTemporaryDirectory()).path, _WaveStore.folderName),
      );
      await folder.create(recursive: true);
      wav = File(
        p.join(
          folder.path,
          'decode-${DateTime.now().microsecondsSinceEpoch}.wav',
        ),
      );

      final decoded = await AudioConverter.toWav(
        source: path,
        destination: wav.path,
      );
      if (!decoded) return null;
      return await _ownRead(wav.path);
    } catch (e) {
      debugPrint('WAVEFORM DECODE FAILED ($path): $e');
      return null;
    } finally {
      try {
        if (wav != null && await wav.exists()) await wav.delete();
      } catch (_) {}
    }
  }

  /// Takes a place in the queue. Generic, because the fine-grained bars go
  /// through the same codec as the coarse ones and wait in the same line.
  static Future<T> _next<T>(Future<T> Function() read) {
    final result = _queue.then((_) => read());

    // The queue must survive a failed read, or one unreadable file would
    // block every file behind it for the rest of the session.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// A file that is not a WAV - a source MP3 the converter could not
  /// touch - by the phones' native extractor, which a desktop does not
  /// have.
  static Future<ClipAudio> _foreignRead(String path) async {
    aw.PlayerController? controller;

    try {
      var duration = Duration.zero;

      if (_hasNativeExtractor) {
        controller = aw.PlayerController();
        await controller.preparePlayer(
          path: path,
          shouldExtractWaveform: false,
        );
        duration = Duration(milliseconds: controller.maxDuration);
      }

      // The waveform library reports no length for some encoders - mp3 in
      // particular - which used to cost the whole merged timeline. The
      // player itself has no such trouble, so it is asked instead.
      if (duration <= Duration.zero) {
        duration = await _probeDuration(path) ?? Duration.zero;
      }

      if (!_hasNativeExtractor) {
        return ClipAudio(bars: const [], duration: duration);
      }

      // Reuses the controller when the slow path already made one, so the
      // fast path builds one rather than two - and either way it is disposed
      // below.
      final extractor = controller ??= aw.PlayerController();
      final bars = await extractor.waveformExtraction.extractWaveformData(
        path: path,
        noOfSamples: barCount,
      );

      return ClipAudio(bars: bars, duration: duration);
    } finally {
      controller?.dispose();
    }
  }

  static final Map<String, Future<List<double>>> _details = {};

  /// Fine-grained bars for the full-screen view: [barsPerSecond] of them for
  /// every second of the file, each the loudest moment in its slice, scaled
  /// so the loudest in the file is 1 - or less, for a file that is silence
  /// from end to end.
  ///
  /// The 120 bars [load] gives are plenty for a strip across a card, and
  /// nothing like enough for a window five seconds wide - that is one bar,
  /// stretched across the screen. These are read only when somebody opens
  /// that view, and once per file per session like everything else here.
  ///
  /// A 16-bit PCM WAV - every take this app records - is read straight off
  /// the disk on another isolate, a quarter of a megabyte at a time, so a
  /// ten-minute Set neither sits in memory whole nor holds up a frame on a
  /// mid-range phone. Anything else goes to the native extractor, in the
  /// same queue as [load] because it is the same single codec.
  static Future<List<double>> detail(String path, {int barsPerSecond = 20}) {
    final key = '$path|$barsPerSecond';

    return _details.putIfAbsent(key, () async {
      try {
        final fromWav = await _fine(path, barsPerSecond);
        if (fromWav != null && fromWav.isNotEmpty) return fromWav;

        final seconds = (await duration(path)).inMilliseconds / 1000;
        final count = (seconds * barsPerSecond).round().clamp(120, 6000);

        if (!_hasNativeExtractor) return const <double>[];

        return await _next(() async {
          final controller = aw.PlayerController();
          try {
            final bars = await controller.waveformExtraction
                .extractWaveformData(path: path, noOfSamples: count)
                .timeout(_codecPatience);
            return _normalise(bars);
          } finally {
            controller.dispose();
          }
        });
      } catch (e) {
        // A failure must not be remembered as the answer, or the file could
        // never be read again this session.
        _details.remove(key);
        debugPrint('DETAIL WAVEFORM READ FAILED ($path): $e');
        rethrow;
      }
    });
  }

  /// Whether the phones' native waveform extractor exists on this platform.
  /// `audio_waveforms` builds for Android and iOS only.
  static bool get _hasNativeExtractor => Platform.isAndroid || Platform.isIOS;

  /// A whole file as exactly [count] bars, 0..1, folded down from [fine] -
  /// what [_wavDetail] read of it, at forty slices a second.
  static List<double> _fold(Float32List fine, int count) {
    // Each bar is the loudness of its share, not the loudest moment in
    // it: the loudest moment of any stretch of speech is much the same
    // height, and a strip of those is a flat wall. The average rises and
    // falls with the voice, which is the shape people expect to see.
    //
    // Walked bar by bar rather than slice by slice: a take under six
    // seconds has fewer slices than bars, and handing slices out would
    // leave every third bar with none - a gap in the strip. Here a bar
    // with no slice of its own takes the one it falls inside.
    final bars = List<double>.filled(count, 0);
    for (var i = 0; i < count; i++) {
      final from = i * fine.length ~/ count;
      final to = math.max(from + 1, (i + 1) * fine.length ~/ count);
      var sum = 0.0;
      for (var at = from; at < to; at++) {
        sum += fine[at] * fine[at];
      }
      bars[i] = math.sqrt(sum / (to - from));
    }

    // As tall as the file is loud: 1 for anything with a voice in it,
    // less for one that never rises out of silence (see [_wavDetail]).
    var top = 0.0;
    for (final slice in fine) {
      if (slice > top) top = slice;
    }
    return [for (final bar in _normalise(bars)) bar * top];
  }

  /// Below this a slice is silence: -45 dBFS of a 16-bit sample, the line
  /// QC draws for the same word.
  static const double _silenceLevel = 184.27;

  static List<double> _normalise(List<double> bars) {
    var peak = 0.0;
    for (final bar in bars) {
      if (bar.abs() > peak) peak = bar.abs();
    }
    if (peak <= 0) return List<double>.filled(bars.length, 0);

    return [for (final bar in bars) (bar.abs() / peak).clamp(0.0, 1.0)];
  }

  /// Loudness (RMS) per slice of a 16-bit PCM WAV, or null when the file is
  /// anything else. Runs on its own isolate, which is why the file calls are the
  /// blocking ones: there is no frame here to hold up, and they are quicker.
  static Float32List? _wavDetail((String, int) request) {
    final (path, barsPerSecond) = request;
    RandomAccessFile? file;

    try {
      file = File(path).openSync();

      final layout = _WavLayout.of(file.readSync(4096), file.lengthSync());
      if (layout == null) return null;

      final slices = _Slices(layout, barsPerSecond);
      file.setPositionSync(layout.dataStart);

      while (slices.wanted > 0) {
        if (!slices.add(file.readSync(slices.wanted))) break;
      }
      return slices.finish();
    } catch (_) {
      // Not a reason to fail: the caller tries the native extractor next.
      return null;
    } finally {
      file?.closeSync();
    }
  }

  /// What [_wavDetail] reads, read where it is asked for: the same
  /// slices, the file taken an eighth of a megabyte at a time with the
  /// frame given its turn between one piece and the next. What is left
  /// for a long recording when an isolate does not answer.
  static Future<Float32List?> _wavDetailHere(
    String path,
    int barsPerSecond,
  ) async {
    RandomAccessFile? file;

    try {
      file = await File(path).open();

      final layout = _WavLayout.of(await file.read(4096), await file.length());
      if (layout == null) return null;

      final slices = _Slices(layout, barsPerSecond, chunkBytes: 131072);
      await file.setPosition(layout.dataStart);

      while (slices.wanted > 0) {
        if (!slices.add(await file.read(slices.wanted))) break;
      }
      return slices.finish();
    } catch (_) {
      return null;
    } finally {
      try {
        await file?.close();
      } catch (_) {}
    }
  }

  @visibleForTesting
  static Future<Duration?> debugHeaderDuration(String path) =>
      _headerDuration(path);

  /// A WAV's length, worked out from its header.
  ///
  /// Canonical 16-bit PCM only - the shape this app records and the shape
  /// `WavAnalyzer` grades - and null for anything else, which is the signal
  /// to measure it the slow way.
  static Future<Duration?> _headerDuration(String path) async {
    RandomAccessFile? file;

    try {
      file = await File(path).open();

      // Enough for the header and anything a recorder puts in front of the
      // audio. A file that hides its `data` chunk further in than this is
      // measured the slow way instead.
      final head = await file.read(4096);
      if (head.length < 44 || !WavAnalyzer.isWav(head)) return null;

      // Walked chunk by chunk rather than read at fixed offsets. A canonical
      // WAV puts `fmt ` then `data` in the first 44 bytes, but a file that
      // has been through a converter often carries a `LIST` of metadata in
      // between - and read positionally, that chunk's length is taken for
      // the length of the audio, which is how a twenty-second take came out
      // as some other number entirely.
      var offset = 12;
      var sampleRate = 0;
      var channels = 0;
      var bitsPerSample = 0;

      while (offset + 8 <= head.length) {
        final id = String.fromCharCodes(head.sublist(offset, offset + 4));
        final size = WavAnalyzer.readUint32(head, offset + 4);
        final body = offset + 8;

        if (id == 'fmt ' && body + 16 <= head.length) {
          channels = WavAnalyzer.readUint16(head, body + 2);
          sampleRate = WavAnalyzer.readUint32(head, body + 4);
          bitsPerSample = WavAnalyzer.readUint16(head, body + 14);
        } else if (id == 'data') {
          final bytesPerSecond = sampleRate * channels * (bitsPerSample ~/ 8);
          if (bytesPerSecond <= 0 || size <= 0) return null;

          return Duration(milliseconds: size * 1000 ~/ bytesPerSecond);
        }

        if (size <= 0) return null;
        // Chunks are padded to an even length, and the pad byte is not
        // counted in the size.
        offset = body + size + (size.isOdd ? 1 : 0);
      }

      return null;
    } catch (e) {
      debugPrint('WAV HEADER UNREADABLE ($path): $e');
      return null;
    } finally {
      await file?.close();
    }
  }

  static Future<Duration?> _probeDuration(String path) async {
    final player = AudioBackend();
    try {
      await player.setSource(path);
      return await player.getDuration();
    } catch (e) {
      debugPrint('DURATION PROBE FAILED ($path): $e');
      return null;
    } finally {
      await player.dispose();
    }
  }
}

/// Where a WAV keeps its audio, and in what shape.
class _WavLayout {
  const _WavLayout({
    required this.dataStart,
    required this.dataSize,
    required this.channels,
    required this.sampleRate,
  });

  final int dataStart;
  final int dataSize;
  final int channels;
  final int sampleRate;

  int get frameBytes => channels * 2;
  int get frames => dataSize ~/ frameBytes;

  /// Read off the first of the file, or null when the file is not a
  /// 16-bit PCM WAV with audio in it.
  static _WavLayout? of(Uint8List head, int fileLength) {
    if (head.length < 44 || !WavAnalyzer.isWav(head)) return null;

    // Walked chunk by chunk, for the reason given in
    // [WaveformCache._headerDuration]: a converter's `LIST` chunk sits
    // between `fmt ` and `data`, and audio read from a fixed offset would
    // start in the middle of its metadata.
    var offset = 12;
    var format = 0;
    var sampleRate = 0;
    var channels = 0;
    var bitsPerSample = 0;
    var dataStart = -1;
    var dataSize = 0;

    while (offset + 8 <= head.length) {
      final id = String.fromCharCodes(head.sublist(offset, offset + 4));
      final size = WavAnalyzer.readUint32(head, offset + 4);
      final body = offset + 8;

      if (id == 'fmt ' && body + 16 <= head.length) {
        format = WavAnalyzer.readUint16(head, body);
        channels = WavAnalyzer.readUint16(head, body + 2);
        sampleRate = WavAnalyzer.readUint32(head, body + 4);
        bitsPerSample = WavAnalyzer.readUint16(head, body + 14);
      } else if (id == 'data') {
        dataStart = body;
        dataSize = size;
        break;
      }

      if (size <= 0) return null;
      offset = body + size + (size.isOdd ? 1 : 0);
    }

    // 1 is plain PCM; 0xFFFE is the extensible wrapper some encoders put
    // around the very same samples.
    final isPcm = format == 1 || format == 0xFFFE;
    if (dataStart < 0 || !isPcm || bitsPerSample != 16) return null;
    if (sampleRate <= 0 || channels <= 0) return null;

    // A recorder that was stopped abruptly leaves the size it meant to
    // fill in later as zero, or as all ones. What is actually on disk is
    // the better witness.
    final available = fileLength - dataStart;
    if (dataSize <= 0 || dataSize > available) dataSize = available;
    if (dataSize ~/ (channels * 2) <= 0) return null;

    return _WavLayout(
      dataStart: dataStart,
      dataSize: dataSize,
      channels: channels,
      sampleRate: sampleRate,
    );
  }
}

/// The loudness of a WAV slice by slice, taken in as the file is read.
class _Slices {
  _Slices(this.layout, this.barsPerSecond, {int chunkBytes = 262144})
    : count = (layout.frames * barsPerSecond / layout.sampleRate).ceil().clamp(
        1,
        1 << 22,
      ),
      _stride = math.max(1, layout.sampleRate ~/ (barsPerSecond * _perSlice)),
      _chunkBytes =
          math.max(1, chunkBytes ~/ layout.frameBytes) * layout.frameBytes {
    _sums = Float64List(count);
    _frameCounts = Int32List(count);
  }

  final _WavLayout layout;
  final int barsPerSecond;
  final int count;
  final int _chunkBytes;

  /// How many samples a slice is measured by, or as near as the file's
  /// rate allows. A fortieth of a second holds eleven hundred; how loud
  /// it is can be told from a quarter of them as well as from all, and a
  /// quarter of an hour of source audio is read in a quarter of the time.
  static const int _perSlice = 256;

  /// One frame in this many is measured.
  final int _stride;

  late final Float64List _sums;
  late final Int32List _frameCounts;
  int _frame = 0;

  /// How many bytes to read next; none when the audio has all been read.
  int get wanted =>
      ((layout.frames - _frame) * layout.frameBytes).clamp(0, _chunkBytes);

  /// Takes in the next piece of the file. False when it held nothing, which
  /// is the end of the file come sooner than its header said.
  bool add(Uint8List chunk) {
    final frameBytes = layout.frameBytes;
    final channels = layout.channels;
    final sampleRate = layout.sampleRate;

    final usable = chunk.length - chunk.length % frameBytes;
    if (usable <= 0) return false;

    final framesHere = usable ~/ frameBytes;

    // Read as the numbers they are wherever the machine keeps its numbers
    // the way a WAV does - every phone and every desktop this runs on -
    // which is several times quicker than taking each out of its bytes.
    final plain =
        Endian.host == Endian.little &&
        chunk.offsetInBytes.isEven &&
        chunk.offsetInBytes + usable <= chunk.buffer.lengthInBytes;
    final samples = plain
        ? chunk.buffer.asInt16List(chunk.offsetInBytes, usable ~/ 2)
        : null;
    final data = plain ? null : ByteData.sublistView(chunk, 0, usable);

    // The first frame of this piece that falls on the stride.
    for (
      var i = (_stride - _frame % _stride) % _stride;
      i < framesHere;
      i += _stride
    ) {
      // The loudest channel speaks for the frame. Averaging them lets
      // two out-of-phase tracks cancel into a silence nobody hears.
      var loudest = 0;
      for (var c = 0; c < channels; c++) {
        final at = i * channels + c;
        final sample =
            (samples != null
                    ? samples[at]
                    : data!.getInt16(at * 2, Endian.little))
                .abs();
        if (sample > loudest) loudest = sample;
      }

      final bucket = (_frame + i) * barsPerSecond ~/ sampleRate;
      if (bucket < count) {
        _sums[bucket] += loudest * loudest;
        _frameCounts[bucket]++;
      }
    }
    _frame += framesHere;
    return true;
  }

  /// The loudness of each slice, scaled so the loudest slice is 1 -
  /// unless the loudest is itself silence. A recording the microphone
  /// put nothing into still has a loudest slice, and scaled to that
  /// its hiss stands as tall as a voice: a strip full of bars over a
  /// file with nothing to hear. Measured against the silence level
  /// instead, it draws as what it is.
  Float32List finish() {
    final peaks = Float32List(count);
    var top = 0.0;
    for (var i = 0; i < count; i++) {
      if (_frameCounts[i] > 0) {
        peaks[i] = math.sqrt(_sums[i] / _frameCounts[i]);
        if (peaks[i] > top) top = peaks[i];
      }
    }
    final scale = math.max(top, WaveformCache._silenceLevel);
    for (var i = 0; i < count; i++) {
      peaks[i] = peaks[i] / scale;
    }
    return peaks;
  }
}

/// The bars of recordings read on earlier days, kept on the disk.
///
/// A recording's bars are a kilobyte; reading them off a quarter of an
/// hour of source audio is every sample of it, every time the app is
/// opened. Kept under the recording's path, size and date, so a file
/// that has been recorded over or trimmed is read afresh. In the
/// temporary folder: the phone may clear it, and nothing is lost but
/// the reading.
class _WaveStore {
  _WaveStore._();

  static const String folderName = 'waves';

  /// "OBW" and the version of the bars. Changed whenever the bars are
  /// worked out differently, so what was kept by the old way is not
  /// drawn as though by the new.
  static const int _magic = 0x4F425701;

  /// The folder, once it has been found. The phone is asked where its
  /// temporary folder is only the once.
  static Directory? _folder;
  static Future<void>? _preparing;

  static Future<void> prepare() => _preparing ??= () async {
    try {
      final folder = Directory(
        p.join((await getTemporaryDirectory()).path, folderName),
      );
      await folder.create(recursive: true);
      _folder = folder;
      unawaited(_sweep(folder));
    } catch (e) {
      // Nowhere to keep them, as in a test. Every file is read instead.
      debugPrint('WAVEFORMS ARE NOT KEPT: $e');
    }
  }();

  /// Where the bars of [path] are kept, or would be. Null when there is
  /// nowhere, or no such recording.
  static File? _fileFor(String path) {
    final folder = _folder;
    if (folder == null) return null;

    final stat = File(path).statSync();
    if (stat.type == FileSystemEntityType.notFound) return null;

    var hash = 0x811c9dc5;
    for (final unit in path.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return File(
      p.join(
        folder.path,
        '${hash.toRadixString(16)}-${stat.size}-'
        '${stat.modified.millisecondsSinceEpoch}.bars',
      ),
    );
  }

  static Future<ClipAudio?> read(String path) async {
    await prepare();
    return readNow(path);
  }

  /// Read there and then: a kilobyte, which is not worth a wait.
  static ClipAudio? readNow(String path) {
    try {
      final file = _fileFor(path);
      if (file == null || !file.existsSync()) return null;

      final bytes = file.readAsBytesSync();
      if (bytes.length < 16) return null;

      final data = ByteData.sublistView(bytes);
      if (data.getUint32(0) != _magic) return null;

      final count = data.getUint32(8);
      if (count == 0 || bytes.length != 12 + count * 4) return null;

      return ClipAudio(
        bars: [for (var i = 0; i < count; i++) data.getFloat32(12 + i * 4)],
        duration: Duration(milliseconds: data.getUint32(4)),
      );
    } catch (e) {
      debugPrint('KEPT WAVEFORM UNREADABLE ($path): $e');
      return null;
    }
  }

  static Future<void> write(String path, ClipAudio audio) async {
    try {
      await prepare();
      final file = _fileFor(path);
      if (file == null) return;

      // Signed out in the meantime, and the folder went with everything
      // else.
      await file.parent.create(recursive: true);

      final data = ByteData(12 + audio.bars.length * 4)
        ..setUint32(0, _magic)
        ..setUint32(4, audio.duration.inMilliseconds.clamp(0, 0xffffffff))
        ..setUint32(8, audio.bars.length);
      for (var i = 0; i < audio.bars.length; i++) {
        data.setFloat32(12 + i * 4, audio.bars[i]);
      }

      // Written beside and swapped in, so a half-written file is never
      // one that is read.
      final part = File('${file.path}.part');
      await part.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('WAVEFORM NOT KEPT ($path): $e');
    }
  }

  /// Drops what has not been written for a month: the bars of recordings
  /// that have since been replaced, or are no longer on the phone.
  static Future<void> _sweep(Directory folder) async {
    try {
      final old = DateTime.now().subtract(const Duration(days: 30));
      await for (final entry in folder.list()) {
        if (entry is! File) continue;
        if ((await entry.stat()).modified.isBefore(old)) await entry.delete();
      }
    } catch (e) {
      debugPrint('WAVEFORMS NOT SWEPT: $e');
    }
  }
}
