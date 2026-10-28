import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';

/// Drag the knob from the left edge to the right to send and check for
/// updates.
///
/// A drag rather than a tap. This is the one control in the app that goes
/// to the server, and a phone in a pocket taps itself; a swipe the whole
/// width of the track does not happen by accident. It also makes the
/// waiting deliberate: the knob has to be carried all the way, and let go
/// early it slides back home.
///
/// Left to right, the way a slide-to-unlock reads: the knob starts at the
/// beginning of the label and is carried across it.
class SlideToSync extends StatefulWidget {
  const SlideToSync({
    super.key,
    required this.label,
    required this.onComplete,
    this.busy = false,
    this.busyLabel = '',
  });

  /// What completing the drag does - "Send (6)" or "Check for updates".
  final String label;
  final Future<void> Function() onComplete;

  /// While the send runs the knob parks at the far end with a spinner in
  /// it, and the track cannot be dragged.
  final bool busy;
  final String busyLabel;

  @override
  State<SlideToSync> createState() => _SlideToSyncState();
}

// Two controllers - the drag and the shimmer - so the plural mixin.
class _SlideToSyncState extends State<SlideToSync>
    with TickerProviderStateMixin {
  static const double _height = 56;
  static const double _knob = 48;
  static const double _pad = 4;

  /// How far the knob has been dragged, 0 at rest on the left and 1 at the
  /// right end.
  late final AnimationController _drag;

  /// The hint's shimmer, so the track itself says "drag me" without words
  /// having to.
  late final AnimationController _shimmer;

  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _drag = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _drag.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  double _travel(double width) => width - _knob - _pad * 2;

  void _onStart(DragStartDetails _) {
    if (widget.busy) return;
    _dragging = true;
    _drag.stop();
  }

  void _onUpdate(DragUpdateDetails d, double width) {
    if (!_dragging) return;
    // Rightwards is positive progress.
    _drag.value = (_drag.value + d.delta.dx / _travel(width)).clamp(0.0, 1.0);
  }

  Future<void> _onEnd(DragEndDetails _) async {
    if (!_dragging) return;
    _dragging = false;

    // Most of the way is far enough - a thumb on a narrow phone runs out of
    // screen before the knob does.
    if (_drag.value < 0.85) {
      await _drag.animateBack(0, curve: Curves.easeOutCubic);
      return;
    }

    await _drag.animateTo(1, curve: Curves.easeOut);
    HapticFeedback.mediumImpact();
    await widget.onComplete();
    if (mounted) await _drag.animateBack(0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final travel = _travel(width);

        return AnimatedBuilder(
          animation: Listenable.merge([_drag, _shimmer]),
          builder: (context, _) {
            final t = widget.busy ? 1.0 : _drag.value;
            final knobLeft = _pad + travel * t;

            return GestureDetector(
              onHorizontalDragStart: _onStart,
              onHorizontalDragUpdate: (d) => _onUpdate(d, width),
              onHorizontalDragEnd: _onEnd,
              onHorizontalDragCancel: () {
                if (_dragging) _onEnd(DragEndDetails());
              },
              child: Container(
                height: _height,
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEBE4),
                  borderRadius: BorderRadius.circular(_height / 2),
                  border: Border.all(color: const Color(0xFFF3CDBF)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // The fill sweeps in from the left behind the knob, so
                    // how far there is to go is drawn as well as felt. It
                    // reaches the knob's centre, not its far edge: at rest
                    // that leaves a half-disc of colour tucked behind the
                    // knob rather than a full one poking out ahead of it.
                    // At the end it runs on to the track's edge, so the
                    // rounded corner is coloured too.
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: t >= 0.999
                          ? width
                          : (knobLeft + _knob / 2).clamp(0.0, width),
                      child: ColoredBox(
                        // Faint until the knob arrives, then filling in
                        // over the last stretch.
                        color: MainApp.primaryGreen.withValues(
                          alpha: 0.18 + 0.82 * Curves.easeIn.transform(t),
                        ),
                      ),
                    ),
                    // The label, in the part of the track the knob has not
                    // yet covered. Fades as the knob crosses it.
                    Positioned.fill(
                      child: Opacity(
                        opacity: (1 - t * 1.6).clamp(0.0, 1.0),
                        child: _Hint(
                          label: widget.label,
                          shimmer: _shimmer.value,
                          knobLeft: knobLeft,
                        ),
                      ),
                    ),
                    if (widget.busy)
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: _knob + _pad,
                            ),
                            child: Text(
                              widget.busyLabel.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: _pad,
                      left: knobLeft,
                      child: Container(
                        width: _knob,
                        height: _knob,
                        decoration: BoxDecoration(
                          color: MainApp.primaryGreen,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: widget.busy
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                t > 0.85
                                    ? Icons.check_rounded
                                    : Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// The words on the track, with a light sweeping across them from left to
/// right - the direction the knob is meant to go.
class _Hint extends StatelessWidget {
  const _Hint({
    required this.label,
    required this.shimmer,
    required this.knobLeft,
  });

  final String label;
  final double shimmer;
  final double knobLeft;

  @override
  Widget build(BuildContext context) {
    // Sweeps from -0.5 (off the left edge) up to 1.5 (off the right).
    final sweep = -0.5 + shimmer * 2;

    return Padding(
      padding: const EdgeInsets.only(left: _SlideToSyncState._knob),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Color(0xFFCD572D),
            Color(0xFFF2B49C),
            Color(0xFFCD572D),
          ],
          stops: [
            (sweep - 0.25).clamp(0.0, 1.0),
            sweep.clamp(0.0, 1.0),
            (sweep + 0.25).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_double_arrow_right_rounded,
              size: 20,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
