import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:get/get.dart' show Trans;

import 'package:livuka/Audio/voice_detector.dart';
import 'package:livuka/services/qc_feedback.dart';

/// Thresholds for the automated QC checks.
///
/// The limits are the web app's, figure for figure. What they are applied
/// to is not: the website measures loudness, and calls speech whatever is
/// louder than the room. Here the voice is found first ([VoiceDetector])
/// and the rest is judged against it - the silence before the first word
/// and after the last, the room between the words, the noises that are
/// not the reader. Clipping, duration, format and truncation have nothing
/// to do with who is speaking, and are the website's still.
class AudioQcConfig {
  const AudioQcConfig({
    this.expectedDurationSeconds,
    this.clippingCeiling = 0.98,
    this.clippedSampleFraction = 0.0005,
    this.minClippedSamples = 10,
    this.windowMs = 20,
    this.silenceThresholdDb = -45,
    this.maxEdgeSilenceSeconds = 1.5,
    this.noiseFloorThresholdDb = -42,
    this.noiseFloorWindowFloorDb = -80,
    this.noiseFloorWindowCeilingDb = -15,
    this.noiseFloorQuietestFraction = 0.3,
    this.minDurationRatio = 0.5,
    this.maxDurationRatio = 2.0,
    this.minDurationSeconds = 1.5,
    this.maxDurationSecondsWithoutSource = 180,
    this.allowedSampleRates = const {44100, 48000, 32000, 22050, 16000},
    this.allowedChannels = const {1, 2},
    this.truncationTailSeconds = 0.15,
    this.truncationThresholdDb = -32,
    this.voiceAboveFloorDb = 8,
    this.minVoiceLevelDb = -40,
    this.minVoiceActiveFraction = 0.10,
    this.minActiveWindowsForVolumeCheck = 10,
    this.volumeConsistencySpreadDb = 18,
    this.enhancedQc = false,
    this.noiseSpikeAboveMedianDb = 15,
    this.noiseSpikeMinWindows = 3,
    this.maxNoiseSpikeSeconds = 0.5,
  });

  /// How long the source recording runs, when this device has it.
  final double? expectedDurationSeconds;

  /// Normalized amplitude at which a sample counts as clipped.
  final double clippingCeiling;

  /// Share of samples allowed to clip before the check fails, with a floor so
  /// a very short clip is not held to an impossibly small count.
  final double clippedSampleFraction;
  final int minClippedSamples;

  /// Everything measured in windows uses this length.
  final int windowMs;
  final double silenceThresholdDb;
  final double maxEdgeSilenceSeconds;

  final double noiseFloorThresholdDb;

  /// Windows quieter than this are digital silence, louder than this are
  /// speech - neither says anything about the room.
  final double noiseFloorWindowFloorDb;
  final double noiseFloorWindowCeilingDb;
  final double noiseFloorQuietestFraction;

  /// A translation of a passage runs to roughly the source's length: at least
  /// half of it, at most twice.
  final double minDurationRatio;
  final double maxDurationRatio;
  final double minDurationSeconds;
  final double maxDurationSecondsWithoutSource;

  final Set<int> allowedSampleRates;
  final Set<int> allowedChannels;

  final double truncationTailSeconds;
  final double truncationThresholdDb;

  /// Kept for the record of the website's rule, which counted as speech
  /// any window this far over the take's own noise floor. Not used: see
  /// [VoiceDetector].
  final double voiceAboveFloorDb;

  /// Voice detected: how loud a voice has to be to be the reader's, and
  /// how much of the take has to be one. A voice at the phone is tens of
  /// decibels over this line; the voices in the next room are under it.
  final double minVoiceLevelDb;
  final double minVoiceActiveFraction;

  /// Less voice than this, in seconds, is none at all: the person is told
  /// to speak, not that they spoke too little.
  double get noVoiceSeconds => 0.5;

  /// Background noise: a sound that is not the voice counts once it is
  /// within this many decibels of the voice's own level. Quieter than
  /// that it is the room, which the noise floor answers for.
  double get noiseNearVoiceDb => 10;

