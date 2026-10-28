import 'package:flutter/material.dart';

/// The source script and the target script, laid out together.
///
/// Upright, one above the other, as the pages have always shown them. With
/// the phone on its side they share one row, half each, the way the drafter's
/// recording screen already lays them out: a landscape screen is wide and
/// short, and two scripts stacked in it left each a few lines tall.
///
/// Nothing else changes between the two: the same widgets, the same gap.
class ScriptPair extends StatelessWidget {
  const ScriptPair({
    super.key,
    required this.source,
    required this.target,
    this.gap = 10,
    this.stretch = false,
  });

  final Widget source;
  final Widget target;

  /// The space between the two, in either direction.
  final double gap;

  /// Whether the two are pulled to the same height in a row, and to the full
  /// width in a column. On for fixed frames that fill what they are given;
  /// off for cards in a scrolling list, which are as tall as their text.
  final bool stretch;

  /// Whether the pages that use this should show the two side by side.
  static bool sideBySide(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  @override
  Widget build(BuildContext context) {
    if (sideBySide(context)) {
      return Row(
        crossAxisAlignment: stretch
            ? CrossAxisAlignment.stretch
            : CrossAxisAlignment.start,
        children: [
          Expanded(child: source),
          SizedBox(width: gap),
          Expanded(child: target),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        source,
        SizedBox(height: gap),
        target,
      ],
    );
  }
}
