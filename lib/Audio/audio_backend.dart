import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livuka/Audio/sped_copy.dart';

/// One file player, as the app's players need one: load, play, pause, seek,
/// speed, and four streams. `audioplayers` sits behind it, and nothing
/// above this line knows.
abstract class AudioBackend {
  factory AudioBackend() => _AudioplayersBackend();

  /// What to say when [onSpeedRefused] fires.
  static const String speedRefusedMessage =
      'This phone cannot play this recording at another speed. Playing at '
      'normal speed.';

  /// What to say when a file will not play at all. The phone's own account
  /// of it is for the log.
  static const String failedMessage =
      'This recording could not be played. Tap play to try again.';

  /// True while sound is being produced, false when paused, stopped or done.
  Stream<bool> get onPlayingChanged;
  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;

  /// Fires once each time a file plays out to its end.
  Stream<void> get onComplete;

  /// Fires with the speed now in force when the one asked for could not be
  /// had: this phone will not play this file at any pace but its own. The
  /// file plays on at that speed, and whoever shows a speed shows this one.
  Stream<double> get onSpeedRefused;

  /// Opens [path] and leaves it paused at the start.
  Future<void> setSource(String path);

  /// Opens [path] and starts it from the beginning.
  Future<void> play(String path);

  /// Carries on from where it was paused - or, after the end, from the top.
  Future<void> resume();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setPlaybackRate(double rate);

  /// The loaded file's length, once known.
  Future<Duration?> getDuration();

  Future<void> dispose();
}

// ---------------------------------------------------------------- phones

class _AudioplayersBackend implements AudioBackend {
  final ap.AudioPlayer _player = ap.AudioPlayer();
  final StreamController<double> _refused = StreamController.broadcast();

  /// The recording now open, as the app names it, and the speed asked of
  /// it.
  String? _path;
  double _rate = 1;

  /// How much faster than the recording the file actually loaded runs:
  /// the speed of the [SpedCopy] in the player, or 1 when it is the
  /// recording itself. The player counts in the loaded file's time, and
  /// everything above this class counts in the recording's.
  ///
  /// Read off the file the player is holding, not kept beside it: a
  /// figure kept beside it has to be changed at exactly the right moment
  /// as files are swapped, and the one time it was not, a one-minute
  /// recording at 5x was shown as twelve seconds long.
  double get _factor {
    final loaded = _player.source;
    return loaded is ap.DeviceFileSource ? _factorOfCopy[loaded.path] ?? 1 : 1;
  }

  /// Every faster copy handed out, and how much faster it is.
  final Map<String, double> _factorOfCopy = {};

  /// The speed the phone's own player was last told, where it is told one.
  double _told = 1;

  /// On Android a speed is a copy of the file, not a setting of the
  /// player - see [SpedCopy] for why the player is not asked. Elsewhere
  /// the player is asked, as it always was.
  static bool get _copies => Platform.isAndroid;

  /// One thing at a time. Changing speed swaps the file under the
  /// playhead, and a seek or a pause that landed in the middle of that
  /// would be answered by whichever file happened to be there.
  Future<void> _last = Future<void>.value();

