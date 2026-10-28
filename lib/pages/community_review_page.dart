import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/stage_action_button.dart';
import 'package:livuka/Widgets/sent_back_banner.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/mark_sheet.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/work_queue.dart';

/// Reviewing what the community said about a Set.
class CommunityReviewController extends GetxController {
  CommunityReviewController(this.set);

  final WorkSet set;

  final isLoading = true.obs;
  final isBusy = false.obs;

  final isSending = false.obs;
  final questions = <CommunityQuestion>[].obs;

  /// One key per question card, so a pin on the waveform can find the card it
  /// belongs to and bring it into view.
  final Map<String, GlobalKey> cardKeys = {};

  /// The card being pointed at, flashed for a moment after a pin is tapped.
  final highlighted = RxnString();

  final audio = Rxn<SetAudio>();

  @override
  void onInit() {
    super.onInit();
    TimeTracker.instance.enter(
      stage: TimeTracker.stageOf(set.workflowStatus),
      setId: set.id,
    );
    load();
  }

  @override
  void onClose() {
    TimeTracker.instance.leave();
    super.onClose();
  }

  /// Questions the community never answered. There is nothing to like or
  /// dislike about silence, so these hold BOTH buttons until the drafter's
  /// test supplies an answer.
  int get unanswered => questions.where((q) => !q.isAnswered).length;

  int get undecided =>
      questions.where((q) => q.isAnswered && q.reaction == null).length;

  bool get anyDisliked => questions.any((q) => q.isDisliked);

  /// Every answer liked. With no questions at all there is nothing to
  /// dislike, and the website lets such a Set through - it is the drafter's
  /// choice not to have asked anything, not a reason to hold the Set.
  bool get allLiked => questions.every((q) => q.isLiked);

  /// Why [action] cannot be taken right now, or null when it can.
  String? blockedReason(StageAction action) {
    if (unanswered > 0) {
      return unanswered == 1
          ? 'One question has no answer yet. It needs one before this Set '
                'can go anywhere.'
          : '@count questions have no answer yet. They need one before this '
                    'Set can go anywhere.'
                .trParams({'count': '$unanswered'});
    }
    if (action.isSendBack) {
      return anyDisliked
          ? null
          : 'Dislike at least one answer first, so the Drafter knows what '
                'to fix.';
    }
    if (anyDisliked) {
      return 'A disliked answer has to go back to the Drafter - it cannot go '
          'on to Back Translation.';
    }
    return allLiked ? null : 'Like every answer before sending this on.';
  }

  List<StageAction> get actions => WorkQueue.actionsFor(
    role: set.roleKey,
    status: set.workflowStatus,
    redoFromStage: set.redoFromStage,
  );

  /// The questions, pinned where they were asked. A reviewer reading an
  /// answer needs to hear the part of the recording it was about, and these
  /// pins are the only thing that says where that was. A disliked one turns
  /// red, the same as on the website.
  List<SegmentMark> get marks => [
    for (final question in questions)
      if (question.positionSeconds != null && !question.isGeneral)
        SegmentMark(
          id: question.id,
          leafId: question.leafKey,
          offsetSeconds: question.positionSeconds!,
          color: MarkColors.question(
            hasAudio: question.hasAudio,
            hasReply: question.isDisliked,
          ),
        ),
  ];

  Future<void> load() async {
    isLoading.value = true;
    try {
      final leaves = await WorkQueue.leavesForSet(set.id);
      _labels = {for (final leaf in leaves) leaf.key: leaf.label};
      await TakeRepository.resolveSupersededComments(
        setId: set.id,
        stageKey: 'community_review',
      );
      await TakeRepository.resolveSupersededReplies(setId: set.id);

      questions.value = await TakeRepository.questionsFor(
        setId: set.id,
        leafLabels: _labels,
      );
      audio.value = await buildSetAudio(setId: set.id, leaves: leaves);
    } finally {
      isLoading.value = false;
    }
  }

  /// Passage names, kept from the load so the marks can be re-read without
  /// going back for the leaves.
  Map<String, String> _labels = const {};

  /// Re-reads what was just written and nothing else.
  ///
  /// A save changes one card. Running the whole load again for that put the
  /// page back on its spinner and rebuilt the recording, so somebody who had
  /// listened through watched the player reappear and lost their place.
  Future<void> _reloadMarks() async {
    questions.value = await TakeRepository.questionsFor(
      setId: set.id,
      leafLabels: _labels,
    );
  }

