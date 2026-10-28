import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:livuka/Audio/audio_backend.dart';
import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/Audio/timeline_playback.dart';
import 'package:livuka/Audio/waveform_cache.dart';
import 'package:livuka/Widgets/continuous_player.dart' show ListenHint;
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/review_player.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/speed_selector.dart';
import 'package:livuka/Widgets/wave_bars.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/Widgets/pulse_halo.dart';

/// A point pinned onto a clip's waveform — a question or a review mark.
class ClipMark {
  const ClipMark({
    required this.id,
    required this.positionSeconds,
    this.color = const Color(0xFFDC2626),
    this.icon = Icons.help_outline,
  });

  final String id;
  final double positionSeconds;
  final Color color;
  final IconData icon;
}

/// A waveform player for one audio file.
///
/// Playback goes through [AudioBus], so starting this clip stops whatever
/// else was sounding anywhere in the app.
/// A waveform player for one audio file, on either face of the app.
///
/// On the desktop every recording - a take, a source passage, a comment, a
/// back translation - is drawn by the one desktop player, so they all
/// share a waveform, differing only in accent colour by kind. On a phone
/// the phone's own clip is used. The rules the callers rely on (a full
/// listen, marks, seeking, speed) mean the same on both.
class AudioClip extends StatelessWidget {
  const AudioClip({
    super.key,
    required this.filePath,
    this.onPosition,
    this.onEnded,
    this.mustListen,
    this.marks = const [],
    this.onMarkTap,
    this.allowSeek = false,
    this.showSpeed = true,
    this.highlight = false,
    this.accent = MainApp.primaryGreen,
    this.title = 'Recording',
    this.showExpand = true,
    this.header,
    this.onAddMark,
    this.addMarkLabel,
    this.addMarkColor,
  });

  /// Leaves a comment from inside the full-screen player, as the web's
  /// full-wave popup offers beside a recording that can be commented on.
  /// The compact clip itself is not changed: the page keeps its own
  /// button beside it, and this is the same action carried into the
  /// expanded view, where the player is paused first.
  final Future<void> Function()? onAddMark;
  final String? addMarkLabel;
  final Color? addMarkColor;

  final Widget? header;
  static Widget label(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: MainApp.mutedText),
      const SizedBox(width: 6),
      Text(
        text.tr,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MainApp.mutedText,
        ),
      ),
    ],
  );

  final String filePath;
  final String title;
  final bool showExpand;
  final VoidCallback? onEnded;

  /// Whether a full listen is still owed here; see
  /// [TimelinePlayback.mustListen]. Left out, it is owed wherever
  /// [onEnded] is given.
  final bool? mustListen;
  final Color accent;
  final List<ClipMark> marks;
  final ValueChanged<ClipMark>? onMarkTap;
  final bool allowSeek;
  final bool showSpeed;
  final ValueChanged<Duration>? onPosition;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return _PhoneClip(
      filePath: filePath,
      onPosition: onPosition,
      onEnded: onEnded,
      mustListen: mustListen,
      marks: marks,
      onMarkTap: onMarkTap,
      allowSeek: allowSeek,
      showSpeed: showSpeed,
      highlight: highlight,
      accent: accent,
      title: title,
      showExpand: showExpand,
      header: header,
      onAddMark: onAddMark,
      addMarkLabel: addMarkLabel,
      addMarkColor: addMarkColor,
    );
  }
}

class _PhoneClip extends StatefulWidget {
  const _PhoneClip({
    required this.filePath,
    this.onPosition,
    this.onEnded,
    this.mustListen,
    this.marks = const [],
    this.onMarkTap,
    this.allowSeek = false,
    this.showSpeed = true,
    this.highlight = false,
    this.accent = MainApp.primaryGreen,
    this.title = 'Recording',
    this.showExpand = true,
    this.header,
    this.onAddMark,
    this.addMarkLabel,
    this.addMarkColor,
  });

  /// Carried into the full-screen player; see [AudioClip.onAddMark].
  final Future<void> Function()? onAddMark;
  final String? addMarkLabel;
  final Color? addMarkColor;

  /// What this recording is, set at the top left of the waveform beside the
  /// controls. A heading on a line of its own above the player cost a row
  /// for a few words, and left the space beside the controls empty. It
  /// scrolls sideways when it is longer than the room it has.
  final Widget? header;

