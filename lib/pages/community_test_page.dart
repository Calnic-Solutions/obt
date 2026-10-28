import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/sent_back_banner.dart';
import 'package:livuka/l10n/plural.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/mark_sheet.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/work_queue.dart';

/// Loads a Set's questions and its audio, and records the answers.
class CommunityTestController extends GetxController {
  CommunityTestController(this.set);

  final WorkSet set;

  final cardKeys = <String, GlobalKey>{};

  final isLoading = true.obs;
  final isBusy = false.obs;
  final isSending = false.obs;
  final questions = <CommunityQuestion>[].obs;
  final audio = Rxn<SetAudio>();
  final highlighted = RxnString();

  /// The web gates the hand-off on hearing the merged recording end to end,
  /// not merely pressing play. The point of a community test is that the
  /// community actually heard it, so the same gate applies here.
  final heardInFull = false.obs;

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

  int get unanswered => questions.where((q) => !q.isAnswered).length;

  bool get needsListen =>
      (audio.value?.isPlayable ?? false) && !heardInFull.value;

  bool get canForward => unanswered == 0 && !needsListen && !isSending.value;

  Future<void> load() async {
    isLoading.value = true;
    try {
      // Kept for this round of the Set: the room has heard it, and coming
      // back to the screen after a break must not mean playing it again.
      heardInFull.value = await ListenGate.isHeard(
        setId: set.id,
        round: set.workflowUpdatedAt,
        what: ListenGate.merged,
      );
      final leaves = await WorkQueue.leavesForSet(set.id);
      _labels = {for (final leaf in leaves) leaf.key: leaf.label};

      questions.value = await TakeRepository.questionsFor(
        setId: set.id,
        leafLabels: _labels,
      );
      audio.value = await buildSetAudio(setId: set.id, leaves: leaves);
    } finally {
      isLoading.value = false;
    }
  }

  /// Passage names, kept from the load so the questions can be re-read
  /// without going back for the leaves.
  Map<String, String> _labels = const {};

  /// Re-reads the questions and nothing else.
  ///
  /// Saving an answer changes one card. Running the whole load again for
  /// that put the page back on its spinner and rebuilt the recording - so
  /// somebody who had listened right through watched the player reappear and
  /// had to find their place again, in the middle of answering.
  Future<void> _reloadQuestions() async {
    questions.value = await TakeRepository.questionsFor(
      setId: set.id,
      leafLabels: _labels,
    );
  }

  /// Pins for every question that names both a passage and an offset. The
  /// player turns these into timeline positions once it knows the durations.
  List<SegmentMark> get questionMarks => [
    for (final question in questions)
      if (question.positionSeconds != null && !question.isGeneral)
        SegmentMark(
          id: question.id,
          leafId: question.leafKey,
          offsetSeconds: question.positionSeconds!,
          color: MarkColors.question(
            hasAudio: question.hasAudio,
            hasReply: question.hasReplies,
          ),
        ),
  ];

  Future<void> answer(CommunityQuestion question) async {
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Answer this question',
      icon: Icons.reply_rounded,
      subtitle: question.text,
      hint: 'Type what they said',
    );
    if (draft == null) return;