  /// A noise this close to a word is taken for part of it - the hiss that
  /// ends one, the breath before the next.
  double get noisePaddingSeconds => 0.2;

  /// Volume consistency: the spread between the quietest and loudest
  /// "normal" stretches of speech (10th to 90th percentile), judged only
  /// once there is enough speech to judge.
  final int minActiveWindowsForVolumeCheck;
  final double volumeConsistencySpreadDb;

  /// The project's `enhanced_qc` setting: adds the Background noise check,
  /// which is the one most likely to mistake an emphatic word for noise.
  final bool enhancedQc;

  /// Background noise: a stretch this far above the median speaking level,
  /// lasting at least this many consecutive windows, is a spike; spikes
  /// adding up to more than this many seconds fail the take.
  final double noiseSpikeAboveMedianDb;
  final int noiseSpikeMinWindows;
  final double maxNoiseSpikeSeconds;

  /// Shorter than this and the take is refused before QC runs at all - the
  /// same rule the web app and the server apply.
  static const double minimumTakeSeconds = 5;
}

/// One check's verdict.
///
/// [detail] is an English sentence with `@name` holes and [params] what
/// fills them - kept apart because the checks run in a background isolate,
/// where the interface language is not to hand. The screen reads [shown],
/// in the app's language; the log and the server get [english].
class QcCheckResult {
  const QcCheckResult({
    required this.key,
    required this.label,
    required this.passed,
    required this.detail,
    this.params = const {},
  });

  final String key;
  final String label;
  final bool passed;
  final String detail;
  final Map<String, String> params;

  /// What the screen says under the check's name: what it found and, on
  /// a fail, what to do next time - in the app's language. The measured
  /// detail only for a check [QcFeedback] has no words for.
  String get shown {
    final feedback = QcFeedback.of(key, passed: passed);
    return feedback.isEmpty ? detail.trParams(params) : feedback;
  }

  /// The detail in English, for the log and the report sent to the server.
  String get english {
    var text = detail;
    for (final entry in params.entries) {
      text = text.replaceAll('@${entry.key}', entry.value);
    }
    return text;
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'label': label,
    'detail': english,
    'status': passed ? 'pass' : 'fail',
    // Kept beside the English, so a report read back off the take can
    // still be shown in the reader's language.
    'template': detail,
    'params': params,
  };
}

class AudioQcResult {
  const AudioQcResult({required this.checks, required this.metrics});

  final List<QcCheckResult> checks;
  final Map<String, dynamic> metrics;

  int get failedCount => checks.where((check) => !check.passed).length;

  /// Nothing wrong is a pass; one problem is worth a second listen; two is a
  /// recording to do again. A take with no speech in it is unusable
  /// outright, whatever else it passes.
  String get status {
    final noVoice = checks.any(
      (check) => check.key == 'voice_presence' && !check.passed,
    );
    if (noVoice) return 'Bad';
    return switch (failedCount) {
      0 => 'Good',
      1 => 'Average',
      _ => 'Bad',
    };
  }

  bool get allPassed => failedCount == 0;

  /// The stored report, in the shape the server sends one.
  Map<String, dynamic> toJson() => {
    'checks': [for (final check in checks) check.toJson()],
    'status': status,
    'metrics': metrics,
    'checkedAt': DateTime.now().toUtc().toIso8601String(),
  };
}

