import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:livuka/main.dart';

/// A glow that grows out of a control and fades as it goes, to say "this
/// one".
///
/// A single soft disc rather than a drawn ring: an outlined circle behind a
/// small button reads as a second button, and two of them read as three. The
/// colour is strongest where it leaves the icon and feathers away to nothing
/// at its edge, so what the eye catches is a pulse of colour rather than a
/// shape.

class PulseHalo extends StatefulWidget {
  const PulseHalo({
    super.key,
    required this.active,
    required this.child,
    this.color = MainApp.primaryGreen,
    this.minSize = 30,
    this.maxSize = 64,
    this.borderRadius,
  });

  /// Whether to draw at all.
  final bool active;

  final Widget child;
  final Color color;

  /// Where a ring starts - about the size of the control it comes out of -
  /// and where it has faded out by. Round controls only; a card takes its
  /// size from the child and spreads outward from there.
  final double minSize;
  final double maxSize;

  /// Set for something that is not a circle - a card, say. The glow then
  /// follows the child's own shape and swells outward from its edge instead
  /// of growing from the middle.
  final BorderRadius? borderRadius;

  @override
  State<PulseHalo> createState() => _PulseHaloState();
}

class _PulseHaloState extends State<PulseHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Made here, not in the field's initializer. A `late final` with an
    // initializer is only built when first touched - and for a halo that was
    // never switched on, the first touch was `dispose()`, which then made a
    // controller whose `vsync` went looking for an ancestor from a widget
    // already taken out of the tree.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(PulseHalo old) {
    super.didUpdateWidget(old);
    if (widget.active == old.active) return;

    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      // The child is built once and handed through: the rings redraw sixty
      // times a second, and the button behind them has no reason to.
      child: widget.child,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        // A card or a bar keeps the width it was given: a Stack shrinks its
        // children to their own size, which turned a full-width button
        // into one as wide as its words the moment it started to pulse.
        // A round control has a size of its own and is left with it.
        fit: widget.borderRadius != null
            ? StackFit.passthrough
            : StackFit.loose,
        // The glow is wider than the control it comes from, and nothing here
        // should make room for it.
        clipBehavior: Clip.none,
        children: [_glow(_controller.value), child!],
      ),
    );
  }

  /// The glow, [progress] of the way through its cycle.
  Widget _glow(double progress) {
    // Square-rooted rather than straight, so the colour holds while the
    // glow is growing and only drops away near the end. Fading in step with
    // the size leaves nothing to see around a large control: by the time the
    // glow is wider than it, the glow has already gone.
    final fade = math.sqrt(1.0 - progress);

    // A card keeps its own outline and pushes the colour out past its edge.
    final radius = widget.borderRadius;
    if (radius != null) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              // The website's ring (`obAttnRing`): a hard-edged band that
              // spreads twelve pixels out from the control and fades as
              // it goes. Blurred, it read as a smudge round a small pill.
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: fade * 0.55),
                  blurRadius: 0,
                  spreadRadius: 12 * progress,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final size = widget.minSize + (widget.maxSize - widget.minSize) * progress;

    return Positioned.fill(
      child: IgnorePointer(
        child: OverflowBox(
          // The minimums stated too, as zero. Left to the parent, a Stack
          // that was handed a tight width - a sheet stretching its
          // children, a phone on its side - passed that width down as the
          // minimum, above the maximum here, and the layout threw.
          minWidth: 0,
          minHeight: 0,
          maxWidth: widget.maxSize,
          maxHeight: widget.maxSize,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Solid where it leaves the icon, gone by the edge. No border:
              // the fade is the whole effect.
              gradient: RadialGradient(
                colors: [
                  // Strong enough to be seen round a small grey button
                  // on a white card: fainter, the star and the arrows
                  // pulsed and nobody noticed.
                  widget.color.withValues(alpha: fade * 0.62),
                  widget.color.withValues(alpha: fade * 0.45),
                  widget.color.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.62, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
