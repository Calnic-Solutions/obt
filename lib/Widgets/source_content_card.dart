import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/services/script_text.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/script_reader.dart';
import 'package:livuka/Widgets/script_text_view.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/work_queue.dart';

/// The passage the Set was translated from: its script, then its recording.
///
/// A peer's whole job is the comparison, and the script is half of what they
/// are comparing against - checking a reading with only the audio to go on
/// means holding a paragraph in your head while another one plays. Script
/// above player, in one card, so both are the same piece of material.
class SourceContentCard extends StatelessWidget {
  const SourceContentCard({
    super.key,
    required this.leaves,
    required this.audio,
    this.active = 0,
    this.onEnded,
    this.showAudio = true,
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

  /// Whether the source recording's player sits in this card under the
  /// script. Off where the page keeps its players somewhere they cannot be
  /// scrolled away from.
  final bool showAudio;

  /// The Set's passages in reading order.
  final List<SetLeaf> leaves;

  /// Which of [leaves] is shown. One passage at a time, as the website's
  /// Peer Check shows them: the script in the box is the script of the
  /// passage now playing, and the rest of the Set is not run on under it.
  final int active;

  final SetAudio? audio;
  final VoidCallback? onEnded;

  @override
  Widget build(BuildContext context) {
    final leaf = active >= 0 && active < leaves.length ? leaves[active] : null;
    final script = leaf != null && leaf.hasSourceScript
        ? shownScript(leaf.sourceScript)
        : '';

    return Container(
      // In a fixed frame the heading is a small label over the reading
      // room, as on the drafter's screen; in a list it is a card's title.
      padding: scroll != null
          ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
          : const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                Icons.description_outlined,
                size: scroll != null ? 14 : 16,
                // The quiet grey of a label, wherever the card is: the
                // script is the thing to read, and its name is not.
                color: MainApp.mutedText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Source script'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: scroll != null ? 12 : 14,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
              if (script.isNotEmpty)
                ExpandScriptButton(
                  title: 'Source script',
                  icon: Icons.description_outlined,
                  // What the card holds, made large: this passage.
                  text: script,
                ),
            ],
          ),
          // Close under its heading: the heading is a label for the text,
          // and on a short frame every line of room is reading room.
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
          if (showAudio) const SizedBox(height: 14),
          // Flat, because the card around it is this one.
          if (showAudio)
            MergedRecordingCard(
              title: 'Source audio',
              icon: Icons.volume_up_rounded,
              audio: audio,
              allowSeek: true,
              onEnded: onEnded,
              flat: true,
            ),
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
                : 'No source script yet.')
            .tr,
        style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
      );
    }
    return ScriptTextView(text: script);
  }
}
