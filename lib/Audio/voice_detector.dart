import 'dart:math';
import 'dart:typed_data';

/// Where in a recording somebody is speaking.
///
/// One entry for each of the analyzer's windows, in order.
class VoiceMap {
  const VoiceMap({required this.voiced, required this.speech});

  /// The windows that are voice itself: the sung part of a syllable.
  final List<bool> voiced;

  /// The windows that are somebody speaking: [voiced], and the short
  /// stretches between - the consonants, and the breath between words.
  final List<bool> speech;

  /// The first and last windows of speech; null when there is none.
  int? get first {
    final at = speech.indexOf(true);
    return at < 0 ? null : at;
  }

  int? get last {
    final at = speech.lastIndexOf(true);
    return at < 0 ? null : at;
  }

  int get speechWindows => speech.where((window) => window).length;
}

/// Tells a voice from everything else a microphone hears.
///
/// Loudness cannot. A recording made in an ordinary room with nobody
/// speaking is louder than its own quietest moments a quarter of the time
/// - a fan, a chair, a door down the hall - and measured by loudness alone
/// that quarter was counted as speech.
///
/// What a voice has that those do not is pitch: the sound repeats itself
/// 70 to 400 times a second, as the vocal cords open and close. So each
/// short stretch is laid over itself, shifted by every delay in that
/// range, and how well the best of them matches says how voice-like the
/// stretch is. Hiss, rustle, knocks and hum of the room match badly.
///
/// And a voice being recorded is near the microphone. The same test finds
/// the voices in the next room, which are nobody's take, so a stretch has
/// to be loud enough as well: [minLevelDb].
///
/// The figures were settled on recordings, not chosen: 44 source
/// recordings and takes from the server came out at 70-94% speech, a
/// 36-second take made on a Moto G9 with nobody speaking at 2%, and a
/// silent one at none.
class VoiceDetector {
  VoiceDetector._();

  /// Pitch is found as well at 8 kHz as at 44.1, in a sixth of the work.
  static const int _rate = 8000;

  /// 40 ms looked at, every 20 ms: long enough to hold three turns of the
  /// lowest voice, and in step with the analyzer's windows.
  static const int _frame = 320;
  static const int _hop = 160;

  /// The delays that are pitches of a voice: 400 Hz down to 70 Hz.
  static const int _shortestLag = _rate ~/ 400;
  static const int _longestLag = _rate ~/ 70;

  /// How well a stretch has to match itself, 0 to 1.
  static const double _minMatch = 0.55;

  /// Three in a row, 60 ms, or it is a click that happened to ring.
  static const int _minRun = 3;

  /// Runs of voice this close together, 0.3 s, are one phrase.
  static const int _bridge = 15;

  static VoiceMap detect(
    Float64List samples,
    int sampleRate, {
    required int windows,
    double minLevelDb = -40,
  }) {
    final low = _to8k(samples, sampleRate);
    final count = low.length < _frame ? 0 : (low.length - _frame) ~/ _hop + 1;

    final hit = List<bool>.filled(windows, false);
    final frame = Float64List(_frame);
    final squares = Float64List(_frame + 1);
    final quietest = pow(10, minLevelDb / 10) * _frame;

    for (var i = 0; i < count && i < windows; i++) {
      final from = i * _hop;
      var mean = 0.0;
      for (var k = 0; k < _frame; k++) {
        mean += low[from + k];
      }
      mean /= _frame;

      // The running total of squares gives the loudness of any part of
      // the stretch without adding it up again for every delay.
      for (var k = 0; k < _frame; k++) {
        final value = low[from + k] - mean;
        frame[k] = value;
        squares[k + 1] = squares[k] + value * value;
      }
      // Too quiet to be the reader, whatever it is: not looked at further.
      if (squares[_frame] < quietest) continue;

      for (var lag = _shortestLag; lag <= _longestLag; lag++) {
        final length = _frame - lag;
        var dot = 0.0;
        for (var k = 0; k < length; k++) {
          dot += frame[k] * frame[k + lag];
        }
        final scale = sqrt(squares[length] * (squares[_frame] - squares[lag]));
        if (scale > 0 && dot / scale >= _minMatch) {
          hit[i] = true;
          break;
        }
      }
    }

    // Runs long enough to be voice, and what lies between near neighbours.
    final voiced = List<bool>.filled(windows, false);
    final speech = List<bool>.filled(windows, false);
    int? lastEnd;
    var at = 0;
    while (at < windows) {
      if (!hit[at]) {
        at++;
        continue;
      }
      var end = at;
      while (end < windows && hit[end]) {
        end++;
      }
      if (end - at >= _minRun) {
        final bridgeFrom = lastEnd != null && at - lastEnd <= _bridge
            ? lastEnd
            : at;
        for (var k = bridgeFrom; k < end; k++) {
          speech[k] = true;
        }
        for (var k = at; k < end; k++) {
          voiced[k] = true;
        }
        lastEnd = end;
      }
      at = end;
    }

    return VoiceMap(voiced: voiced, speech: speech);
  }

  /// [samples] at 8 kHz, each new sample the average of the ones it
  /// stands for - which is also what keeps the higher sounds from
  /// folding down into the range a voice's pitch is looked for in.
  static Float64List _to8k(Float64List samples, int sampleRate) {
    final step = sampleRate / _rate;
    final length = (samples.length / step).floor();
    final out = Float64List(length);

    for (var i = 0; i < length; i++) {
      final from = (i * step).floor();
      final to = min(samples.length, max(from + 1, ((i + 1) * step).floor()));
      var sum = 0.0;
      for (var k = from; k < to; k++) {
        sum += samples[k];
      }
      out[i] = sum / (to - from);
    }
    return out;
  }
}
