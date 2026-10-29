import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Audio/timeline_playback.dart';
import 'package:livuka/Widgets/review_player.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/Widgets/speed_selector.dart';
import 'package:livuka/Widgets/wave_bars.dart';
import 'package:livuka/main.dart';

// The passages and their marks are the engine's vocabulary and live beside
// it now. Every page that builds a player still finds them here.
export 'package:livuka/Audio/timeline_playback.dart'
    show AudioSegment, SegmentMark;

/// Plays a Set's takes as if they were one recording.
///
/// The playing itself is [TimelinePlayback]'s. This is the compact view over
/// one: a play button, the whole reading as one strip of bars, its pins, its
/// clock. It owns the engine it shows, and lends the same engine to the
/// full-screen player, so a reading carried over there is the same reading -
/// heard to the end in either place, it is heard.
class ContinuousPlayer extends StatefulWidget {
  const ContinuousPlayer({
    super.key,
    required this.segments,
    this.marks = const [],
    this.onMarkTap,
    this.onEnded,
    this.mustListen,
    this.onSegment,
    this.allowSeek = true,
    this.accent = MainApp.primaryGreen,
    this.header,
    this.subheader,
    this.title = 'Recording',
    this.onAddMark,
    this.addMarkLabel,
    this.addMarkColor,
    this.highlight = false,
    this.highlightUntilPlayed = false,
  });

  /// Whether playing this is the next thing to do: the play button pulses
  /// while it is not playing.
  final bool highlight;

  /// Whether the pulse goes for good the first time play is pressed,
  /// rather than staying until whoever set [highlight] takes it away.
  final bool highlightUntilPlayed;

  final List<AudioSegment> segments;

  /// What this recording is, set at the left of the controls row - the card
  /// around the player hands its heading in here rather than drawing it on a
  /// line of its own above. It scrolls sideways when it is longer than the
  /// room the controls leave it, so a long name is read in full rather than
  /// cut short.
  final Widget? header;

  /// A line under the heading, above the waveform.
  final Widget? subheader;
  final List<SegmentMark> marks;
  final ValueChanged<SegmentMark>? onMarkTap;

  /// Fires when the last passage finishes — a full listen. Reaching the end
  /// by skipping to it does not fire this; see [TimelinePlayback.heardUpTo].
  final VoidCallback? onEnded;

  /// Whether a full listen is still owed here; see
  /// [TimelinePlayback.mustListen]. Left out, it is owed wherever somebody
  /// is waiting to hear of one ([onEnded]). A page whose gate has already
  /// been opened says false, and the player stops minding how it is
  /// listened to.
  final bool? mustListen;

  /// Which passage the playhead is in, and how far into it.
  final void Function(String leafId, String label, Duration offset)? onSegment;

  final bool allowSeek;

  /// The play button and the played bars. Green for a team's own recording;
  /// the source audio takes indigo, so the two are never mistaken for each
  /// other on a screen that has both.
  final Color accent;

  /// What the full-screen player is headed with.
  final String title;

  /// Adds a comment or a question at the playhead, from the full-screen
  /// player. The page supplies it, and already knows where the playhead is:
  /// [onSegment] has been telling it all along.
  final Future<void> Function()? onAddMark;
  final String? addMarkLabel;
  final Color? addMarkColor;

  @override
  State<ContinuousPlayer> createState() => _ContinuousPlayerState();
}

class _ContinuousPlayerState extends State<ContinuousPlayer> {
  late TimelinePlayback _playback;