/// Reads a 16-bit PCM WAV and grades it.
///
/// Only that format is supported, which is why everything is converted to it
/// on the way in: the checks read raw samples, and there is no decoder here
/// for anything else.
class WavAnalyzer {
  static Future<AudioQcResult> analyze(
    String path, {
    AudioQcConfig config = const AudioQcConfig(),
  }) async {
    final bytes = await File(path).readAsBytes();

    if (bytes.length < 44) throw Exception('Invalid WAV file');
    if (!isWav(bytes)) throw Exception('File is not a WAV file');

    // The `fmt ` chunk is found by walking the chunks, not read at byte
    // 20: Media Foundation - the Windows recorder - writes a JUNK chunk
    // ahead of it, and read positionally that padding came out as a
    // nonsense sample format, so every take recorded on Windows was
    // refused as "not a WAV" and thrown away.
    final format = _formatChunk(bytes);
    if (format == null) throw Exception('WAV header has no format chunk');
    final channels = format.channels;
    final sampleRate = format.sampleRate;
    final bitsPerSample = format.bitsPerSample;

    if (bitsPerSample != 16) {
      throw Exception('This analyzer expects 16-bit PCM WAV audio');
    }
    if (sampleRate <= 0 || channels <= 0) {
      throw Exception('WAV header reports no audio');
    }

    // One pass over the raw bytes: the mono frames, the peak and the
    // clipped count all come out of it. A few minutes of audio is millions
    // of samples, and building boxed lists of them one by one - then
    // walking those lists again per check - was most of the wait behind
    // "Checking audio...".
    final decoded = _decode(_dataChunk(bytes), channels, config);
    final sampleCount = decoded.sampleCount;
    if (sampleCount == 0) throw Exception('No audio samples found');

    // Everything after this point works on one channel: a stereo recording is
    // one performance in two tracks, and its silence, noise and clipping are
    // properties of the performance.
    final frames = decoded.frames;
    final durationSeconds = frames.length / sampleRate;
    final windows = _windowLevelsDb(frames, sampleRate, config.windowMs);

    final peakDb = _toDb(decoded.peak);

    // Every figure is rounded where the website rounds it, and judged
    // after the rounding as it is there: a take sitting on a limit must
    // not pass on one side and fail on the other.
    final clipped = decoded.clipped;
    final clippedPct = _round(clipped / sampleCount * 100, 3);

    // The voice first. Everything below that depends on who is speaking
    // is measured against it.
    final map = VoiceDetector.detect(
      frames,
      sampleRate,
      windows: windows.length,
      minLevelDb: config.minVoiceLevelDb,
    );
    final windowSeconds = config.windowMs / 1000;
    final first = map.first;
    final last = map.last;

    // From the start to the first word, and from the last word to the
    // end. With no voice, the whole take is both.
    final leadingSilence = first == null
        ? durationSeconds
        : first * windowSeconds;
    final trailingSilence = last == null
        ? durationSeconds
        : max(0.0, (windows.length - 1 - last) * windowSeconds);

    // The room is measured as the website measures it: the quietest
    // part of the take is the room whoever is speaking.
    final noiseFloorDb = _noiseFloorDb(windows, config);
    final tailDb = _tailLevelDb(windows, config);

    final voice = (
      windows: map.speechWindows,
      fraction: windows.isEmpty ? 0.0 : map.speechWindows / windows.length,
      seconds: map.speechWindows * windowSeconds,
    );
    // With too little voice to call it a take, there is nothing to
    // compare its volume or its noises against.
    final heard = voice.fraction >= config.minVoiceActiveFraction;
    final voiceLevels = [
      if (heard)
        for (var i = 0; i < windows.length; i++)
          if (map.voiced[i]) windows[i],
    ]..sort();
    final spreadDb = _volumeSpreadDb(voiceLevels, config);
    final spike = config.enhancedQc
        ? _otherNoise(windows, map, voiceLevels, config)
        : null;

    final checks = <QcCheckResult>[
      _clipping(peakDb, clipped, clippedPct, sampleCount, config),
      _edgeSilence(leadingSilence, trailingSilence, config),
      _noiseFloor(noiseFloorDb, config),
      _duration(durationSeconds, config),
      _sampleFormat(sampleRate, channels, config),
      _truncation(tailDb, config),
      _voicePresence(voice, config),
      _volumeConsistency(spreadDb, config),
      if (spike != null) _backgroundNoise(spike, config),
    ];

    return AudioQcResult(
      checks: checks,
      metrics: {
        'sampleRate': sampleRate,
        'durationSec': _round(durationSeconds, 2),
        'numChannels': channels,
        'noiseFloorDb': noiseFloorDb,
        'peakVolumeDb': _round(peakDb, 1),
        'tailEnergyDb': tailDb,
        'clippedSamplePct': clippedPct,
        'leadingSilenceSec': _round(leadingSilence, 2),
        'trailingSilenceSec': _round(trailingSilence, 2),
        'voiceActiveSeconds': _round(voice.seconds, 2),
        'volumeSpreadDb': spreadDb,
        if (spike != null) ...{
          'medianSpeechDb': spike.medianDb,
          // Nothing to measure is no figure, as the website stores it -
          // not a zero, which would say it was measured and found clean.
          'noiseSpikeSeconds': spike.medianDb == null ? null : spike.seconds,
        },
      },
    );
  }

