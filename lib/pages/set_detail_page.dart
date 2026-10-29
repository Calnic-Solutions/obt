import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/script_pair.dart';
import 'package:livuka/Widgets/stage_action_button.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/l10n/plural.dart';
import 'package:livuka/Widgets/sent_back_banner.dart';
import 'package:livuka/Widgets/target_content_card.dart';
import 'package:livuka/Widgets/source_content_card.dart';
import 'package:livuka/Widgets/scrolling_title.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/comment_button.dart';
import 'package:livuka/Widgets/continuous_player.dart';
import 'package:livuka/Widgets/mark_sheet.dart';
import 'package:livuka/Widgets/merged_recording.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/Widgets/sheet_actions.dart';
import 'package:livuka/main.dart';
import 'package:livuka/pages/leaf_recorder_page.dart';
import 'package:livuka/services/hand_off.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/work_queue.dart';

/// Loads a Set's passages and its draft audio, and moves the Set on.
class SetDetailController extends GetxController {
  SetDetailController(this.set);

  final WorkSet set;

  final isLoading = true.obs;
  final isSending = false.obs;
  final isBusy = false.obs;
  final leaves = <SetLeaf>[].obs;
  final comments = <TakeComment>[].obs;

  /// Dislikes on general questions - the ones about the Set as a whole,
  /// which no passage's take can carry. Listed under the banner while
  /// the Set is back from Community Review, as on the website's Set page.
  final generalFeedback = <CommunityQuestion>[].obs;
  final audio = Rxn<SetAudio>();
  final sourceAudio = Rxn<SetAudio>();

  /// A reviewer has to hear both readings end to end before deciding. The
  /// job is the comparison, and a verdict reached without listening is the
  /// one thing this stage exists to prevent.
  final heardSource = false.obs;
  final heardMerged = false.obs;

  /// Why the Set could not be read, if it could not.
  final loadError = RxnString();

  /// Where the playhead is, as a passage and an offset inside it, so a note
  /// can be pinned without the screen doing the arithmetic.
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