  /// The usual heading: a small icon and a muted label.

  final String filePath;

  /// What the full-screen player calls this recording.
  final String title;

  /// Whether to offer the full-screen player. On for every recording; there
  /// for a caller with a clip too small to be worth it.
  final bool showExpand;

  /// Fires when the clip reaches its end. Community test gates its hand-off
  /// on a full listen, which needs the difference between "played" and
  /// "played all the way through".
  ///
  /// Reaching the end by tapping near it does not count, and does not fire
  /// this - only an end that was played up to does.
  final VoidCallback? onEnded;

  /// Whether a full listen is still owed; see [AudioClip.mustListen].
  final bool? mustListen;

  /// The play button and the played bars. Green unless told otherwise; the
  /// source audio is indigo wherever it appears.
  final Color accent;

  /// Pins drawn over the waveform at their timestamps.
  final List<ClipMark> marks;
  final ValueChanged<ClipMark>? onMarkTap;

  /// Lets a tap on the waveform jump to that point.
  final bool allowSeek;

  /// Offers playback speed beside the clip. Off where the row is already
  /// crowded - the composer's preview sits next to a mic and a bin.
  final bool showSpeed;

  /// Fires as playback moves. The recorder screen anchors marks to this, so a
  /// reviewer can stop on a problem and pin a note to that exact second.
  final ValueChanged<Duration>? onPosition;

  /// Ripples the play button while something else on the screen is waiting
  /// on this clip being heard. The recorder holds its mic until the source
  /// has been played, and a button that is merely greyed does not say which
  /// other button would ungrey it.
  final bool highlight;

  @override
  State<_PhoneClip> createState() => _AudioClipState();
}

class _AudioClipState extends State<_PhoneClip> {
  final AudioBackend _audioPlayer = AudioBackend();
  StreamSubscription<bool>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<double>? _speedSubscription;
  StreamSubscription<void>? _completeSubscription;

  List<double> _waveform = const [];
  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  /// Whether this clip has been listened to right through. The bars stay
  /// green afterwards instead of reverting to grey, so a reviewer working
  /// down a long list can see at a glance which ones they have already
  /// heard. Only a full listen counts - a clip stopped part way is one the
  /// reviewer still has to come back to.
  bool _heard = false;

  /// How far into the clip has been heard without a break.
  ///
  /// The drafter's mic waits on [AudioClip.onEnded], and "the file finished"
  /// was never proof of listening: with seeking on, one tap at the right-hand
  /// edge finished it. So the end only counts when playback arrived there
  /// from here. Seeking stays free; it just does not move this. The same
  /// rule the merged player keeps - see `TimelinePlayback.heardUpTo`.
  Duration _heardUpTo = Duration.zero;

  /// The last place playback itself reported being. Kept apart from
  /// [_position], which is for the clock and is wound back to zero by the
  /// player as it finishes - and the end is judged from where the listener
  /// was just before that.
  Duration _listenedAt = Duration.zero;

  /// True once the end has been reached by skipping, until play is pressed
  /// again. A gate that stays shut without a word reads as a fault.
  bool _skippedAhead = false;

  /// Where the next play should pick up, after an end that did not count:
  /// the part not yet heard, rather than the whole clip again.
  Duration? _resumeAt;

  /// How far past [_heardUpTo] playback may be and still count as carrying
  /// straight on. Positions come about five times a second of real time,
  /// which at 5x is a second of the recording between one and the next, so
  /// the allowance grows with the speed.
  /// Where the last seek was aimed, and when it was asked for.
  Duration? _seekTarget;
  DateTime? _seekAsked;

  /// Whether a position is left over from before the last seek.
  ///
  /// A seek takes a moment to land and the player reports its old place in
  /// the meantime. Seek to the final instant, take one such report, and the
  /// end could arrive looking as though it had been listened up to. So
  /// until the player reaches the target - or plainly is not going to -
  /// anything from short of it is not believed.
  bool _isStale(Duration position) {
    final target = _seekTarget;
    final asked = _seekAsked;
    if (target == null || asked == null) return false;

    final landed = position >= target - const Duration(milliseconds: 500);
    final givenUp =
        DateTime.now().difference(asked) > const Duration(milliseconds: 1500);

    if (landed || givenUp) {
      _seekTarget = null;
      _seekAsked = null;
      return false;
    }
    return true;
  }