  // ---- the checks --------------------------------------------------------

  static QcCheckResult _clipping(
    double peakDb,
    int clipped,
    double clippedPct,
    int totalSamples,
    AudioQcConfig config,
  ) {
    final allowed = max(
      config.minClippedSamples,
      (totalSamples * config.clippedSampleFraction).round(),
    );

    return QcCheckResult(
      key: 'clipping',
      label: 'Clipping',
      passed: clipped <= allowed,
      detail: 'Peak @peak dBFS, @pct% samples at/near full scale',
      params: {'peak': peakDb.toStringAsFixed(1), 'pct': _pct(clippedPct)},
    );
  }

  static QcCheckResult _edgeSilence(
    double leading,
    double trailing,
    AudioQcConfig config,
  ) {
    final limit = config.maxEdgeSilenceSeconds;

    return QcCheckResult(
      key: 'edge_silence',
      label: 'Head / tail silence',
      passed: leading <= limit && trailing <= limit,
      detail:
          '@before before the first word, @after after the last '
          '(limit @limit)',
      params: {
        'before': '${leading.toStringAsFixed(2)}s',
        'after': '${trailing.toStringAsFixed(2)}s',
        'limit': '${limit.toStringAsFixed(1)}s',
      },
    );
  }

  static QcCheckResult _noiseFloor(double? level, AudioQcConfig config) {
    // Nothing sat between digital silence and speech, so there is no
    // background to measure - which is not a fault of the recording.
    if (level == null) {
      return const QcCheckResult(
        key: 'noise_floor',
        label: 'Noise floor',
        passed: true,
        detail:
            'Recording is too uniform to isolate a background level - '
            'treated as clean',
      );
    }

    return QcCheckResult(
      key: 'noise_floor',
      label: 'Noise floor',
      passed: level <= config.noiseFloorThresholdDb,
      detail: 'Background level @level dBFS (limit @limit dBFS)',
      params: {
        'level': level.toStringAsFixed(1),
        'limit': config.noiseFloorThresholdDb.toStringAsFixed(0),
      },
    );
  }

  static QcCheckResult _duration(double seconds, AudioQcConfig config) {
    final source = config.expectedDurationSeconds;

    final minimum = source == null || source <= 0
        ? config.minDurationSeconds
        : max(config.minDurationSeconds, source * config.minDurationRatio);
    final maximum = source == null || source <= 0
        ? config.maxDurationSecondsWithoutSource
        : source * config.maxDurationRatio;

    final range =
        '${minimum.toStringAsFixed(1)}-${maximum.toStringAsFixed(1)}s';

    return QcCheckResult(
      key: 'duration',
      label: 'Duration',
      passed: seconds >= minimum && seconds <= maximum,
      detail: source == null || source <= 0
          ? '@seconds recorded. No source audio to compare against, '
                'expected roughly @range'
          : '@seconds recorded. Source audio is @source, expected roughly '
                '@range',
      params: {
        'seconds': '${seconds.toStringAsFixed(1)}s',
        'source': '${(source ?? 0).toStringAsFixed(1)}s',
        'range': range,
      },
    );
  }

