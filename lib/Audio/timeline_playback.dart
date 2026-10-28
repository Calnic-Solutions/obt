import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Audio/audio_backend.dart';
import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/Audio/waveform_cache.dart';
import 'package:livuka/services/services.dart';

/// One passage's final take, as a piece of the whole recording.
class AudioSegment {
  const AudioSegment({
    required this.leafId,
    required this.label,
    required this.path,
    this.unavailable,
  });

  final String leafId;
  final String label;
  final String path;

  /// Why this passage has no audio, when it has none. A passage is listed
  /// either way — a gap the reader can see and ask about is worth more than
  /// a silent omission.
  final String? unavailable;

  bool get isAvailable => unavailable == null;
}

/// A mark pinned to a point inside one passage.
///
/// Offsets are stored per passage — the same way the web stores them — so the
/// absolute position on the timeline is worked out here, once the durations
/// are known.
class SegmentMark {
  const SegmentMark({
    required this.id,
    required this.leafId,
    required this.offsetSeconds,
    this.color = const Color(0xFFEA580C),
    this.icon = Icons.question_mark,
  });

  final String id;
  final String leafId;
  final double offsetSeconds;
  final Color color;
  final IconData icon;
}

/// Plays a Set's takes as if they were one recording.
///
/// Nothing is joined on disk. The files are played back to back behind a
/// single timeline whose length is the sum of them all, so the listener sees
/// one waveform, one clock and one progress bar, and hears one continuous
/// reading. Doing it this way means the audio can be in any format the device
/// can play — the browser's WebM/Opus included — where actually concatenating
/// the files would demand raw PCM.
///
/// This is the engine on its own, with no widget attached. The compact player
/// and the full-screen review player are both views over one of these, which
/// is what lets a reading started in one carry on in the other - same
/// position, same record of what has been heard, same `onEnded`.
class TimelinePlayback extends ChangeNotifier {
  TimelinePlayback(List<AudioSegment> segments)
    : segments = List.unmodifiable(segments) {
    playable = List.unmodifiable(this.segments.where((s) => s.isAvailable));
    _coarse = List<List<double>>.filled(playable.length, const []);
    _detail = List<List<double>?>.filled(playable.length, null);

    // Both players are listened to, and whatever the one waiting its turn
    // has to say is ignored: loading a file makes it report positions and
    // states of its own, and acting on those would move the playhead while
    // another passage is still playing.
    for (var i = 0; i < _players.length; i++) {
      final player = _players[i];

      _subs.add(
        player.onPlayingChanged.listen((playing) {
          if (_disposed || i != _turn) return;

          _playing = playing;
          // Claimed, never released here: a passage ending is the gap before
          // the next one starts, not the end of this player's turn.
          if (_playing) AudioBus.instance.claim(this);
          _notify();
        }),
      );

      _subs.add(
        player.onPositionChanged.listen((position) {
          if (_disposed || i != _turn) return;

          // Only while the listener has it running. A player sends one last
          // position as it finishes, and that arrives after the end of the
          // reading has already wound the playhead back to the start - which
          // put the clock back onto the passage that had just ended and left
          // the bar green up to it. Nothing that is not playing has anything
          // to say about where the playhead is.
          if (!_running) return;

          // A player winding itself back as it finishes says "zero" on its
          // way out. Taken at its word, that zero would stand as the last
          // place the listener was - and the end of the passage is judged
          // from exactly that. Zero is only believed at a start.
          if (position == Duration.zero && _offset > Duration.zero) return;
          if (_isStale(position)) return;

          _offset = position;
          _noteProgress();
          _notify();

          if (_index < playable.length) {
            final segment = playable[_index];
            onSegment?.call(segment.leafId, segment.label, position);
          }
        }),
      );

      _subs.add(
        player.onComplete.listen((_) {
          if (_disposed || i != _turn) return;
          _advance();
        }),
      );

      // Either player, whoever's turn it is: the speed is one setting for
      // the whole reading, and a phone that will not give it to one
      // passage is shown as not giving it.
      _subs.add(
        player.onSpeedRefused.listen((speed) {
          if (_disposed || _speed == speed) return;
          _speed = speed;
          _notify();
          toaster(AudioBackend.speedRefusedMessage);
        }),
      );
    }

    AudioBus.instance.addListener(_stopIfSupplanted);
  }

