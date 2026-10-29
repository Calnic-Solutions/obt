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
import 'package:livuka/Widgets/sheet_actions.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/pages/community_test_page.dart' show QuestionScopeTag;
import 'package:livuka/services/services.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/work_queue.dart';

/// Loads a Set's audio and the questions written against it.
class CommunitySetupController extends GetxController {
  CommunitySetupController(this.set);

  final WorkSet set;

  final isLoading = true.obs;
  final isBusy = false.obs;

  /// Whether to say that a spot has to be chosen first.
  ///
  /// Raised by trying to write without one, not shown from the start: the
  /// instruction means something at the moment somebody wants to say
  /// something, and nothing at all before that.
  final showSpotHint = false.obs;
  final isSending = false.obs;
  final questions = <CommunityQuestion>[].obs;
  final audio = Rxn<SetAudio>();

  /// Where the playhead is, expressed as a passage and an offset inside it.
  /// Supplied by the player, so pinning never has to do the arithmetic.
  String? currentLeafId;
  String currentLabel = '';
  Duration currentOffset = Duration.zero;

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

  /// The final take of each passage, so a question can name the recording
  /// it was asked about.
  Map<String, String> _finalTakeByLeaf = const {};

  List<CommunityQuestion> get general =>
      questions.where((q) => q.isGeneral).toList();

  List<CommunityQuestion> get pinned =>
      questions.where((q) => !q.isGeneral).toList();

  bool get hasQuestions => questions.isNotEmpty;

