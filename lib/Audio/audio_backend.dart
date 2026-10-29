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
  _AudioplayersBackend() {
    _listenTo(_player);
  }

  /// The player now sounding. Replaced by another when the speed changes
  /// mid-play - see [_handOver] - so nothing outside this class holds it,
  /// and its streams reach the app through the controllers below.
  ap.AudioPlayer _player = ap.AudioPlayer();
  final StreamController<double> _refused = StreamController.broadcast();

  final StreamController<bool> _playing = StreamController.broadcast();
  final StreamController<Duration> _position = StreamController.broadcast();
  final StreamController<Duration> _duration = StreamController.broadcast();
  final StreamController<void> _complete = StreamController.broadcast();
  List<StreamSubscription<Object?>> _feeds = const [];

  /// Passes [player]'s news on as this backend's, and stops passing on the
  /// last one's. Whoever listens never learns the player changed.
  void _listenTo(ap.AudioPlayer player) {
    for (final feed in _feeds) {
      unawaited(feed.cancel());
    }
    _feeds = [
      player.onPlayerStateChanged.listen(
        (state) => _playing.add(state == ap.PlayerState.playing),
        onError: _playing.addError,
      ),
      player.onPositionChanged.listen(
        (position) => _report(_ofRecording(position)),
        onError: _position.addError,
      ),
      player.onDurationChanged.listen(
        (length) => _duration.add(_ofRecording(length)),
        onError: _duration.addError,
      ),
      player.onPlayerComplete.listen(
        (_) => _complete.add(null),
        onError: _complete.addError,
      ),
    ];
  }

  /// The last place in the recording passed on as the playhead.
  Duration _lastPosition = Duration.zero;

  /// After a change of speed, nothing behind this is passed on for a
  /// moment. The new file is wound to where the old one was read, and the
  /// old one plays on a few frames after that reading - so the first
  /// places the new one reports can sit a hair behind the last the old
  /// one did, and the played bars stepped backwards with nobody touching
  /// anything.
  Duration? _floor;
  DateTime? _floorSet;

  /// Passes a playhead on, unless it is a step back left over from a
  /// change of speed.
  void _report(Duration at) {
    final floor = _floor;
    if (floor != null) {
      final fresh =
          DateTime.now().difference(_floorSet!) <
          const Duration(milliseconds: 1500);
      if (fresh && at < floor) return;
      _floor = null;
    }
    _lastPosition = at;
    _position.add(at);
  }

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
  Stream<bool> get onPlayingChanged => _playing.stream;

  @override
  Stream<Duration> get onPositionChanged => _position.stream;

  @override
  Stream<Duration> get onDurationChanged => _duration.stream;

  @override
  Stream<void> get onComplete => _complete.stream;

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
    _floor = null;
    final open = await _fileFor(path);
    await _player.setSource(ap.DeviceFileSource(open.file));
  });

  @override
  Future<void> play(String path) => _inTurn(() async {
    _path = path;
    _floor = null;
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
  Future<void> seek(Duration position) => _inTurn(() async {
    // Sent somewhere on purpose: backwards included.
    _floor = null;
    // A file that has played out is let go of, and a seek sent to nothing
    // waits half a minute for an answer that never comes - with every
    // play and pause after it queued behind. There is nothing to wind;
    // whoever starts it next says where from.
    if (_player.source == null) return;
    await _player.seek(_ofFile(position));
  });

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
      final playing = _player.state == ap.PlayerState.playing;

      // The new speed takes over in a second player: playing, without a
      // stop; paused, without the playhead being wound to the start and
      // back on the way. Only if the second player cannot be readied does
      // it fall back to the swap below, with its moment of silence.
      if (await _handOver(open.file, playing: playing)) return;

      // The copy at the new speed goes in under the playhead: same place
      // in the recording, which is a different place in the file.
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

  /// Carries on playing [file] - the recording at the speed now asked for
  /// - in a second player, from where the recording has got to, and only
  /// then stops the first.
  ///
  /// Swapping the file in the one player meant pausing it, opening the new
  /// file and starting again: a gap in the sound, and the play button
  /// flicking to "paused" and back. Here the new file is opened while the
  /// old one plays on, and the two meet at the playhead.
  ///
  /// Paused, the new file is simply readied at the same place and takes
  /// over in silence: swapped in the one player instead, it reported the
  /// start of the file on the way, and the played bars went back to
  /// nothing and forward again.
  ///
  /// False when the new player could not be readied; nothing has changed
  /// then, and the caller swaps the file the old way.
  Future<bool> _handOver(String file, {required bool playing}) async {
    final outgoing = _player;
    final outgoingFactor = _factor;
    final incomingFactor = _factorOfCopy[file] ?? 1;
    final incoming = ap.AudioPlayer();

    try {
      await incoming.setSource(ap.DeviceFileSource(file));
      // The recording itself, where no copy could be made, is sped up by
      // the player; a copy already runs at the speed.
      final owed = incomingFactor == 1 ? _rate : 1.0;
      if (owed != 1) await incoming.setPlaybackRate(owed);

      // Read as late as possible: the old file has played on while the
      // new one opened, and this is where the listener now is.
      final inFile = await outgoing.getCurrentPosition() ?? Duration.zero;
      final inRecording = Duration(
        microseconds: (inFile.inMicroseconds * outgoingFactor).round(),
      );
      if (inRecording > Duration.zero) {
        await incoming.seek(
          Duration(
            microseconds: (inRecording.inMicroseconds / incomingFactor).round(),
          ),
        );
      }

      _player = incoming;
      _told = owed;
      if (playing) {
        // The new file starts from where the old one was read; the old
        // one has said a little more since. Neither is let draw the
        // playhead back.
        _floor = inRecording > _lastPosition ? inRecording : _lastPosition;
        _floorSet = DateTime.now();
      }
      _listenTo(incoming);
    } catch (e) {
      debugPrint('SPEED HAND-OVER NOT READY ($_path): $e');
      unawaited(incoming.dispose());
      return false;
    }

    if (!playing) {
      unawaited(outgoing.dispose());
      return true;
    }

    // Started before the old one stops, so there is no gap between them;
    // the old one's "paused" goes nowhere, as it is no longer listened to.
    await _start(incoming.resume);
    try {
      await outgoing.pause();
    } catch (_) {}
    unawaited(outgoing.dispose());
    return true;
  }

  @override
  Future<Duration?> getDuration() async {
    final length = await _player.getDuration();
    return length == null ? null : _ofRecording(length);
  }

  @override
  Future<void> dispose() async {
    for (final feed in _feeds) {
      await feed.cancel();
    }
    await _refused.close();
    await _player.dispose();
    await _playing.close();
    await _position.close();
    await _duration.close();
    await _complete.close();
  }
}