  /// How many bars the compact strip is built from.
  static const int _totalBars = 240;

  /// Every passage handed in, including the ones with no audio.
  final List<AudioSegment> segments;

  /// Only the passages that have audio. The timeline is built from these,
  /// while the notes under the player name the ones that are absent.
  late final List<AudioSegment> playable;

  /// Fires when the last passage finishes - and only when the reading was
  /// actually heard on the way there. See [heardUpTo].
  VoidCallback? onEnded;

  /// Fires when the end was reached without a full listen: the listener
  /// skipped ahead, or a passage's file was not there to be played.
  VoidCallback? onEndedWithoutFullListen;

  /// Which passage the playhead is in, and how far into it.
  void Function(String leafId, String label, Duration offset)? onSegment;

  /// Two players, taking it in turns.
  ///
  /// One player can only load a file when it is free, so the join between
  /// passages cost however long opening the next one took - a silence in the
  /// middle of a reading that is supposed to sound continuous. While one
  /// plays, the other is already holding the passage after it, so the swap is
  /// a resume rather than a load.
  final List<AudioBackend> _players = [AudioBackend(), AudioBackend()];
  int _turn = 0;

  AudioBackend get _player => _players[_turn];
  AudioBackend get _standby => _players[1 - _turn];

  /// Which passage the standby player is holding, so it is only loaded once.
  int? _readied;

  final List<StreamSubscription<void>> _subs = [];

  bool _disposed = false;
  bool _prepared = false;

  /// Set once this has been disposed. A full-screen view can outlive the
  /// compact player that owns the engine, and has to know to stop asking.
  bool get isDisposed => _disposed;

  /// Bar heights for every passage laid end to end.
  List<double> _bars = const [];
  List<double> get bars => _bars;

  /// Each passage's own bars, scaled so the loudest is 1. What the full
  /// screen view draws from until the finer ones have been read.
  late List<List<double>> _coarse;

  /// Each passage's fine-grained bars, or null until they have been read.
  late List<List<double>?> _detail;
  List<List<double>?> get detailBars => _detail;
  bool _detailRequested = false;

  /// Playback speed. Each passage is a separate source, so the rate is
  /// re-applied every time one starts - it does not carry over on its own.
  double _speed = 1;
  double get speed => _speed;

  /// Where each passage starts on the timeline, and how long each one runs.
  final List<Duration> _starts = [];
  final List<Duration> _lengths = [];
  Duration _total = Duration.zero;

  List<Duration> get starts => _starts;
  List<Duration> get lengths => _lengths;
  Duration get total => _total;

  int _index = 0;
  int get index => _index;

  /// Whether the player itself is producing sound right now.
  bool _playing = false;
  bool get playing => _playing;

  /// Whether the listener has it running.
  ///
  /// The passages are separate files played back to back, so the player
  /// falls silent for a moment at every join - and following that, the
  /// button blinked to Play and the waveform to its finished colour twice in
  /// the middle of one reading. This says what the listener asked for, and
  /// only they, or the end of the last passage, can change it.
  bool _running = false;
  bool get running => _running;

  /// Whether the whole reading has been heard through to the end. The bars
  /// stay green afterwards rather than reverting to grey, so the listener can
  /// tell a Set they have been through from one they have not.
  bool _heard = false;
  bool get heard => _heard;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  /// Position inside the passage now playing.
  Duration _offset = Duration.zero;
  Duration get offset => _offset;

  Duration get elapsed =>
      (_index < _starts.length ? _starts[_index] : Duration.zero) + _offset;

  /// How far along the whole timeline the playhead is, 0 to 1.
  double get progress => _total == Duration.zero
      ? 0.0
      : (elapsed.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0);

  /// How far into the timeline the reading has been heard without a break.
  ///
  /// Buttons elsewhere unlock on a full listen, and "the last passage
  /// finished" was never proof of one: a tap near the right-hand edge of the
  /// waveform finished it in a fifth of a second. So what counts is this -
  /// the furthest point reached by playing, not by seeking. Seeking is still
  /// free, in either direction; it just does not move this. Playback only
  /// pushes it forward when it is happening at, or just past, the place
  /// already heard up to.
  Duration _heardUpTo = Duration.zero;
  Duration get heardUpTo => _heardUpTo;

  /// True after the end was reached by skipping rather than by listening,
  /// until the listener presses play again. The players show a line about
  /// it, since a gate that stays shut with no reason given reads as broken.
  bool _skippedAhead = false;
  bool get skippedAhead => _skippedAhead;

