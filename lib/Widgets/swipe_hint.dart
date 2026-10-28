import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/l10n/app_locale.dart';

/// A hand that slides across the screen, the way a finger would, to show
/// that the page turns by swiping.
///
/// Drawn over the recorder after a drafter's first Final take, when the
/// next thing to do is the next passage and nothing on the screen says how
/// to get there now that the arrows are gone - and again whenever they sit
/// on a finished passage without touching it. Six passes, then it goes;
/// any touch takes it away sooner, and the swipe it was showing still goes
/// through to the page beneath.
class SwipeHint extends StatefulWidget {
  const SwipeHint({super.key, required this.onDone});

  /// Called when the hint has finished or been touched away.
  final VoidCallback onDone;

  @override
  State<SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<SwipeHint>
    with SingleTickerProviderStateMixin {
  static const int _passes = 6;

  late final AnimationController _pass = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  int _done = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _pass.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _done++;
      if (_done < _passes) {
        _pass.forward(from: 0);
      } else {
        _finish();
      }
    });
    _pass.forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Forward is where reading runs to: the finger moves left in English
    // and Hindi, right in Urdu.
    final rtl = AppLocale.isRtl;
    final label = rtl
        ? 'Swipe right for the next passage'
        : 'Swipe left for the next passage';

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _finish(),
      child: IgnorePointer(
        // The page shows through, dimmed, so the hand reads as being over
        // it and the eye goes to the one thing that is lit. Drawn over
        // the whole Scaffold, so the text needs a Material of its own
        // for its font.
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            color: const Color(0x8C000000),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _pass,
              builder: (context, _) {
                final t = _pass.value;
                // Fade in, cross, fade out: visible for the middle of the pass.
                final opacity = t < 0.15
                    ? t / 0.15
                    : t > 0.85
                    ? (1 - t) / 0.15
                    : 1.0;
                final travel = Curves.easeInOut.transform(
                  ((t - 0.15) / 0.7).clamp(0.0, 1.0),
                );
                // Across the middle of the screen, 160 px, the way a finger
                // would.
                final dx = (rtl ? -80 : 80) + (rtl ? 160 : -160) * travel;

                // The hand and its arrow travel; the sentence under them
                // holds still, where it can be read.
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(dx, 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // The arrow, the way the finger is about to move.
                            CustomPaint(
                              size: const Size(72, 22),
                              painter: _ArrowPainter(toLeft: !rtl),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.touch_app_rounded,
                              size: 84,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label.tr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain arrow: a line and an open head, in the hand's own stroke.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.toLeft});

  final bool toLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final y = size.height / 2;
    final tip = toLeft ? 2.0 : size.width - 2;
    final tail = toLeft ? size.width - 2 : 2.0;
    final back = toLeft ? 12.0 : -12.0;
    canvas.drawLine(Offset(tail, y), Offset(tip, y), paint);
    canvas.drawPath(
      Path()
        ..moveTo(tip + back, y - 9)
        ..lineTo(tip, y)
        ..lineTo(tip + back, y + 9),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.toLeft != toLeft;
}
