import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/script_pair.dart';
import 'package:livuka/Widgets/stage_action_button.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/Widgets/sent_back_banner.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Audio/timeline_playback.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/mark_sheet.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/source_content_card.dart';
import 'package:livuka/Widgets/target_content_card.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/sheet_actions.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/work_queue.dart';

/// The consultant's check: the back translation against the recording.
class ConsultantController extends GetxController {
  ConsultantController(this.set);

  final WorkSet set;

  final isLoading = true.obs;
  final isBusy = false.obs;
  final isSending = false.obs;
  final comments = <TakeComment>[].obs;
  final audio = Rxn<SetAudio>();
  final backTranslation = Rxn<BackTranslation>();

  /// The passages, with what was translated: the source recording and
  /// both scripts, as the website's consultant page shows them beside the
  /// back translation.
  final leaves = <SetLeaf>[].obs;
  final sourceAudio = Rxn<SetAudio>();

  /// Which passage the script boxes show: the one playing, in either
  /// player, starting from the first.
  final activeLeaf = 0.obs;

  void onSegment(String leafId, String label, Duration offset) {
    final index = leaves.indexWhere((leaf) => leaf.key == leafId);
    if (index >= 0 && index != activeLeaf.value) activeLeaf.value = index;
  }

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

  List<StageAction> get actions => WorkQueue.actionsFor(
    role: set.roleKey,
    status: set.workflowStatus,
    redoFromStage: set.redoFromStage,
  );

  /// The consultant's own open comments on the back translation now in
  /// front of them. Anything from an earlier stage, or closed when the back
  /// translator submitted again, is history and neither blocks nor unlocks.
  List<TakeComment> get openComments => [
    for (final comment in comments)
      if (comment.type == 'comment' &&
          comment.isOpen &&
          comment.stageKey == 'consultant')
        comment,
  ];

  /// When the back translation before this one was written; see
  /// [TakeRepository.previousBackTranslationAt].
  final previousRoundAt = RxnString();

  /// What is listed under the back translation: every comment of the
  /// Consultant's from the round that led to it, open or closed, so that
  /// what the Back Translator said back can be read beside what it
  /// answers. The back translator's new submission closes the comment it
  /// answers, and listing the open ones alone lost the reply with it.
  List<TakeComment> get shownComments {
    final since = previousRoundAt.value;
    return [
      for (final comment in comments)
        if (comment.type == 'comment' &&
            comment.stageKey == 'consultant' &&
            (since == null || TakeRepository.isSince(comment.createdAt, since)))
          comment,
    ];
  }

  List<TakeComment> repliesTo(TakeComment comment) => [
    for (final reply in comments)
      if (reply.type == 'reply' && reply.parentId == comment.id) reply,
  ];

  bool get hasComments => openComments.isNotEmpty;

  /// Where the back translation is paused, in either player. A comment is
  /// pinned here, as the website pins it at the player's current time.
  Duration btPosition = Duration.zero;

  void onBtPosition(Duration position) => btPosition = position;

  /// The open comments as pins on the back translation's waveform: one
  /// per comment with a spot, in the comment red, the chat bubble the
  /// website uses. Tapping one opens the comment.
  List<ClipMark> get marks => [
    for (final comment in openComments)
      if (comment.positionSeconds != null)
        ClipMark(
          id: comment.id,
          positionSeconds: comment.positionSeconds!,
          color: MarkColors.comment,
          icon: Icons.wechat_rounded,
        ),
  ];