  /// True after the end was reached with a passage's file missing. Kept
  /// apart from [skippedAhead] because the listener did nothing wrong, and
  /// telling them to stop skipping would send them looking for a mistake
  /// they did not make.
  bool _missedPassage = false;
  bool get missedPassage => _missedPassage;

  /// Passages that were stepped over because their file was not there. One
  /// is forgiven as soon as it does play.
  final Set<int> _missed = {};

  /// What the players say under themselves when the end did not count.
  static const String skippedHint =
      'Skipping ahead does not count - play from where you left off to '
      'finish listening.';
  static const String missedHint =
      'A passage could not be played, so this does not count as a full '
      'listen yet.';

  /// Whether anything is waiting on this reading being heard right
  /// through. The website asks for a full listen in six places and no
  /// others - the source before a first take, the target recording before
  /// the Drafter, the Peer, the community tester and the Back Translator
  /// send a Set on, the back translation before the Consultant approves -
  /// and once that listen has been given, it is not asked for again.
  ///
  /// Where nothing is waiting, a recording is there to be dipped into:
  /// skipping to the end of it is not a fault to be told about, and the
  /// playhead is not taken back to the part that was passed over.
  bool mustListen = true;

  /// The line to show under a player, or null when there is nothing to say.
  String? get listenHint {
    if (!mustListen) return null;
    if (_skippedAhead) return skippedHint;
    if (_missedPassage) return missedHint;
    return null;
  }

  /// How far past [heardUpTo] playback may be and still count as carrying
  /// straight on from it.
  ///
  /// Positions are reported about five times a second of real time, which at
  /// 5x is a full second of the recording between one report and the next -
  /// and a join between passages loses a little more. So the allowance grows
  /// with the speed: 1.5s at 1x, a little over 3s at 5x. Small enough that
  /// nobody skips a reading in steps of it, large enough that nobody who
  /// listened is told they did not.
  Duration get _tolerance =>
      Duration(milliseconds: 1500 + (400 * (_speed - 1)).round());

  /// Moves [heardUpTo] along, if the playhead is where listening left off.
  void _noteProgress() {
    final at = elapsed;
    if (at > _heardUpTo && at <= _heardUpTo + _tolerance) _heardUpTo = at;
  }

  /// Where the last seek was aimed, and when it was asked for.
  Duration? _seekTarget;
  DateTime? _seekAsked;

  /// Whether a position is left over from before the last seek.
  ///
  /// A seek takes a moment to land, and the player goes on reporting where
  /// it was in the meantime. Normally that is a flicker. But the end of a
  /// passage is judged from the last position heard - so a seek to the final
  /// instant, one report from the old place, and then the end arriving
  /// before any report from the new place, would pass for having listened
  /// all the way there. Until the player says it has reached the target, or
  /// long enough has passed that it plainly is not going to, what it reports
  /// from short of the target is not believed.
  bool _isStale(Duration position) {
    final target = _seekTarget;
    final asked = _seekAsked;
    if (target == null || asked == null) return false;

    final at =
        (_index < _starts.length ? _starts[_index] : Duration.zero) + position;
    final landed = at >= target - const Duration(milliseconds: 500);
    final givenUp =
        DateTime.now().difference(asked) > const Duration(milliseconds: 1500);

    if (landed || givenUp) {
      _seekTarget = null;
      _seekAsked = null;
      return false;
    }
    return true;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    AudioBus.instance.removeListener(_stopIfSupplanted);
    AudioBus.instance.release(this);
    for (final sub in _subs) {
      sub.cancel();
    }
    for (final player in _players) {
      player.dispose();
    }

    // Said once on the way out, so a full-screen view still holding this
    // can close itself rather than sit over a player that will never move.
    notifyListeners();
    super.dispose();
  }

  void _stopIfSupplanted() {
    if (_disposed) return;
    if (_playing && !AudioBus.instance.holds(this)) {
      _running = false;
      _notify();
      unawaited(_player.pause());
    }
  }

  /// One passage's bars and length, or nothing when the file is not here.
  Future<ClipAudio> _readSegment(AudioSegment segment) async {
    if (!await File(segment.path).exists()) return ClipAudio.empty;
    return WaveformCache.load(segment.path);
  }