  List<SegmentMark> get marks => [
    for (final question in pinned)
      if (question.positionSeconds != null)
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

  Future<void> load() async {
    isLoading.value = true;
    try {
      final leaves = await WorkQueue.leavesForSet(set.id);
      _finalTakeByLeaf = {
        for (final leaf in leaves)
          if (leaf.finalTake?['id'] != null)
            leaf.key: leaf.finalTake!['id'].toString(),
      };
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

  /// Passage names, kept from the load so the marks can be re-read without
  /// going back for the leaves.
  Map<String, String> _labels = const {};

  /// Re-reads what was just written and nothing else.
  ///
  /// A save changes one card. Running the whole load again for that put the
  /// page back on its spinner and rebuilt the recording, so somebody who had
  /// listened through watched the player reappear and lost their place.
  Future<void> _reloadQuestions() async {
    questions.value = await TakeRepository.questionsFor(
      setId: set.id,
      leafLabels: _labels,
    );
  }

  void onSegment(String leafId, String label, Duration offset) {
    if (showSpotHint.value) showSpotHint.value = false;
    currentLeafId = leafId;
    currentLabel = label;
    currentOffset = offset;
  }

  Future<void> addPinnedQuestion() async {
    final leafId = currentLeafId;
    if (leafId == null) {
      showSpotHint.value = true;
      return;
    }

    final at = currentOffset;
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Question - @passage'.trParams({'passage': currentLabel}),
      subtitle: 'Pinned at @time'.trParams({'time': formatDuration(at)}),
      hint: 'What should the community be asked here?',
      // The composer has no question yet, so it takes the generic
      // question colour; the pin picks its own once there is one to read.
      accent: MarkColors.voiceQuestion,
    );
    if (draft == null) return;

    await _save(
      () => TakeRepository.addQuestion(
        setId: set.id,
        text: draft.text,
        audioFilePath: draft.audioPath,
        // The player names the leaf by its key; the row wants the two apart.
        leafType: SetLeaf.parseKey(leafId).type,
        leafId: SetLeaf.parseKey(leafId).id,
        // The take the question is about, so it drops out of the test if
        // the drafter later records over that take.
        takeId: _finalTakeByLeaf[leafId],
        // Offset within the passage, not the joined timeline. The web stores
        // it the same way - its `addMark` pairs `position_seconds` with a
        // `segIndex` - so a question pinned here lands in the same spot there.
        positionSeconds: at.inMilliseconds / 1000,
      ),
    );
  }

  Future<void> addGeneralQuestion() async {
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'General question',
      subtitle: 'About the whole set, not one passage.'.tr,
      hint: 'What should the community be asked?',
    );
    if (draft == null) return;

    await _save(
      () => TakeRepository.addQuestion(
        setId: set.id,
        text: draft.text,
        audioFilePath: draft.audioPath,
      ),
    );
  }

  Future<void> _save(Future<void> Function() action) async {
    isBusy.value = true;
    try {
      await action();
      await _reloadQuestions();
    } catch (e) {
      toaster('Could not save the question: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> sendToTest() async {
    final action = WorkQueue.actionsFor(
      role: set.roleKey,
      status: set.workflowStatus,
    ).firstOrNull;
    if (action == null) return;

    isSending.value = true;
    final sent = await HandOff.run(set: set, action: action);
    if (!sent) isSending.value = false;
  }

  /// Takes back a question. Only the person who wrote it may.
  Future<void> deleteQuestion(CommunityQuestion question) async {
    if (!question.isMine) return;
    if (!await ConfirmDialog.askDeleteComment()) return;

    await _save(
      () => TakeRepository.deleteComment(commentId: question.id, setId: set.id),
    );
  }

  void showQuestion(CommunityQuestion question) {
    showAppSheet(
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuestionScopeTag(question: question),
            const SizedBox(height: 12),
            Text(
              question.displayText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (question.hasAudio) ...[
              const SizedBox(height: 10),
              AudioClip(filePath: question.audioPath),
            ],
            // Only whoever wrote it may take it back.
            SheetActions(
              deleteLabel: 'Delete question',
              onDelete: question.isMine ? () => deleteQuestion(question) : null,
            ),
          ],
        ),
      ),
    );
  }

  static String formatDuration(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Writing the questions the community will be asked.
///
/// The drafter listens to the recording, stops where a question is worth
/// asking, and pins it there. A pinned question is only ever shown on the
/// waveform — the list below is for general questions about the whole Set,
/// which have no place to sit on the timeline.
class CommunitySetupPage extends StatelessWidget {
  const CommunitySetupPage({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<CommunitySetupController>(
        // Page-scoped: created with this route and disposed with it.
        init: CommunitySetupController(set),
        global: false,
        // GetBuilder, not GetX: this builds the page once. Everything that
        // moves while the page is open has its own Obx below, so writing a
        // question does not rebuild the recording above it.
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
                      'Community setup'.tr,
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
                ? _SetupSkeleton(banner: SentBackBanner(set: controller.set))
                : _body(controller),
          ),
          bottomNavigationBar: Obx(
            () => controller.isLoading.value
                ? const StageBarBones.forward()
                : _forwardBar(controller),
          ),
        ),
      ),
    );
  }

  Widget _body(CommunitySetupController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SentBackBanner(set: controller.set),
        // The player watches the recording and its pins, and nothing else.
        // Typing a question or pressing a button must not rebuild it: the
        // waveform is rebuilt with the card, and the playhead with it.
        Obx(
          () => MergedRecordingCard(
            audio: controller.audio.value,
            allowSeek: true,
            // Listening is where a question starts. Nothing here waits on
            // it, so the pulse goes the moment play is pressed.
            highlight: true,
            highlightUntilPlayed: true,
            onSegment: controller.onSegment,
            marks: controller.marks,
            // The same composer, reachable from the full-screen player: a
            // spot found by zooming in is asked about there and then.
            onAddMark: controller.addPinnedQuestion,
            addMarkLabel: 'Add a question here',
            addMarkColor: MarkColors.voiceQuestion,
            onMarkTap: (mark) => controller.showQuestion(
              controller.pinned.firstWhere((q) => q.id == mark.id),
            ),
          ),
        ),
        // Said when somebody tries to write without choosing a spot, and
        // not before: an instruction nobody needs yet is one that stops
        // being read by the time they do.
        Obx(
          () => !controller.showSpotHint.value
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F2F4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Tap the waveform to jump to the spot you mean, then add '
                            'the question there.'
                        .tr,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
        ),
        Obx(() => _addRow(controller)),
        Obx(() => _questions(controller)),
      ],
    );
  }

  /// The two ways to add a question, once there is a recording to pin to.
  Widget _addRow(CommunitySetupController controller) {
    if (!(controller.audio.value?.isPlayable ?? false)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: _AddQuestionButton(
              // The bare mark, matching the composer this opens.
              icon: Icons.question_mark_rounded,
              label: 'Add a question here',
              onPressed: controller.isBusy.value
                  ? null
                  : controller.addPinnedQuestion,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _AddQuestionButton(
              icon: Icons.wechat_rounded,
              label: 'Add a general question',
              onPressed: controller.isBusy.value
                  ? null
                  : controller.addGeneralQuestion,
            ),
          ),
        ],
      ),
    );
  }

  /// What has been asked so far, pinned and general.
  Widget _questions(CommunitySetupController controller) {
    final pinned = controller.pinned;
    final general = controller.general;
    if (pinned.isEmpty && general.isEmpty) return const SizedBox.shrink();

    return Column(
      // Stretch, because these were list children before they were lifted
      // into a Column: a ListView gives every child the full width, and a
      // Column would otherwise shrink each card to its own content.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pinned.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            trCount(
              pinned.length,
              '@count question pinned to the recording - tap a marker to '
                  'read one.',
              '@count questions pinned to the recording - tap a marker to '
                  'read one.',
            ),
            style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
          ),
        ],
        if (general.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.wechat_rounded,
                size: 14,
                color: MainApp.mutedText,
              ),
              const SizedBox(width: 6),
              Text(
                'General questions'.tr,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: MainApp.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final question in general) ...[
            _GeneralQuestionRow(
              question: question,
              // Only whoever wrote it may take it back, as with a pinned
              // one.
              onDelete: question.isMine && !controller.isSending.value
                  ? () => controller.deleteQuestion(question)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _forwardBar(CommunitySetupController controller) {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: PulseHalo(
          active: controller.hasQuestions && !controller.isSending.value,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: MainApp.primaryGreen,
              ),
              // Nothing to test without at least one question.
              onPressed:
                  (controller.hasQuestions && !controller.isSending.value)
                  ? controller.sendToTest
                  : null,
              icon: const Icon(Icons.send, size: 18),
              label: Text(
                controller.hasQuestions
                    ? 'Send to Community Test'.tr
                    : 'Add a question first'.tr,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the two ways to add a question.
///
/// A card rather than an outlined button: these two sit under the recording
/// as the things to do with it, and reading as panels puts them on a level
/// with the cards above rather than looking like a toolbar under them.
class _AddQuestionButton extends StatelessWidget {
  const _AddQuestionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? Colors.black : MainApp.mutedText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? Colors.black : MainApp.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneralQuestionRow extends StatelessWidget {
  const _GeneralQuestionRow({required this.question, this.onDelete});

  final CommunityQuestion question;

  /// Null where the question is not this user's to delete.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MainApp.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.displayText,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              if (question.isLocal)
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 13,
                  color: Color(0xFFB45309),
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete question'.tr,
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: Color(0xFFDC2626),
                  ),
                ),
            ],
          ),
          if (question.hasAudio)
            AudioClip(
              key: ValueKey('g-${question.id}'),
              filePath: question.audioPath,
            ),
        ],
      ),
    );
  }
}

/// The page while it loads: the recording, and the two buttons for adding
/// a question as themselves - they say the same before and after. The
/// questions asked so far are usually none, and draw nothing.
class _SetupSkeleton extends StatelessWidget {
  const _SetupSkeleton({required this.banner});

  final Widget banner;

  @override
  Widget build(BuildContext context) {
    return RecordingPageSkeleton(
      children: [
        banner,
        const PlayerBones(),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: IgnorePointer(
            child: Row(
              children: [
                Expanded(
                  child: _AddQuestionButton(
                    icon: Icons.question_mark_rounded,
                    label: 'Add a question here',
                    onPressed: () {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AddQuestionButton(
                    icon: Icons.wechat_rounded,
                    label: 'Add a general question',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
