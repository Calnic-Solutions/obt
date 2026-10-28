import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/l10n/plural.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/work_queue.dart';

/// The Sets a drafter has been praised on.
///
/// The only good news that travels back down the pipeline. A reviewer who
/// likes a community answer and says why is talking to the drafter, and this
/// is where the drafter hears it. A bare Like is not shown anywhere - there
/// is nothing in it to read - and a Dislike never comes here: that arrives
/// as a Set sent back, which is a job rather than a message.
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  late Future<List<FeedbackSet>> _sets = WorkQueue.feedbackSets();

  @override
  Widget build(BuildContext context) {
    const stage = WorkQueue.feedbackStage;

    return NameLanguageBuilder(
      builder: (context) => Scaffold(
        backgroundColor: MainApp.pageBackground,
        appBar: AppBar(
          actions: AppBarActions.build(),
          title: Row(
            children: [
              Icon(stage.icon, size: 20, color: stage.color),
              const SizedBox(width: 8),
              // Shrinks to fit rather than spilling under the icons beside it:
              // the bar now carries Home and Settings as well, and a stage's name
              // in Urdu or Hindi runs longer than it does in English.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stage.label.tr,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        body: FutureBuilder<List<FeedbackSet>>(
          future: _sets,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SetListSkeleton(leading: true, rows: 4);
            }

            final sets = snapshot.data ?? const [];
            if (sets.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    'No feedback yet.\nLiked answers that come with a '
                            'comment will show here.'
                        .tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: MainApp.mutedText,
                      height: 1.5,
                    ),
                  ),
                ),
              );
            }

            return PullToRefresh(
              onRefresh: () async {
                setState(() => _sets = WorkQueue.feedbackSets());
                await _sets;
              },
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: sets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = sets[index];
                  return Material(
                    color: Colors.white,
                    elevation: 3,
                    shadowColor: MainApp.cardShadowColor,
                    surfaceTintColor: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      // A whole row to aim at, and tall enough for a thumb.
                      minVerticalPadding: 14,
                      onTap: () => Get.to(() => FeedbackSetPage(item: item)),
                      leading: CircleAvatar(
                        backgroundColor: stage.color.withValues(alpha: 0.14),
                        child: Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 18,
                          color: stage.color,
                        ),
                      ),
                      title: Text(
                        item.set.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (item.set.subtitle.isNotEmpty) item.set.subtitle,
                          trCount(
                            item.count,
                            '@count comment',
                            '@count comments',
                          ),
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One Set's praise: the recording, with a thumb where each liked answer's
/// question was asked, and under it what was asked, answered and said.
class FeedbackSetPage extends StatefulWidget {
  const FeedbackSetPage({super.key, required this.item});

  final FeedbackSet item;

  @override
  State<FeedbackSetPage> createState() => _FeedbackSetPageState();
}

class _FeedbackSetPageState extends State<FeedbackSetPage> {
  SetAudio? _audio;
  List<CommunityQuestion> _feedback = const [];
  bool _loading = true;

  final Map<String, GlobalKey> _cards = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final set = widget.item.set;
    final leaves = await WorkQueue.leavesForSet(set.id);
    final feedback = await TakeRepository.feedbackFor(
      setId: set.id,
      leafLabels: {for (final leaf in leaves) leaf.key: leaf.label},
    );
    final audio = await buildSetAudio(setId: set.id, leaves: leaves);

    if (!mounted) return;
    setState(() {
      _feedback = feedback;
      _audio = audio;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = WorkQueue.feedbackStage.color;

    return Scaffold(
      backgroundColor: MainApp.pageBackground,
      appBar: AppBar(
        actions: AppBarActions.build(nameToggle: false),
        title: ScrollingTitle(
          text: widget.item.set.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      body: _loading
          ? const RecordingPageSkeleton(questions: 2)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                MergedRecordingCard(
                  audio: _audio,
                  allowSeek: true,
                  marks: [
                    for (final question in _feedback)
                      if (question.positionSeconds != null)
                        SegmentMark(
                          id: question.id,
                          leafId: question.leafKey,
                          offsetSeconds: question.positionSeconds!,
                          color: color,
                          icon: Icons.thumb_up_alt,
                        ),
                  ],
                  onMarkTap: (mark) {
                    final target = _cards[mark.id]?.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(
                        target,
                        duration: const Duration(milliseconds: 350),
                        alignment: 0.3,
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                for (final question in _feedback) ...[
                  _FeedbackCard(
                    key: _cards.putIfAbsent(question.id, GlobalKey.new),
                    question: question,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({super.key, required this.question});

  final CommunityQuestion question;

  @override
  Widget build(BuildContext context) {
    final answer = question.answer!;
    final praise = question.reaction!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.leafLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                question.leafLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MainApp.mutedText,
                ),
              ),
            ),
          _line(
            Icons.question_mark,
            const Color(0xFFCA8A04),
            question.displayText,
            question.audioPath,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 18),
            child: _line(
              Icons.reply,
              const Color(0xFF15803D),
              answer.text.isEmpty ? 'Voice answer'.tr : answer.text,
              answer.audioPath,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _line(
              Icons.thumb_up_alt,
              const Color(0xFF15803D),
              [
                if (praise.authorName.isNotEmpty && praise.authorName != 'You')
                  '${praise.authorName}: ',
                praise.text.isEmpty ? 'Voice comment'.tr : praise.text,
              ].join(),
              praise.audioPath,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, Color color, String label, String audioPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
        if (audioPath.isNotEmpty)
          AudioClip(key: ValueKey(audioPath), filePath: audioPath),
      ],
    );
  }
}