  /// Measures every passage and builds one waveform out of them.
  ///
  /// Each passage contributes bars in proportion to its length, so the
  /// finished strip reads as a single recording rather than a row of equal
  /// blocks that misrepresent how long each part is.
  Future<void> prepare() async {
    if (_prepared) return;
    _prepared = true;

    final lengths = <Duration>[];

    try {
      // Lengths first, and only lengths. A timeline needs nothing else, and
      // a length can be had off a WAV's header or from the player - where
      // the bars mean decoding every sample of every passage. Asking for the
      // bars up front is what kept a Set of a dozen passages on its spinner
      // when it could have been playing.
      //
      // All of them at once, and cached for the session, so scrolling this
      // player out of view and back does not ask again.
      lengths.addAll(
        await Future.wait([
          for (final segment in playable) _segmentDuration(segment),
        ]),
      );
    } catch (e) {
      if (!_disposed) {
        _loading = false;
        _error = 'This recording could not be read: @error'.trParams({
          'error': '$e',
        });
        _notify();
      }
      return;
    }

    // Playable now, with whatever bars have been read before. The rest
    // are read behind that and dropped in as they arrive - a strip that
    // fills itself in is worth more than a wait.
    final known = [
      for (final segment in playable) WaveformCache.peek(segment.path)?.bars,
    ];
    if (known.any((bars) => bars != null)) {
      _coarse = [for (final bars in known) _normalised(bars ?? const [])];
      _commit(lengths, [for (final bars in known) bars ?? const []]);
    } else {
      _commit(lengths, const []);
    }

    if (known.any((bars) => bars == null || bars.isEmpty)) {
      unawaited(_loadBars(lengths, known));
    }
  }

  /// One passage's length, or zero when the file is not here.
  Future<Duration> _segmentDuration(AudioSegment segment) async {
    if (!await File(segment.path).exists()) return Duration.zero;
    return WaveformCache.duration(segment.path);
  }

  /// Reads every passage's bars, redrawing the strip as each arrives.
  ///
  /// Each on its own: waiting for all of them held the whole strip flat
  /// for the longest passage, and one that could not be read cost every
  /// other passage its bars as well.
  Future<void> _loadBars(
    List<Duration> lengths,
    List<List<double>?> known,
  ) async {
    final bars = [for (final read in known) read ?? const <double>[]];

    await Future.wait([
      for (var i = 0; i < playable.length; i++)
        if (bars[i].isEmpty)
          () async {
            try {
              final audio = await _readSegment(playable[i]);
              if (_disposed || audio.bars.isEmpty) return;

              bars[i] = audio.bars;
              _coarse[i] = _normalised(audio.bars);
              _commit(lengths, bars);
            } catch (e) {
              // The bars are decoration on a timeline that already works.
              debugPrint('WAVEFORM BARS UNAVAILABLE (${playable[i].path}): $e');
            }
          }(),
    ]);
  }

  /// Reads the fine-grained bars the full-screen view draws, one passage at
  /// a time, saying so as each arrives.
  ///
  /// Only ever asked for by that view. The compact strip has 110 bars for
  /// the whole Set and no use for twenty a second, and reading those for
  /// every player on every screen would be a great deal of work nobody sees.
  Future<void> loadDetail() async {
    if (_detailRequested) return;
    _detailRequested = true;

    for (var i = 0; i < playable.length; i++) {
      if (_disposed) return;

      try {
        final path = playable[i].path;
        if (!await File(path).exists()) continue;

        final detail = await WaveformCache.detail(path);
        if (_disposed) return;

        _detail[i] = detail;
        _notify();
      } catch (e) {
        // The coarse bars stay in its place. Coarse is still a waveform.
        debugPrint('DETAIL BARS UNAVAILABLE (${playable[i].path}): $e');
      }
    }
  }

  /// The best bars there are for one passage, loudest scaled to 1: the fine
  /// ones once they have been read, the strip's own until then.
  List<double> barsFor(int segment) {
    if (segment < 0 || segment >= playable.length) return const [];
    return _detail[segment] ?? _coarse[segment];
  }

  static List<double> _normalised(List<double> source) {
    if (source.isEmpty) return const [];

    var peak = 0.0;
    for (final value in source) {
      peak = math.max(peak, value.abs());
    }
    if (peak <= 0) return List<double>.filled(source.length, 0);

    return [for (final value in source) (value.abs() / peak).clamp(0.0, 1.0)];
  }

