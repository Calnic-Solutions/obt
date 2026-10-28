import 'package:flutter/material.dart';

/// The LIVUKA smile (assets/brand/livuka-smile.svg), animated as the
/// website's sign-in panel animates it: it floats, blinks, and glances
/// about. The shapes and colours are the kit file's, unchanged - the kit
/// forbids altering the character - and it is drawn on a canvas rather
/// than from the SVG only so the eyes and pupils can move.
class LivukaSmile extends StatefulWidget {
  const LivukaSmile({super.key, this.width = 150, this.animate = true});

  final double width;
  final bool animate;

  @override
  State<LivukaSmile> createState() => _LivukaSmileState();
}

class _LivukaSmileState extends State<LivukaSmile>
    with SingleTickerProviderStateMixin {
  // 60 seconds holds a whole number of every loop: the 5-second float, the
  // 6-second blink and the 12-second glance.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The website holds still for prefers-reduced-motion; this is the
    // phone's own setting for the same thing.
    final still = !widget.animate || MediaQuery.disableAnimationsOf(context);
    if (still) {
      _clock.stop();
      _clock.value = 0;
    } else if (!_clock.isAnimating) {
      // Begun 1.5 seconds into the loops rather than at their start. From
      // zero, the first glance comes at 3 seconds and the first blink just
      // before - the moment the 3-second splash hands over - so the
      // splash only ever showed the float. From here the smile looks
      // round at once and blinks at about a second and a half.
      _clock.value = 1.5 / 60;
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width * _SmilePainter.box.height / _SmilePainter.box.width,
      child: CustomPaint(painter: _SmilePainter(_clock)),
    );
  }
}

class _SmilePainter extends CustomPainter {
  _SmilePainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  /// The SVG's viewBox.
  static const Rect box = Rect.fromLTWH(-14, -45, 166, 159);

  static const Color orange = Color(0xFFCD572D);
  static const Color blue = Color(0xFF5DA0D3);
  static const Color navy = Color(0xFF040134);

  /// The box both eyes fill, which the blink squashes about its centre
  /// (CSS `transform-box: fill-box`).
  static const Rect eyes = Rect.fromLTRB(36.06, -31, 102.94, 5);

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * 60;
    final s = size.width / box.width;

    canvas.save();
    canvas.scale(s);
    canvas.translate(-box.left, -box.top);

    // obSmileFloat: up 6px and back every 5 seconds, measured on the
    // website's 150px-wide smile.
    final float = _track((seconds % 5) / 5 * 100, const [
      [0, 0],
      [50, -6],
      [100, 0],
    ])[0];
    canvas.translate(0, float * box.width / 150);

    final body = Paint()..color = orange;
    for (final r in const [
      Rect.fromLTWH(40.38, 62, 18.6, 30.5),
      Rect.fromLTWH(79.02, 62, 18.6, 30.5),
    ]) {
      canvas.drawRect(r, body);
    }
    for (final r in const [
      Rect.fromLTWH(23.13, 85, 35.85, 15),
      Rect.fromLTWH(79.02, 85, 35.85, 15),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(7.5)),
        body,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(15, 15)
        ..cubicTo(13.8, 81.67, 124.2, 81.67, 123, 15),
      Paint()
        ..color = orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round,
    );

    // obSmileBlink: shut at 49% of a 6-second loop, open by 46% and 52%.
    final blink = _track((seconds % 6) / 6 * 100, const [
      [0, 1],
      [46, 1],
      [49, 0.1],
      [52, 1],
      [100, 1],
    ])[0];
    // obSmileGlance: a look down and to the left, twice in 12 seconds.
    final glance = _track((seconds % 12) / 12 * 100, const [
      [0, 0, 0],
      [20, 0, 0],
      [25, -5, 2],
      [40, -5, 2],
      [45, 0, 0],
      [65, 0, 0],
      [70, -2, 4],
      [85, -2, 4],
      [90, 0, 0],
      [100, 0, 0],
    ]);

    canvas.save();
    canvas.translate(eyes.center.dx, eyes.center.dy);
    canvas.scale(1, blink);
    canvas.translate(-eyes.center.dx, -eyes.center.dy);
    final iris = Paint()..color = blue;
    canvas.drawCircle(const Offset(51.06, -10), 15, iris);
    canvas.drawCircle(const Offset(86.94, -15), 16, iris);
    canvas.translate(glance[0], glance[1]);
    final pupil = Paint()..color = navy;
    canvas.drawCircle(const Offset(55.56, -11.8), 6.3, pupil);
    canvas.drawCircle(const Offset(91.74, -16.92), 6.72, pupil);
    canvas.restore();

    canvas.restore();
  }

  /// CSS `ease-in-out`, near enough.
  static double _ease(double t) => t * t * (3 - 2 * t);

  /// Reads rows of (percent, values...) at [pct], eased between rows as a
  /// CSS keyframe animation is.
  static List<double> _track(double pct, List<List<double>> rows) {
    for (var i = 1; i < rows.length; i++) {
      if (pct <= rows[i][0]) {
        final a = rows[i - 1], b = rows[i];
        final span = b[0] - a[0];
        final t = _ease(span <= 0 ? 1.0 : (pct - a[0]) / span);
        return [for (var k = 1; k < a.length; k++) a[k] + (b[k] - a[k]) * t];
      }
    }
    return rows.last.sublist(1);
  }

  @override
  bool shouldRepaint(_SmilePainter oldDelegate) => false;
}