  static QcCheckResult _sampleFormat(
    int sampleRate,
    int channels,
    AudioQcConfig config,
  ) {
    return QcCheckResult(
      key: 'sample_format',
      label: 'Sample rate / channels',
      passed:
          config.allowedSampleRates.contains(sampleRate) &&
          config.allowedChannels.contains(channels),
      detail: channels == 1 ? '@rate Hz, 1 channel' : '@rate Hz, @channels channels',
      params: {'rate': '$sampleRate', 'channels': '$channels'},
    );
  }

  static QcCheckResult _truncation(double tailDb, AudioQcConfig config) {
    return QcCheckResult(
      key: 'truncation',
      label: 'Truncation',
      // Still loud at the very end means the recording was cut off while
      // someone was speaking, rather than trailing into silence.
      passed: tailDb <= config.truncationThresholdDb,
      detail: 'Last @tail at @level dBFS (limit @limit dBFS)',
      params: {
        'tail': '${config.truncationTailSeconds}s',
        'level': tailDb.toStringAsFixed(1),
        'limit': config.truncationThresholdDb.toStringAsFixed(0),
      },
    );
  }

  /// What the report says of a take with nobody speaking in it.
  static const String noVoiceDetail =
      'No voice was detected in this recording - speak clearly, close to '
      'the phone, and record again';

  static QcCheckResult _voicePresence(
    ({int windows, double fraction, double seconds}) voice,
    AudioQcConfig config,
  ) {
    final passed = voice.fraction >= config.minVoiceActiveFraction;
    final params = {
      'seconds': '${voice.seconds.toStringAsFixed(2)}s',
      'pct': '${(voice.fraction * 100).round()}',
    };

    return QcCheckResult(
      key: 'voice_presence',
      label: 'Voice detected',
      passed: passed,
      detail: passed
          ? '@seconds (@pct%) of this take is a voice'
          : voice.seconds < config.noVoiceSeconds
          ? noVoiceDetail
          : 'Only @seconds (@pct%) of this take is a voice - speak clearly, '
                'close to the phone, and record again',
      params: params,
    );
  }

  static QcCheckResult _volumeConsistency(
    double? spreadDb,
    AudioQcConfig config,
  ) {
    if (spreadDb == null) {
      return const QcCheckResult(
        key: 'volume_consistency',
        label: 'Volume consistency',
        passed: true,
        detail: 'Not enough speech detected to judge volume consistency',
      );
    }

    final passed = spreadDb <= config.volumeConsistencySpreadDb;
    return QcCheckResult(
      key: 'volume_consistency',
      label: 'Volume consistency',
      passed: passed,
      detail: passed
          ? 'Speech volume ranged @spread dB across the take (limit @limit '
                'dB) - stays fairly even throughout'
          : 'Speech volume ranged @spread dB across the take (limit @limit '
                'dB) - volume changes noticeably partway through',
      params: {
        'spread': spreadDb.toStringAsFixed(1),
        'limit': config.volumeConsistencySpreadDb.toStringAsFixed(0),
      },
    );
  }

  static QcCheckResult _backgroundNoise(
    ({double? medianDb, double seconds}) spike,
    AudioQcConfig config,
  ) {
    if (spike.medianDb == null) {
      return const QcCheckResult(
        key: 'background_noise',
        label: 'Background noise',
        passed: true,
        detail: 'Not enough speech detected to judge background noise',
      );
    }

    final passed = spike.seconds <= config.maxNoiseSpikeSeconds;
    return QcCheckResult(
      key: 'background_noise',
      label: 'Background noise',
      passed: passed,
      detail: spike.seconds > 0
          ? 'Found @seconds of sound that is not the voice and is about as '
                'loud (limit @limit) - have a listen, this may be background '
                'noise'
          : 'No other sound near the level of the voice',
      params: {
        'seconds': '${spike.seconds.toStringAsFixed(2)}s',
        'limit': '${config.maxNoiseSpikeSeconds}s',
      },
    );
  }

  // ---- measurements ------------------------------------------------------