  /// Lays the passages end to end and draws whatever bars there are.
  void _commit(List<Duration> lengths, List<List<double>> samples) {
    var total = Duration.zero;
    final starts = <Duration>[];
    for (final length in lengths) {
      starts.add(total);
      total += length;
    }

    // Bars are handed out by accumulating the exact fraction and taking the
    // difference, so the shares always add up to _totalBars. Rounding each
    // one on its own let the total drift, which pushed the drawn boundary
    // away from the time it actually falls at - and the pins, which are
    // placed by time, then looked misaligned against it.
    final waveform = <double>[];
    if (total.inMilliseconds > 0) {
      var elapsed = 0;
      var placed = 0;
      for (var i = 0; i < samples.length; i++) {
        elapsed += lengths[i].inMilliseconds;
        final upTo = (_totalBars * elapsed / total.inMilliseconds).round();
        waveform.addAll(
          resample(samples[i], (upTo - placed).clamp(0, _totalBars)),
        );
        placed = upTo;
      }
    }

    if (_disposed) return;
    _starts
      ..clear()
      ..addAll(starts);
    _lengths
      ..clear()
      ..addAll(lengths);
    _total = total;
    _bars = waveform;
    _loading = false;
    _notify();
  }

  /// Squeezes a passage's bars into the width its duration has earned.
  static List<double> resample(List<double> source, int count) {
    if (source.isEmpty) return List<double>.filled(count, 0);
    if (source.length == count) return source;

    return List<double>.generate(count, (i) {
      final at = (i * source.length / count).floor();
      return source[at.clamp(0, source.length - 1)];
    });
  }

  Future<void> _playFrom(int index, Duration offset) async {
    if (index >= playable.length) return;

    final segment = playable[index];
    if (!await File(segment.path).exists()) {
      if (_disposed) return;

      // Stepped over - and the playhead is moved onto it first. Advancing
      // works out "next" from where the playhead is, so leaving it on the
      // passage before meant the next one was this same missing file, and
      // the two functions handed it back and forth for ever.
      //
      // It is also written down. A reading with a passage missing out of
      // the middle has not been heard in full, however it ended.
      _missed.add(index);
      _index = index;
      _offset = Duration.zero;
      await _advance();
      return;
    }
    if (_disposed) return;

    _missed.remove(index);
    _index = index;
    _offset = offset;
    _notify();

    // Said straight away, not left to the first position event.
    //
    // Whoever is listening uses this to know which passage the playhead is
    // in - and a question pinned here is filed against that passage. The
    // position stream only speaks once audio is actually running, so between
    // a tap on a later passage and the first frame of it playing, the
    // listener still held the passage before it: tap into passage two, add a
    // question quickly, and it was filed under passage one.
    onSegment?.call(segment.leafId, segment.label, offset);

    AudioBus.instance.claim(this);
    await _player.play(segment.path);
    await _player.setPlaybackRate(_speed);
    if (offset > Duration.zero) await _player.seek(offset);

    unawaited(_ready(index + 1));
  }

  /// Makes sure the handover actually produced sound, and loads the passage
  /// properly if it did not.
  ///
  /// Resuming a player that was only ever loaded and never played is not
  /// something every platform honours - and when it does nothing, the
  /// reading simply stops at the join with the clock parked on the passage
  /// that just ended, which looks exactly like it stopped on its own. Rather
  /// than trust the handover, this checks a moment later and falls back to
  /// loading the file the ordinary way.
  Future<void> _confirmStarted(int index) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (_disposed || !_running) return;
    if (_playing || _index != index) return;

