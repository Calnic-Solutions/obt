import 'package:flutter/widgets.dart';

/// A sentence with part of it in bold, kept as ONE sentence.
///
/// The bold part is wrapped in `*stars*` inside the sentence itself, so a
/// translator moves it to wherever it falls in their language. Built from
/// separate spans, the sentence would be glued together in English order -
/// and Urdu and Hindi put the verb last.
List<InlineSpan> emphasisSpans(String sentence, TextStyle bold) {
  final parts = sentence.split('*');
  return [
    for (var i = 0; i < parts.length; i++)
      if (parts[i].isNotEmpty)
        TextSpan(text: parts[i], style: i.isOdd ? bold : null),
  ];
}
