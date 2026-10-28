import 'package:flutter/material.dart';

import 'package:livuka/services/script_text.dart';

/// A passage of script, laid out the way its own writing system wants.
///
/// Every screen that shows a script uses this, so the source a drafter reads
/// while recording and the source a peer checks against are the same text in
/// the same hand.
class ScriptTextView extends StatelessWidget {
  const ScriptTextView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // The website's rule: the paragraph takes the direction of the script
    // it holds ([scriptIsRtl]), which is what `dir="rtl"` on its script
    // boxes does. It decides two things. The block sits against the margin
    // the script starts from; and the verse reference at the head of every
    // line - `# 1:14 #`, digits and punctuation with no direction of their
    // own - is set at that same end, ahead of the words, rather than being
    // left at the far edge with the Urdu running in to meet it.
    //
    // 12, a step under the app's body text: the passage sits in a card
    // that shares the screen with a player, the takes and the recorder,
    // and the smaller size fits more of it on screen before scrolling.
    //
    // Plain Text rather than SelectableText. A selectable passage takes the
    // vertical drag for itself to run a selection, and a script long enough
    // to fill the panel it sits in is then one the reader cannot scroll:
    // every place a finger lands is text. Reading the passage is the whole
    // point of showing it; selecting it was never asked for.
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textDirection: scriptIsRtl(text)
            ? TextDirection.rtl
            : TextDirection.ltr,
        textAlign: TextAlign.start,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