    debugPrint('SEGMENT HANDOVER DID NOT START: playing $index the long way');
    await _playFrom(index, Duration.zero);
  }

  /// Loads a passage into the player that is not speaking, so its turn can
  /// start without waiting for the file to open.
  ///
  /// Paused rather than playing: `setSource` alone leaves the file open and
  /// silent, which is exactly what is wanted a passage early.
  Future<void> _ready(int index) async {
    if (index >= playable.length || _readied == index) return;

    final segment = playable[index];

    try {
      if (!await File(segment.path).exists()) return;
      if (_disposed) return;

      await _standby.setSource(segment.path);
      _readied = index;
    } catch (e) {
      // A passage that will not preload still plays when its turn comes; it
      // just costs the join it would have saved.
      debugPrint('SEGMENT PRELOAD FAILED (${segment.path}): $e');
      _readied = null;
    }
  }

  /// Rolls straight into the next passage — this is what makes it feel joined.
  Future<void> _advance() async {
    if (_disposed) return;

    // A passage that played out from where listening had got to has been
    // heard to its end, even though the last position reported falls a
    // little short of it - positions come in steps, and the end rarely
    // lands on one.
    if (_index < _starts.length && !_missed.contains(_index)) {
      final end = _starts[_index] + _lengths[_index];
      if (elapsed <= _heardUpTo + _tolerance && end > _heardUpTo) {
        _heardUpTo = end;
      }
    }

    final next = _index + 1;

    if (next < playable.length) {
      // The standby player already has it open, so its turn starts with a
      // resume. Only when the preload did not happen does this fall back to
      // loading the file here, which is what the join used to cost every
      // time.
      if (_readied == next) {
        _turn = 1 - _turn;
        _index = next;
        _offset = Duration.zero;
        _readied = null;
        _missed.remove(next);
        _notify();

        final segment = playable[next];
        onSegment?.call(segment.leafId, segment.label, Duration.zero);

        AudioBus.instance.claim(this);
        await _player.resume();
        await _player.setPlaybackRate(_speed);

        unawaited(_ready(next + 1));
        unawaited(_confirmStarted(next));
        return;
      }

      await _playFrom(next, Duration.zero);
      return;
    }

    _playing = false;
    _running = false;
    AudioBus.instance.release(this);

    // A reading already heard in full stays heard: going back over the end
    // of it afterwards, by whatever route, takes nothing away.
    final listened =
        _heard || (_missed.isEmpty && _heardUpTo >= _total - _tolerance);

    if (listened) {
      _index = 0;
      _offset = Duration.zero;
      _heard = true;
      _heardUpTo = _total;
      _skippedAhead = false;
      _missedPassage = false;
      _notify();
      onEnded?.call();
      return;
    }

    // Nothing was waiting on a full listen: the reading has simply ended,
    // and goes back to its start like any other.
    if (!mustListen) {
      _skippedAhead = false;
      _missedPassage = false;
      _notify();
      await _moveTo(0, Duration.zero);
      return;
    }

    // The end was reached, but not by listening to what came before it. No
    // gate opens. The playhead goes back to where listening actually got
    // to, so that pressing play carries on with the part not yet heard
    // rather than starting the whole reading again.
    _missedPassage = _missed.isNotEmpty;
    _skippedAhead = !_missedPassage;
    _notify();
    onEndedWithoutFullListen?.call();

    final resumeAt = _heardUpTo >= _total - _tolerance
        ? Duration.zero
        : _heardUpTo;
    final place = _locate(resumeAt) ?? (index: 0, offset: Duration.zero);
    await _moveTo(place.index, place.offset);
  }

  Future<void> setSpeed(double speed) async {
    if (_disposed) return;
    _speed = speed;
    _notify();

    try {
      await _player.setPlaybackRate(speed);
    } catch (e) {
      // Nothing is loaded yet. The rate is applied when something starts.
      debugPrint('PLAYBACK RATE NOT APPLIED YET: $e');
    }

    // The player waiting its turn is told as well. It already holds the
    // next passage, and on a phone a speed is a copy of the file: told
    // only when its turn came, it would open the join at the old speed
    // and change a moment into the passage.
    try {
      await _standby.setPlaybackRate(speed);
    } catch (e) {
      debugPrint('STANDBY PLAYBACK RATE NOT APPLIED YET: $e');
    }
  }

  Future<void> toggle() => _running ? pause() : play();

  Future<void> pause() async {
    if (!_running || _disposed) return;

    // Read from what the listener asked for, not from whether sound happens
    // to be coming out: between two passages neither is true, and a tap
    // there used to start the reading again rather than stop it.
    _running = false;
    _notify();
    await _player.pause();
  }

  Future<void> play() async {
    if (_loading || _total == Duration.zero || _running || _disposed) return;

    _running = true;
    // The line about skipping has been read by now; what happens next is
    // the listening it asked for.
    _skippedAhead = false;
    _missedPassage = false;
    _notify();

    if (_offset > Duration.zero) {
      AudioBus.instance.claim(this);
      await _player.resume();
      await _player.setPlaybackRate(_speed);
      unawaited(_ready(_index + 1));
      return;
    }
    await _playFrom(_index, Duration.zero);
  }

  /// Jumps to a point on the whole timeline, whichever passage that lands in.
  Future<void> seekFraction(double fraction) {
    return seekTo(
      Duration(
        milliseconds: (_total.inMilliseconds * fraction.clamp(0.0, 1.0))
            .round(),
      ),
    );
  }

  /// Moves the playhead by this much, forwards or back.
  Future<void> skip(Duration by) => seekTo(elapsed + by);

  Duration? _pendingSeek;
  bool _seeking = false;

  /// Jumps to an absolute time on the timeline.
  ///
  /// Seeks are taken one at a time and only the latest waits its turn. A
  /// finger dragged along a waveform asks for ten a second, each of which
  /// may mean opening a file; run side by side they finish in any order, and
  /// the playhead ends up wherever the slowest one put it rather than where
  /// the finger stopped.
  Future<void> seekTo(Duration absolute) async {
    if (_total == Duration.zero || _disposed) return;

    _pendingSeek = absolute;
    if (_seeking) return;

    _seeking = true;
    try {
      while (_pendingSeek != null && !_disposed) {
        final target = _pendingSeek!;
        _pendingSeek = null;
        await _seekNow(target);
      }
    } finally {
      _seeking = false;
    }
  }

  /// Which passage an absolute time falls in, and how far into it.
  ///
  /// Scanned from the end so the latest passage starting at or before the
  /// target wins - except that a passage of no length starts where the next
  /// one does, and picking it would land the playhead on a passage with
  /// nothing in it. Those are skipped.
  ({int index, Duration offset})? _locate(Duration target) {
    for (var i = _starts.length - 1; i >= 0; i--) {
      if (target < _starts[i]) continue;
      if (i < _lengths.length && _lengths[i] == Duration.zero) continue;

      return (index: i, offset: target - _starts[i]);
    }
    return null;
  }

  Future<void> _seekNow(Duration absolute) async {
    final clamped = absolute < Duration.zero
        ? Duration.zero
        : (absolute > _total ? _total : absolute);

    final place = _locate(clamped);
    if (place == null) return;

    // A tap on the waveform moves the playhead; it does not decide whether
    // the recording is running. Playing, it carries on from the new spot.
    // Paused, it stays paused there - somebody scrubbing through a reading
    // to find a place is not asking to hear it yet, and having it start
    // under their finger means pressing pause again every time they look.
    if (!_running) {
      await _moveTo(place.index, place.offset);
      return;
    }

    _seekTarget = clamped;
    _seekAsked = DateTime.now();

    // Within the passage already sounding there is nothing to open: the
    // player is wound to the spot and keeps going. Starting the file again
    // for every step of a drag is what made scrubbing stutter.
    if (place.index == _index && _playing) {
      _offset = place.offset;
      _notify();
      final segment = playable[_index];
      onSegment?.call(segment.leafId, segment.label, place.offset);

      try {
        await _player.seek(place.offset);
        return;
      } catch (e) {
        debugPrint('SEEK WHILE PLAYING FAILED (${segment.path}): $e');
      }
    }

    await _playFrom(place.index, place.offset);
  }

  /// Puts the playhead somewhere without starting the audio.
  ///
  /// The file is opened and wound to the spot so the play button resumes
  /// from there rather than from wherever the last passage left off.
  Future<void> _moveTo(int index, Duration offset) async {
    if (index >= playable.length || _disposed) return;

    final segment = playable[index];

    _index = index;
    _offset = offset;
    _notify();
    onSegment?.call(segment.leafId, segment.label, offset);

    try {
      if (!await File(segment.path).exists()) return;
      if (_disposed) return;

      await _player.setSource(segment.path);
      await _player.seek(offset);
      _readied = null;
    } catch (e) {
      debugPrint('SEEK WHILE PAUSED FAILED (${segment.path}): $e');
    }
  }

  /// Where a mark sits on the timeline, in seconds from the very start.
  double? absoluteSecondsOf(SegmentMark mark) {
    for (var i = 0; i < playable.length && i < _starts.length; i++) {
      if (playable[i].leafId == mark.leafId) {
        return _starts[i].inMilliseconds / 1000 + mark.offsetSeconds;
      }
    }
    return null;
  }

  /// Minutes and seconds, the way every clock on a player is written.
  static String format(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
