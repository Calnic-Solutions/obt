import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'package:livuka/Audio/timeline_playback.dart';
import 'package:livuka/Widgets/continuous_player.dart' show ListenHint;
import 'package:livuka/Widgets/speed_selector.dart';
import 'package:livuka/main.dart';

/// The recording, full screen, as a small audio editor.
///
/// The compact player shows a whole Set in the width of a card, which is a
/// summary: twenty minutes in three hundred pixels cannot be aimed at. This
/// is the same recording with room to work - a window of it a few seconds
/// wide, a ruler over that, the whole track in a strip underneath, and
/// controls large enough to work with the thumb of the hand holding the
/// phone.
///
/// It is a second view over a [TimelinePlayback] that somebody else owns, not
/// a player of its own. That is the point of it: the position carries over
/// both ways, what has been heard carries over, and hearing the reading to
/// its end in here fires the very same `onEnded` as hearing it outside. The
/// web's full-screen player has an audio element of its own and needed a
/// hook to make a listen in it count; this one cannot fail to.
class ReviewPlayerPage extends StatefulWidget {
  const ReviewPlayerPage({
    super.key,
    required this.playback,
    required this.title,
    this.marks = const [],
    this.onMarkTap,
    this.onAddMark,
    this.addMarkLabel,
    this.addMarkColor,
    this.accent = MainApp.primaryGreen,
    this.allowSeek = true,
  });

  final TimelinePlayback playback;
  final String title;
  final List<SegmentMark> marks;
  final ValueChanged<SegmentMark>? onMarkTap;

  /// Adds a comment or a question at the playhead. When given, a large
  /// button for it sits at the very bottom, under the thumb. The page that
  /// supplies this already knows where the playhead is - the engine has been
  /// reporting it through `onSegment` all along - so nothing is passed.
  final Future<void> Function()? onAddMark;
  final String? addMarkLabel;
  final Color? addMarkColor;

  /// Played bars and the play button, matching the compact player this was
  /// opened from.
  final Color accent;

  final bool allowSeek;

  @override
  State<ReviewPlayerPage> createState() => _ReviewPlayerPageState();
}

/// What a finger on the page is doing to the playhead, if anything.
enum _Scrub {
  none,

  /// Dragging the playhead's handle: the window holds still and the
  /// playhead moves through it.
  handle,

  /// Dragging the waveform itself: the recording is pulled past the
  /// playhead, like tape past a head.
  body,

  /// A finger on the overview strip.
  overview,

  /// Let go, and waiting for the engine to arrive where it was sent. Without
  /// this the playhead darts back to where the audio still is for a moment,
  /// then forward again to where it was dropped.
  settle,
}

/// The numbers a frame is drawn from. The painters listen to this rather
/// than being rebuilt, so sixty frames a second costs sixty paints and not
/// sixty passes through the widget tree.
class _View extends ChangeNotifier {
  double t = 0;
  double start = 0;
  double window = 30;
  double total = 0;

  /// Heard in full and back at its start: every bar is drawn as played, the
  /// way the compact player draws it.
  bool allPlayed = false;

  void changed() => notifyListeners();
}

