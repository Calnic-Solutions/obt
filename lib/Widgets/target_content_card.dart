import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/script_reader.dart';
import 'package:livuka/Widgets/script_text_view.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/script_text.dart';
import 'package:livuka/services/work_queue.dart';

/// What the Set is being translated into, in writing.
///
/// It sits under the source so the two read in the order the work happens:
/// this is the passage, and this is what it should come out as. Shown even
/// when it is empty, because "no target script yet" is itself worth knowing
/// to a peer wondering what they are checking against.
class TargetContentCard extends StatelessWidget {
  const TargetContentCard({
    super.key,
    required this.leaves,
    this.active = 0,
    this.flat = false,
    this.scroll,
  });

  /// Given, the heading stays put and only the script scrolls, inside
  /// whatever height the card is handed - the Peer Check's fixed frames.
  /// The frame owns the controller so it can wind the text back to the top
  /// when the passage changes. Left null, the card is as tall as its text.
  final ScrollController? scroll;

  /// Without the card's own outline and shadow, for a page that draws the
  /// box itself - a fixed frame the script scrolls inside.
  final bool flat;

  /// The Set's passages in reading order.
  final List<SetLeaf> leaves;

  /// Which of [leaves] is shown - the same passage the source box shows,
  /// so the two are always the two halves of one comparison.
  final int active;

  @override
  Widget build(BuildContext context) {
    final leaf = active >= 0 && active < leaves.length ? leaves[active] : null;
    final script = leaf != null && leaf.hasTargetScript
        ? shownScript(leaf.targetScript)
        : '';

    return Container(
      // In a fixed frame the heading is a small label over the reading
      // room, as on the drafter's screen; in a list it is a card's title.
      padding: scroll != null
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: flat
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: MainApp.cardShadow,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.translate,
                size: scroll != null ? 14 : 16,
                // The quiet grey of a label, wherever the card is: the
                // script is the thing to read, and its name is not.
                color: MainApp.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Target script'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: scroll != null ? 12 : 14,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
              if (script.isNotEmpty)
                ExpandScriptButton(
                  title: 'Target script',
                  icon: Icons.translate,
                  text: script,
                ),
            ],
          ),
          SizedBox(height: 4),
          if (scroll case final scroll?)
            Expanded(
              child: Scrollbar(
                controller: scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scroll,
                  // Clear of the scrollbar, which rides the end edge -
                  // where a right-to-left script's lines begin.
                  padding: const EdgeInsetsDirectional.only(end: 12, bottom: 4),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: _text(leaf, script),
                  ),
                ),
              ),
            )
          else
            _text(leaf, script),
        ],
      ),
    );
  }

  /// The script itself, or the line that says there is none yet.
  Widget _text(SetLeaf? leaf, String script) {
    if (script.isEmpty) {
      return Text(
        (leaf == null
                ? 'No passages in this Set yet.'
                : 'No target script yet.')
            .tr,
        style: const TextStyle(fontSize: 13, color: Color(0xFFB45309)),
      );
    }
    return ScriptTextView(text: script);
  }
}