  /// Bumped when this widget is handed new marks or callbacks, so a
  /// full-screen player that is open over it picks them up. It was built by
  /// a route, not by this widget's parent, and would otherwise go on showing
  /// the marks there were when it opened - without the one just added.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _playback = _createPlayback();
  }

  TimelinePlayback _createPlayback() {
    final playback = TimelinePlayback(widget.segments)
      ..mustListen = widget.mustListen ?? widget.onEnded != null
      // Through the state rather than the widget of the moment, so a parent
      // that rebuilds with new closures is still the one that gets called.
      ..onEnded = (() {
        // Every passage, or it is not the whole reading. One that has not
        // been downloaded is left out of the timeline, and playing the rest
        // to the end is not having heard the Set.
        if (widget.segments.any((segment) => !segment.isAvailable)) return;
        widget.onEnded?.call();
      })
      ..onSegment = ((leafId, label, offset) =>
          widget.onSegment?.call(leafId, label, offset))
      ..addListener(_onPlayback);

    unawaited(playback.prepare());
    return playback;
  }

  /// Whether play has been pressed since this player was made.
  bool _played = false;

  void _onPlayback() {
    if (_playback.running) _played = true;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(ContinuousPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A different set of files is a different recording: what was measured,
    // heard and preloaded all belongs to the old one.
    if (!_samePassages(oldWidget.segments, widget.segments)) {
      _playback
        ..removeListener(_onPlayback)
        ..dispose();
      _playback = _createPlayback();
    }
    _playback.mustListen = widget.mustListen ?? widget.onEnded != null;

    // After the frame, not during it: whoever is listening rebuilds, and
    // nothing outside this widget may be asked to while it is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revision.value++;
    });
  }

  static bool _samePassages(List<AudioSegment> a, List<AudioSegment> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i].path != b[i].path ||
          a[i].leafId != b[i].leafId ||
          a[i].unavailable != b[i].unavailable) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _playback
      ..removeListener(_onPlayback)
      ..dispose();
    _revision.dispose();
    super.dispose();
  }

  /// Opens the same reading full screen.
  ///
  /// Nothing is paused and nothing is reloaded - the full-screen player is
  /// another view over the engine already running here.
  void _openFullScreen() {
    final playback = _playback;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _revision,
          // Read off the widget as it is now, not as it was when the route
          // was pushed.
          builder: (_, _, _) => ReviewPlayerPage(
            playback: playback,
            title: widget.title.tr,
            marks: widget.marks,
            onMarkTap: widget.onMarkTap,
            onAddMark: widget.onAddMark,
            addMarkLabel: widget.addMarkLabel,
            addMarkColor: widget.addMarkColor,
            accent: widget.accent,
            allowSeek: widget.allowSeek,
          ),
        ),
      ),
    );
  }

  // What the view reads off the engine, under the names it always had.
  List<AudioSegment> get _playable => _playback.playable;
  List<Duration> get _starts => _playback.starts;
  Duration get _total => _playback.total;
  Duration get _elapsed => _playback.elapsed;
  bool get _running => _playback.running;
  List<double> get _waveform => _playback.bars;

  /// The play button's width and the gap after it: how far in from the
  /// left the waveform starts, and so where the clocks under it start too.
  static const double _waveInset = 46;

  /// The strip the bars are drawn in. The bars sit on its centre line, so
  /// its height is also how far the clocks underneath sit from them: a
  /// taller strip left a band of nothing between a quiet recording's bars
  /// and its times.
  static const double _waveHeight = 40;

  static const TextStyle _clock = TextStyle(
    fontSize: 11,
    color: MainApp.mutedText,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static String _format(Duration value) => TimelinePlayback.format(value);

  @override
  Widget build(BuildContext context) {
    if (_playback.loading) {
      // The player's own shape, row for row: the heading and controls as
      // themselves, since they are fixed, and grey where the play button,
      // the waveform and the clocks will be.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayerControlsRow(header: widget.header ?? const SizedBox.shrink()),
          Shimmer(child: PlayerWaveBones(waveTop: _waveTop)),
        ],
      );
    }

    // One timeline needs every passage's length. When they cannot be read -
    // an encoder the waveform decoder will not measure, most often - the
    // passages are offered separately instead. They still play, which is
    // what matters; they just cannot be strung into a single track.
    if (_playback.error != null) {
      return Text(
        _playback.error!.tr,
        style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
      );
    }

    final progress = _playback.progress;

    // The bars underneath are always the unplayed grey, and the green is
    // always the strip drawn over them - only how much of it shows changes.
    //
    // Recolouring the bars themselves meant rebuilding the waveform, which
    // reads on screen as the audio reloading at the very moment it finishes.
    // Nothing is rebuilt now; the green covers exactly what has been played
    // up to the playhead, and the whole width only once the reading has run
    // out at its end and nobody has moved since - see
    // [TimelinePlayback.atEnd].
    final played = _playback.atEnd ? 1.0 : progress;

    // Time runs left to right whatever language the app is in. Left to
    // mirror, the play button and the clock would swap ends under Urdu while
    // the waveform between them still read from the left.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The controls, above the waveform's right-hand end - the website's
        // arrangement. They used to share the line under the waveform with
        // the two clocks, which left the total squeezed into a corner and
        // nothing at all under the waveform's left end.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              Expanded(
                child: widget.header == null
                    ? const SizedBox.shrink()
                    // In the reader's own direction, inside a row that is
                    // held left to right for the sake of the waveform.
                    : Directionality(
                        textDirection: Directionality.of(context),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: widget.header,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              // The whole reading in a strip this wide is a summary. Finding
              // one word in twenty minutes wants the full-screen view, which
              // zooms; this is the way into it.
              IconButton(
                onPressed: _total == Duration.zero ? null : _openFullScreen,
                tooltip: 'Full screen'.tr,
                icon: const Icon(Icons.open_in_full_rounded),
                iconSize: 16,
                color: MainApp.mutedText,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
              ),
              const SizedBox(width: 4),
              SpeedSelector(
                value: _playback.speed,
                onChanged: _playback.setSpeed,
              ),
            ],
          ),
        ),
        if (widget.subheader != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 4),
            child: widget.subheader,
          ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: [
              // The row centres its children over the whole strip, but the
              // waveform sits in the lower part of it - the space above is the
              // pins' lane. Nudging the button down by that lane puts it level
              // with the middle of the wave rather than the middle of the box.
              Padding(
                padding: EdgeInsets.only(top: _waveTop),
                child: PulseHalo(
                  active:
                      widget.highlight &&
                      !_running &&
                      !(widget.highlightUntilPlayed && _played),
                  color: widget.accent,
                  minSize: 38,
                  maxSize: 72,
                  child: GestureDetector(
                    onTap: _playback.toggle,
                    // The triangle is a hole cut in the icon's circle, so the
                    // halo showed through it. A small white disc behind,
                    // just big enough to fill the triangle (and the pause
                    // bars), keeps it white.
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        MarkColors.shaded(
                          widget.accent,
                          Icon(
                            _running ? Icons.pause_circle : Icons.play_circle,
                            size: 38,
                            color: widget.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    // Tall enough to hold the pins as well as the waveform.
                    // They used to be drawn at a negative offset, which paints
                    // fine under Clip.none but is never hit-tested: a tap
                    // outside the Stack's own bounds does not reach the child,
                    // so a pin could look right and do nothing.
                    return SizedBox(
                      height: _waveTop + _waveHeight,
                      child: Stack(
                        children: [
                          Positioned(
                            top: _waveTop,
                            left: 0,
                            right: 0,
                            child: GestureDetector(
                              onTapDown: widget.allowSeek
                                  ? (d) => _playback.seekFraction(
                                      d.localPosition.dx / width,
                                    )
                                  : null,
                              child: _wave(width, _unplayed, _unplayed),
                            ),
                          ),
                          if (played > 0)
                            Positioned(
                              top: _waveTop,
                              left: 0,
                              // Sized on the Positioned itself. Setting only
                              // `left` leaves the child unbounded in both
                              // directions, and pinning `left` and `right`
                              // makes the width tight, which is what made
                              // Align drop its widthFactor. Stating both
                              // avoids each trap.
                              width: (width * played).clamp(0.0, width),
                              height: _waveHeight,
                              child: IgnorePointer(
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.centerLeft,
                                    minWidth: width,
                                    maxWidth: width,
                                    minHeight: 52,
                                    maxHeight: 52,
                                    child: MarkColors.shaded(
                                      widget.accent,
                                      _wave(
                                        width,
                                        widget.accent,
                                        widget.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ..._buildSegmentTicks(width),
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
        // Under the waveform and no wider than it: where playback has got to
        // at its left end, how long the whole thing runs at its right - each
        // beside the end of the strip it describes.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.only(left: _waveInset),
            child: Row(
              children: [
                // At the end, as the bars are, until the listener moves.
                Text(
                  _format(_playback.atEnd ? _total : _elapsed),
                  style: _clock,
                ),
                const Spacer(),
                Text(_format(_total), style: _clock),
              ],
            ),
          ),
        ),
        if (_playback.listenHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: ListenHint(text: _playback.listenHint!),
          ),
        ..._buildMissingNotes(),
      ],
    );
  }

  /// What is absent from the recording, said under it.
  ///
  /// One reason shared by every missing passage is a fact about the Set, so
  /// it is stated once; otherwise each passage is named with its own, since
  /// "not added" and "not downloaded" send you to different places.
  List<Widget> _buildMissingNotes() {
    final missing = widget.segments.where((s) => !s.isAvailable).toList();
    if (missing.isEmpty) return const [];

    final reasons = missing.map((s) => s.unavailable!).toSet();
    // Two whole sentences side by side, each translated as one.
    final howMany = '@missing of @total passages are not in this recording.'
        .trParams({
          'missing': '${missing.length}',
          'total': '${widget.segments.length}',
        });
    final lines = reasons.length == 1
        ? [
            missing.length == widget.segments.length
                ? reasons.first.tr
                : '$howMany ${reasons.first.tr}',
          ]
        : [for (final s in missing) '${s.label}: ${s.unavailable!.tr}'];

    return [
      const SizedBox(height: 8),
      for (final line in lines)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline,
                size: 13,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  line,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Where one passage ends and the next begins — a plain black rule,
  /// unlabelled. It reads as a division of the same recording rather than as
  /// a mark on it, which is what the pins above the waveform are for.
  List<Widget> _buildSegmentTicks(double width) {
    if (_total == Duration.zero || _playable.length < 2) return const [];

    final totalMs = _total.inMilliseconds;

    return [
      // From the second passage on. The first begins at zero, where a rule
      // would sit on the waveform's own edge and read as a border.
      for (var i = 1; i < _playable.length; i++)
        Positioned(
          left: (_starts[i].inMilliseconds / totalMs).clamp(0.0, 1.0) * width,
          top: _waveTop,
          child: Container(
            width: 2,
            height: _waveHeight,
            color: const Color(0xFF040134),
          ),
        ),
    ];
  }

  /// How far a pin's lane sits above the waveform, and so where the
  /// waveform itself begins.
  static const double _pinLane = 15;

  /// The lane is only there to hold pins. A player with none - the source
  /// audio, or any recording nobody has marked - was reserving thirty empty
  /// pixels above its waveform, which read as a gap between the heading and
  /// the player rather than as room for something.
  double get _waveTop => widget.marks.isEmpty ? 0 : _pinLane * 2;

  List<Widget> _buildMarks(double width) {
    if (widget.marks.isEmpty || _total == Duration.zero) return const [];

    final totalSeconds = _total.inMilliseconds / 1000;

    final placed = <({SegmentMark mark, double x})>[];
    for (final mark in widget.marks) {
      final at = _playback.absoluteSecondsOf(mark);
      if (at == null) continue;
      placed.add((mark: mark, x: (at / totalSeconds).clamp(0.0, 1.0) * width));
    }
    placed.sort((a, b) => a.x.compareTo(b.x));

    // Two lanes. Questions asked seconds apart land on top of one another,
    // and a covered pin cannot be tapped at all - only the last one drawn
    // receives the gesture.
    final widgets = <Widget>[];
    var lane = 0;
    double? previousX;

    for (final item in placed) {
      lane = (previousX != null && (item.x - previousX) < 26) ? 1 - lane : 0;
      previousX = item.x;

      // The bubble stays inside the strip; only the stem marks the moment.
      // A pin in the first or last second used to be drawn half off the edge
      // - cut in two by the clip, its icon gone, and the half outside the
      // bounds deaf to taps.
      const bubble = 22.0;
      const box = 26.0;
      final boxLeft = (item.x - box / 2).clamp(0.0, width - box);
      final stemLeft = (item.x - boxLeft - 1).clamp(0.0, box - 2);
      final top = lane * _pinLane;
      final stemHeight = (_waveTop + 26) - bubble - top;

      widgets.add(
        Positioned(
          left: boxLeft,
          top: top,
          child: GestureDetector(
            // Without this the gaps either side of the stem stay transparent
            // to taps, so most of the target does nothing.
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onMarkTap?.call(item.mark),
            child: SizedBox(
              width: box,
              height: bubble + stemHeight,
              child: Stack(
                children: [
                  // Reaches down to the waveform's centre line, where the
                  // bars actually sit. Stopping at the top of the 52px band
                  // left the stem hanging above quiet audio, which is what
                  // made the mark look detached from the recording.
                  Positioned(
                    left: stemLeft,
                    top: bubble - 2,
                    child: Container(
                      width: 2,
                      height: stemHeight + 2,
                      color: item.mark.color,
                    ),
                  ),
                  Positioned(
                    left: (box - bubble) / 2,
                    top: 0,
                    child: Container(
                      width: bubble,
                      height: bubble,
                      // Filled, not outlined. A white disc with a coloured
                      // rim is nearly invisible over a pale card, and what a
                      // pin has to say is its colour.
                      decoration: BoxDecoration(
                        color: item.mark.color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        item.mark.icon,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// Unplayed bars. The same grey as [AudioClip]'s, so a passage looks the
  /// same whether it is heard on its own or as part of the Set; the played
  /// colour is the widget's accent.
  static const Color _unplayed = Color(0xFFAEB6BE);

  Widget _wave(double width, Color fixed, Color live) {
    // AudioFileWaveforms only reads waveformData in its own initState, so it
    // must not be built before the bars exist. Until they do, a flat rule
    // stands in - the timeline is already usable, and an empty space where
    // the recording should be reads as a failure rather than as a wait.
    if (_waveform.isEmpty) {
      return SizedBox(
        width: width,
        height: _waveHeight,
        child: Center(
          child: Container(height: 2, width: width, color: fixed),
        ),
      );
    }

    // The painter lays bars out at a fixed spacing and drops whatever falls
    // past the edge - it does not scale to fit, despite the name. With more
    // bars than the width can hold, the tail of the recording is simply not
    // drawn, and a pin placed by its share of the duration lands somewhere
    // the waveform does not agree with. So the bars are resampled to exactly
    // the number that fit.
    //
    // And the other way about: a strip wider than the bars at four pixels
    // each - a tablet on its side - spreads them to the far end, where the
    // taps, the played colour and the pins already reach.
    final count = ((width - 4.0) / 4.0).floor().clamp(1, _waveform.length);
    final spacing = width / count;
    final fitted = TimelinePlayback.resample(_waveform, count);

    return SizedBox(
      width: width,
      height: _waveHeight,
      child: WaveBars(
        bars: fitted,
        color: fixed,
        height: _waveHeight,
        spacing: spacing,
      ),
    );
  }
}

/// The line under a player whose end was reached without a full listen.
///
/// Shared with the full-screen player, which says the same thing in the same
/// words - it is the same reading, and the same gate that did not open.
class ListenHint extends StatelessWidget {
  const ListenHint({super.key, required this.text, this.dark = false});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 13, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text.tr,
            style: TextStyle(fontSize: 11, height: 1.4, color: color),
          ),
        ),
      ],
    );
  }
}