class _ReviewPlayerPageState extends State<ReviewPlayerPage>
    with SingleTickerProviderStateMixin {
  static const Color _scaffold = Color(0xFF0B0F14);
  static const Color _panel = Color(0xFF141A22);
  static const Color _grid = Color(0xFF243040);
  static const Color _text = Color(0xFFE5E7EB);
  static const Color _muted = Color(0xFF8B95A5);

  /// How wide the window may be, in seconds. The web's own list, so the two
  /// players zoom through the same steps.
  static const List<int> _zoomLevels = [5, 10, 20, 30, 60, 120, 300, 600];

  late final Ticker _ticker;
  final _View _view = _View();
  final ValueNotifier<int> _clock = ValueNotifier<int>(0);
  final Map<String, TextPainter> _labels = {};

  /// The width asked for. What is drawn is this or the whole track,
  /// whichever is shorter - a thirty second window on a twelve second clip
  /// would be most of a screen of nothing.
  int _zoom = 30;

  _Scrub _scrub = _Scrub.none;
  double _scrubT = 0;
  double _frozenStart = 0;
  Duration _settleBy = Duration.zero;
  DateTime _lastSeek = DateTime.fromMillisecondsSinceEpoch(0);

  /// The last position the engine reported, and when the ticker saw it.
  double _reported = -1;
  Duration _stamp = Duration.zero;
  Duration _lastTick = Duration.zero;

  /// How far the window sits from where the playhead model would put it.
  ///
  /// The model is exact and is where the window always ends up. But applied
  /// the instant a tap lands, it snatches the whole waveform sideways to put
  /// the tapped spot in the middle - a jump cut, the one thing this player
  /// is meant not to have. So a jump in time leaves the window where it was,
  /// records the difference here, and lets it run down to nothing over the
  /// next few frames: the playhead goes to the tap, then the tape glides
  /// under it.
  double _pan = 0;

  double _waveWidth = 1;
  double _overviewWidth = 1;
  bool _adding = false;
  bool _closing = false;

  TimelinePlayback get _playback => widget.playback;

  @override
  void initState() {
    super.initState();
    _playback.addListener(_onPlayback);
    unawaited(_playback.loadDetail());
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(ReviewPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.playback, widget.playback)) {
      oldWidget.playback.removeListener(_onPlayback);
      widget.playback.addListener(_onPlayback);
      unawaited(widget.playback.loadDetail());
      _reported = -1;
      _pan = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _playback.removeListener(_onPlayback);
    _view.dispose();
    _clock.dispose();
    for (final label in _labels.values) {
      label.dispose();
    }
    super.dispose();
  }

  void _onPlayback() {
    if (!mounted) return;

    // The compact player owns the engine, and can go away underneath this
    // page - its screen rebuilt around a different Set, say. Word of that
    // arrives while the tree is being torn down, when nothing may be
    // rebuilt, so all that happens here is a note to leave.
    if (_playback.isDisposed) {
      _leaveIfOrphaned();
      return;
    }

    setState(() {});
  }

  void _leaveIfOrphaned() {
    if (_closing) return;
    _closing = true;

    // Two frames on. If the engine was only being replaced, the page is
    // handed the new one in the frame after this, and should stay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _closing = false;
        // Only while this page is the one on top. Closing it by hand is
        // followed by its engine being disposed while the page is still
        // sliding away - still mounted, no longer current - and popping
        // "again" from there took the screen underneath with it, which is
        // how Close on a take's player landed back on the passage list.
        final onTop = ModalRoute.of(context)?.isCurrent ?? false;
        if (mounted && onTop && _playback.isDisposed) {
          Navigator.of(context).maybePop();
        }
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static double _seconds(Duration value) => value.inMicroseconds / 1e6;

  double get _total => _seconds(_playback.total);

  double _windowFor(double total) =>
      total > 0 ? math.min(_zoom.toDouble(), total) : _zoom.toDouble();

  /// Where the window starts for the playhead to be where the model says.
  ///
  /// windowStart = clamp(t - W/2, 0, max(0, T - W)). Under half a window in,
  /// the clamp holds the window at zero and the playhead sweeps from the
  /// left edge to the middle; from there the window moves with the time and
  /// the playhead stands still at the centre while the recording scrolls
  /// under it; and over the last half window the clamp holds again, and the
  /// playhead runs out from the centre to the right-hand edge, reaching it
  /// exactly as the recording ends.
  static double _idealStart(double t, double window, double total) =>
      (t - window / 2).clamp(0.0, math.max(0.0, total - window));

  void _onTick(Duration now) {
    final playback = _playback;
    if (playback.isDisposed) return;

    final dt = (_seconds(now - _lastTick)).clamp(0.0, 0.1);
    _lastTick = now;

    final total = _total;
    final window = _windowFor(total);
    final speed = playback.speed;

    final reported = _seconds(playback.elapsed);
    if (reported != _reported) {
      _reported = reported;
      _stamp = now;
    }

    if (_scrub == _Scrub.settle &&
        ((reported - _scrubT).abs() < 0.3 || now > _settleBy)) {
      _scrub = _Scrub.none;
      _stamp = now;
    }

    final before = _view.t;
    final oldStart = _view.start;
    var t = before;

    if (_scrub != _Scrub.none) {
      t = _scrubT;
    } else if (playback.running && playback.playing) {
      // Positions arrive about five times a second, and a playhead moved
      // only then crosses the screen in steps. Between two reports the time
      // is carried forward at the speed the audio is known to be running
      // at, and each report pulls it back onto the truth. Never further
      // than a second on its own: if the reports stop, so does this.
      final ahead = math.min(_seconds(now - _stamp), 1.0) * speed;
      final target = math.min(reported + ahead, total);
      final gap = target - t;

      if (gap.abs() > 0.5 + 0.5 * speed) {
        t = target;
      } else if (gap > 0) {
        // Caught up with at no more than double pace, so a report that
        // lands a little ahead of the guess is absorbed, not jumped to.
        t += math.min(gap, dt * speed * 2);
      }
      // A little behind the guess: hold, and let the audio catch up. A
      // playhead that twitches backwards looks like a fault.
    } else {
      // Not playing, so nothing is guessed at. The engine's word is final.
      t = reported;
    }

    t = t.clamp(0.0, math.max(0.0, total));

    final ideal = _idealStart(t, window, total);

    if (window != _view.window || total != _view.total) {
      // A change of zoom is a deliberate act, and recentres at once.
      _pan = 0;
    } else if (_scrub == _Scrub.handle) {
      _pan = _frozenStart - ideal;
    } else {
      final jumped = (t - before).abs() > 0.25;
      final gliding = _scrub == _Scrub.none || _scrub == _Scrub.settle;

      if (jumped && gliding && t >= oldStart && t <= oldStart + window) {
        _pan = oldStart - ideal;
      } else if (jumped) {
        // Somewhere the window was not showing. There is nothing to glide
        // from, so it is simply there.
        _pan = 0;
      }

      _pan *= math.exp(-dt * 9);
      if (_pan.abs() < window * 0.0005) _pan = 0;
    }

    final double start = (ideal + _pan)
        .clamp(0.0, math.max(0.0, total - window))
        .toDouble();

    final allPlayed =
        playback.heard &&
        !playback.running &&
        _scrub == _Scrub.none &&
        playback.elapsed == Duration.zero;

    _clock.value = t.floor();

    if (t != _view.t ||
        start != _view.start ||
        window != _view.window ||
        total != _view.total ||
        allPlayed != _view.allPlayed) {
      _view
        ..t = t
        ..start = start
        ..window = window
        ..total = total
        ..allPlayed = allPlayed
        ..changed();
    }
  }

  // ---- scrubbing ---------------------------------------------------------

  /// Sends the engine after the finger, ten times a second at most. Each
  /// seek may mean opening a file, and a drag reports far more often than
  /// that; the engine would only throw most of them away.
  void _seekThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastSeek) < const Duration(milliseconds: 100)) return;

    _lastSeek = now;
    unawaited(_playback.seekTo(_asDuration(_scrubT)));
  }

  void _finishScrub() {
    unawaited(_playback.seekTo(_asDuration(_scrubT)));
    _scrub = _Scrub.settle;
    _settleBy = _lastTick + const Duration(milliseconds: 700);
  }

  static Duration _asDuration(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

  void _jumpTo(double seconds) {
    _scrubT = seconds.clamp(0.0, _total);
    _finishScrub();
  }

  void _onWaveDragStart(DragStartDetails details) {
    final x = details.localPosition.dx;
    final y = details.localPosition.dy;
    final playheadX = (_view.t - _view.start) / _view.window * _waveWidth;

    // The handle is the top of the line. Lower down the line runs through
    // the middle of the waveform - which is exactly where a thumb lands to
    // drag the waveform - and treating that as the handle too would make
    // the tape impossible to pull from its centre.
    final onHandle =
        (x - playheadX).abs() <= 26 && y <= _WavePainter.handleZone;

    _scrubT = _view.t;
    _frozenStart = _view.start;
    _scrub = onHandle ? _Scrub.handle : _Scrub.body;
  }

  void _onWaveDragUpdate(DragUpdateDetails details) {
    final total = _total;

    if (_scrub == _Scrub.handle) {
      final x = details.localPosition.dx.clamp(0.0, _waveWidth);
      _scrubT = (_view.start + x / _waveWidth * _view.window).clamp(0.0, total);
    } else if (_scrub == _Scrub.body) {
      // Opposite to the finger: pulling the recording to the right brings
      // earlier audio under the playhead.
      _scrubT = (_scrubT - details.delta.dx / _waveWidth * _view.window).clamp(
        0.0,
        total,
      );
    } else {
      return;
    }

    _seekThrottled();
  }

  void _onWaveDragEnd([DragEndDetails? _]) {
    if (_scrub == _Scrub.handle || _scrub == _Scrub.body) _finishScrub();
  }

  void _onWaveTap(TapUpDetails details) {
    final at = details.localPosition;

    // Pins first. One sits on top of the waveform, and a tap on it means
    // the pin, not the audio behind it.
    final placed = _WavePainter.placeMarks(
      widget.marks,
      _playback,
      _view,
      _waveWidth,
    );
    for (final item in placed.reversed) {
      if ((at - item.centre).distance <= _WavePainter.bubbleRadius + 8) {
        widget.onMarkTap?.call(item.mark);
        return;
      }
    }

    if (!widget.allowSeek || _total <= 0) return;
    _jumpTo(
      _view.start + at.dx.clamp(0.0, _waveWidth) / _waveWidth * _view.window,
    );
  }

  void _onOverview(Offset at, {required bool last}) {
    if (_total <= 0) return;

    _scrubT = (at.dx.clamp(0.0, _overviewWidth) / _overviewWidth) * _total;
    if (last) {
      _finishScrub();
    } else {
      _scrub = _Scrub.overview;
      _seekThrottled();
    }
  }

  Future<void> _addMark() async {
    final add = widget.onAddMark;
    if (add == null || _adding) return;

    setState(() => _adding = true);
    try {
      // Stopped first, as on the web. Whoever is about to say what is wrong
      // at this spot does not want the spot moving on while they say it -
      // and the page files the mark against wherever the playhead was last
      // reported to be.
      await _playback.pause();
      await add();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  // ---- building ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    final ready = !playback.loading && playback.total > Duration.zero;
    final hint = playback.isDisposed ? null : playback.listenHint;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _scaffold,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A phone on its side: the fixed rows alone are as tall as
              // the screen, so the page scrolls and the wave takes a fixed
              // height rather than what is left.
              final short = constraints.maxHeight < 480;

              // Time runs left to right whatever language the app is in.
              // Under an RTL locale the rows here would otherwise mirror,
              // and a transport whose "back five seconds" is on the right
              // of a waveform that still reads from the left is two
              // conventions on one screen.
              final controls = Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomRow(ready),
                    if (short)
                      SizedBox(
                        height: 180,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          child: _buildWave(ready),
                        ),
                      )
                    else
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                          child: _buildWave(ready),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildOverview(),
                    ),
                    if (!short) const Spacer(),
                    _buildTransport(ready),
                  ],
                ),
              );
              final foot = [
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ListenHint(text: hint, dark: true),
                  ),
                if (widget.onAddMark != null) _buildAddMark(),
              ];

              if (short) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [_buildTopBar(context), controls, ...foot],
                  ),
                );
              }
              return Column(
                children: [
                  _buildTopBar(context),
                  Expanded(child: controls),
                  ...foot,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    const figures = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _text,
      fontFeatures: [FontFeature.tabularFigures()],
    );

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Close'.tr,
            icon: const Icon(Icons.close_rounded),
            color: _text,
            iconSize: 24,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // The clock ticks on its own. Rebuilding the page for it would
          // rebuild everything else on the page once a second too.
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int>(
              valueListenable: _clock,
              builder: (_, second, _) => Text.rich(
                TextSpan(
                  text: TimelinePlayback.format(Duration(seconds: second)),
                  children: [
                    TextSpan(
                      text: '  /  ${TimelinePlayback.format(_playback.total)}',
                      style: const TextStyle(color: _muted),
                    ),
                  ],
                ),
                style: figures,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  static String _zoomLabel(int seconds) =>
      seconds >= 60 ? '${seconds ~/ 60}m' : '${seconds}s';

  Widget _buildZoomRow(bool ready) {
    final total = _total;

    // Widths longer than the recording all show the same thing - all of it -
    // so only the first of them is offered.
    final firstCovering = _zoomLevels.firstWhere(
      (level) => level >= total,
      orElse: () => _zoomLevels.last,
    );
    final shown = _zoomLevels.contains(_zoom) && _zoom <= firstCovering
        ? _zoom
        : firstCovering;

    // Two buttons and a read-out, the way the website does it. Zooming is a
    // thing done by feel - a bit closer, a bit further - and a step either
    // way suits that better than choosing a number from a list. It is also
    // two fixed targets a thumb can find without looking.
    final at = _zoomLevels.indexOf(shown);
    final last = _zoomLevels.indexOf(firstCovering);

    // In shows less time, so it steps DOWN the list; out steps up, and stops
    // at the first width that already shows the whole recording.
    final canZoomIn = ready && at > 0;
    final canZoomOut = ready && at < last;

    return SizedBox(
      height: 52,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _zoomButton(
            icon: Icons.zoom_out_rounded,
            tooltip: 'Zoom out',
            onTap: canZoomOut
                ? () => setState(() => _zoom = _zoomLevels[at + 1])
                : null,
          ),
          SizedBox(
            width: 116,
            child: Text(
              '@length window'.trParams({'length': _zoomLabel(shown)}),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ready ? _text : _muted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _zoomButton(
            icon: Icons.zoom_in_rounded,
            tooltip: 'Zoom in',
            onTap: canZoomIn
                ? () => setState(() => _zoom = _zoomLevels[at - 1])
                : null,
          ),
        ],
      ),
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip.tr,
      child: Material(
        color: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _grid),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 40,
            child: Icon(
              icon,
              size: 22,
              // Faded at either end of the range, so it is plain there is
              // no further to go rather than that the button is broken.
              color: onTap == null ? _muted.withValues(alpha: 0.45) : _text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWave(bool ready) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _waveWidth = math.max(1.0, constraints.maxWidth);

        final seekable = ready && widget.allowSeek;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: ready ? _onWaveTap : null,
          onHorizontalDragStart: seekable ? _onWaveDragStart : null,
          onHorizontalDragUpdate: seekable ? _onWaveDragUpdate : null,
          onHorizontalDragEnd: seekable ? _onWaveDragEnd : null,
          onHorizontalDragCancel: seekable ? _onWaveDragEnd : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              size: Size.infinite,
              painter: _WavePainter(
                view: _view,
                playback: _playback,
                marks: widget.marks,
                accent: widget.accent,
                labels: _labels,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverview() {
    return SizedBox(
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          _overviewWidth = math.max(1.0, constraints.maxWidth);

          final seekable = widget.allowSeek;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: seekable
                ? (d) => _onOverview(d.localPosition, last: true)
                : null,
            onHorizontalDragStart: seekable
                ? (d) => _onOverview(d.localPosition, last: false)
                : null,
            onHorizontalDragUpdate: seekable
                ? (d) => _onOverview(d.localPosition, last: false)
                : null,
            onHorizontalDragEnd: seekable
                ? (_) {
                    if (_scrub == _Scrub.overview) _finishScrub();
                  }
                : null,
            onHorizontalDragCancel: seekable
                ? () {
                    if (_scrub == _Scrub.overview) _finishScrub();
                  }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                size: Size.infinite,
                painter: _OverviewPainter(
                  view: _view,
                  playback: _playback,
                  marks: widget.marks,
                  accent: widget.accent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransport(bool ready) {
    final playback = _playback;
    final seekable = ready && widget.allowSeek;

    Widget skip(IconData icon, String tooltip, Duration by) {
      return IconButton(
        onPressed: seekable ? () => unawaited(playback.skip(by)) : null,
        tooltip: tooltip,
        icon: Icon(icon),
        iconSize: 32,
        color: _text,
        disabledColor: _muted.withValues(alpha: 0.4),
        style: IconButton.styleFrom(
          backgroundColor: _panel,
          fixedSize: const Size(60, 60),
          shape: const CircleBorder(side: BorderSide(color: _grid)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          skip(
            Icons.replay_5_rounded,
            'Back 5 seconds'.tr,
            const Duration(seconds: -5),
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: Material(
              color: ready ? widget.accent : _grid,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: ready ? () => unawaited(playback.toggle()) : null,
                child: Tooltip(
                  message: playback.running ? 'Pause'.tr : 'Play'.tr,
                  child: Icon(
                    playback.running
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 42,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          skip(
            Icons.forward_5_rounded,
            'Forward 5 seconds'.tr,
            const Duration(seconds: 5),
          ),
          SpeedSelector(
            value: playback.speed,
            onChanged: (speed) => unawaited(playback.setSpeed(speed)),
            enabled: ready,
            dark: true,
            large: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAddMark() {
    final color = widget.addMarkColor ?? widget.accent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          onPressed: _adding ? null : _addMark,
          icon: const Icon(Icons.add_comment_rounded, size: 20),
          label: Text(
            (widget.addMarkLabel ?? 'Add comment').tr,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.4),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

/// A pin, and where its bubble has been put.
typedef _PlacedMark = ({SegmentMark mark, double x, Offset centre});

/// The window onto the recording: ruler, bars, passage boundaries, pins and
/// the playhead.
///
/// Painted rather than built. `AudioFileWaveforms` draws a fixed list of
/// bars at a fixed pitch and knows nothing of time; this has to draw an
/// arbitrary slice of several files, slide it a fraction of a pixel a frame,
/// and do it sixty times a second without touching the widget tree.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.view,
    required this.playback,
    required this.marks,
    required this.accent,
    required this.labels,
  }) : super(repaint: Listenable.merge([view, playback]));

  final _View view;
  final TimelinePlayback playback;
  final List<SegmentMark> marks;
  final Color accent;
  final Map<String, TextPainter> labels;

  static const double rulerHeight = 24;
  static const double bubbleRadius = 12;
  static const double _laneStep = 16;

  /// How far down from the top a drag still counts as taking the handle.
  static const double handleZone = rulerHeight + 40;

  /// Where the bars begin: under the ruler and the two lanes pins sit in.
  static const double _waveTop = rulerHeight + bubbleRadius * 2 + _laneStep + 6;

  static const Color _panel = Color(0xFF141A22);
  static const Color _grid = Color(0xFF243040);
  static const Color _muted = Color(0xFF8B95A5);
  static const Color _unplayed = Color(0xFF5B6675);
  static const Color _playhead = Colors.white;

  /// Pins inside the window, with their bubbles put into lanes.
  ///
  /// Shared with the tap handler, so that what can be tapped is exactly what
  /// was drawn. Two lanes for the reason the compact player has two:
  /// questions asked seconds apart land on top of one another, and a covered
  /// pin cannot be reached at all.
  static List<_PlacedMark> placeMarks(
    List<SegmentMark> marks,
    TimelinePlayback playback,
    _View view,
    double width,
  ) {
    if (marks.isEmpty || view.window <= 0 || playback.isDisposed) {
      return const [];
    }

    final found = <({SegmentMark mark, double x})>[];
    for (final mark in marks) {
      final at = playback.absoluteSecondsOf(mark);
      if (at == null) continue;
      if (at < view.start || at > view.start + view.window) continue;

      found.add((mark: mark, x: (at - view.start) / view.window * width));
    }
    found.sort((a, b) => a.x.compareTo(b.x));

    final placed = <_PlacedMark>[];
    var lane = 0;
    double? previousX;

    for (final item in found) {
      lane = (previousX != null && item.x - previousX < bubbleRadius * 2 + 4)
          ? 1 - lane
          : 0;
      previousX = item.x;

      placed.add((
        mark: item.mark,
        x: item.x,
        // Kept whole at either edge; the stem still drops from the exact
        // moment, so the bubble leans in rather than being cut in half.
        centre: Offset(
          item.x.clamp(
            bubbleRadius,
            math.max(bubbleRadius, width - bubbleRadius),
          ),
          rulerHeight + 4 + bubbleRadius + lane * _laneStep,
        ),
      ));
    }

    return placed;
  }

  TextPainter _label(String text, Color color, {double size = 10}) {
    final key = '$text|${color.toARGB32()}|$size';

    final known = labels[key];
    if (known != null) return known;

    // The ruler's labels change as the window scrolls, so this fills up over
    // a long listen. Emptied rather than pruned: laying out a few words of
    // text again is cheap, and a cache with a policy is not.
    if (labels.length > 240) {
      for (final label in labels.values) {
        label.dispose();
      }
      labels.clear();
    }

    return labels[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
  }

  static String _clock(double seconds, {required bool tenths}) {
    final whole = seconds.floor();
    final base = '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
    if (!tenths) return base;

    return '$base.${((seconds - whole) * 10).floor().clamp(0, 9)}';
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _panel);
    if (playback.isDisposed || view.window <= 0 || size.width <= 0) return;

    final width = size.width;
    final window = view.window;
    final start = view.start;
    final perSecond = width / window;

    _paintRuler(canvas, size, start, window);

    final waveBottom = size.height - 10;
    final waveHeight = math.max(8.0, waveBottom - _waveTop);
    final centreY = _waveTop + waveHeight / 2;

    _paintBars(canvas, width, start, window, centreY, waveHeight);
    _paintBoundaries(canvas, size, start, window, perSecond);

    // Pins.
    final stem = Paint()..strokeWidth = 2;
    final fill = Paint();
    for (final item in placeMarks(marks, playback, view, width)) {
      stem.color = item.mark.color;
      fill.color = item.mark.color;

      canvas.drawLine(
        Offset(item.x, item.centre.dy),
        Offset(item.x, waveBottom),
        stem,
      );
      canvas.drawCircle(item.centre, bubbleRadius, fill);

      final icon = item.mark.icon;
      final glyph = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 14,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(
        canvas,
        item.centre - Offset(glyph.width / 2, glyph.height / 2),
      );
      glyph.dispose();
    }

    // The playhead, last, over everything.
    final x = ((view.t - start) * perSecond).clamp(0.0, width);
    canvas.drawLine(
      Offset(x, rulerHeight - 2),
      Offset(x, size.height),
      Paint()
        ..color = _playhead
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(x, rulerHeight + 8),
      10,
      Paint()..color = _playhead,
    );
    canvas.drawCircle(
      Offset(x, rulerHeight + 8),
      3.5,
      // Dark, now that the handle itself is white: the dot is what makes it
      // read as a grip rather than a plain disc.
      Paint()..color = const Color(0xFF0B0F14),
    );
  }

  /// Six ticks, evenly spaced from one edge of the window to the other, each
  /// saying what time it stands at.
  void _paintRuler(Canvas canvas, Size size, double start, double window) {
    final line = Paint()
      ..color = _grid
      ..strokeWidth = 1;

    canvas.drawLine(
      const Offset(0, rulerHeight),
      Offset(size.width, rulerHeight),
      line,
    );

    const ticks = 6;
    for (var i = 0; i < ticks; i++) {
      final x = size.width * i / (ticks - 1);
      final at = math.min(start + window * i / (ticks - 1), view.total);

      canvas.drawLine(Offset(x, rulerHeight - 6), Offset(x, size.height), line);

      final label = _label(_clock(at, tenths: window <= 10), _muted);

      // The outer two sit inside the panel; centred on their ticks, half of
      // each would be off the edge.
      final left = i == 0
          ? 4.0
          : i == ticks - 1
          ? size.width - label.width - 4
          : x - label.width / 2;
      label.paint(canvas, Offset(left, 4));
    }
  }

  void _paintBars(
    Canvas canvas,
    double width,
    double start,
    double window,
    double centreY,
    double waveHeight,
  ) {
    final count = playback.playable.length;
    final starts = playback.starts;
    final lengths = playback.lengths;
    if (count == 0 || starts.length < count || lengths.length < count) return;

    // A bar stands for a fixed slice of time, counted from the very start of
    // the recording - not for a column of the screen. Tied to the screen,
    // every bar would be measured over a slightly different stretch of audio
    // each frame, and the waveform would shimmer as it scrolled. Tied to
    // time, a bar keeps its height and simply moves.
    const pitch = 3.0;
    final secondsPerBar = window / (width / pitch);
    if (secondsPerBar <= 0) return;

    final played = Paint()
      ..color = accent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final unplayed = Paint()
      ..color = _unplayed
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final first = (start / secondsPerBar).floor();
    final last = ((start + window) / secondsPerBar).ceil();
    final end = view.total;

    var segment = 0;

    for (var k = first; k <= last; k++) {
      final from = k * secondsPerBar;
      if (from < 0 || from >= end) continue;

      while (segment + 1 < count &&
          from >= starts[segment + 1].inMicroseconds / 1e6) {
        segment++;
      }

      final level = _level(
        segment,
        from,
        from + secondsPerBar,
        starts[segment].inMicroseconds / 1e6,
        lengths[segment].inMicroseconds / 1e6,
      );

      // Nothing read yet is drawn as a stub, so the track has a shape to
      // aim at while the bars are on their way.
      final half = level < 0 ? 1.5 : math.max(1.0, level * waveHeight * 0.46);

      final x = (from - start) / window * width + 1;
      final isPlayed = view.allPlayed || from + secondsPerBar / 2 <= view.t;

      canvas.drawLine(
        Offset(x, centreY - half),
        Offset(x, centreY + half),
        isPlayed ? played : unplayed,
      );
    }
  }

  /// The loudest bar of one passage between two absolute times, or -1 when
  /// that passage has no bars yet.
  double _level(
    int segment,
    double from,
    double to,
    double segmentStart,
    double segmentLength,
  ) {
    final bars = playback.barsFor(segment);
    if (bars.isEmpty) return -1;
    if (segmentLength <= 0) return 0;

    final n = bars.length;
    final a = ((from - segmentStart) / segmentLength * n).floor().clamp(
      0,
      n - 1,
    );
    final b = ((to - segmentStart) / segmentLength * n).ceil().clamp(a + 1, n);

    // Zoomed right out, one bar on screen covers hundreds in the file. A
    // sample of them finds the peak as well as all of them would.
    final stride = math.max(1, (b - a) ~/ 48);

    var peak = 0.0;
    for (var i = a; i < b; i += stride) {
      if (bars[i] > peak) peak = bars[i];
    }
    return peak;
  }

  /// Where one passage ends and the next begins, each named at its top-left.
  void _paintBoundaries(
    Canvas canvas,
    Size size,
    double start,
    double window,
    double perSecond,
  ) {
    final playable = playback.playable;
    final starts = playback.starts;
    final lengths = playback.lengths;
    if (starts.length < playable.length) return;

    final rule = Paint()
      ..color = const Color(0xFF3B4A5E)
      ..strokeWidth = 1;

    const labelY = _waveTop - 2;

    // The passage the window opens in began somewhere off to the left, and
    // its name went with it. It is pinned to the edge instead, until the
    // next boundary comes along and pushes it off.
    int? opening;
    double? nextBoundaryX;

    for (var i = 0; i < playable.length; i++) {
      if (i < lengths.length && lengths[i] == Duration.zero) continue;

      final at = starts[i].inMicroseconds / 1e6;
      if (at <= start) {
        opening = i;
        continue;
      }
      if (at > start + window) break;

      final x = (at - start) * perSecond;
      nextBoundaryX ??= x;

      canvas.drawLine(Offset(x, rulerHeight), Offset(x, size.height), rule);
      _label(playable[i].label, _muted).paint(canvas, Offset(x + 5, labelY));
    }

    if (opening != null) {
      final label = _label(playable[opening].label, _muted);
      if (nextBoundaryX == null || nextBoundaryX > label.width + 14) {
        label.paint(canvas, const Offset(5, labelY));
      }
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.marks != marks ||
      old.accent != accent ||
      !identical(old.playback, playback);
}

/// The whole track in one strip: where the window is, how much has been
/// played, and where every pin is - the one place they are all visible at
/// once, however far the window above is zoomed in.
class _OverviewPainter extends CustomPainter {
  _OverviewPainter({
    required this.view,
    required this.playback,
    required this.marks,
    required this.accent,
  }) : super(repaint: Listenable.merge([view, playback]));

  final _View view;
  final TimelinePlayback playback;
  final List<SegmentMark> marks;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF141A22),
    );
    if (playback.isDisposed || view.total <= 0 || size.width <= 0) return;

    final width = size.width;
    final total = view.total;
    final centreY = size.height / 2;
    final playedTo = view.allPlayed ? width : view.t / total * width;

    final source = playback.bars;
    const pitch = 3.0;
    final count = math.max(1, (width / pitch).floor());

    var peak = 0.0;
    for (final value in source) {
      if (value.abs() > peak) peak = value.abs();
    }

    final played = Paint()
      ..color = accent.withValues(alpha: 0.85)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final unplayed = Paint()
      ..color = const Color(0xFF5B6675).withValues(alpha: 0.75)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final x = i * pitch + 1.5;

      var half = 1.0;
      if (source.isNotEmpty && peak > 0) {
        final at = (i * source.length / count).floor().clamp(
          0,
          source.length - 1,
        );
        half = math.max(1.0, source[at].abs() / peak * (size.height * 0.36));
      }

      canvas.drawLine(
        Offset(x, centreY - half),
        Offset(x, centreY + half),
        x <= playedTo ? played : unplayed,
      );
    }

    // Passage boundaries, faintly.
    final starts = playback.starts;
    final rule = Paint()
      ..color = const Color(0xFF3B4A5E)
      ..strokeWidth = 1;
    for (var i = 1; i < starts.length; i++) {
      final x = starts[i].inMicroseconds / 1e6 / total * width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), rule);
    }

    // The window above, as a pane laid over the part it shows.
    final left = view.start / total * width;
    final paneWidth = math.max(6.0, math.min(1.0, view.window / total) * width);
    final pane = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        left.clamp(0.0, math.max(0.0, width - paneWidth)),
        1,
        paneWidth,
        size.height - 2,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      pane,
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      pane,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    // Pins, as dots along the top.
    final dot = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF0B0F14);
    for (final mark in marks) {
      final at = playback.absoluteSecondsOf(mark);
      if (at == null) continue;

      final centre = Offset((at / total).clamp(0.0, 1.0) * width, 8);
      dot.color = mark.color;
      canvas.drawCircle(centre, 4, dot);
      canvas.drawCircle(centre, 4, ring);
    }

    final x = (view.t / total * width).clamp(0.0, width);
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.marks != marks ||
      old.accent != accent ||
      !identical(old.playback, playback);
}
