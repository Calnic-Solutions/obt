import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/work_queue.dart';

/// A Set's final takes, in reading order, plus why any are absent.
class SetAudio {
  const SetAudio({this.segments = const [], this.problem, this.accent});

  final List<AudioSegment> segments;

  /// What is missing, when something is. Shown alongside whatever did load,
  /// so a community hearing 5 of 7 passages is told so.
  final String? problem;

  /// The colour this recording's player wears, when it has one of its own.
  ///
  /// Decided where the audio is collected rather than where it is shown:
  /// the card that draws source audio is the same card that draws a draft,
  /// and only whoever built the list knows which of the two it is holding.
  final Color? accent;

  bool get isPlayable => segments.any((segment) => segment.isAvailable);
}

/// Collects the final take of every passage in a Set.
///
/// Nothing is joined here. The takes are handed to [ContinuousPlayer], which
/// plays them end to end behind one timeline — so this works with whatever
/// format the takes happen to be in.
Future<SetAudio> buildSetAudio({
  required String setId,
  required List<SetLeaf> leaves,
}) async {
  if (leaves.isEmpty) {
    return const SetAudio(
      problem:
          'This set has no passages on this device. Log out and back in to '
          're-sync.',
    );
  }

  final directory = await UserStore.work();
  final segments = <AudioSegment>[];

  for (final leaf in leaves) {
    final path = leaf.finalAudioPath;
    if (path.isEmpty) continue;

    // A take that has synced carries a server URL, but the audio cache has
    // already pulled it down under the same file name. Resolving to that
    // copy is what lets a Set drafted on another device still play here.
    final resolved = path.startsWith('http')
        ? p.join(directory.path, 'audio', p.basename(Uri.parse(path).path))
        : path;

    segments.add(
      AudioSegment(
        leafId: leaf.key,
        label: leaf.label,
        path: resolved,
        // Said, rather than left as a passage of no length that quietly
        // takes up no room on the timeline: the listener would otherwise
        // hear a Set with a passage missing and be told nothing.
        unavailable: await File(resolved).exists()
            ? null
            : 'This recording has not been downloaded to this phone yet. '
                      'Use Check for updates when there is a connection.'
                  .tr,
      ),
    );
  }

  if (segments.isEmpty) {
    return SetAudio(
      problem:
          'None of the @count passages here has a final take on this device. '
                  'The final_takes table did not sync - check it in the '
                  'database viewer.'
              .trParams({'count': '${leaves.length}'}),
    );
  }

  return SetAudio(
    segments: segments,
    problem: segments.length == leaves.length
        ? null
        : '@missing of @total passages have no final take yet, so they are '
                  'not in this recording.'
              .trParams({
                'missing': '${leaves.length - segments.length}',
                'total': '${leaves.length}',
              }),
  );
}

/// The source recordings of every passage, in reading order.
///
/// The reviewer's counterpart to [buildSetAudio]: what the passage was meant
/// to say, against what the drafter recorded.
Future<SetAudio> buildSourceAudio({required List<SetLeaf> leaves}) async {
  final segments = [
    for (final leaf in leaves)
      AudioSegment(
        leafId: leaf.key,
        label: leaf.label,
        path: leaf.sourceAudioPath,
        unavailable: _sourceProblem(leaf.sourceAudioPath),
      ),
  ];

  return SetAudio(segments: segments, accent: sourceAudioAccent);
}

/// Source audio is indigo wherever it plays, and a team's own recording is
/// green. A reviewer with both on one screen tells them apart before reading
/// either heading.
const Color sourceAudioAccent = MarkColors.sourceAudio;

/// Why a stored path cannot be played from here, if it cannot.
String? _sourceProblem(String path) {
  if (path.isEmpty) return 'No source audio has been added for this passage.';
  if (path.startsWith('http')) {
    return 'The source audio has not been downloaded to this device yet.';
  }
  return null;
}

/// The player at the top of Community Setup and Community Test.
class MergedRecordingCard extends StatelessWidget {
  const MergedRecordingCard({
    super.key,
    required this.audio,
    this.marks = const [],
    this.onMarkTap,
    this.onEnded,
    this.mustListen,
    this.onSegment,
    this.allowSeek = true,
    this.hint = '',
    this.title = 'Target Recording',
    this.icon = Icons.headphones,
    this.flat = false,
    this.accent,
    this.onAddMark,
    this.addMarkLabel,
    this.addMarkColor,
    this.highlight = false,
    this.highlightUntilPlayed = false,
  });

  /// See [ContinuousPlayer.highlight].
  final bool highlight;
  final bool highlightUntilPlayed;

  final SetAudio? audio;
  final List<SegmentMark> marks;
  final ValueChanged<SegmentMark>? onMarkTap;
  final VoidCallback? onEnded;

  /// Whether a full listen is still owed; see [ContinuousPlayer.mustListen].
  final bool? mustListen;
  final void Function(String leafId, String label, Duration offset)? onSegment;
  final bool allowSeek;
  final String hint;

  /// What the website calls it at every stage, the drafter's included:
  /// the Target Recording, under headphones. Only a player of something
  /// else - the source - is named and marked otherwise.
  final String title;

  /// Beside the title. Headphones for the target recording, a speaker for
  /// the source audio, as the website marks the two.
  final IconData icon;

  /// Drops the card around the player, for placing it inside one that is
  /// already drawn - a shadow inside a shadow reads as a mistake.
  final bool flat;

  /// The play button and played bars. Left null, the recording's own
  /// [SetAudio.accent] decides, and failing that the usual green.
  final Color? accent;

  /// Passed through to the full-screen player, which offers a large button
  /// for adding a comment or a question at the playhead when this is given.
  /// The page already knows where the playhead is from [onSegment].
  final Future<void> Function()? onAddMark;
  final String? addMarkLabel;
  final Color? addMarkColor;

  @override
  Widget build(BuildContext context) {
    final set = audio;
    final tint = accent ?? set?.accent ?? MainApp.primaryGreen;
    final playable = set != null && set.isPlayable;

    final heading = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 6),
        Text(
          title.tr,
          // One line, however long: the player scrolls it sideways.
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
    final hintLine = Text(
      hint.tr,
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
    );

    return Container(
      padding: flat
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
          // With a recording to play, the heading rides in the player's own
          // top row beside the controls. Only a card with nothing to play
          // draws it here, where there is no such row to put it in.
          if (!playable) ...[
            heading,
            if (hint.isNotEmpty) ...[const SizedBox(height: 4), hintLine],
            const SizedBox(height: 10),
          ],
          if (set?.problem != null) ...[
            _Notice(text: set!.problem!),
            if (set.isPlayable) const SizedBox(height: 10),
          ],
          if (set != null && set.isPlayable)
            Padding(
              padding: EdgeInsets.zero,
              child: ContinuousPlayer(
                key: ValueKey(set.segments.map((s) => s.path).join('|')),
                segments: set.segments,
                marks: marks,
                onMarkTap: onMarkTap,
                onEnded: onEnded,
                mustListen: mustListen,
                onSegment: onSegment,
                allowSeek: allowSeek,
                accent: tint,
                title: title,
                highlight: highlight,
                highlightUntilPlayed: highlightUntilPlayed,
                // The hint rides with the heading, in the space beside the
                // controls. On a line of its own under that row it sat a
                // full control's height below the words it explains.
                header: hint.isEmpty
                    ? heading
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading,
                          const SizedBox(height: 2),
                          hintLine,
                        ],
                      ),
                onAddMark: onAddMark,
                addMarkLabel: addMarkLabel,
                addMarkColor: addMarkColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.tr,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }
}
