import 'package:flutter/material.dart';

/// An app-bar title that can be dragged sideways to read the rest of it.
///
/// A Set's name is as long as whoever wrote it made it - "Set 6 - Jesus begins
/// his work in Galilee" does not fit an app bar beside a back button and a
/// language toggle, and an ellipsis leaves the reader unable to tell two
/// similarly-named Sets apart. Scrolling gives them the whole name without
/// wrapping the bar onto a second line or shrinking the text to fit.
class ScrollingTitle extends StatelessWidget {
  const ScrollingTitle({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Nothing to drag when the name already fits, so the bar does not
      // wobble under a stray horizontal swipe on the short titles.
      physics: const ClampingScrollPhysics(),
      child: Text(text, maxLines: 1, style: style),
    );
  }
}
