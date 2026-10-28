import 'package:flutter/material.dart';

/// A row of bars, one per sample, centred on the middle line - the strip
/// every player in the app draws its recording as.
///
/// Drawn here rather than by the recorder package's `AudioFileWaveforms`.
/// That widget was only ever handed a list of bars this app had already
/// worked out, with its own seeking and playhead switched off - a painter
/// with a native controller it did not need. The controller is what has no
/// desktop build, and dropping it costs nothing: the same bars, the same
/// spacing, the same two colours.
class WaveBars extends StatelessWidget {
  const WaveBars({
    super.key,
    required this.bars,
    required this.color,
    required this.height,
    this.spacing = 4,
    this.thickness = 2,
  });

  /// Heights, 0..1, one per bar, already fitted to the width.
  final List<double> bars;
  final Color color;
  final double height;

  /// Centre-to-centre distance between bars.
  final double spacing;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _WaveBarsPainter(
          bars: bars,
          color: color,
          spacing: spacing,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _WaveBarsPainter extends CustomPainter {
  const _WaveBarsPainter({
    required this.bars,
    required this.color,
    required this.spacing,
    required this.thickness,
  });

  final List<double> bars;
  final Color color;
  final double spacing;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    final mid = size.height / 2;
    // The tallest bar fills the strip; nothing shorter than the line's own
    // thickness, so silence still draws as a line rather than a gap.
    final reach = mid - thickness / 2;

    for (var i = 0; i < bars.length; i++) {
      final x = spacing / 2 + i * spacing;
      if (x > size.width) break;
      final half = (bars[i].clamp(0.0, 1.0) * reach).clamp(
        thickness / 2,
        reach,
      );
      canvas.drawLine(Offset(x, mid - half), Offset(x, mid + half), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveBarsPainter old) =>
      old.bars != bars ||
      old.color != color ||
      old.spacing != spacing ||
      old.thickness != thickness;
}