  Future<T> _inTurn<T>(Future<T> Function() action) {
    final result = _last.then((_) => action());
    _last = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  Duration _ofRecording(Duration inFile) => _factor == 1
      ? inFile
      : Duration(microseconds: (inFile.inMicroseconds * _factor).round());

  Duration _ofFile(Duration inRecording) => _factor == 1
      ? inRecording
      : Duration(microseconds: (inRecording.inMicroseconds / _factor).round());

  @override
  Stream<double> get onSpeedRefused => _refused.stream;

  @override
  Stream<bool> get onPlayingChanged => _player.onPlayerStateChanged.map(
    (state) => state == ap.PlayerState.playing,
  );

  @override
  Stream<Duration> get onPositionChanged =>
      _player.onPositionChanged.map(_ofRecording);

  @override
  Stream<Duration> get onDurationChanged =>
      _player.onDurationChanged.map(_ofRecording);

  @override
  Stream<void> get onComplete => _player.onPlayerComplete;

  /// What to load for [path] at the speed now asked for.
  Future<({String file, double factor})> _fileFor(String path) async {
    if (!_copies || _rate == 1) return (file: path, factor: 1.0);

    final copy = await SpedCopy.of(path, _rate);
    // No copy to be had: the recording itself, and the phone's player
    // asked after all.
    if (copy == null) return (file: path, factor: 1.0);
    _factorOfCopy[copy] = _rate;
    return (file: copy, factor: _rate);
  }

  /// The speed the phone's player should be running at: the one asked
  /// for, unless a copy is already supplying it.
  double get _owed => _factor == 1 ? _rate : 1;

  /// Tells the phone's player its speed. A phone that will not have it
  /// plays on at its own, and says so.
  Future<void> _tell(double speed) async {
    try {
      await _player.setPlaybackRate(speed);
      _told = speed;
    } on PlatformException catch (e) {
      if (speed == 1) rethrow;
      debugPrint('PLAYBACK AT ${speed}x REFUSED ($_path): ${e.message}');
      await _ownPace();
    }
  }

  Future<void> _ownPace() async {
    _rate = 1;
    _told = 1;
    _refused.add(1);
    try {
      await _player.setPlaybackRate(1);
    } catch (_) {}
  }

  /// Starts the file. Some phones take a speed while paused and refuse it
  /// only on starting (`setPlaybackParams: IllegalArgumentException`);
  /// the file is then started at its own pace instead of not at all.
  Future<void> _start(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (e) {
      if (_told == 1) rethrow;
      debugPrint('START AT ${_told}x REFUSED ($_path): ${e.message}');
      await _ownPace();
      await action();
    }
  }

  @override
  Future<void> setSource(String path) => _inTurn(() async {
    _path = path;
    final open = await _fileFor(path);
    await _player.setSource(ap.DeviceFileSource(open.file));
  });

  @override
  Future<void> play(String path) => _inTurn(() async {
    _path = path;
    final open = await _fileFor(path);
    final owed = open.factor == 1 ? _rate : 1.0;
    if (_copies && _told != owed) await _tell(owed);
    await _start(() => _player.play(ap.DeviceFileSource(open.file)));
  });

  @override
  Future<void> resume() => _inTurn(() => _start(_player.resume));

  @override
  Future<void> pause() => _inTurn(_player.pause);

  @override
  Future<void> seek(Duration position) =>
      _inTurn(() => _player.seek(_ofFile(position)));

  @override
  Future<void> setPlaybackRate(double rate) => _inTurn(() async {
    _rate = rate;

    // Asked every time, as before: this player forgets its speed with
    // each file it is given.
    if (!_copies) return _tell(rate);

    // Nothing open. The next file is opened at this speed.
    final path = _path;
    if (path == null) return;

    final open = await _fileFor(path);
    final loaded = _player.source;
    final same =
        open.factor == _factor &&
        loaded is ap.DeviceFileSource &&
        loaded.path == open.file;

    if (!same) {
      // The copy at the new speed goes in under the playhead: same place
      // in the recording, which is a different place in the file.
      final playing = _player.state == ap.PlayerState.playing;
      // Stopped where it is first, so the file going out has said its
      // last about where the playhead is before the new one speaks.
      if (playing) await _player.pause();
      var at = Duration.zero;
      try {
        at = _ofRecording(await _player.getCurrentPosition() ?? Duration.zero);
      } catch (_) {}

      await _player.setSource(ap.DeviceFileSource(open.file));
      if (_told != _owed) await _tell(_owed);
      if (at > Duration.zero) await _player.seek(_ofFile(at));
      if (playing) await _start(_player.resume);
      return;
    }

    if (_told != _owed) await _tell(_owed);
  });

  @override
  Future<Duration?> getDuration() async {
    final length = await _player.getDuration();
    return length == null ? null : _ofRecording(length);
  }

  @override
  Future<void> dispose() async {
    await _refused.close();
    await _player.dispose();
  }
}