  Future<void> load() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      leaves.value = await WorkQueue.leavesForSet(set.id);
      if (activeLeaf.value >= leaves.length) activeLeaf.value = 0;
      // Before reading them: a comment about a take since replaced is
      // closed on the way in, as the website does on every visit.
      if (isReviewer) {
        await TakeRepository.resolveSupersededComments(
          setId: set.id,
          stageKey: set.workflowStatus,
        );
      }
      comments.value = await TakeRepository.commentsForSet(set.id);
      generalFeedback.value =
          set.workflowStatus == 'redo' &&
              set.redoFromStage == 'community_review'
          ? [
              for (final question in await TakeRepository.disputedQuestionsFor(
                setId: set.id,
                leafLabels: const {},
              ))
                if (question.isGeneral) question,
            ]
          : const [];
      // Kept on the phone and filed under this round of the Set, so stepping
      // into a passage and back does not cost a second listen - and a Set
      // that comes round again starts unheard.
      heardSource.value = await ListenGate.isHeard(
        setId: set.id,
        round: set.workflowUpdatedAt,
        what: ListenGate.source,
      );
      heardMerged.value = await _mergedStillHeard();
      audio.value = hasMergedDraft
          ? await buildSetAudio(setId: set.id, leaves: leaves)
          : null;
      sourceAudio.value = isReviewer && showsSourceAudio
          ? await buildSourceAudio(leaves: leaves)
          : null;
    } catch (e, stack) {
      // Anything thrown here used to leave the screen on its spinner with no
      // way to tell what went wrong. The reason is worth showing: it is the
      // difference between "this Set is empty" and "this build is broken".
      debugPrint('SET DETAIL LOAD ERROR (${set.id}): $e');
      debugPrint('$stack');
      loadError.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  /// What the merged draft is made of right now: the final take of every
  /// passage, in order. A drafter who swaps one after listening is holding a
  /// recording nobody has heard, and the mark must not carry over to it.
  String get _mergedKey =>
      '${ListenGate.merged}:'
      '${leaves.map((leaf) => leaf.finalTake?['id'] ?? '-').join(',')}';

  Future<bool> _mergedStillHeard() => ListenGate.isHeard(
    setId: set.id,
    round: set.workflowUpdatedAt,
    what: _mergedKey,
  );

  void markSourceHeard() {
    heardSource.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.source,
    );
  }

  void markMergedHeard() {
    heardMerged.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: _mergedKey,
    );
  }

  /// The merged draft exists once there is a whole reading to hear.
  ///
  /// Part way through drafting there is nothing to play end to end and the
  /// player would only report that it found nothing. But a drafter who has
  /// finalized every passage has exactly what the next stage will receive,
  /// and ought to hear it before sending it - so the player appears at the
  /// Draft stage too, on the last take rather than after the hand-off.
  bool get hasMergedDraft {
    // Both of the drafter's recording stages. A Set sent back has had the
    // faulted passages' finals cleared, and playing the rest as "the merged
    // draft" would offer a reading with holes in it to listen through.
    final drafting = const {
      'not_started',
      'recorded',
      'redo',
    }.contains(set.workflowStatus);
    return !drafting || (leaves.isNotEmpty && missing == 0);
  }

  /// Whether the merged draft can actually be played. A Set whose audio will
  /// not load must not leave the drafter holding a button that can never
  /// light up.
  bool get mergedPlayable => audio.value?.isPlayable ?? false;

  /// Notes are what a reviewer leaves for the drafter. The drafter holding
  /// the Set has nobody to leave them for — anything wrong they simply
  /// re-record — so the merged draft is theirs to listen to, not annotate.
  bool get canAddNotes => set.roleKey != 'drafter';

  /// Anyone holding the Set who is not its drafter is reviewing it: peer
  /// check, community review, back translation, consultant.
  bool get isReviewer => set.roleKey != 'drafter';

  /// Only the drafter and the peer work against the source recording, so
  /// only they are shown it - and only for them is it downloaded. Offering a
  /// consultant a player for a file this device deliberately skipped would
  /// be a dead control.
  bool get showsSourceAudio =>
      set.roleKey == 'drafter' || set.roleKey == 'peer';

  /// Whether the source recording still has to be heard right through:
  /// the Peer's, once per round of the Set.
  bool get sourceListenOwed => isReviewer && !heardSource.value;

  /// Whether the target recording still has to be heard right through
  /// before this Set can be sent on. Not on a finished Set, which is sent
  /// nowhere, and not once it has been heard.
  bool get mergedListenOwed =>
      !isFinished && actions.isNotEmpty && !heardMerged.value;

  /// Whether the recordings this stage turns on have been heard right
  /// through. A reviewer compares two readings and cannot judge without
  /// hearing both. A drafter has one - the merged draft - and sending a Set
  /// on without listening to it is how a bad join reaches peer check.
  /// Whether the source audio has been heard through, or there is none
  /// to hear.
  bool get sourceHeardOrAbsent =>
      heardSource.value ||
      !(showsSourceAudio && leaves.any((leaf) => leaf.hasSourceAudio));

  bool get listenDone {
    if (isReviewer) {
      // The source is only owed a hearing where there is one, as on the
      // website: a Set none of whose passages has source audio has no
      // player to finish, and asking for it held the Set at this stage
      // with no way on.
      final sourceOwed =
          showsSourceAudio && leaves.any((leaf) => leaf.hasSourceAudio);
      return (!sourceOwed || heardSource.value) && heardMerged.value;
    }
    if (!hasMergedDraft || !mergedPlayable) return true;
    return heardMerged.value;
  }

  /// Whether anything still stands against the recording. Sending a Set back
  /// with no open comment leaves the drafter guessing at what to change - and
  /// a comment on a take the drafter has since replaced has been answered by
  /// the new take, so it no longer counts as something to send back for.
  bool get hasComments => comments.any(_stillStands);

  bool _stillStands(TakeComment comment) {
    if (!comment.isOpen) return false;
    // This stage's own. A consultant's old comment on the same Set is not a
    // reason for the peer to send it back, nor a bar to sending it on.
    if (comment.stageKey != set.workflowStatus) return false;

    // A comment with no passage is about the Set as a whole.
    if (comment.leafId.isEmpty) return true;

    for (final leaf in leaves) {
      if (leaf.key != comment.leafKey) continue;
      // By the take it names, or - for one made on the website before takes
      // were named - by whether the Final take was recorded after it.
      return TakeRepository.isCurrentFor(
        finalTake: leaf.finalTake,
        takeId: comment.takeId,
        createdAt: comment.createdAt,
      );
    }
    return false;
  }

  /// A reviewer sends back BECAUSE of an open comment and cannot send on
  /// while one stands - the website refuses both the same way. Delete the
  /// comment or send the Set back; there is no third way out.
  ///
  /// Listening gates the way FORWARD only. Sending back has no listen
  /// requirement at all, as on the website: having just left a comment is
  /// already proof the reviewer heard what they are flagging, and making
  /// them sit through the rest of a recording they have decided to return
  /// is a step with nothing behind it. A fault in the first ten seconds of a
  /// twenty-minute Set should cost ten seconds to send back.
  bool canRun(StageAction action) {
    if (!isReviewer) return listenDone;
    if (action.isSendBack) return hasComments;
    return listenDone && !hasComments;
  }

  /// What is holding the buttons, in the order somebody would deal with it.
  String? get blockedReason {
    if (!isReviewer) {
      return listenDone
          ? null
          : 'Play the target recording to the end before sending it on.';
    }
    // An open comment decides it whatever has been heard: the Set can only
    // go back now, and that is already available.
    if (hasComments) {
      return 'An open comment blocks sending this on. Delete it, or send the '
          'Set back to the Drafter.';
    }
    if (!listenDone) {
      return 'Play both recordings to the end to send this on - or leave a '
          'comment to send it back.';
    }
    return 'Leave a comment on the recording to send it back.';
  }

  /// A finished Set is a record, not a worklist: nothing can be opened or
  /// changed, so the passages are not listed and the page is just the
  /// recording and a way to keep it.
  bool get isFinished => set.workflowStatus == 'approved';

  int get done => leaves.where((leaf) => leaf.hasFinal).length;
  int get missing => leaves.length - done;

  List<StageAction> get actions => WorkQueue.actionsFor(
    role: set.roleKey,
    status: set.workflowStatus,
    redoFromStage: set.redoFromStage,
  );

  /// Open notes on passages that are not finalized yet, drawn on the merged
  /// waveform. A resolved mark is dealt with, and a finalized passage has
  /// answered whatever was raised on it — pinning either would cover the
  /// recording in marks that need nothing.
  List<SegmentMark> get marks => [
    for (final comment in comments)
      if (comment.positionSeconds != null &&
          comment.leafId.isNotEmpty &&
          (isReviewer ? _stillStands(comment) : comment.isOpen) &&
          (isReviewer || !_isFinalized(comment.leafKey)))
        SegmentMark(
          id: comment.id,
          leafId: comment.leafKey,
          offsetSeconds: comment.positionSeconds!,
          // Every pin here is open now, so they are all the one colour.
          color: MarkColors.comment,
          icon: Icons.wechat_rounded,
        ),
  ];

  bool _isFinalized(String leafId) =>
      leaves.any((leaf) => leaf.key == leafId && leaf.hasFinal);

  /// Which passage the two script boxes are showing, as a place in
  /// [leaves]. One passage at a time and the same one in both, as on the
  /// website's Peer Check: it starts at the first and goes to whichever is
  /// playing, in either player, so reading along never means finding the
  /// place by hand.
  final activeLeaf = 0.obs;

  void _showLeaf(String leafId) {
    final index = leaves.indexWhere((leaf) => leaf.key == leafId);
    if (index >= 0 && index != activeLeaf.value) activeLeaf.value = index;
  }

  void onSegment(String leafId, String label, Duration offset) {
    currentLeafId = leafId;
    currentLabel = label;
    currentOffset = offset;
    _showLeaf(leafId);
  }

  /// The source player's passage. It moves the scripts and nothing else:
  /// where a note is pinned is the merged recording's playhead, and the
  /// source has no say in that.
  void onSourceSegment(String leafId, String label, Duration offset) =>
      _showLeaf(leafId);

  Future<void> openLeaf(SetLeaf leaf) async {
    // The whole list goes with it, and where in the list to start. The
    // recorder steps between passages itself, so this route is pushed once
    // for a walk through the Set rather than once per passage - which is
    // what makes the arrows at either end land back here.
    final index = leaves.indexWhere((candidate) => candidate.key == leaf.key);

    await Get.to(
      () => LeafRecorderPage(
        set: set,
        leaves: leaves.toList(),
        startIndex: index < 0 ? 0 : index,
        // A sent-back Set opens each passage on its takes, as the website
        // does: what the reviewer objected to is a take, and the drafter
        // needs to hear it before deciding what to do about it. A first
        // pass opens on the recorder, there being nothing to look at yet.
        startOnTakes: set.workflowStatus == 'redo',
      ),
    );
    await load();
  }

  /// Leaves a note at the spot now playing, the way the web pins one from the
  /// merged player rather than from inside a passage.
  Future<void> addNote() async {
    final leafId = currentLeafId;
    if (leafId == null) {
      toaster('Play the recording first, then leave a note there.');
      return;
    }

    final at = currentOffset;
    final draft = await MarkSheet.show(
      Get.context!,
      title: 'Note - @passage'.trParams({'passage': currentLabel}),
      subtitle: 'At @time'.trParams({'time': formatDuration(at)}),
      hint: 'What needs to change here?',
    );
    if (draft == null) return;

    isBusy.value = true;
    try {
      await TakeRepository.addComment(
        setId: set.id,
        // The player names the leaf by its key; the row wants the two apart.
        leafType: SetLeaf.parseKey(leafId).type,
        leafId: SetLeaf.parseKey(leafId).id,
        stageKey: set.workflowStatus,
        text: draft.text,
        audioFilePath: draft.audioPath,
        // The take being heard, so the comment can stop counting once the
        // drafter has recorded over it.
        takeId: leaves
            .firstWhereOrNull((leaf) => leaf.key == leafId)
            ?.finalTake?['id']
            ?.toString(),
        positionSeconds: at.inMilliseconds / 1000,
      );
      await load();
    } catch (e) {
      toaster('Could not save the note: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  void showNote(TakeComment comment) {
    showAppSheet(
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Only open marks are pinned, so this is only ever reached
                // for one that still needs work.
                const Icon(
                  Icons.error_outline,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Text(
                  [
                    comment.authorName.isEmpty
                        ? 'Reviewer'.tr
                        // The user's own rows are stamped 'You'; a real name
                        // has no translation and comes back as it is.
                        : comment.authorName.tr,
                    if (comment.positionLabel.isNotEmpty) comment.positionLabel,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MainApp.mutedText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(comment.text, style: const TextStyle(fontSize: 14)),
            if (comment.hasAudio) AudioClip(filePath: comment.audioPath),
            const SizedBox(height: 6),
            // Only whoever wrote it may take it back.
            SheetActions(
              deleteLabel: 'Delete comment',
              onDelete: comment.isMine ? () => deleteNote(comment) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteNote(TakeComment comment) async {
    if (!await ConfirmDialog.askDeleteComment()) return;

    isBusy.value = true;
    try {
      await TakeRepository.deleteComment(commentId: comment.id, setId: set.id);
      await load();
    } catch (e) {
      toaster('Could not delete the comment: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }

  /// Moving the Set on is queued like any other write, so a Set can be
  /// finished in the field and the hand-off lands when the device next has
  /// signal.
  Future<void> runAction(StageAction action) async {
    isSending.value = true;
    final sent = await HandOff.run(set: set, action: action);
    if (!sent) isSending.value = false;
  }

  static String formatDuration(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// The passages inside one Set, the draft heard end to end, and the way on.
///
/// The passages are listed down the page, with the merged draft below them.
/// A drafter working through a sent-back Set listens to the whole reading and
/// pins notes where it is wrong, rather than opening each passage in turn to
/// find out which one is.
class SetDetailPage extends StatelessWidget {
  const SetDetailPage({super.key, required this.set, this.passages});

  final WorkSet set;

  /// How many passages the Set has, when the queue already counted them -
  /// so the page is drawn with that many while it loads.
  final int? passages;

  @override
  Widget build(BuildContext context) {
    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<SetDetailController>(
        // Page-scoped: created with this route and disposed with it, so opening
        // another Set never reuses this one's state.
        init: SetDetailController(set),
        global: false,
        // GetBuilder, not GetX: the page is built once. Each piece below
        // watches what it shows, so finishing the source recording does not
        // rebuild the merged player halfway through it.
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
                    fontSize: 16,
                  ),
                ),
                if (set.subtitle.isNotEmpty)
                  Text(
                    set.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: MainApp.mutedText,
                    ),
                  ),
              ],
            ),
          ),
          body: Obx(
            () => controller.isLoading.value
                ? _SetDetailSkeleton(controller: controller, passages: passages)
                : Stack(
                    children: [
                      Obx(() => _body(controller)),
                      // The dim is its own layer, so putting it up does not
                      // rebuild the page underneath it. Positioned on the
                      // outside, so what the Obx returns can never change
                      // how the Stack sizes itself.
                      Positioned.fill(
                        child: Obx(
                          () => !controller.isBusy.value
                              ? const SizedBox.shrink()
                              : const ColoredBox(
                                  color: Color(0x33000000),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
          bottomNavigationBar: Obx(
            // The bar's room is held while loading: appearing afterwards, it
            // shortened the page under it and moved everything up a bar.
            () => controller.isLoading.value
                ? _ActionBarBones(
                    count: controller.actions.length,
                    // A reviewer is always told what stands in the way.
                    reason: controller.isReviewer,
                  )
                : _actionBar(controller),
          ),
        ),
      ),
    );
  }

  Widget _body(SetDetailController controller) {
    final error = controller.loadError.value;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 40,
                color: Color(0xFFB45309),
              ),
              const SizedBox(height: 12),
              Text(
                'This set could not be opened.'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: controller.load,
                child: Text('Try again'.tr),
              ),
            ],
          ),
        ),
      );
    }

    final leaves = controller.leaves;
    if (leaves.isEmpty) {
      return Center(child: Text('No passages in this set yet.'.tr));
    }

    // Peer check is a comparison: two texts to read against two recordings
    // to hear. Scrolling all four as one page meant the player a reviewer was
    // listening to slid off the top as they read down the script, and the
    // place to leave a comment was somewhere below that again. So only the
    // texts scroll. The recordings, and what can be done about them, stay
    // put at the foot of the screen with the script moving behind them.
    if (controller.isReviewer && controller.showsSourceAudio) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // A phone on its side has no room to pin the players under two
          // script frames: the whole page scrolls instead, scripts first,
          // recordings after.
          if (constraints.maxHeight < 480) {
            return _reviewerScrolling(controller);
          }
          return _reviewerPinned(context, controller);
        },
      );
    }

    // Laid out once. Each row below opens its own window on the controller,
    // so a note being written, a download starting, or a recording reaching
    // its end redraws that row alone.
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 20),
      children: [
        Obx(() => _missingNotice(controller)),

        // Why the Set is here a second time. Under the warning about what is
        // still missing, because that is what to do next; this is why.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SentBackBanner(set: controller.set),
        ),
        Obx(() => _generalFeedback(controller)),

        Obx(() => _passages(controller)),
        const SizedBox(height: 10),
        Obx(() => _listenNotice(controller)),
        Obx(() => _mergedPlayer(controller)),
        Obx(() => _mergedActions(controller)),
      ],
    );
  }

  /// The two recordings a reviewer hears, in the order they are heard.
  List<Widget> _reviewerPlayers(SetDetailController controller) => [
    Obx(
      () => MergedRecordingCard(
        title: 'Source audio',
        icon: Icons.volume_up_rounded,
        audio: controller.sourceAudio.value,
        allowSeek: true,
        flat: true,
        onEnded: controller.markSourceHeard,
        mustListen: controller.sourceListenOwed,
        onSegment: controller.onSourceSegment,
        // First the source, then the recording made from it.
        highlight: !controller.sourceHeardOrAbsent,
      ),
    ),
    // The draft and the button that comments on it are one thing, so they
    // share a box.
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() => _mergedPlayer(controller, flat: true)),
        Obx(() => _mergedActions(controller, flat: true)),
      ],
    ),
  ];

  Widget _reviewerScrolling(SetDetailController controller) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      children: [
        SentBackBanner(set: controller.set),
        // Side by side with the phone on its side, stacked upright.
        ScriptPair(
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
        const SizedBox(height: 10),
        for (final player in _reviewerPlayers(controller)) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: MainApp.cardShadow,
            ),
            child: player,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _reviewerPinned(BuildContext context, SetDetailController controller) {
    // A tablet on its side: the two frames share one row, each the full
    // height left under the banner, as the drafter's screen lays them out.
    if (ScriptPair.sideBySide(context)) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Column(
                children: [
                  SentBackBanner(set: controller.set),
                  Expanded(
                    child: Obx(() {
                      final leaves = controller.leaves.toList();
                      final active = controller.activeLeaf.value;
                      final hasTarget = leaves.any((l) => l.hasTargetScript);
                      return ScriptPair(
                        stretch: true,
                        source: _ScriptFrame(
                          passage: active,
                          builder: (scroll) => SourceContentCard(
                            leaves: leaves,
                            active: active,
                            audio: null,
                            showAudio: false,
                            flat: true,
                            scroll: scroll,
                          ),
                        ),
                        // The same frame as the source when there is a
                        // script to read; the short card saying there is
                        // none, at the top of its half, when there is not.
                        target: hasTarget
                            ? _ScriptFrame(
                                passage: active,
                                builder: (scroll) => TargetContentCard(
                                  leaves: leaves,
                                  active: active,
                                  flat: true,
                                  scroll: scroll,
                                ),
                              )
                            : Align(
                                alignment: Alignment.topCenter,
                                child: TargetContentCard(
                                  leaves: leaves,
                                  active: active,
                                ),
                              ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          _PinnedPlayers(children: _reviewerPlayers(controller)),
        ],
      );
    }
    {
      return Column(
        children: [
          // Top to bottom: source script, target script, source audio, the
          // merged draft, and the two buttons. Each script has a frame of its
          // own and scrolls inside it, so both stay on screen together - the
          // comparison is between the two, and with one long scroller the
          // target was always a screen and a half below the source.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Column(
                children: [
                  SentBackBanner(set: controller.set),
                  //
                  // One passage at a time, the same one in both, and the
                  // one now playing - the website's rule. A new passage
                  // is read from its top, so each frame winds back when
                  // the passage changes.
                  Expanded(
                    child: Obx(
                      () => _ScriptFrame(
                        passage: controller.activeLeaf.value,
                        builder: (scroll) => SourceContentCard(
                          leaves: controller.leaves.toList(),
                          active: controller.activeLeaf.value,
                          audio: null,
                          showAudio: false,
                          flat: true,
                          scroll: scroll,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // What it should come out as, under what it came from.
                  //
                  // Half the space when there is a script to read, and only
                  // the line it needs when there is not: a tall empty box
                  // saying "no target script yet" took half the source's
                  // room to say nothing.
                  Obx(() {
                    final leaves = controller.leaves.toList();
                    final active = controller.activeLeaf.value;
                    if (!leaves.any((leaf) => leaf.hasTargetScript)) {
                      return TargetContentCard(leaves: leaves, active: active);
                    }
                    return const SizedBox.shrink();
                  }),
                  Obx(
                    () => controller.leaves.any((l) => l.hasTargetScript)
                        ? Expanded(
                            child: _ScriptFrame(
                              passage: controller.activeLeaf.value,
                              builder: (scroll) => TargetContentCard(
                                leaves: controller.leaves.toList(),
                                active: controller.activeLeaf.value,
                                flat: true,
                                scroll: scroll,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          _PinnedPlayers(children: _reviewerPlayers(controller)),
        ],
      );
    }
  }

  /// What this Set would be sent to next, for the notices that say what is
  /// standing in the way of sending it.
  ///
  /// Null when there is nowhere to send it, which has its own sentence: the
  /// name goes into the middle of one, and "go to move on" was never one.
  String? _nextStage(SetDetailController controller) {
    final actions = controller.actions;
    if (actions.isEmpty) return null;

    return actions.last.label
        .replaceFirst('Send to the ', '')
        .replaceFirst('Send to ', '')
        .tr;
  }

  String _missingText(int missing, String? stage) {
    if (stage == null) {
      return trCount(
        missing,
        '@count passage still needs a final take before this can move on.',
        '@count passages still need a final take before this can move on.',
      );
    }

    return (missing == 1
            ? '@count passage still needs a final take before this can go '
                  'to @stage.'
            : '@count passages still need a final take before this can go '
                  'to @stage.')
        .trParams({'count': '$missing', 'stage': stage});
  }

  /// Passages still without a final take.
  Widget _missingNotice(SetDetailController controller) {
    final missing = controller.missing;
    if (missing == 0 || controller.isFinished || controller.isReviewer) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _Notice(text: _missingText(missing, _nextStage(controller))),
    );
  }

  /// The passages themselves, for whoever is recording them.
  Widget _passages(SetDetailController controller) {
    // Read before anything can return. An Obx that finishes without touching
    // an observable is one GetX rejects outright, and the checks below are
    // about the role, which never changes while the page is open.
    final leaves = controller.leaves.toList();
    if (controller.isFinished || controller.isReviewer) {
      return const SizedBox.shrink();
    }

    // The website's nudge: the button that pulses is the first passage in
    // reading order still without a final take - not the first card
    // whatever its state - so finalizing one moves the pulse on to the
    // next, and with every passage finalized there is none.
    final next = leaves.where((leaf) => !leaf.hasFinal).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final leaf in leaves) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PassageChip(
              leaf: leaf,
              highlight: identical(leaf, next),
              onTap: () => controller.openLeaf(leaf),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Said above the player rather than beside the button, where the
  /// listening actually happens - by the time someone has scrolled to a
  /// greyed-out control, being told why is late.
  Widget _listenNotice(SetDetailController controller) {
    if (!controller.hasMergedDraft ||
        controller.listenDone ||
        controller.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: _Notice(
        text:
            'Listen to the target recording in full before sending to '
                    '@stage.'
                .trParams({'stage': _nextStage(controller) ?? ''}),
      ),
    );
  }

  /// The draft itself. Watches the recording and its pins and nothing else,
  /// so a note written under it does not rebuild the waveform.
  Widget _mergedPlayer(SetDetailController controller, {bool flat = false}) {
    if (!controller.hasMergedDraft) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: flat ? 0 : 16),
      child: MergedRecordingCard(
        title: 'Target Recording',
        audio: controller.audio.value,
        allowSeek: true,
        flat: flat,
        // Pinned to the foot of the screen there is no room to spare, and
        // the button under the player says the same thing.
        hint: flat
            ? ''
            : controller.canAddNotes
            ? 'Tap the waveform to jump to a spot, then leave a note there.'
            : 'Tap the waveform to jump to a spot.',
        onSegment: controller.onSegment,
        marks: controller.marks,
        onEnded: controller.markMergedHeard,
        mustListen: controller.mergedListenOwed,
        // The next thing to do once what comes before it is done: for a
        // reviewer the source audio, for the drafter a final take on
        // every passage.
        highlight:
            !controller.heardMerged.value &&
            controller.actions.isNotEmpty &&
            (controller.isReviewer
                ? controller.sourceHeardOrAbsent
                : controller.missing == 0),
        onAddMark: controller.canAddNotes ? controller.addNote : null,
        addMarkLabel: 'Comment here',
        addMarkColor: MarkColors.comment,
        onMarkTap: (mark) => controller.showNote(
          controller.comments.firstWhere((c) => c.id == mark.id),
        ),
      ),
    );
  }

  /// The disliked answers to general questions - what the community said
  /// about the Set as a whole - laid out in full: the question, the answer
  /// and the reviewer's reply, each with its recording. The website's
  /// "Community Review feedback" box.
  Widget _generalFeedback(SetDetailController controller) {
    final feedback = controller.generalFeedback;
    if (feedback.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDC2626), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                Text(
                  'Community Review feedback'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            for (final question in feedback) ...[
              const SizedBox(height: 10),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Pill(
                  icon: Icons.wechat_rounded,
                  label: 'General question',
                  color: Color(0xFF4B4870),
                ),
              ),
              _FeedbackLine(
                icon: Icons.help_outline,
                iconColor: const Color(0xFF15803D),
                text: question.text,
                emptyText: 'Voice question',
                audioPath: question.audioPath,
                audioKey: 'gq-${question.id}',
              ),
              if (question.answer case final answer?)
                _FeedbackLine(
                  icon: Icons.reply_rounded,
                  iconColor: const Color(0xFF4338CA),
                  text: answer.text,
                  emptyText: 'Voice answer',
                  audioPath: answer.audioPath,
                  audioKey: 'ga-${answer.id}',
                  indent: 1,
                ),
              if (question.reaction case final reply?)
                _FeedbackLine(
                  icon: Icons.reply_rounded,
                  iconColor: const Color(0xFFDC2626),
                  who: reply.authorName,
                  text: reply.text,
                  emptyText: 'Voice reply',
                  audioPath: reply.audioPath,
                  audioKey: 'gr-${reply.id}',
                  indent: 2,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// What can be done with the draft, under it.
  Widget _mergedActions(SetDetailController controller, {bool flat = false}) {
    final inset = EdgeInsets.symmetric(horizontal: flat ? 0 : 16);

    if (!controller.hasMergedDraft) return const SizedBox.shrink();

    final playable = controller.audio.value?.isPlayable ?? false;
    if (!playable) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.isFinished) ...[
          const SizedBox(height: 10),
          Padding(padding: inset, child: const _TaskDone()),
        ],
        if (controller.canAddNotes) ...[
          const SizedBox(height: 10),
          Padding(
            padding: inset,
            child: CommentButton(
              label: 'Add a note here',
              onPressed: controller.isBusy.value ? null : controller.addNote,
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionBar(SetDetailController controller) {
    final actions = controller.actions;
    if (actions.isEmpty) return const SizedBox.shrink();

    final missing = controller.missing;

    return ColoredBox(
      color: Colors.transparent,
      child: _actionBarContent(controller, actions, missing),
    );
  }

  Widget _actionBarContent(
    SetDetailController controller,
    List<StageAction> actions,
    int missing,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.blockedReason case final reason?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  reason.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
            Row(
              children: [
                for (final action in actions) ...[
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: _ActionButton(
                        action: action,
                        // Only the drafter's hand-off waits on every passage
                        // having a final take — the same condition the Laravel
                        // screen gates on.
                        blockedLabel: action.requiresAllFinal && missing > 0
                            ? trCount(
                                missing,
                                '@count passage left',
                                '@count passages left',
                              )
                            : null,
                        highlight:
                            !controller.isSending.value &&
                            controller.canRun(action),
                        // Listening gates the way forward only; sending back
                        // needs an open comment and nothing else. See
                        // [SetDetailController.canRun].
                        onPressed:
                            (controller.isSending.value ||
                                !controller.canRun(action))
                            ? null
                            : () => controller.runAction(action),
                      ),
                    ),
                  ),
                  if (action != actions.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One passage in the top strip: its name, and what state it is in.
class _PassageChip extends StatelessWidget {
  const _PassageChip({
    required this.leaf,
    required this.onTap,
    this.highlight = false,
  });

  final SetLeaf leaf;
  final VoidCallback onTap;

  /// Whether this is the passage to record next: its button pulses.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    // The outline says "this one still needs you". A finalized passage does
    // not, even if a mark was raised on it along the way — the drafter has
    // already answered it by finalizing. The count stays as a record.
    final flagged = leaf.openMarks > 0 && !leaf.hasFinal;

    // The website's card: the name and its state along the top, and a real
    // button underneath saying what tapping does. A finalized passage has
    // nothing left to check, so its button says Re-record - going back in is
    // only ever to record it again, and a bare chevron did not say so.
    //
    // No verse range. The passage's name is what the team calls it, and the
    // reference under every card was one more line to read past.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: MainApp.cardShadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        // A hairline all round when there is nothing to flag. The shadow
        // falls downward, so on a page nearly as white as the card the top
        // edge had nothing to show where the card began.
        side: flagged
            ? const BorderSide(color: Color(0xFFDC2626), width: 0.8)
            : const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      // The whole card still opens the passage: the button is the label for
      // the action, not the only place a thumb is allowed to land.
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          // Name over state on the left, the button on the right and
          // centred on the card's height - so it sits level with the pair
          // beside it rather than hanging off the title row.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leaf.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    // Close under the name: the pill is about this passage,
                    // and a wide gap made it read as a row of its own.
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // A finalized passage shows no marks at all: whatever was
                        // raised has been answered by the take that was finalized,
                        // so flagging it only sends the drafter back to a passage
                        // with nothing left to do.
                        if (flagged) ...[
                          // Red, and pulsing: what a reviewer said about
                          // this passage is waiting to be read.
                          PulseHalo(
                            active: true,
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(999),
                            child: _Pill(
                              icon: Icons.warning_amber_rounded,
                              label: '${leaf.openMarks}',
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (leaf.hasFinal)
                          const _Pill(
                            icon: Icons.check_circle,
                            label: 'Finalized',
                            color: Color(0xFF15803D),
                          )
                        else if (leaf.takesCount > 0)
                          _Pill(
                            icon: Icons.mic,
                            label: trCount(
                              leaf.takesCount,
                              '@count take',
                              '@count takes',
                            ),
                            color: const Color(0xFFB45309),
                          )
                        else
                          const _Pill(
                            icon: Icons.mic_none,
                            label: 'Not started',
                            color: Color(0xFF667085),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PulseHalo(
                active: highlight,
                borderRadius: BorderRadius.circular(10),
                child: _RecordButton(rerecord: leaf.hasFinal, onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Record, or Re-record once the passage has a final take.
///
/// Amber for Re-record, the brand green for Record: recording over a take
/// that was already chosen is a step back, and should not look like the
/// next thing to do.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.rerecord, required this.onTap});

  final bool rerecord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = rerecord ? const Color(0xFF92400E) : Colors.white;
    final background = rerecord
        ? const Color(0xFFFEF3C7)
        : MainApp.primaryGreen;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: rerecord ? const Color(0xFFB45309) : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                rerecord ? Icons.refresh_rounded : Icons.mic,
                size: 16,
                color: foreground,
              ),
              const SizedBox(width: 6),
              Text(
                (rerecord ? 'Re-record' : 'Record').tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A stage transition. Sending work backwards is outlined in red rather than
/// filled, so it never reads as the obvious next tap.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.blockedLabel,
    required this.onPressed,
    this.highlight = false,
  });

  final StageAction action;
  final String? blockedLabel;
  final VoidCallback? onPressed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    // Filled like the one beside it, so the two hand-offs carry the same
    // weight and are told apart by colour alone: green on, dark red back -
    // and refused, both drop to the same plain grey.
    return StageActionButton(
      label: blockedLabel ?? action.label,
      icon: action.isSendBack ? Icons.rotate_left : Icons.send,
      sendBack: action.isSendBack,
      highlight: highlight && blockedLabel == null,
      onPressed: blockedLabel != null ? null : onPressed,
    );
  }
}

/// One line of a feedback chain: a question, its answer or the reply,
/// stepped in by [indent] under the one it answers.
class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.emptyText,
    required this.audioPath,
    required this.audioKey,
    this.who = '',
    this.indent = 0,
  });

  final IconData icon;
  final Color iconColor;
  final String who;
  final String text;
  final String emptyText;
  final String audioPath;
  final String audioKey;
  final int indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(start: 18.0 * indent, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (who.isNotEmpty)
                          TextSpan(
                            text: '$who: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(
                          text: text.isNotEmpty ? text : emptyText.tr,
                          style: text.isEmpty
                              ? const TextStyle(color: MainApp.mutedText)
                              : null,
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ),
            ],
          ),
          if (audioPath.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 32),
              child: AudioClip(
                key: ValueKey(audioKey),
                filePath: audioPath,
                showSpeed: false,
                showExpand: false,
                accent: iconColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        // Solid, not see-through: the pulse drawn behind a flagged pill
        // showed through it and recoloured the pill with every beat.
        color: Color.alphaBlend(color.withValues(alpha: 0.12), Colors.white),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.tr,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A quiet status line above the passages.
///
/// Deliberately neutral rather than tinted red or amber: the passages
/// underneath already carry their own colour — a red outline, a warning pill
/// — and repeating that alarm up here made a Set in ordinary progress look
/// like a Set in trouble. This states a fact; the cards show the state.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // The sentence alone. An icon beside a line of plain instruction adds
    // nothing to it - a headphone or a warning triangle only repeats what
    // the words already say, and two of these stacked read as a row of
    // symbols to decode rather than as something to do.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

/// The recordings, held at the foot of the peer check screen while the
/// scripts scroll behind them.
///
/// Each child is a card of its own, like the ones above, set apart by a
/// small gap. They do not scroll in the
/// ordinary way of things; the scroll view inside is only there so that a
/// very short screen, or a keyboard, squeezes the panel rather than
/// overflowing it with a striped warning.
class _PinnedPlayers extends StatelessWidget {
  const _PinnedPlayers({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // One box per recording, a small gap between: the source is one thing
    // and the draft another, and inside a single panel with a rule across
    // it they read as two halves of the same player.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: SingleChildScrollView(
        // Room for the cards' shadows, which the scroll view would clip.
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in children) ...[
              Container(
                // Tight above: the player's own control row is the card's
                // heading, and the scripts above are what the room is for.
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: MainApp.cardShadow,
                ),
                child: child,
              ),
              if (child != children.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// As on the website (2026-09-25): a "Task Done" indicator where the
/// download button used to be - drafters are no longer offered a download
/// of the final audio.
class _TaskDone extends StatelessWidget {
  const _TaskDone();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 18, color: Color(0xFF166534)),
            const SizedBox(width: 8),
            Text(
              'Task Done'.tr,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF166534),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Set screen while it loads, laid out by the same rules as the page:
/// the role and the Set's status are known before anything is read, and
/// they decide which layout is coming.
class _SetDetailSkeleton extends StatelessWidget {
  const _SetDetailSkeleton({required this.controller, this.passages});

  /// See [SetDetailPage.passages]. Three when nobody said.
  final int? passages;

  final SetDetailController controller;

  static const Set<String> _drafting = {'not_started', 'recorded', 'redo'};

  @override
  Widget build(BuildContext context) {
    if (controller.isReviewer && controller.showsSourceAudio) {
      return LayoutBuilder(
        // The page's own rule for when the players cannot be pinned.
        builder: (context, constraints) => constraints.maxHeight < 480
            ? _reviewerScrolling()
            : _reviewerPinned(context),
      );
    }

    final reviewer = controller.isReviewer;
    final finished = controller.isFinished;
    // While drafting, the merged draft only exists once every passage has a
    // final take, which is not known yet - drawn as absent, the usual case.
    final drafting = _drafting.contains(controller.set.workflowStatus);
    final player = !drafting;

    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: [
          if (!reviewer && !finished && drafting) ...[
            const _NoticeBones(),
            const SizedBox(height: 10),
          ],
          SentBackBanner(set: controller.set),
          if (!reviewer && !finished)
            for (var i = 0; i < (passages ?? 3); i++) ...[
              const _PassageChipBones(),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 10),
          if (player)
            PlayerBones(
              hint: controller.canAddNotes
                  ? 'Tap the waveform to jump to a spot, then leave a note '
                        'there.'
                  : 'Tap the waveform to jump to a spot.',
            ),
          if (player && finished) ...[
            const SizedBox(height: 10),
            const _TaskDone(),
          ],
          if (player && controller.canAddNotes) ...[
            const SizedBox(height: 10),
            const _CommentButtonBones(),
          ],
        ],
      ),
    );
  }

  /// The two recordings a reviewer hears, each as its card's content.
  List<Widget> _players() => [
    const PlayerBones.source(flat: true),
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlayerBones(flat: true),
        if (controller.canAddNotes) ...[
          const SizedBox(height: 10),
          const _CommentButtonBones(),
        ],
      ],
    ),
  ];

  Widget _reviewerPinned(BuildContext context) {
    const source = ScriptBones.source(kind: ScriptCardKind.frame, lines: 20);
    const target = ScriptBones.target(kind: ScriptCardKind.frame, lines: 20);
    final frames = ScriptPair.sideBySide(context)
        ? const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: source),
              SizedBox(width: 10),
              Expanded(child: target),
            ],
          )
        : const Column(
            children: [
              Expanded(child: source),
              SizedBox(height: 10),
              Expanded(child: target),
            ],
          );

    return Shimmer(
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
              child: Column(
                children: [
                  SentBackBanner(set: controller.set),
                  Expanded(child: frames),
                ],
              ),
            ),
          ),
          _PinnedPlayers(children: _players()),
        ],
      ),
    );
  }

  Widget _reviewerScrolling() {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        children: [
          SentBackBanner(set: controller.set),
          const ScriptPair(
            source: ScriptBones.source(lines: 5),
            target: ScriptBones.target(lines: 5),
          ),
          const SizedBox(height: 10),
          for (final player in _players()) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: MainApp.cardShadow,
              ),
              child: player,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// A passage card still loading: [_PassageChip]'s frame, its name as a
/// line, and its pill and button as shapes of their real size.
class _PassageChipBones extends StatelessWidget {
  const _PassageChipBones();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: MainApp.cardShadowColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BoneText(
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    width: 150,
                  ),
                  const SizedBox(height: 4),
                  BoneShape(
                    radius: 999,
                    child: const _Pill(
                      icon: Icons.mic_none,
                      label: 'Not started',
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            BoneShape(
              radius: 10,
              child: _RecordButton(rerecord: false, onTap: () {}),
            ),
          ],
        ),
      ),
    );
  }
}

/// [_Notice] holding a sentence still being worked out.
class _NoticeBones extends StatelessWidget {
  const _NoticeBones();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const BoneParagraph(
        lines: 2,
        style: TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}

/// The reviewer's "Add a note here", which is the same before and after
/// loading - drawn as itself, out of reach until the page is ready.
class _CommentButtonBones extends StatelessWidget {
  const _CommentButtonBones();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CommentButton(label: 'Add a note here', onPressed: () {}),
    );
  }
}

/// The action bar's room while loading, one shape per hand-off, so the
/// page above it is already the height it will be.
class _ActionBarBones extends StatelessWidget {
  const _ActionBarBones({required this.count, this.reason = false});

  final int count;

  /// Whether the bar carries [SetDetailController.blockedReason] over its
  /// buttons. Its usual wording before anything has been played - "Play
  /// both recordings to the end..." - takes two lines.
  final bool reason;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Shimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reason)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: BoneParagraph(
                    lines: 2,
                    style: TextStyle(fontSize: 11),
                    lastWidth: 0.7,
                  ),
                ),
              Row(
                children: [
                  for (var i = 0; i < count; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    const Expanded(child: Bone(height: 58, radius: 10)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A fixed white box one script scrolls inside - the heading pinned at its
/// top, the text moving under it.
class _ScriptFrame extends StatefulWidget {
  const _ScriptFrame({required this.builder, required this.passage});

  /// Builds the card, given the controller its text should scroll with.
  final Widget Function(ScrollController scroll) builder;

  /// Which passage is inside. When it changes the frame goes back to the
  /// top: left where the last passage was scrolled to, the new one would
  /// open part way down - or, being shorter, past its own end.
  final int passage;

  @override
  State<_ScriptFrame> createState() => _ScriptFrameState();
}

class _ScriptFrameState extends State<_ScriptFrame> {
  // Its own, because there are two of these on the page: sharing the page's
  // primary controller would tie the two scripts' scrolling together.
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(_ScriptFrame old) {
    super.didUpdateWidget(old);
    if (widget.passage != old.passage && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
      ),
      child: widget.builder(_scroll),
    );
  }
}
