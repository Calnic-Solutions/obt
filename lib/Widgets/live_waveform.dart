import 'package:audio_waveforms/audio_waveforms.dart' as aw;
import 'package:flutter/material.dart';

import 'package:livuka/Audio/take_recorder.dart';

/// The bars that run while a take is being recorded: `audio_waveforms`'
/// own strip, drawn off its recorder.
class LiveWaveform extends StatelessWidget {
  const LiveWaveform({
    super.key,
    required this.recorder,
    required this.color,
    this.height = 40,
  });

  final TakeRecorder recorder;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return aw.AudioWaveforms(
      size: Size(double.infinity, height),
      recorderController: recorder.waveformController,
      waveStyle: aw.WaveStyle(
        waveColor: color,
        extendWaveform: true,
        showMiddleLine: false,
      ),
    );
  }
}