    isBusy.value = true;
    try {
      await TakeRepository.addAnswer(
        setId: set.id,
        question: question,
        text: draft.text,
        audioFilePath: draft.audioPath,
      );
      await _reloadQuestions();
    } catch (e) {
      toaster('Could not save the answer: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  /// Tapping a pin on the waveform brings its card into view and flashes it,
  /// so it is obvious which question the mark belongs to.
  void revealQuestion(String id) {
    // The card is lit whether or not it can be scrolled to: the desktop
    // lays the cards out in a pager with no keys to scroll by, and
    // returning early here left a tap on a pin doing nothing there.
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

  Future<void> sendToReview() async {
    final action = WorkQueue.actionsFor(
      role: set.roleKey,
      status: set.workflowStatus,
    ).firstOrNull;
    if (action == null) return;

    isSending.value = true;
    final sent = await HandOff.run(set: set, action: action);
    if (!sent) isSending.value = false;
  }

  void markHeard() {
    heardInFull.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.merged,
    );
  }
}

/// Running the community test for one Set.
///
/// The community hears the whole Set as one continuous recording rather than
/// passage by passage, then the drafter works through the questions with the
/// people in the room.
class CommunityTestPage extends StatelessWidget {
  const CommunityTestPage({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<CommunityTestController>(
        // Page-scoped: created with this route and disposed with it.
        init: CommunityTestController(set),
        global: false,
        // GetBuilder, not GetX: the page is built once. Answering a question
        // redraws the questions, and leaves the recording above them alone.
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
                      Icons.assignment_outlined,
                      size: 12,
                      color: Color(0xFF1D6FD0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Community test'.tr,
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
                : _questionList(controller),
          ),
          bottomNavigationBar: Obx(
            () => controller.isLoading.value
                ? const SizedBox.shrink()
                : _forwardBar(controller),
          ),
        ),
      ),
    );
  }

  Widget _questionList(CommunityTestController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SentBackBanner(set: controller.set),
        // The player watches the recording and its pins. Answering a
        // question below must not rebuild it - the waveform would be
        // rebuilt with it, and the playhead lost.
        Obx(
          () => MergedRecordingCard(
            audio: controller.audio.value,
            // Held back with the questions themselves, as on the website:
            // a pin says where a question is about, and a room shown that
            // before it has listened waits for those places instead of
            // hearing the passage. They arrive when the recording ends.
            marks: controller.needsListen ? const [] : controller.questionMarks,
            onMarkTap: (mark) => controller.revealQuestion(mark.id),
            onEnded: controller.markHeard,
            mustListen: controller.needsListen,
            highlight: controller.needsListen,
          ),
        ),
        const SizedBox(height: 18),
        Obx(() => _questions(controller)),
      ],
    );
  }

  /// The questions themselves, and how far through them the answering is.
  Widget _questions(CommunityTestController controller) {
    final unanswered = controller.unanswered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nothing to answer until the whole reading has been heard.
        //
        // The questions are about the passage as a piece, and a community
        // member who reads them first listens for the answer rather than to
        // the recording - which is the opposite of what this stage is for.
        if (controller.needsListen)
          const _ListenFirst()
        else ...[
          Row(
            children: [
              Text(
                'Questions'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unanswered == 0
                    ? 'all answered'.tr
                    : '@count unanswered'.trParams({'count': '$unanswered'}),
                style: TextStyle(
                  fontSize: 12,
                  color: unanswered == 0
                      ? const Color(0xFF1E8E3E)
                      : MainApp.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (controller.questions.isEmpty)
            const _NoQuestions()
          else
            // Dealt out one after another rather than all at once. The whole
            // list arriving in a block at the end of a two-minute recording
            // reads as a wall of work; a card at a time gives the person
            // answering somewhere to start.
            for (final (index, question) in controller.questions.indexed) ...[
              _Reveal(
                delay: Duration(milliseconds: 90 * index),
                child: _QuestionCard(
                  key: controller.cardKeys.putIfAbsent(
                    question.id,
                    GlobalKey.new,
                  ),
                  question: question,
                  highlighted: controller.highlighted.value == question.id,
                  onAnswer: controller.isBusy.value
                      ? null
                      : () => controller.answer(question),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ],
    );
  }

  Widget _forwardBar(CommunityTestController controller) {
    final unanswered = controller.unanswered;

    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.needsListen)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Play the target recording to the end first.'.tr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
            PulseHalo(
              active: controller.canForward,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: MainApp.primaryGreen,
                  ),
                  onPressed: controller.canForward
                      ? controller.sendToReview
                      : null,
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(
                    unanswered > 0
                        ? trCount(
                            unanswered,
                            '@count question left',
                            '@count questions left',
                          )
                        : 'Send to Community Review'.tr,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts its child into place, after a wait.
///
/// Once only: the state is made when the card first appears and the animation
/// runs from there, so answering one question does not set the rest moving
/// again on the next rebuild.
class _Reveal extends StatefulWidget {
  const _Reveal({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 320),
    vsync: this,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  Timer? _start;

  @override
  void initState() {
    super.initState();

    // Made now, while the widget is in the tree - not by whichever of
    // `build` or `dispose` happens to touch it first.
    _controller;

    if (widget.delay == Duration.zero) {
      _controller.forward();
      return;
    }

    _start = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Stands in for the questions until the recording has been heard through.
class _ListenFirst extends StatelessWidget {
  const _ListenFirst();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.headphones, size: 28, color: Color(0xFF4B5563)),
          const SizedBox(height: 12),
          Text(
            'Listen to the whole recording above first - the questions will '
                    'appear here once you have.'
                .tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: MainApp.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    super.key,
    required this.question,
    required this.highlighted,
    required this.onAnswer,
  });

  final CommunityQuestion question;
  final bool highlighted;
  final VoidCallback? onAnswer;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
        border: highlighted
            ? Border.all(color: MainApp.primaryGreen, width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuestionScopeTag(question: question),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final accent = MarkColors.question(
                    hasAudio: question.hasAudio,
                    hasReply: question.hasReplies,
                  );

                  return Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.question_mark, size: 13, color: accent),
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.displayText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          // A question can carry text and a recording at once, so the player
          // sits below the wording rather than replacing it.
          if (question.hasAudio) ...[
            const SizedBox(height: 4),
            AudioClip(
              key: ValueKey('q-${question.id}'),
              filePath: question.audioPath,
            ),
          ],
          const SizedBox(height: 8),
          if (question.answer != null)
            _AnswerRow(answer: question.answer!)
          else if (onAnswer != null)
            // Filled and green: answering is the one thing to do on an
            // unanswered question, and an outline read as a second thought
            // beside the question it belongs to.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: onAnswer,
                style: FilledButton.styleFrom(
                  backgroundColor: MainApp.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: Text(
                  'Answer'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.answer});

  final CommunityAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check, size: 14, color: Color(0xFF1E8E3E)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  answer.text.isEmpty
                      ? 'Answered'.tr
                      : 'Answered - @answer'.trParams({'answer': answer.text}),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E8E3E),
                  ),
                ),
              ),
              if (answer.isLocal)
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 13,
                  color: Color(0xFFB45309),
                ),
            ],
          ),
          if (answer.hasAudio)
            AudioClip(
              key: ValueKey('a-${answer.id}'),
              filePath: answer.audioPath,
            ),
        ],
      ),
    );
  }
}

/// "General question" or the passage the question was pinned to.
class QuestionScopeTag extends StatelessWidget {
  const QuestionScopeTag({super.key, required this.question});

  final CommunityQuestion question;

  @override
  Widget build(BuildContext context) {
    final general = question.isGeneral;
    final color = general ? const Color(0xFF4B4870) : const Color(0xFF1D6FD0);
    final label = general
        ? 'General question'.tr
        : (question.leafLabel.isEmpty ? 'Passage'.tr : question.leafLabel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            general ? Icons.wechat_rounded : Icons.place_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoQuestions extends StatelessWidget {
  const _NoQuestions();

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
          const Icon(
            Icons.assignment_outlined,
            size: 26,
            color: MainApp.mutedText,
          ),
          const SizedBox(height: 8),
          Text(
            'No questions to test yet.'.tr,
            style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
          ),
        ],
      ),
    );
  }
}