  /// A Like goes down at once: it needs nothing said, and asking for a
  /// comment nobody has to give would turn one tap into three.
  Future<void> like(CommunityQuestion question) => _save(
    () => TakeRepository.setReaction(
      setId: set.id,
      question: question,
      reaction: 'like',
      // Praise already written stays when the thumb is pressed again.
      text: question.isLiked ? question.reaction!.text : '',
      audioFilePath: question.isLiked && question.reaction!.isLocal
          ? question.reaction!.audioPath
          : null,
    ),
  );

  /// The only praise that reaches the drafter: a liked answer WITH a comment
  /// shows on their Feedback screen, and a bare Like shows nowhere.
  Future<void> praise(CommunityQuestion question) async {
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Tell the Drafter what worked',
      icon: Icons.thumb_up_alt_outlined,
      subtitle: question.displayText,
      hint: 'Optional - this is the only praise the Drafter sees.',
      accent: const Color(0xFF15803D),
    );
    if (draft == null) return;

    await _save(
      () => TakeRepository.setReaction(
        setId: set.id,
        question: question,
        reaction: 'like',
        text: draft.text,
        audioFilePath: draft.audioPath,
      ),
    );
  }

  /// A Dislike has to say why. Closing the composer without saying anything
  /// leaves the answer as it was.
  Future<void> dislike(CommunityQuestion question) async {
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'What is wrong with this answer?',
      icon: Icons.thumb_down_alt_outlined,
      subtitle: question.displayText,
      hint: 'A Dislike needs a comment - the Drafter works from it.',
      accent: const Color(0xFFDC2626),
    );
    if (draft == null) return;
    if (draft.text.isEmpty && (draft.audioPath ?? '').isEmpty) {
      toaster('A Dislike needs a comment.');
      return;
    }

    await _save(
      () => TakeRepository.setReaction(
        setId: set.id,
        question: question,
        reaction: 'dislike',
        text: draft.text,
        audioFilePath: draft.audioPath,
      ),
    );
  }

  Future<void> _save(Future<void> Function() action) async {
    isBusy.value = true;
    try {
      await action();
      await _reloadMarks();
    } catch (e) {
      toaster('Could not save it: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  /// A pin scrolls to its question's card rather than opening a copy of it
  /// over the top - a sheet that says what is a few centimetres below is one
  /// more thing to dismiss.
  void showMark(SegmentMark mark) => revealQuestion(mark.id);

  /// Brings a question's card into view and flashes it, so it is obvious
  /// which one the pin belonged to.
  void revealQuestion(String id) {
    // Lit whether or not it can be scrolled to; see the test page's note.
    final context = cardKeys[id]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        alignment: 0.3,
      );
    }

    highlighted.value = id;
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (highlighted.value == id) highlighted.value = null;
    });
  }

  Future<void> runAction(StageAction action) async {
    if (blockedReason(action) != null) return;

    isSending.value = true;
    final sent = await HandOff.run(set: set, action: action);
    if (!sent) isSending.value = false;
  }
}

/// The community review screen: the recording, what the community was asked
/// and answered, and what the reviewer makes of it.
class CommunityReviewPage extends StatelessWidget {
  const CommunityReviewPage({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<CommunityReviewController>(
        init: CommunityReviewController(set),
        global: false,
        // GetBuilder, not GetX: the page is built once. Replying to an
        // answer redraws the replies, and leaves the recording alone.
        builder: (controller) => Scaffold(
          backgroundColor: MainApp.pageBackground,
          appBar: AppBar(
            actions: AppBarActions.build(),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScrollingTitle(
                  text: set.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 12,
                      color: Color(0xFF1D6FD0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Community review'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1D6FD0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Obx(
            () => controller.isLoading.value
                ? const RecordingPageSkeleton(questions: 2)
                : _body(controller),
          ),
          bottomNavigationBar: Obx(
            () => controller.isLoading.value
                ? const SizedBox.shrink()
                : _actionBar(controller),
          ),
        ),
      ),
    );
  }

  Widget _body(CommunityReviewController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SentBackBanner(set: controller.set),
        // The player watches the recording and its pins, and nothing else.
        // A reply written below must not rebuild it: the waveform goes with
        // the card, and the playhead with the waveform.
        Obx(
          () => MergedRecordingCard(
            audio: controller.audio.value,
            allowSeek: true,
            highlight: true,
            highlightUntilPlayed: true,
            marks: controller.marks,
            onMarkTap: controller.showMark,
          ),
        ),
        const SizedBox(height: 18),
        Obx(() => _questions(controller)),
      ],
    );
  }