  Duration get _tolerance =>
      Duration(milliseconds: 1500 + (400 * (_speed - 1)).round());

  bool get _mustListen => widget.mustListen ?? widget.onEnded != null;

  /// Playback speed. audioplayers resets the rate with each new source, so
  /// this is the remembered choice rather than the player's state.
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _audioPlayer.onPlayingChanged.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);

      if (playing) {
        AudioBus.instance.claim(this);
      } else {
        AudioBus.instance.release(this);
      }
    });
    _completeSubscription = _audioPlayer.onComplete.listen((_) {
      // Played out from where listening had got to: heard to the end, even
      // though the last position reported falls a little short of it.
      if (_listenedAt <= _heardUpTo + _tolerance) _heardUpTo = _duration;

      // A clip whose length was never learnt cannot be seeked either, so
      // finishing it can only have been done by listening.
      final listened =
          _heard ||
          _duration == Duration.zero ||
          _heardUpTo >= _duration - _tolerance;

      _listenedAt = Duration.zero;
      _paused = false;
      if (mounted) setState(() => _position = Duration.zero);

      if (!listened) {
        // Only where a full listen is owed is the listener told, and
        // taken back. Anywhere else the clip has simply ended.
        if (!_mustListen) return;
        _resumeAt = _heardUpTo;
        if (mounted) setState(() => _skippedAhead = true);
        return;
      }

      if (mounted) setState(() => _heard = true);
      widget.onEnded?.call();
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;

      // Zero is only believed at a start: a player winding itself back as
      // it finishes says zero too, and that is not where the listener was.
      if (!(position == Duration.zero && _listenedAt > Duration.zero) &&
          !_isStale(position)) {
        _listenedAt = position;
        if (position > _heardUpTo && position <= _heardUpTo + _tolerance) {
          _heardUpTo = position;
        }
      }

      setState(() => _position = position);
      widget.onPosition?.call(position);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      // The player's word is taken only until the file has given its own.
      if (mounted && !_lengthFromFile) setState(() => _duration = duration);
    });
    _speedSubscription = _audioPlayer.onSpeedRefused.listen((speed) {
      // Said once: the engine says it again each time the speed is asked
      // for, and the selector has already gone back by then.
      if (!mounted || _speed == speed) return;
      setState(() => _speed = speed);
      toaster(AudioBackend.speedRefusedMessage);
    });

    AudioBus.instance.addListener(_stopIfSupplanted);

    // Read before: drawn in the first frame, and the length said in it.
    final known = WaveformCache.peek(widget.filePath);
    if (known != null) _waveform = known.bars;

    final length = known != null && known.duration > Duration.zero
        ? known.duration
        : WaveformCache.lengthNow(widget.filePath);
    if (length != null && length > Duration.zero) {
      _duration = length;
      _lengthFromFile = true;
    }

    unawaited(_loadAudio());
  }

  /// Something else took over, so this one gives up the speaker.
  void _stopIfSupplanted() {
    if (_isPlaying && !AudioBus.instance.holds(this)) {
      // Paused, not stopped: coming back to this clip carries on from where
      // the other one cut in.
      _paused = true;
      unawaited(_audioPlayer.pause());
    }
  }

  /// Held part way through, to be carried on from there. A tap on the button
  /// used to STOP the clip, so pausing a two-minute source recording to
  /// check the script meant hearing it again from the top.
  bool _paused = false;

  Future<void> _loadAudio() async {
    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        throw Exception('Audio file is not available offline');
      }

      // Neither waits for the other. Drawing a waveform means reading
      // every sample of the file, and waiting for that to offer playback
      // is what made a clip sit on its spinner long after it was ready to
      // play; the player in its turn can take the better part of a second
      // to open a file, and the bars were not asked for until it had.
      unawaited(_loadLength());
      unawaited(_loadWaveform());

      await _audioPlayer.setSource(widget.filePath);
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (error) {
      debugPrint('CLIP LOAD FAILED (${widget.filePath}): $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // This screen's own sentence is shown as written; anything the
        // player threw is not.
        _error = error is PlatformException
            ? AudioBackend.failedMessage
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Whether [_duration] was read from the recording itself.
  bool _lengthFromFile = false;

  /// How long the recording runs, from the recording. A recording is as
  /// long as it is at any speed; what the player reports is the length of
  /// whatever it has been given to play, which at 5x is a fifth of that.
  Future<void> _loadLength() async {
    try {
      final length = await WaveformCache.duration(widget.filePath);
      if (!mounted || length <= Duration.zero) return;
      setState(() {
        _lengthFromFile = true;
        _duration = length;
      });
    } catch (e) {
      debugPrint('CLIP LENGTH UNAVAILABLE (${widget.filePath}): $e');
    }
  }

  /// The bars, once they have been read.
  ///
  /// Read once per file per session. AudioFileWaveforms draws whatever bars
  /// it is handed, so its controller never has to be prepared.
  ///
  /// A waveform that cannot be read is not a reason to refuse the file: the
  /// decoder behind the bars is fussier than the one behind playback, so the
  /// clip still plays and simply shows the flat rule it started with.
  ///
  /// Asked for again when nothing came: a file still being written when
  /// it was first read is whole a moment later.
  Future<void> _loadWaveform() async {
    if (_waveform.isNotEmpty) return;

    for (final wait in const [0, 1, 3]) {
      if (wait > 0) await Future<void>.delayed(Duration(seconds: wait));
      if (!mounted) return;

      try {
        final bars = (await WaveformCache.load(widget.filePath)).bars;
        if (bars.isNotEmpty) {
          if (mounted) setState(() => _waveform = bars);
          return;
        }
      } catch (e) {
        debugPrint('WAVEFORM UNAVAILABLE (${widget.filePath}): $e');
      }
    }
  }

  /// Opens this recording in the full-screen player.
  ///
  /// The clip's own little player is paused and a full engine is made for
  /// the one file - the big player wants a zoomable waveform, a scrubbing
  /// playhead and its own record of what has been heard, none of which this
  /// widget keeps. Hearing the recording to the end in there counts exactly
  /// as it does here: the same `onEnded`, so a listen gate opened by the
  /// source audio or the back translation opens either way.
  Future<void> _openFullScreen() async {
    if (_isLoading || _error != null) return;

    if (_isPlaying) {
      _paused = true;
      await _audioPlayer.pause();
    }
    if (!mounted) return;

    const leaf = 'clip';
    final playback = TimelinePlayback([
      AudioSegment(leafId: leaf, label: '', path: widget.filePath),
    ]);
    playback.mustListen = _mustListen;
    // The playhead, reported as the compact clip reports its own: a page
    // that pins a comment where the recording is paused needs the spot
    // whichever player it was paused in.
    playback.onSegment = (_, _, offset) => widget.onPosition?.call(offset);
    playback.onEnded = () {
      if (mounted) setState(() => _heard = true);
      widget.onEnded?.call();
    };
    unawaited(playback.prepare());

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ReviewPlayerPage(
          playback: playback,
          title: widget.title.tr,
          accent: widget.accent,
          onAddMark: widget.onAddMark,
          addMarkLabel: widget.addMarkLabel,
          addMarkColor: widget.addMarkColor,
          marks: [
            for (final mark in widget.marks)
              SegmentMark(
                id: mark.id,
                leafId: leaf,
                offsetSeconds: mark.positionSeconds,
                color: mark.color,
                icon: mark.icon,
              ),
          ],
          onMarkTap: widget.onMarkTap == null
              ? null
              : (tapped) => widget.onMarkTap!(
                  widget.marks.firstWhere((mark) => mark.id == tapped.id),
                ),
        ),
      ),
    );

    // Silenced at once, thrown away a moment later. The page is still on
    // screen while it slides out, drawing from this engine, and one disposed
    // under it reads to that page as having been orphaned.
    unawaited(playback.pause());
    Future<void>.delayed(const Duration(milliseconds: 600), playback.dispose);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _audioPlayer.setPlaybackRate(speed);
  }

  Future<void> _togglePlayback() async {
    if (_isLoading) return;
    // A tap is another go: what went wrong last time is not still wrong
    // until it goes wrong again.
    if (_error != null && mounted) setState(() => _error = null);
    try {
      if (_isPlaying) {
        _paused = true;
        await _audioPlayer.pause();
      } else if (_paused && _resumeAt == null) {
        _paused = false;
        AudioBus.instance.claim(this);
        await _audioPlayer.resume();
        await _audioPlayer.setPlaybackRate(_speed);
      } else {
        _paused = false;
        // Claimed before the source starts, so the clip that was already
        // sounding is stopped rather than briefly overlapping this one.
        AudioBus.instance.claim(this);

        final resumeAt = _resumeAt;
        _resumeAt = null;
        _listenedAt = resumeAt ?? Duration.zero;
        if (_skippedAhead && mounted) setState(() => _skippedAhead = false);

        await _audioPlayer.play(widget.filePath);
        // Playing a source starts it at normal pace, so a chosen speed has
        // to be set again rather than once.
        await _audioPlayer.setPlaybackRate(_speed);
        if (resumeAt != null && resumeAt > Duration.zero) {
          await _audioPlayer.seek(resumeAt);
        }
      }
    } catch (error) {
      // What the phone said goes to the log. On the screen it is a page
      // of the player's own workings, which tells a drafter nothing and
      // pushes the passage they came to read off the panel.
      debugPrint('CLIP PLAYBACK FAILED (${widget.filePath}): $error');
      if (mounted) setState(() => _error = AudioBackend.failedMessage);
    }
  }

  @override
  void dispose() {
    AudioBus.instance.removeListener(_stopIfSupplanted);
    AudioBus.instance.release(this);
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _speedSubscription?.cancel();
    _completeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  /// The play button's width and the gap after it: where the waveform
  /// starts, and so where the clocks under it start.
  static const double _waveInset = 29;

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = _duration == Duration.zero
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    // The total, always. Where playback has got to is said by the marker on
    // the waveform, at the spot it is talking about.
    final displayDuration = _duration;
    final clock = TextStyle(
      fontSize: 11,
      color: colors.onSurface.withValues(alpha: 0.6),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // The bars underneath are always the unplayed grey, and the green is
    // always the strip over them - only how much of it shows changes. Green
    // covers the whole width once the clip has been heard and is back at its
    // start, so a reviewer can see which clips they have been through; it
    // covers what has been played otherwise.
    //
    // Recolouring the bars themselves meant rebuilding the waveform, which
    // reads on screen as the clip reloading the moment it finishes.
    final played = _heard && !_isPlaying && _position == Duration.zero
        ? 1.0
        : progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The controls, above the waveform's right-hand end, the way the
        // website has them - leaving the whole width beside the play button
        // to the waveform itself.
        if (widget.showSpeed || widget.showExpand || widget.header != null)
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              children: [
                Expanded(
                  child: widget.header == null
                      ? const SizedBox.shrink()
                      // In the reader's own direction, inside a row held
                      // left to right for the waveform's sake.
                      : Directionality(
                          textDirection: Directionality.of(context),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: widget.header,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                if (widget.showExpand)
                  // A full 34px to aim at, though the glyph is small.
                  InkResponse(
                    onTap: _isLoading || _error != null
                        ? null
                        : _openFullScreen,
                    radius: 20,
                    child: Tooltip(
                      message: 'Full screen'.tr,
                      child: SizedBox(
                        width: 34,
                        height: 30,
                        child: Icon(
                          Icons.open_in_full_rounded,
                          size: 16,
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                if (widget.showSpeed) ...[
                  const SizedBox(width: 4),
                  SpeedSelector(
                    value: _speed,
                    onChanged: _setSpeed,
                    enabled: !_isLoading,
                  ),
                ],
              ],
            ),
          ),
        // Time runs left to right whatever language the app is in, so the
        // play button stays at the end the recording starts from.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              // A grey disc where the play button will be, lit by the same
              // moving light as every other loading shape in the app.
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: Shimmer(child: Bone.circle(size: 32)),
                    )
                  : PulseHalo(
                      // Only while it is the thing to do: once it is playing,
                      // the drafter has done what the ripple was asking for.
                      active: widget.highlight && !_isPlaying,
                      child: GestureDetector(
                        onTap: _togglePlayback,
                        child: MarkColors.shaded(
                          widget.accent,
                          Icon(
                            color: widget.accent,
                            size: 25,
                            _isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ),
              const SizedBox(width: 4),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return SizedBox(
                      height: 52,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTapDown: widget.allowSeek
                                ? (details) =>
                                      _seekTo(details.localPosition.dx / width)
                                : null,
                            child: _waveformView(
                              width: width,
                              fixedColor: _unplayed,
                              liveColor: _unplayed,
                            ),
                          ),
                          if (played > 0)
                            IgnorePointer(
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: played,
                                  child: MarkColors.shaded(
                                    widget.accent,
                                    _waveformView(
                                      width: width,
                                      fixedColor: widget.accent,
                                      liveColor: widget.accent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ..._buildMarks(width),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Under the waveform and no wider than it: where playback has got
        // to at the left, the full length at the right.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.only(left: _waveInset, top: 2),
            child: Row(
              children: [
                Text(
                  _isLoading ? '--:--' : _formatDuration(_position),
                  style: clock,
                ),
                const Spacer(),
                Text(
                  // As soon as the file has said it, player or no player.
                  _isLoading && !_lengthFromFile
                      ? '--:--'
                      : _formatDuration(displayDuration),
                  style: clock,
                ),
              ],
            ),
          ),
        ),
        if (_skippedAhead && _mustListen)
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 8, top: 6),
            child: ListenHint(text: TimelinePlayback.skippedHint),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
            child: Text(
              _error!.tr,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Future<void> _seekTo(double fraction) async {
    if (_duration == Duration.zero) return;
    final target = Duration(
      milliseconds: (_duration.inMilliseconds * fraction.clamp(0.0, 1.0))
          .round(),
    );
    _listenedAt = target;
    _seekTarget = target;
    _seekAsked = DateTime.now();
    await _audioPlayer.seek(target);
    if (mounted) setState(() => _position = target);
  }

  /// Pins, drawn at their share of the total duration. Nothing is placed
  /// until the duration is known, since every position would otherwise
  /// collapse onto the left edge.
  List<Widget> _buildMarks(double width) {
    if (widget.marks.isEmpty || _duration == Duration.zero) return const [];

    final totalSeconds = _duration.inMilliseconds / 1000;

    return [for (final mark in widget.marks) _pin(mark, totalSeconds, width)];
  }

  /// One pin. The bubble is kept inside the strip and only the stem marks
  /// the moment: a pin in the first or last second otherwise hangs half off
  /// the edge, where a tap on it lands outside the player and does nothing.
  Widget _pin(ClipMark mark, double totalSeconds, double width) {
    const bubble = 22.0;
    final x = (mark.positionSeconds / totalSeconds).clamp(0.0, 1.0) * width;
    final left = (x - bubble / 2).clamp(0.0, width - bubble);
    final stemLeft = (x - left - 1).clamp(0.0, bubble - 2);

    return Positioned(
      left: left,
      top: -4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onMarkTap?.call(mark),
        child: SizedBox(
          width: bubble,
          height: bubble + 26,
          child: Stack(
            children: [
              Positioned(
                left: stemLeft,
                top: bubble - 2,
                child: Container(width: 2, height: 28, color: mark.color),
              ),
              Container(
                width: bubble,
                height: bubble,
                // Filled, as on the merged player: the pin's colour is
                // what it has to say, and a rim says it too quietly.
                decoration: BoxDecoration(
                  color: mark.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(mark.icon, size: 13, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unplayed bars. A solid mid-grey rather than a faint tint: before anyone
  /// presses play this is the only thing showing there is audio here at all.
  static const Color _unplayed = Color(0xFFAEB6BE);

  Widget _waveformView({
    required double width,
    required Color fixedColor,
    required Color liveColor,
  }) {
    // AudioFileWaveforms copies waveformData in its own initState and never
    // looks again - it has no didUpdateWidget - so building it before the
    // bars have been read leaves it permanently empty. That is why nothing
    // was drawn until playback started.
    // No bars: a flat rule stands in, so the clip still reads as a track
    // with a play head rather than an empty gap.
    if (_waveform.isEmpty) {
      return SizedBox(
        width: width,
        height: 60,
        child: Center(
          child: Container(height: 2, width: width, color: fixedColor),
        ),
      );
    }

    // One bar per four pixels, the spacing the recorder package used, so a
    // pin placed by its share of the duration lands where the bars agree.
    // A strip wider than the 240 bars the cache holds - a tablet on its
    // side - spreads them instead, so the bars still reach the far end
    // where the taps, the played colour and the pins already do.
    final count = ((width - 4.0) / 4.0).floor().clamp(1, _waveform.length);
    final spacing = width / count;
    final fitted = TimelinePlayback.resample(_waveform, count);

    return SizedBox(
      width: width,
      height: 60,
      child: WaveBars(
        bars: fitted,
        color: fixedColor,
        height: 60,
        spacing: spacing,
      ),
    );
  }
}
