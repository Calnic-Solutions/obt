import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';
import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/stage_action_button.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/Widgets/sent_back_banner.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/recording_timer.dart';
import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/Audio/take_recorder.dart';
import 'package:livuka/Widgets/live_waveform.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/comment_button.dart';
import 'package:livuka/Widgets/mark_sheet.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/sheet_actions.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/l10n/app_locale.dart';
import 'package:livuka/services/permissions.dart';
import 'package:livuka/services/qc_service.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/work_queue.dart';

/// Writing the back translation of a Set.
class BackTranslationController extends GetxController {
  BackTranslationController(this.set);

  final WorkSet set;

  final textController = TextEditingController();
  final TakeRecorder recorder = TakeRecorder();

  final isLoading = true.obs;
  final isBusy = false.obs;

  /// Whether to say that a spot has to be chosen first.
  ///
  /// Raised by trying to write without one, not shown from the start: the
  /// instruction means something at the moment somebody wants to say
  /// something, and nothing at all before that.
  final showSpotHint = false.obs;
  final isSending = false.obs;
  final isRecording = false.obs;
  final comments = <TakeComment>[].obs;
  final audio = Rxn<SetAudio>();
  final saved = Rxn<BackTranslation>();
  final recordedPath = RxnString();
  final typed = ''.obs;

  /// Where the playhead is, so a comment can be pinned to the recording.
  String? currentLeafId;
  String currentLabel = '';
  Duration currentOffset = Duration.zero;

  @override
  void onInit() {
    super.onInit();
    textController.addListener(() => typed.value = textController.text.trim());
    AudioBus.instance.addListener(_stopIfPlaybackStarts);
    TimeTracker.instance.enter(
      stage: TimeTracker.stageOf(set.workflowStatus),
      setId: set.id,
    );
    load();
  }

  /// Ends the recording when something starts to play: a back translation
  /// spoken over the recording it translates is neither.
  void _stopIfPlaybackStarts() {
    if (!isRecording.value || AudioBus.instance.holds(recorder)) return;

    toaster(AudioBus.recordingStoppedMessage);
    unawaited(toggleRecording());
  }

  @override
  void onClose() {
    AudioBus.instance.removeListener(_stopIfPlaybackStarts);
    AudioBus.instance.release(recorder);
    textController.dispose();
    recorder.dispose();
    TimeTracker.instance.leave();
    super.onClose();
  }

  List<StageAction> get actions => WorkQueue.actionsFor(
    role: set.roleKey,
    status: set.workflowStatus,
    redoFromStage: set.redoFromStage,
  );

  /// A back translation exists once something has been written or recorded —
  /// either here and now, or on a previous visit.
  bool get hasBackTranslation =>
      typed.value.isNotEmpty ||
      recordedPath.value != null ||
      !(saved.value?.isEmpty ?? true);

  /// The merged recording has to be heard to the end before the back
  /// translation of it can go to the consultant.
  final heardMerged = false.obs;

  bool get needsListen =>
      (audio.value?.isPlayable ?? false) && !heardMerged.value;