  /// The spread of the voice's level, 10th to 90th percentile of the
  /// windows that are voice ([active], sorted). Null with too little of it.
  static double? _volumeSpreadDb(List<double> active, AudioQcConfig config) {
    if (active.length < config.minActiveWindowsForVolumeCheck) return null;
    final last = active.length - 1;
    final p10 = active[(last * 0.10).floor()];
    final p90 = active[(last * 0.90).floor()];
    return _round(p90 - p10, 1);
  }

  /// Seconds of sound that is not the reader and is loud enough to be
  /// heard over them: a door, a horn, somebody else in the room.
  ///
  /// Two kinds. Anything that is not speech - nor close enough to a word
  /// to be the end of it - and within [AudioQcConfig.noiseNearVoiceDb] of
  /// the voice's level. And, as the website has it, anything far louder
  /// than the voice at all, since a bang over a word is still a bang. A
  /// run shorter than [AudioQcConfig.noiseSpikeMinWindows] is a click,
  /// and is not counted.
  static ({double? medianDb, double seconds}) _otherNoise(
    List<double> windows,
    VoiceMap map,
    List<double> voiceLevels,
    AudioQcConfig config,
  ) {
    if (voiceLevels.isEmpty) return (medianDb: null, seconds: 0.0);

    final mid = voiceLevels.length ~/ 2;
    final median = _round(
      voiceLevels.length.isEven
          ? (voiceLevels[mid - 1] + voiceLevels[mid]) / 2
          : voiceLevels[mid],
      1,
    );
    final near = median - config.noiseNearVoiceDb;
    final over = median + config.noiseSpikeAboveMedianDb;

    // Speech, and a little either side of it.
    final padding = (config.noisePaddingSeconds * 1000 / config.windowMs)
        .round();
    final spoken = List<bool>.filled(windows.length, false);
    for (var i = 0; i < windows.length; i++) {
      if (!map.speech[i]) continue;
      final to = min(windows.length - 1, i + padding);
      for (var k = max(0, i - padding); k <= to; k++) {
        spoken[k] = true;
      }
    }

    var seconds = 0.0;
    var run = 0;
    void close() {
      if (run >= config.noiseSpikeMinWindows) {
        seconds += run * config.windowMs / 1000;
      }
      run = 0;
    }

    for (var i = 0; i < windows.length; i++) {
      final level = windows[i];
      if ((!spoken[i] && level >= near) || level > over) {
        run++;
      } else {
        close();
      }
    }
    close();

    return (medianDb: median, seconds: _round(seconds, 2));
  }

  /// Level of each fixed-length window, in dBFS.
  static List<double> _windowLevelsDb(
    Float64List frames,
    int sampleRate,
    int windowMs,
  ) {
    final size = max(1, (sampleRate * windowMs / 1000).round());
    final levels = <double>[];

    // The last window is kept even when it is short, as the website does.
    for (var start = 0; start < frames.length; start += size) {
      final end = min(frames.length, start + size);
      var sumSquares = 0.0;
      for (var i = start; i < end; i++) {
        sumSquares += frames[i] * frames[i];
      }
      levels.add(_toDb(sqrt(sumSquares / (end - start))));
    }

    return levels;
  }

  /// The room, as heard in the quietest windows that still hold something:
  /// the mean of the quietest 30% of them, that share rounded up.
  static double? _noiseFloorDb(List<double> windows, AudioQcConfig config) {
    final candidates =
        windows
            .where(
              (level) =>
                  level >= config.noiseFloorWindowFloorDb &&
                  level < config.noiseFloorWindowCeilingDb,
            )
            .toList()
          ..sort();

    if (candidates.isEmpty) return null;

    final take = max(
      1,
      (candidates.length * config.noiseFloorQuietestFraction).ceil(),
    );
    final quietest = candidates.take(take);

    return _round(quietest.reduce((a, b) => a + b) / take, 1);
  }

  /// The end of the take, as the website hears it: the mean of the levels
  /// of its last windows - 0.15 s of 20 ms windows is eight of them - and
  /// not the level of those samples taken together. One loud window among
  /// quiet ones weighs an eighth here; taken together it would be nearly
  /// all of the figure, and fail a take the website passes.
  static double _tailLevelDb(List<double> windows, AudioQcConfig config) {
    final count = max(
      1,
      (config.truncationTailSeconds / (config.windowMs / 1000)).round(),
    );
    final tail = windows.sublist(max(0, windows.length - count));

    return _round(tail.reduce((a, b) => a + b) / tail.length, 1);
  }