  /// The questions and what has been said about them.
  Widget _questions(CommunityReviewController controller) {
    if (controller.questions.isEmpty) return const _Empty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final question in controller.questions) ...[
          _QaCard(
            key: controller.cardKeys.putIfAbsent(question.id, GlobalKey.new),
            question: question,
            highlighted: controller.highlighted.value == question.id,
            busy: controller.isBusy.value,
            onLike: () => controller.like(question),
            onDislike: () => controller.dislike(question),
            onPraise: () => controller.praise(question),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _actionBar(CommunityReviewController controller) {
    final actions = controller.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // One line, for whichever button is refused: both are held by an
            // unanswered question, and otherwise it is the one that is greyed
            // that needs explaining.
            if (actions
                    .map(controller.blockedReason)
                    .whereType<String>()
                    .firstOrNull
                case final reason?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  reason.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
            for (final action in actions) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: StageActionButton(
                  label: action.label,
                  icon: action.isSendBack ? Icons.rotate_left : Icons.send,
                  sendBack: action.isSendBack,
                  highlight:
                      !action.isSendBack &&
                      !controller.isSending.value &&
                      controller.blockedReason(action) == null,
                  onPressed:
                      controller.isSending.value ||
                          controller.blockedReason(action) != null
                      ? null
                      : () => controller.runAction(action),
                ),
              ),
              if (action != actions.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// One question, what the community answered, and the review of it.
class _QaCard extends StatelessWidget {
  const _QaCard({
    super.key,
    required this.question,
    required this.busy,
    required this.onLike,
    required this.onDislike,
    required this.onPraise,
    this.highlighted = false,
  });

  final CommunityQuestion question;
  final bool busy;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onPraise;

  /// Ringed for a moment after its pin was tapped, so the eye lands on the
  /// right card among several that look alike.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final answer = question.answer;
    final reaction = question.reaction;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
        border: Border.all(
          color: highlighted ? MainApp.primaryGreen : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Line(
            icon: Icons.question_mark,
            color: MarkColors.question(
              hasAudio: question.hasAudio,
              hasReply: question.isDisliked,
            ),
            label: question.displayText,
            audioPath: question.audioPath,
          ),
          if (answer != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18),
              child: _Line(
                icon: Icons.reply,
                color: const Color(0xFF1E8E3E),
                label: answer.text.isEmpty ? 'Voice answer'.tr : answer.text,
                audioPath: answer.audioPath,
              ),
            ),
          ],
          // Never answered: nothing to judge, so no buttons - and the Set
          // goes nowhere until the drafter's test supplies one.
          if (answer == null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18),
              child: Text(
                'No answer yet.'.tr,
                style: const TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: MainApp.mutedText,
                ),
              ),
            ),
          ] else ...[
            if (reaction != null && reaction.hasComment) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 36),
                child: _Line(
                  icon: reaction.isLike
                      ? Icons.thumb_up_alt_outlined
                      : Icons.thumb_down_alt_outlined,
                  color: reaction.isLike
                      ? const Color(0xFF15803D)
                      : MainApp.sendBackRed,
                  label: reaction.text.isEmpty
                      ? 'Voice comment'.tr
                      : reaction.text,
                  audioPath: reaction.audioPath,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _VerdictButton(
                    label: 'Like',
                    icon: Icons.thumb_up_alt_rounded,
                    color: const Color(0xFF15803D),
                    selected: question.isLiked,
                    onPressed: busy ? null : onLike,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VerdictButton(
                    label: 'Dislike',
                    icon: Icons.thumb_down_alt_rounded,
                    color: MainApp.sendBackRed,
                    selected: question.isDisliked,
                    onPressed: busy ? null : onDislike,
                  ),
                ),
              ],
            ),
            if (question.isLiked) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: busy ? null : onPraise,
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: Text(
                    reaction!.hasComment
                        ? 'Change your comment'.tr
                        : 'Add a comment for the Drafter (optional)'.tr,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Like or Dislike. Tall enough for a thumb, and filled once chosen so the
/// verdict on each card can be read while scrolling past it.
class _VerdictButton extends StatelessWidget {
  const _VerdictButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: selected ? color : color.withValues(alpha: 0.10),
          foregroundColor: selected ? Colors.white : color,
          disabledForegroundColor: selected ? Colors.white70 : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label.tr,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.color,
    required this.label,
    required this.audioPath,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String audioPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          ],
        ),
        if (audioPath.isNotEmpty)
          AudioClip(key: ValueKey(audioPath), filePath: audioPath),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 26, color: MainApp.mutedText),
          const SizedBox(height: 8),
          Text(
            'The community test produced no questions.'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
          ),
        ],
      ),
    );
  }
}
