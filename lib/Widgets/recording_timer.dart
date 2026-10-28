import 'dart:async';

import 'package:flutter/material.dart';

/// How long the recording running right now has been going.
///
/// Timed here rather than read from the recorder's own duration stream,
/// because that stream reports twice the real length: audio_waveforms 2.0.2
/// counts the bytes it reads off the microphone as if they were samples
/// (`totalSamples += read / channelCount` in AudioRecorder.kt), and 16-bit
/// PCM has two bytes to the sample. That is why a take saved at an apparent
/// thirty seconds came back as fifteen — the file was right and the clock was
/// wrong. A recording can be paused, so the clock is handed in by whoever
/// owns the recorder and stopped and started along with it; left to itself
/// the widget times its own life, which is right for a recording that
/// cannot pause.
class RecordingTimer extends StatefulWidget {
  const RecordingTimer({
    super.key,
    this.color = const Color(0xFFDC2626),
    this.fontSize = 13,
    this.stopwatch,
  });

  /// The recording's own clock, when it has one that pauses with it.
  final Stopwatch? stopwatch;

  /// Red by default — the same colour the stop button takes while recording.
  final Color color;
  final double fontSize;

  @override
  State<RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<RecordingTimer> {
  late final Stopwatch _stopwatch = widget.stopwatch ?? Stopwatch();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // The widget is built only while a recording is running, so its own life
    // is the recording's life.
    if (widget.stopwatch == null) _stopwatch.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (widget.stopwatch == null) _stopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A dot, because a bare clock could be either the length of a
        // recording or the length of a take already made.
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$minutes:$seconds',
          style: TextStyle(
            fontSize: widget.fontSize,
            color: widget.color,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