  // ---- reading the file --------------------------------------------------

  /// The samples, whatever chunks the encoder put before them.
  ///
  /// The `fmt ` chunk's fields, wherever the encoder put the chunk.
  static ({int channels, int sampleRate, int bitsPerSample})? _formatChunk(
    Uint8List bytes,
  ) {
    var offset = 12;

    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = readUint32(bytes, offset + 4);
      final start = offset + 8;

      if (id == 'fmt ' && start + 16 <= bytes.length) {
        return (
          channels: readUint16(bytes, start + 2),
          sampleRate: readUint32(bytes, start + 4),
          bitsPerSample: readUint16(bytes, start + 14),
        );
      }

      offset = start + size + (size.isOdd ? 1 : 0);
    }

    return null;
  }

  /// ffmpeg writes a LIST chunk into its output, so the data does not always
  /// begin at byte 44 - reading from there would take metadata for audio.
  static Uint8List _dataChunk(Uint8List bytes) {
    var offset = 12;

    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = readUint32(bytes, offset + 4);
      final start = offset + 8;

      if (id == 'data') {
        final end = min(bytes.length, start + size);
        return bytes.sublist(start, end);
      }

      // Chunks are word-aligned, so an odd size carries a pad byte.
      offset = start + size + (size.isOdd ? 1 : 0);
    }

    return bytes.sublist(min(44, bytes.length));
  }

  /// The 16-bit little-endian samples as mono frames normalized to -1..1,
  /// with the peak and the clipped-sample count gathered on the same pass.
  static _Decoded _decode(
    Uint8List pcmBytes,
    int channels,
    AudioQcConfig config,
  ) {
    final data = ByteData.sublistView(pcmBytes);
    final sampleCount = pcmBytes.length ~/ 2;
    final frameCount = sampleCount ~/ channels;
    final frames = Float64List(frameCount);
    final ceiling = config.clippingCeiling * 32768;

    var peak = 0.0;
    var clipped = 0;
    var offset = 0;

    for (var f = 0; f < frameCount; f++) {
      var sum = 0;
      for (var c = 0; c < channels; c++) {
        final sample = data.getInt16(offset, Endian.little);
        offset += 2;
        sum += sample;
        // The peak is the loudest sample on any channel, not of the mix:
        // two channels can cancel in the mix and still have clipped.
        final magnitude = sample.abs() / 32768;
        if (magnitude > peak) peak = magnitude;
        if (sample.abs() >= ceiling) clipped++;
      }
      frames[f] = sum / channels / 32768;
    }

    return _Decoded(
      frames: frames,
      sampleCount: sampleCount,
      peak: peak,
      clipped: clipped,
    );
  }

  static bool isWav(Uint8List bytes) {
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    return riff == 'RIFF' && wave == 'WAVE';
  }

  static int readUint16(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int readUint32(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  /// dBFS of a normalized amplitude. Digital silence has no decibel value, so
  /// it is reported at the bottom of a 16-bit scale rather than as infinity
  /// - the website's figure, which the truncation check averages in.
  static double _toDb(double amplitude) {
    if (amplitude <= 0.0000001) return -96;
    return 20 * log(amplitude) / ln10;
  }

  static double _round(double value, int places) {
    final factor = pow(10, places);
    return (value * factor).round() / factor;
  }

  static String _pct(double value) {
    if (value == 0) return '0';
    if (value < 0.01) return value.toStringAsFixed(4);
    return value.toStringAsFixed(2);
  }
}

class _Decoded {
  const _Decoded({
    required this.frames,
    required this.sampleCount,
    required this.peak,
    required this.clipped,
  });

  final Float64List frames;
  final int sampleCount;
  final double peak;
  final int clipped;
}