  void markHeard() {
    heardMerged.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.merged,
    );
  }

  /// The final take of each passage, so a comment names the recording it is
  /// about and stops counting once the drafter replaces it.
  Map<String, String> _finalTakeByLeaf = const {};

  /// The same, as the take's whole row: a comment that names no take is
  /// judged against when the Final one was recorded.
  Map<String, Map<String, dynamic>> _finalRowByLeaf = const {};

  /// This stage's own open comments on the recording. They are the reason
  /// to send the Set back - and, while they stand, the reason it cannot be
  /// submitted: a back translation of a recording its translator has
  /// faulted is not one to hand a consultant.
  List<TakeComment> get ownOpen => [
    for (final comment in comments)
      if (comment.type == 'comment' &&
          comment.isOpen &&
          comment.stageKey == 'back_translation' &&
          TakeRepository.isCurrentFor(
            finalTake: _finalRowByLeaf[comment.leafKey],
            takeId: comment.takeId,
            createdAt: comment.createdAt,
          ))
        comment,
  ];

  bool get hasComments => ownOpen.isNotEmpty;

  /// What the consultant said about the last back translation, still open.
  List<TakeComment> get consultantComments => [
    for (final comment in comments)
      if (comment.type == 'comment' &&
          comment.isOpen &&
          comment.stageKey == 'consultant')
        comment,
  ];

  List<TakeComment> repliesTo(TakeComment comment) => [
    for (final reply in comments)
      if (reply.type == 'reply' && reply.parentId == comment.id) reply,
  ];

  /// Why Submit is greyed out, in the order somebody would fix it.
  String? get submitBlockedReason {
    if (needsListen) {
      return 'Play the target recording to the end before submitting.';
    }
    if (!hasBackTranslation) {
      return 'Write or record the back translation before submitting it.';
    }
    if (hasComments) {
      return 'You have open comments on the recording - send it back to the '
          'Drafter, or delete them first.';
    }
    return null;
  }

  List<SegmentMark> get marks => [
    for (final comment in ownOpen)
      if (comment.positionSeconds != null && comment.leafId.isNotEmpty)
        SegmentMark(
          id: comment.id,
          leafId: comment.leafKey,
          offsetSeconds: comment.positionSeconds!,
          color: MarkColors.comment,
          icon: Icons.wechat_rounded,
        ),
  ];

  /// Re-reads the comment just left and nothing else, so saving does not
  /// put the page back on its spinner and rebuild the recording.
  Future<void> _reloadComments() async {
    comments.value = await TakeRepository.commentsForSet(
      set.id,
      withReplies: true,
    );
  }

  Future<void> replyTo(TakeComment comment) async {
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Reply to the Consultant',
      icon: Icons.reply_rounded,
      subtitle: comment.text,
      hint: 'What would you like to say back?',
    );
    if (draft == null) return;

    isBusy.value = true;
    try {
      await TakeRepository.addCommentReply(
        setId: set.id,
        parent: comment,
        stageKey: 'back_translation',
        text: draft.text,
        audioFilePath: draft.audioPath,
      );
      await _reloadComments();
    } catch (e) {
      toaster('Could not save the reply: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> deleteComment(TakeComment comment) async {
    if (!comment.isMine) return;
    if (!await ConfirmDialog.askDeleteComment()) return;

    isBusy.value = true;
    try {
      await TakeRepository.deleteComment(commentId: comment.id, setId: set.id);
      await _reloadComments();
    } catch (e) {
      toaster('Could not delete it: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final leaves = await WorkQueue.leavesForSet(set.id);
      _finalTakeByLeaf = {
        for (final leaf in leaves)
          if (leaf.finalTake?['id'] != null)
            leaf.key: leaf.finalTake!['id'].toString(),
      };
      _finalRowByLeaf = {
        for (final leaf in leaves)
          if (leaf.finalTake != null) leaf.key: leaf.finalTake!,
      };
      await TakeRepository.resolveSupersededComments(
        setId: set.id,
        stageKey: 'back_translation',
      );
      await _reloadComments();
      audio.value = await buildSetAudio(setId: set.id, leaves: leaves);
      heardMerged.value = await ListenGate.isHeard(
        setId: set.id,
        round: set.workflowUpdatedAt,
        what: ListenGate.merged,
      );

      final existing = await TakeRepository.backTranslationFor(set.id);
      saved.value = existing;
      // A recording made on an earlier visit and not yet sent is still the
      // one in hand - it was saved the moment it stopped.
      if (existing != null && existing.isLocal && existing.hasAudio) {
        recordedPath.value = existing.audioPath;
      }
      if (existing != null && textController.text.isEmpty) {
        textController.text = existing.text;
        typed.value = existing.text;
      }
    } finally {
      isLoading.value = false;
    }
  }

  void onSegment(String leafId, String label, Duration offset) {
    if (showSpotHint.value) showSpotHint.value = false;
    currentLeafId = leafId;
    currentLabel = label;
    currentOffset = offset;
  }

  Future<void> addComment() async {
    final leafId = currentLeafId;
    if (leafId == null) {
      showSpotHint.value = true;
      return;
    }

    final at = currentOffset;
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Comment - @passage'.trParams({'passage': currentLabel}),
      icon: Icons.wechat_rounded,
      subtitle: 'At @time'.trParams({'time': _format(at)}),
      hint: 'What is wrong here?',
    );
    if (draft == null) return;

    isBusy.value = true;
    try {
      await TakeRepository.addComment(
        setId: set.id,
        // The player names the leaf by its key; the row wants the two apart.
        leafType: SetLeaf.parseKey(leafId).type,
        leafId: SetLeaf.parseKey(leafId).id,
        stageKey: 'back_translation',
        takeId: _finalTakeByLeaf[leafId],
        text: draft.text,
        audioFilePath: draft.audioPath,
        positionSeconds: at.inMilliseconds / 1000,
      );
      await _reloadComments();
    } catch (e) {
      toaster('Could not save the comment: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> toggleRecording() async {
    // Guarded end to end. Anything thrown in here used to leave the tap with
    // nothing to show for it: the recorder refusing the microphone, a path
    // that could not be made - the button simply did nothing and said
    // nothing, which reads as a dead control rather than as a failure.
    try {
      if (isRecording.value) {
        // Cleared first: the bus is watched, and must find nothing still
        // recording when it is let go of.
        isRecording.value = false;
        final path = await recorder.stop();
        AudioBus.instance.release(recorder);
        if (path != null && path.isNotEmpty) {
          recordedPath.value = path;
          // Written down now, not at Submit. Until it is in the database a
          // recording is only a path in this screen's memory, and an app
          // closed from the recents list would leave the file on disk with
          // nothing pointing at it.
          await TakeRepository.saveBackTranslation(
            setId: set.id,
            text: typed.value,
            audioFilePath: path,
          );
          // Kept all the same - it is theirs to throw away - but said,
          // because the strip and the clock look the same either way.
          if (await RecordingCheck.isSilent(path)) {
            toaster(RecordingCheck.silentMessage);
          }
        }
        return;
      }

      // A tap on the mic is a decision to speak, not to speak over
      // playback: whatever was sounding stops here.
      AudioBus.instance.claim(recorder);

      if (!await checkMicrophonePermission()) {
        if (await isMicrophoneBlocked()) {
          await openMicrophoneSettings();
        } else {
          toaster('Microphone permission is needed to record.');
        }
        return;
      }

      final directory = await UserStore.work();
      final folder = Directory(p.join(directory.path, 'back-translations'));
      await folder.create(recursive: true);

      await recorder.record(
        path: p.join(
          folder.path,
          'bt-${DateTime.now().millisecondsSinceEpoch}.wav',
        ),
      );
      isRecording.value = true;
    } catch (e) {
      debugPrint('BACK TRANSLATION RECORD FAILED: $e');
      isRecording.value = false;
      toaster('Could not start recording: @error'.trParams({'error': '$e'}));
    }
  }

  void discardRecording() => recordedPath.value = null;

  Future<void> runAction(StageAction action) async {
    // Nothing said, nothing to act on: the first tap opens the composer
    // rather than refusing outright.
    if (action.isSendBack && !hasComments) {
      await addComment();
      return;
    }

    isSending.value = true;
    final sent = await HandOff.run(
      set: set,
      action: action,
      // Saved once the question has been answered yes and before the move,
      // so it travels with the Set while the Set still accepts one.
      beforeMove: action.isSendBack
          ? null
          : () async {
              final current = saved.value;
              final unchanged =
                  current != null &&
                  current.text == typed.value &&
                  (recordedPath.value == null ||
                      current.audioPath == recordedPath.value);
              if (unchanged) return;

              await TakeRepository.saveBackTranslation(
                setId: set.id,
                text: typed.value,
                audioFilePath: recordedPath.value ?? current?.audioPath,
              );
            },
    );
    if (!sent) isSending.value = false;
  }

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
                comment.authorName.isEmpty
                    ? 'Reviewer'.tr
                    : comment.authorName.tr,
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
            // Only whoever wrote it may take it back.
            SheetActions(
              deleteLabel: 'Delete comment',
              onDelete: comment.isMine ? () => deleteComment(comment) : null,
            ),
          ],
        ),
      ),
    );
  }

  static String _format(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// The back translator's screen: hear the Set, then say it back.
class BackTranslationPage extends StatelessWidget {
  const BackTranslationPage({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<BackTranslationController>(
        init: BackTranslationController(set),
        global: false,
        // GetBuilder, not GetX: the page is built once. Typing or recording
        // a back translation redraws the composer, not the recording.
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
                      Icons.translate,
                      size: 12,
                      color: MarkColors.backTranslationAudio,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Back translation'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MarkColors.backTranslationAudio,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          body: Obx(
            () => controller.isLoading.value
                ? const RecordingPageSkeleton(questions: 1)
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

  Widget _body(BackTranslationController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // First thing on the page when the Set has come back: the reason it
        // is here again belongs above the recording, not under it.
        SentBackBanner(set: controller.set),
        // The player watches the recording and its pins, and nothing else.
        // Writing below must not rebuild it: the waveform is rebuilt with
        // the card, and the playhead with the waveform.
        Obx(
          () => MergedRecordingCard(
            audio: controller.audio.value,
            allowSeek: true,
            onSegment: controller.onSegment,
            marks: controller.marks,
            onEnded: controller.markHeard,
            mustListen: controller.needsListen,
            highlight: controller.needsListen,
            onAddMark: controller.addComment,
            addMarkLabel: 'Comment here',
            addMarkColor: MarkColors.comment,
            onMarkTap: (mark) => controller.showComment(
              controller.comments.firstWhere((c) => c.id == mark.id),
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
                    'Tap the waveform to jump to the spot you mean, then '
                            'comment there.'
                        .tr,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
        ),
        Obx(
          () => !(controller.audio.value?.isPlayable ?? false)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CommentButton(
                    label: 'Not satisfied? Comment on it',
                    onPressed: controller.isBusy.value
                        ? null
                        : controller.addComment,
                  ),
                ),
        ),
        Obx(() => _consultantComments(controller)),
        const SizedBox(height: 16),
        _Composer(controller: controller),
      ],
    );
  }

  /// What the consultant sent the back translation back for, each with the
  /// replies made to it and a way to make another.
  Widget _consultantComments(BackTranslationController controller) {
    final comments = controller.consultantComments;
    if (comments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
        border: Border.all(color: const Color(0xFFDC2626), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // The website's heading and its warning sign: this is the
              // notice that the Set has come back, and the comments under
              // it are why.
              const Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'The Consultant sent this back'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MainApp.sendBackRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Submitting a new back translation closes all of these.'.tr,
            style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
          ),
          for (final comment in comments) ...[
            const Divider(height: 22),
            if (comment.text.isNotEmpty)
              Text(comment.text, style: const TextStyle(fontSize: 14)),
            if (comment.hasAudio)
              AudioClip(
                key: ValueKey(comment.audioPath),
                filePath: comment.audioPath,
              ),
            for (final reply in controller.repliesTo(comment))
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // This arrow does not turn itself round for Urdu.
                        Transform.flip(
                          flipX: AppLocale.isRtl,
                          child: const Icon(
                            Icons.subdirectory_arrow_right,
                            size: 14,
                            color: MainApp.mutedText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reply.text.isEmpty ? 'Voice reply'.tr : reply.text,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (reply.isMine)
                          IconButton(
                            tooltip: 'Delete'.tr,
                            visualDensity: VisualDensity.compact,
                            onPressed: () => controller.deleteComment(reply),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                      ],
                    ),
                    if (reply.hasAudio)
                      AudioClip(
                        key: ValueKey(reply.audioPath),
                        filePath: reply.audioPath,
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: controller.isBusy.value
                    ? null
                    : () => controller.replyTo(comment),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: Text('Reply'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionBar(BackTranslationController controller) {
    final actions = controller.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.submitBlockedReason != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  controller.submitBlockedReason!.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
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
                  // Send back is muted until something has been said, but
                  // still opens the composer; submitting needs the back
                  // translation itself, which no tap can stand in for.
                  muted: action.isSendBack && !controller.hasComments,
                  onPressed:
                      (controller.isSending.value ||
                          (!action.isSendBack &&
                              controller.submitBlockedReason != null))
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

/// Text on one side, a recorder on the other — either will do.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller});

  final BackTranslationController controller;

  @override
  Widget build(BuildContext context) {
    // Its own Obx. Whether a recording is running, what has been recorded and
    // what was saved before are all read here, in this widget's build - which
    // runs after the page's GetX builder has returned, so that builder was
    // never told it depended on them. Tapping record started the microphone
    // and changed nothing on screen.
    return Obx(() => _card(context));
  }

  Widget _card(BuildContext context) {
    final recorded = controller.recordedPath.value;
    final existing = controller.saved.value;

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
                  'Back translation (text or voice - either is fine)'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.textController,
            maxLines: 5,
            minLines: 4,
            decoration: InputDecoration(
              hintText: 'Type the back translation...'.tr,
              border: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF9CA3AF)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (controller.isRecording.value)
            Row(
              children: [
                Expanded(
                  child: LiveWaveform(
                    recorder: controller.recorder,
                    color: MarkColors.backTranslationAudio,
                    height: 42,
                  ),
                ),
                const SizedBox(width: 10),
                const RecordingTimer(),
                PulseHalo(
                  active: true,
                  color: const Color(0xFFDC2626),
                  minSize: 34,
                  maxSize: 66,
                  child: IconButton(
                    onPressed: controller.toggleRecording,
                    icon: const Icon(
                      Icons.stop_circle,
                      size: 34,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ],
            )
          else if (recorded != null)
            Row(
              children: [
                Expanded(
                  child: AudioClip(
                    key: ValueKey(recorded),
                    filePath: recorded,
                    accent: MarkColors.backTranslationAudio,
                    title: 'Back translation',
                    header: AudioClip.label(
                      Icons.mic_rounded,
                      'Your recording',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Discard recording'.tr,
                  onPressed: controller.discardRecording,
                  icon: const Icon(Icons.delete_outline, size: 22),
                ),
              ],
            )
          else
            InkWell(
              onTap: controller.toggleRecording,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.mic, size: 30, color: Color(0xFFDC2626)),
                    const SizedBox(height: 6),
                    Text(
                      'Tap to record audio'.tr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // What was submitted before, so a returning translator can hear it
          // rather than start again from nothing.
          if (recorded == null && existing != null && existing.hasAudio) ...[
            const SizedBox(height: 12),
            AudioClip(
              key: ValueKey(existing.audioPath),
              filePath: existing.audioPath,
              accent: MarkColors.backTranslationAudio,
              title: 'Back translation',
              header: AudioClip.label(
                Icons.history_rounded,
                'Previously recorded',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