  /// One comment, opened from its pin: who left it and where, what it
  /// says, and - for the consultant's own - the way to take it back.
  void showComment(TakeComment comment) {
    showAppSheet(
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                comment.authorName.isEmpty ? 'You'.tr : comment.authorName.tr,
                if (comment.positionLabel.isNotEmpty) comment.positionLabel,
              ].join(' · '),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MainApp.mutedText,
              ),
            ),
            const SizedBox(height: 10),
            if (comment.text.isNotEmpty)
              Text(comment.text, style: const TextStyle(fontSize: 14)),
            if (comment.hasAudio) AudioClip(filePath: comment.audioPath),
            SheetActions(
              deleteLabel: 'Delete comment',
              onDelete: comment.isMine
                  ? () {
                      Get.back();
                      deleteComment(comment);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Whether the back translation recording has been played to the end.
  final heardBackTranslation = false.obs;

  /// Only a RECORDED back translation can be listened to. One that was typed
  /// has nothing to play, so there is nothing to wait for.
  bool get needsListen =>
      (backTranslation.value?.hasAudio ?? false) && !heardBackTranslation.value;

  /// A different recording is a different thing to have heard, so the mark
  /// is filed under the back translation it was made against.
  String get _gateKey =>
      '${ListenGate.backTranslation}:${backTranslation.value?.id ?? ''}';

  void markHeard() {
    heardBackTranslation.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: _gateKey,
    );
  }

  /// Why Approve is greyed out.
  String? get approveBlockedReason {
    final bt = backTranslation.value;
    if (bt == null || bt.isEmpty) {
      return 'There is no back translation to approve yet.';
    }
    if (needsListen) {
      return 'Play the back translation recording to the end before '
          'approving.';
    }
    if (hasComments) {
      return 'An open comment blocks Approve. Delete it, or send the Set '
          'back to the Back Translator.';
    }
    return null;
  }

  /// Re-reads the comment just left and nothing else, so saving does not
  /// put the page back on its spinner and rebuild the recording.
  Future<void> _reloadComments() async {
    comments.value = await TakeRepository.commentsForSet(
      set.id,
      withReplies: true,
    );
  }

  Future<void> deleteComment(TakeComment comment) async {
    if (!comment.isMine) return;
    if (!await ConfirmDialog.askDeleteComment()) return;

    isBusy.value = true;
    try {
      await TakeRepository.deleteComment(commentId: comment.id, setId: set.id);
      await _reloadComments();
    } catch (e) {
      toaster('Could not delete the comment: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final leaves = await WorkQueue.leavesForSet(set.id);
      this.leaves.value = leaves;
      if (activeLeaf.value >= leaves.length) activeLeaf.value = 0;
      await _reloadComments();
      audio.value = await buildSetAudio(setId: set.id, leaves: leaves);
      sourceAudio.value = await buildSourceAudio(leaves: leaves);
      backTranslation.value = await TakeRepository.backTranslationFor(set.id);
      previousRoundAt.value = await TakeRepository.previousBackTranslationAt(
        set.id,
      );
      heardBackTranslation.value = await ListenGate.isHeard(
        setId: set.id,
        round: set.workflowUpdatedAt,
        what: _gateKey,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// A comment on the back translation, pinned where its recording is
  /// paused - as the website pins it at the player's current time - so
  /// it shows on the waveform and can be opened from there. With no
  /// recording there is no spot, and the comment stands on its own.
  Future<void> addComment() async {
    final bt = backTranslation.value;
    final at = bt != null && bt.hasAudio ? btPosition : null;
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Comment on the back translation',
      icon: Icons.wechat_rounded,
      subtitle: at == null
          ? ''
          : 'At @time'.trParams({'time': TimelinePlayback.format(at)}),
      hint: 'What does not match?',
    );
    if (draft == null) return;

    isBusy.value = true;
    try {
      await TakeRepository.addComment(
        setId: set.id,
        leafType: '',
        leafId: '',
        stageKey: 'consultant',
        text: draft.text,
        audioFilePath: draft.audioPath,
        positionSeconds: at == null ? null : at.inMilliseconds / 1000,
      );
      await _reloadComments();
    } catch (e) {
      toaster('Could not save the comment: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> runAction(StageAction action) async {
    // Nothing said, nothing to act on: the first tap opens the composer.
    if (action.isSendBack && !hasComments) {
      await addComment();
      return;
    }
    if (!action.isSendBack && approveBlockedReason != null) return;

    isSending.value = true;
    final sent = await HandOff.run(set: set, action: action);
    if (!sent) isSending.value = false;
  }
}

/// The consultant screen: what the back translator wrote, and the reading it
/// claims to render.
class ConsultantPage extends StatelessWidget {
  const ConsultantPage({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<ConsultantController>(
        init: ConsultantController(set),
        global: false,
        // GetBuilder, not GetX: the page is built once. Leaving a comment
        // redraws the comments, and leaves the recording alone.
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
                      Icons.how_to_reg_outlined,
                      size: 12,
                      color: Color(0xFF1E8E3E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Consultant check'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF1E8E3E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Obx(
            () => controller.isLoading.value
                ? _ConsultantSkeleton(
                    banner: SentBackBanner(set: controller.set),
                  )
                : _body(context, controller),
          ),
          bottomNavigationBar: Obx(
            () => controller.isLoading.value
                ? StageBarBones(
                    buttons: controller.actions.length,
                    reasonLines: 1,
                    buttonHeight: 56,
                  )
                : _actionBar(controller),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ConsultantController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        SentBackBanner(set: controller.set),
        // The back translation leads: it is what the consultant is checking,
        // and the recording below is what it claims to say.
        _BackTranslationCard(controller: controller),
        const SizedBox(height: 12),
        // The player watches the recording alone. A comment written below
        // must not rebuild it, or the waveform is rebuilt with it.
        Obx(
          () => MergedRecordingCard(
            audio: controller.audio.value,
            allowSeek: true,
            onSegment: controller.onSegment,
          ),
        ),
        Obx(() => _comments(controller)),
        // What was translated, under what it became: the source script
        // and recording, then the target script, one passage at a time -
        // the passage now playing in either player.
        const SizedBox(height: 12),
        // Upright: source script, source audio, target script. On a phone
        // on its side the two scripts share one row and the recording
        // follows them.
        if (ScriptPair.sideBySide(context)) ...[
          ScriptPair(
            gap: 12,
            source: Obx(
              () => SourceContentCard(
                leaves: controller.leaves.toList(),
                active: controller.activeLeaf.value,
                audio: null,
                showAudio: false,
              ),
            ),
            target: Obx(
              () => TargetContentCard(
                leaves: controller.leaves.toList(),
                active: controller.activeLeaf.value,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sourceAudio(controller),
        ] else ...[
          Obx(
            () => SourceContentCard(
              leaves: controller.leaves.toList(),
              active: controller.activeLeaf.value,
              audio: null,
              showAudio: false,
            ),
          ),
          const SizedBox(height: 12),
          _sourceAudio(controller),
          const SizedBox(height: 12),
          Obx(
            () => TargetContentCard(
              leaves: controller.leaves.toList(),
              active: controller.activeLeaf.value,
            ),
          ),
        ],
      ],
    );
  }

  Widget _sourceAudio(ConsultantController controller) => Obx(
    () => MergedRecordingCard(
      title: 'Source audio',
      icon: Icons.volume_up_rounded,
      audio: controller.sourceAudio.value,
      allowSeek: true,
      onSegment: controller.onSegment,
    ),
  );

  /// What the consultant has said so far.
  Widget _comments(ConsultantController controller) {
    final shown = controller.shownComments;
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      // Stretch, because these were list children before they were lifted
      // into a Column: a ListView gives every child the full width, and a
      // Column would otherwise shrink each card to its own content.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Your comments'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final comment in shown) ...[
          _CommentCard(
            comment: comment,
            replies: controller.repliesTo(comment),
            onDelete: comment.isMine && !controller.isBusy.value
                ? () => controller.deleteComment(comment)
                : null,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _actionBar(ConsultantController controller) {
    final actions = controller.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                (controller.approveBlockedReason ??
                        'Comment on the back translation to send it back.')
                    .tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
              ),
            ),
            for (final action in actions) ...[
              SizedBox(
                width: double.infinity,
                child: StageActionButton(
                  label: action.label,
                  icon: action.isSendBack
                      ? Icons.rotate_left
                      : Icons.check_circle_outline,
                  sendBack: action.isSendBack,
                  // Nothing said yet, so the send-back is offered rather than
                  // ready: pressing it is what opens the composer.
                  muted: action.isSendBack && !controller.hasComments,
                  highlight:
                      !action.isSendBack &&
                      !controller.isSending.value &&
                      controller.approveBlockedReason == null,
                  onPressed:
                      controller.isSending.value ||
                          (!action.isSendBack &&
                              controller.approveBlockedReason != null)
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

class _BackTranslationCard extends StatelessWidget {
  const _BackTranslationCard({required this.controller});

  final ConsultantController controller;

  @override
  Widget build(BuildContext context) {
    // Its own Obx: the reads below happen in this widget's build, after the
    // page's builder has returned, so nothing else is watching them.
    return Obx(() => _card(context));
  }

  Widget _card(BuildContext context) {
    final bt = controller.backTranslation.value;

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
          Row(
            children: [
              const Icon(
                Icons.translate,
                size: 15,
                color: MarkColors.backTranslationAudio,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Back translation'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Comment on the back translation'.tr,
                onPressed: controller.isBusy.value
                    ? null
                    : controller.addComment,
                // The comment red, as the website's button turns.
                icon: const Icon(
                  Icons.wechat_rounded,
                  size: 20,
                  color: MarkColors.comment,
                ),
              ),
            ],
          ),
          if (bt == null || bt.isEmpty)
            Text(
              'The back translator has not submitted one yet.'.tr,
              style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
            )
          else ...[
            if (bt.text.isNotEmpty)
              Text(bt.text, style: const TextStyle(fontSize: 14, height: 1.5)),
            if (bt.hasAudio) ...[
              const SizedBox(height: 8),
              AudioClip(
                key: ValueKey(bt.audioPath),
                filePath: bt.audioPath,
                allowSeek: true,
                accent: MarkColors.backTranslationAudio,
                title: 'Back translation',
                header: AudioClip.label(Icons.translate, 'Back translation'),
                onEnded: controller.markHeard,
                mustListen: controller.needsListen,
                highlight: controller.needsListen,
                // Where the recording is paused, from either player: the
                // spot a new comment is pinned to.
                onPosition: controller.onBtPosition,
                // The open comments, pinned where they were left; a tap
                // opens one.
                marks: controller.marks,
                onMarkTap: (mark) => controller.showComment(
                  controller.openComments.firstWhere(
                    (comment) => comment.id == mark.id,
                  ),
                ),
                // The same comment as the button in the title row, offered
                // in the full-screen player too - as the web's full-wave
                // popup does for this recording, in the comment red.
                onAddMark: controller.isBusy.value
                    ? null
                    : controller.addComment,
                addMarkLabel: 'Comment on the back translation',
                addMarkColor: MarkColors.comment,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    this.replies = const [],
    this.onDelete,
  });

  final TakeComment comment;

  /// What the back translator said back.
  final List<TakeComment> replies;

  /// Null for a comment somebody else wrote: only the author may delete.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    // Red while it stands, grey once the back translator has answered it
    // with a new back translation - as the website draws them.
    final tint = comment.isOpen
        ? const Color(0xFFDC2626)
        : const Color(0xFF4B4870);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                comment.isOpen
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                size: 14,
                color: tint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  comment.authorName.isEmpty ? 'You'.tr : comment.authorName.tr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: tint,
                  ),
                ),
              ),
              if (comment.isLocal)
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 13,
                  color: Color(0xFFB45309),
                ),
            ],
          ),
          if (comment.text.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              comment.text,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
          if (comment.hasAudio)
            AudioClip(
              key: ValueKey('c-${comment.id}'),
              filePath: comment.audioPath,
            ),
          for (final reply in replies)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 14, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reply.authorName.isEmpty
                        ? 'Back Translator'.tr
                        : reply.authorName.tr,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  if (reply.text.isNotEmpty)
                    Text(reply.text, style: const TextStyle(fontSize: 13)),
                  if (reply.hasAudio)
                    AudioClip(
                      key: ValueKey('r-${reply.id}'),
                      filePath: reply.audioPath,
                    ),
                ],
              ),
            ),
          if (onDelete != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
                label: Text(
                  'Delete'.tr,
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The page while it loads, in the page's order and with its landscape
/// rule: the back translation, the recording, then the source script, the
/// source audio and the target script.
class _ConsultantSkeleton extends StatelessWidget {
  const _ConsultantSkeleton({required this.banner});

  final Widget banner;

  @override
  Widget build(BuildContext context) {
    return RecordingPageSkeleton(
      children: [
        banner,
        const _BackTranslationCardBones(),
        const SizedBox(height: 12),
        const PlayerBones(),
        const SizedBox(height: 12),
        if (ScriptPair.sideBySide(context)) ...[
          const ScriptPair(
            gap: 12,
            source: ScriptBones.source(),
            target: ScriptBones.target(),
          ),
          const SizedBox(height: 12),
          const PlayerBones.source(),
        ] else ...[
          const ScriptBones.source(),
          const SizedBox(height: 12),
          const PlayerBones.source(),
          const SizedBox(height: 12),
          const ScriptBones.target(lines: 5),
        ],
      ],
    );
  }
}

/// [_BackTranslationCard] while it loads: its heading and comment button
/// as themselves, the back translation as lines of its own size.
class _BackTranslationCardBones extends StatelessWidget {
  const _BackTranslationCardBones();

  @override
  Widget build(BuildContext context) {
    return BoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.translate,
                size: 15,
                color: MarkColors.backTranslationAudio,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Back translation'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IgnorePointer(
                child: IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.wechat_rounded,
                    size: 20,
                    color: MarkColors.comment,
                  ),
                ),
              ),
            ],
          ),
          const BoneParagraph(
            lines: 3,
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
