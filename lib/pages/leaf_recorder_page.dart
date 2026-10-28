import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;

import 'package:livuka/services/user_store.dart';
import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/Widgets/sheet_host.dart';
import 'package:livuka/Widgets/sheet_actions.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/recording_timer.dart';
import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/Audio/take_recorder.dart';
import 'package:livuka/Widgets/live_waveform.dart';
import 'package:livuka/Audio/wave_analyzer.dart';
import 'package:livuka/Audio/waveform_cache.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/Widgets/swipe_hint.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:livuka/Widgets/qa_feedback_sheet.dart';
import 'package:livuka/Widgets/qc_result_dialog.dart';
import 'package:livuka/Widgets/reference_panel.dart';
import 'package:livuka/l10n/app_locale.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/permissions.dart';
import 'package:livuka/services/qc_service.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/recording_rescue.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/work_queue.dart';

/// Recording, QC and marks for one passage.
///
/// Recording produces a 16-bit PCM WAV on purpose: it is what [QcService] can
/// analyse, and it is the only format that lets a drafter get a pass/fail
/// verdict in the field with no server in reach.
class LeafRecorderController extends GetxController {
  LeafRecorderController({
    required this.set,
    required this.leaves,
    int startIndex = 0,
    bool startOnTakes = false,
  }) : currentIndex = startIndex.obs,
       showingTakes = startOnTakes.obs;

  final WorkSet set;

  /// Every passage in the Set, in reading order. The recorder walks this list
  /// rather than being opened once per passage, so moving on is an arrow
  /// rather than a trip back to the Set.
  final List<SetLeaf> leaves;

  final RxInt currentIndex;

  /// Which of the passage's two screens is showing: the recorder, or its
  /// takes. They share this controller because they share the passage - the
  /// takes are the thing being recorded, not a separate subject.
  final RxBool showingTakes;

  SetLeaf get leaf => leaves[currentIndex.value];

  /// Six takes to a passage.
  ///
  /// Not a storage limit - it is a working one. A drafter with twenty takes
  /// of the same verse is no longer choosing between them, and every take
  /// travels to the server with its audio. Six is enough to get a good read
  /// and few enough to compare.
  static const int maxTakes = 6;

  bool get atTakeLimit => takes.length >= maxTakes;

  final TakeRecorder recorder = TakeRecorder();

  /// Which clip owns the speaker, shared by every [AudioClip] on the screen so
  /// only one plays at a time, and read when anchoring a mark.

  final takes = <Take>[].obs;
  final comments = <TakeComment>[].obs;
  final allComments = <TakeComment>[].obs;

  /// Whether the passage has nothing that could be made Final: no take
  /// at all, or only takes that failed QC or were sent back. Recording a
  /// new one is then the next thing to do.
  bool get needsNewTake =>
      finalTakeId.value == null &&
      !takes.any(
        (take) =>
            finalBlocked[take.id] == null &&
            (!take.hasQcReport || take.passedQc),
      );

  /// The community questions whose answers were disliked, each pinned to
  /// the take it was about. The website's `$qaMarksForLeaf`.
  final disputed = <CommunityQuestion>[].obs;

  /// The disliked questions about [take], as marks on its waveform.
  List<CommunityQuestion> disputedOn(Take take) => [
    for (final question in disputed)
      if (question.positionSeconds != null &&
          TakeRepository.takeOfQuestion(question, takes.toList()) == take.id)
        question,
  ];

  /// Why each take that may not be made Final may not, by take id. Worked
  /// out as the takes are read, so the card can say it before anybody has
  /// to tap the star to be told.
  final finalBlocked = <String, String>{}.obs;

  /// The reviewers' comments pinned to [take], as marks on its waveform.
  /// One with no take named belongs to every take, as on the website.
  List<TakeComment> commentsOn(Take take) => [
    for (final comment in allComments)
      if (comment.positionSeconds != null &&
          (comment.takeId.isEmpty || comment.takeId == take.id))
        comment,
  ];

  /// Who a comment came from, for its popup.
  static String reviewerRole(String stageKey) => switch (stageKey) {
    'drafter' => 'Drafter',
    'peer' => 'Peer Checker',
    'community_setup' => 'Community Setup',
    'community_review' => 'Community Reviewer',
    'back_translation' => 'Back Translator',
    'consultant' => 'Consultant',
    _ => '',
  };

  /// The comment behind a tapped pin: who, what they said, and - for its
  /// author - the way to take it back. The website's comment popup.
  Future<void> showComment(TakeComment comment) async {
    final role = reviewerRole(comment.stageKey);
    final who = comment.authorName.isEmpty ? 'Someone'.tr : comment.authorName;

    await showAppSheet(
      Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  comment.isOpen
                      ? Icons.error_outline
                      : Icons.check_circle_outline,
                  size: 16,
                  color: comment.isOpen
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF98A2B3),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      role.isEmpty ? who : '$who (${role.tr})',
                      if (comment.positionLabel.isNotEmpty)
                        comment.positionLabel,
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MainApp.mutedText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              comment.text.isEmpty ? 'Voice comment'.tr : comment.text,
              style: TextStyle(
                fontSize: 14,
                color: comment.text.isEmpty ? MainApp.mutedText : null,
              ),
            ),
            if (comment.hasAudio) ...[
              const SizedBox(height: 8),
              AudioClip(
                key: ValueKey('c-${comment.id}'),
                filePath: comment.audioPath,
                title: 'Comment',
              ),
            ],
            SheetActions(
              deleteLabel: 'Delete comment',
              onDelete: comment.isMine ? () => deleteComment(comment) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteComment(TakeComment comment) async {
    if (!await ConfirmDialog.askDeleteComment()) return;
    await withBusy('Deleting...', () async {
      await TakeRepository.deleteComment(commentId: comment.id, setId: set.id);
    });
  }

  final finalTakeId = RxnString();
  final isLoading = true.obs;
  final isRecording = false.obs;

  /// Held part way through a take: somebody walked in, a lorry went past.
  /// The file stays open and the next words carry on in it.
  final isPaused = false.obs;

  /// How long the take has actually been running, pauses left out. The
  /// recorder's own figure is twice the truth (see [RecordingTimer]), and it
  /// was that figure the five-second rule and `duration_ms` were reading.
  final Stopwatch recordingClock = Stopwatch();

  final isBusy = false.obs;
  final micDenied = false.obs;
  final busyLabel = ''.obs;

  /// Recording is only open while the Set sits with the drafter, and only for
  /// the person actually holding that role — the same rule the server's
  /// `guardStage` enforces on the way in.
  /// Whether this is the drafter's turn with the Set at all.
  bool get isDraftingStage =>
      set.roleKey == 'drafter' &&
      const {'not_started', 'recorded', 'redo'}.contains(set.workflowStatus);

  /// Whether the drafter has actually heard the source on this visit.
  /// Having the file is not the same as having listened to it, and a take
  /// recorded without doing so is the kind that comes back from peer check.
  ///
  /// The script is no longer asked for separately: it sits open above the
  /// recorder, so there is nothing to open and nothing to check.
  final openedSourceAudio = false.obs;

  /// Whether the source was heard right through, rather than merely started.
  ///
  /// Kept apart from [openedSourceAudio] because they answer different
  /// questions: starting it releases the mic, finishing it is the moment
  /// there is nothing left to do but record.
  final heardSourceInFull = false.obs;

  /// Whether the drafter has ticked "I have read" under each script - the
  /// website's step between hearing the source and recording. One-way:
  /// once ticked it stays ticked, for this round of the Set.
  final readSource = false.obs;
  final readTarget = false.obs;

  /// Which scripts still need their box ticked. A passage with no script
  /// of a kind simply has no box for it.
  bool get needsReadSource => leaf.hasSourceScript && !readSource.value;
  bool get needsReadTarget => leaf.hasTargetScript && !readTarget.value;

  /// Heard to the end and read: pressing play and then the mic is not
  /// listening to the passage, and a script scrolled past is not one read.
  bool get sourceReviewed =>
      heardSourceInFull.value && !needsReadSource && !needsReadTarget;

  void markRead({required bool target}) {
    (target ? readTarget : readSource).value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: target
          ? ListenGate.readTarget(leaf.key)
          : ListenGate.readSource(leaf.key),
    );
  }

  void markSourceHeard() {
    heardSourceInFull.value = true;
    ListenGate.markHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.sourceOf(leaf.key),
    );
  }

  /// Whether the source still has to be opened before recording.
  ///
  /// Only the first take is worth gating. With nothing recorded here there is
  /// no sign the drafter has heard the passage they are about to read; once a
  /// take exists they plainly have, and sending them back through the source
  /// before every retake is a hoop rather than a safeguard - retakes are
  /// usually a fluffed line, seconds after the last attempt.
  bool get needsSourceReview => takes.isEmpty && !sourceReviewed;

  /// Whether the source still has to be heard right through. Only before
  /// a first take, as on the website, whose gate is met for good the
  /// moment the passage has one: a drafter going over the source again
  /// between takes is free to go straight to the line they fluffed.
  bool get sourceListenOwed =>
      isDraftingStage && takes.isEmpty && !heardSourceInFull.value;

  /// The listening step is behind the drafter: heard to the end, or there
  /// was nothing to hear.
  bool get sourceHeardOrAbsent =>
      heardSourceInFull.value || !leaf.hasSourceAudio;

  /// Recording needs the source present, and - for a first take - looked at.
  /// The button is offered but refused rather than hidden: the drafter has to
  /// be able to see what is stopping them, and that it is not the app.
  bool get canRecord =>
      isDraftingStage &&
      !leaf.missingSource &&
      !needsSourceReview &&
      !atTakeLimit;

  /// What is stopping recording, when something is.
  String get blockedReason {
    // First, because it is the one a drafter meets mid-flow rather than on
    // arrival, and the only one with something to do about it.
    if (atTakeLimit) {
      return '@count takes is the limit - remove one on the Takes screen to '
              'record another.'
          .trParams({'count': '$maxTakes'});
    }
    if (!leaf.hasSourceAudio && !leaf.hasSourceScript) {
      return 'Source audio and source script are both missing.';
    }
    if (!leaf.hasSourceAudio) return 'Source audio is missing.';
    if (!leaf.hasSourceScript) return 'Source script is missing.';
    // Hearing first, then reading, then the mic: the order the website
    // walks a drafter through, and the order the reasons come in.
    if (takes.isEmpty && !heardSourceInFull.value) {
      return 'Play the source audio to the end before the first take.';
    }
    if (takes.isEmpty && needsReadSource) {
      return 'Tick "I have read" under the source script.';
    }
    if (takes.isEmpty && needsReadTarget) {
      return 'Tick "I have read" under the target script.';
    }
    if (needsSourceReview) {
      return 'Play the source audio to the end before the first take.';
    }
    return '';
  }

  @override
  void onInit() {
    super.onInit();
    // The idle clock behind the swipe hint follows the pane and the Final
    // take, not only touches: a swipe onto a finished passage's takes
    // starts it too.
    ever(showingTakes, (_) => _armIdleHint());
    ever(finalTakeId, (_) => _armIdleHint());
    AudioBus.instance.addListener(_stopIfPlaybackStarts);
    load();
  }

  // ------------------------------------------------------- the swipe hint

  /// Whether the hand that shows how to swipe to the next passage is up.
  final showSwipeHint = false.obs;

  /// Remembered on the phone once the hand has been shown after a first
  /// Final take, so it is a first-time thing and not an every-time thing.
  static const String _hintShownKey = 'swipe_hint_shown';

  /// How long a finished passage sits untouched before the hand comes up.
  static const Duration _idleBeforeHint = Duration(seconds: 20);

  Timer? _idleHint;

  /// The screen was touched: the hand goes, and the idle clock restarts.
  void touched() {
    if (showSwipeHint.value) showSwipeHint.value = false;
    _armIdleHint();
  }

  /// The hand has finished its passes, or been touched away.
  void hintDone() {
    showSwipeHint.value = false;
    _armIdleHint();
  }

  /// Starts the idle clock when the takes of a passage with a Final take
  /// are showing - the one place where the next thing to do is to move
  /// on - and stops it anywhere else.
  void _armIdleHint() {
    _idleHint?.cancel();
    _idleHint = null;
    if (!showingTakes.value || finalTakeId.value == null) return;
    if (!hasNextPassage) return;
    _idleHint = Timer(_idleBeforeHint, () {
      if (isClosed || !showingTakes.value || finalTakeId.value == null) return;
      if (isRecording.value || isBusy.value) return;
      showSwipeHint.value = true;
    });
  }

  /// After a Final take: the first time ever on this phone, the hand shows
  /// at once, since a new drafter has no way of knowing the page swipes.
  Future<void> _hintAfterFirstFinal() async {
    if (!hasNextPassage) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_hintShownKey) ?? false) return;
      await prefs.setBool(_hintShownKey, true);
    } catch (_) {
      return;
    }
    if (isClosed) return;
    showSwipeHint.value = true;
  }

  @override
  void onClose() {
    _idleHint?.cancel();
    AudioBus.instance.removeListener(_stopIfPlaybackStarts);
    AudioBus.instance.release(recorder);
    recorder.dispose();
    // Back to the Set, whose screen is still open underneath.
    TimeTracker.instance.enter(
      stage: TimeTracker.stageOf(set.workflowStatus),
      setId: set.id,
    );
    super.onClose();
  }

  bool _stopping = false;

  /// Ends the take when something starts to play. A recording made with
  /// the source sounding out of the same phone is a recording of the
  /// source. Paused, the microphone is closed and listening is what a
  /// pause is for, so nothing is ended then.
  void _stopIfPlaybackStarts() {
    if (!isRecording.value || isPaused.value || _stopping) return;
    if (AudioBus.instance.holds(recorder)) return;

    toaster(AudioBus.recordingStoppedMessage);
    unawaited(stopRecording());
  }

  bool get hasNextPassage => currentIndex.value + 1 < leaves.length;

  bool get hasPreviousPassage => currentIndex.value > 0;

  /// Whether the arrows can be used at all. Mid-recording they cannot: the
  /// take being made would be abandoned half-written.
  bool get canNavigate => !isRecording.value && !isBusy.value;

  /// Rightwards through the Set: recorder, then that passage's takes, then
  /// the next passage. Off the end is back to the Set, where the passage list
  /// and the merged draft are.
  Future<void> goForward() async {
    if (!canNavigate) return;
    if (!showingTakes.value) {
      showingTakes.value = true;
      return;
    }
    if (hasNextPassage) {
      await _openPassage(currentIndex.value + 1, onTakes: false);
      return;
    }
    Get.back();
  }

  /// The same walk in reverse, which is why the left arrow from a recorder
  /// lands on the previous passage's takes rather than its recorder: the two
  /// screens are one sequence, stepped through either way.
  Future<void> goBack() async {
    if (!canNavigate) return;
    if (showingTakes.value) {
      showingTakes.value = false;
      return;
    }
    if (hasPreviousPassage) {
      await _openPassage(currentIndex.value - 1, onTakes: true);
      return;
    }
    Get.back();
  }

  /// What the app bar's back arrow does, and the system back gesture with
  /// it.
  ///
  /// The takes are the second half of this passage rather than a screen of
  /// their own, so backing out of them lands on the recorder they belong to.
  /// Only backing out of the recorder leaves the passage.
  void goUp() {
    if (showingTakes.value) {
      showingTakes.value = false;
      return;
    }
    Get.back();
  }

  Future<void> _openPassage(int index, {required bool onTakes}) async {
    // Nothing carries over: the source review is per passage, and a clip
    // still playing belongs to the passage being left.
    AudioBus.instance.silence();

    currentIndex.value = index;
    showingTakes.value = onTakes;
    showSwipeHint.value = false;
    openedSourceAudio.value = false;
    heardSourceInFull.value = false;
    readSource.value = false;
    readTarget.value = false;
    takes.clear();
    comments.clear();
    finalTakeId.value = null;
    isLoading.value = true;

    await load();
  }

  Future<void> load() async {
    // Time on this passage is counted against it.
    TimeTracker.instance.enter(
      stage: TimeTracker.stageOf(set.workflowStatus),
      setId: set.id,
      leafType: leaf.type,
      leafId: leaf.id,
    );
    // Kept on the phone for this round of the Set, so a drafter who heard
    // the source yesterday is not made to hear it again before take one.
    heardSourceInFull.value = await ListenGate.isHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.sourceOf(leaf.key),
    );
    readSource.value = await ListenGate.isHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.readSource(leaf.key),
    );
    readTarget.value = await ListenGate.isHeard(
      setId: set.id,
      round: set.workflowUpdatedAt,
      what: ListenGate.readTarget(leaf.key),
    );
    takes.value = await TakeRepository.takesFor(
      setId: set.id,
      leafType: leaf.type,
      leafId: leaf.id,
    );
    finalTakeId.value = await TakeRepository.finalTakeId(
      leafType: leaf.type,
      leafId: leaf.id,
    );
    // Every reviewer's comment on this passage. The recorder's "why this
    // was sent back" panel shows the open ones; the takes show each on the
    // take it names, resolved or not - a resolved comment is still the
    // reason that take lost, and the drafter listening to it wants to
    // know what was said about it. The website keeps both the same way.
    final all = await TakeRepository.commentsFor(
      setId: set.id,
      leafType: leaf.type,
      leafId: leaf.id,
    );
    allComments.value = all;
    comments.value = all.where((comment) => comment.isOpen).toList();

    // Only while the Set is back from Community Review: a Dislike left
    // open by some other route is not what this passage was sent back
    // for, as on the website.
    disputed.value =
        set.workflowStatus == 'redo' && set.redoFromStage == 'community_review'
        ? [
            for (final question in await TakeRepository.disputedQuestionsFor(
              setId: set.id,
              leafLabels: const {},
            ))
              if (question.leafKey == leaf.key) question,
          ]
        : const [];

    final blocked = <String, String>{};
    for (final take in takes) {
      final reason = await TakeRepository.finalBlockedReason(
        setId: set.id,
        takeId: take.id,
        leafType: leaf.type,
        leafId: leaf.id,
      );
      if (reason != null) blocked[take.id] = reason;
    }
    finalBlocked.value = blocked;

    isLoading.value = false;
  }

  /// Asks for the microphone, and explains itself if the answer is no.
  ///
  /// A refusal that can still be re-prompted needs nothing but another tap.
  /// One that cannot — the system stops showing the dialog after a hard
  /// refusal — has to hand the user to the settings page, or the record
  /// button just appears broken forever.
  Future<bool> ensureMicPermission() async {
    if (await checkMicrophonePermission()) {
      micDenied.value = false;
      return true;
    }

    final blocked = await isMicrophoneBlocked();
    micDenied.value = true;

    await Get.dialog<void>(
      AlertDialog(
        title: Text('Microphone is off'.tr),
        content: Text(
          blocked
              ? 'Recording needs the microphone, and it has been turned off '
                        'for this app. Open settings to switch it back on.'
                    .tr
              : 'Recording needs the microphone. Tap record again to allow it.'
                    .tr,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('Close'.tr)),
          if (blocked)
            TextButton(
              onPressed: () {
                Get.back();
                openMicrophoneSettings();
              },
              child: Text('Open settings'.tr),
            ),
        ],
      ),
    );

    return false;
  }

  /// When the take now running began. `recorded_at` is stamped from this
  /// rather than from the moment recording stops.
  DateTime? _startedAt;

  Future<void> startRecording() async {
    try {
      await _startRecording();
    } catch (e) {
      debugPrint('TAKE RECORD FAILED: $e');
      isRecording.value = false;
      toaster('Could not start recording: @error'.trParams({'error': '$e'}));
    }
  }

  Future<void> _startRecording() async {
    // A tap on the mic is a decision to speak, not to speak over
    // playback: whatever was sounding stops here, and the speaker is the
    // recorder's until the take ends.
    AudioBus.instance.claim(recorder);

    if (!await ensureMicPermission()) {
      AudioBus.instance.release(recorder);
      return;
    }
    debugPrint('REC: permission ok');

    final directory = await UserStore.work();
    final takesDir = Directory(p.join(directory.path, 'takes'));
    await takesDir.create(recursive: true);

    final path = p.join(
      takesDir.path,
      'take-${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await recorder.record(path: path);
    // Noted before anything else: from here until the take is in the
    // database, this file is all there is of it.
    await RecordingRescue.began(
      path: path,
      setId: set.id,
      leafType: leaf.type,
      leafId: leaf.id,
      leafLabel: leaf.label,
    );
    _startedAt = DateTime.now();
    recordingClock
      ..reset()
      ..start();
    isPaused.value = false;
    isRecording.value = true;
    debugPrint('REC: recording state shown');

    // Something was set playing while the microphone was still opening.
    _stopIfPlaybackStarts();
  }

  Future<void> pauseRecording() async {
    try {
      await recorder.pause();
      recordingClock.stop();
      isPaused.value = true;
      AudioBus.instance.release(recorder);
    } catch (e) {
      debugPrint('TAKE PAUSE FAILED: $e');
      toaster('Could not pause - the recording is still running.');
    }
  }

  Future<void> resumeRecording() async {
    try {
      // Whatever was listened to during the pause stops here.
      AudioBus.instance.claim(recorder);
      // The recorder resumes through the same call that starts it.
      await recorder.record();
      recordingClock.start();
      isPaused.value = false;
    } catch (e) {
      debugPrint('TAKE RESUME FAILED: $e');
      toaster('Could not resume. Stop to keep what has been recorded.');
    }
  }

  Future<void> stopRecording() async {
    if (_stopping) return;
    _stopping = true;
    String? stopped;
    try {
      stopped = await recorder.stop();
    } finally {
      _stopping = false;
    }
    final path = stopped;
    recordingClock.stop();

    isRecording.value = false;
    isPaused.value = false;
    AudioBus.instance.release(recorder);

    if (path == null || path.isEmpty) {
      await RecordingRescue.finished();
      toaster('Nothing was recorded.');
      return;
    }

    // How long the file runs, not how long the clock did: what had no
    // volume at the ends has been dropped from it, and the file is what
    // the server measures. The clock stands in only if it cannot be read.
    final measured = (await WaveformCache.duration(path)).inMilliseconds;
    final durationMs = measured > 0
        ? measured
        : recordingClock.elapsedMilliseconds;

    // Refused before anything is measured, the same rule the web app and the
    // server apply: a passage cannot be read in under five seconds, so this
    // is a slip of the button rather than a take worth grading.
    if (durationMs < AudioQcConfig.minimumTakeSeconds * 1000) {
      await File(path).delete().catchError((_) => File(path));
      await RecordingRescue.finished();
      toaster(
        'Too short to keep - a take must be at least @count seconds.'.trParams({
          'count': '${AudioQcConfig.minimumTakeSeconds.round()}',
        }),
      );
      return;
    }

    QcOutcome? checked;

    await withBusy('Checking audio...', () async {
      // QC runs before the take is stored, because it doubles as the format
      // check. If the device handed back something that isn't 16-bit PCM WAV
      // the take is not saved at all: queuing it would mean weeks of
      // unusable recordings that only fail once the device finds signal.
      final qc = await QcService.run(
        path,
        expectedDurationSeconds: await _sourceDurationSeconds(),
      );

      if (qc.error != null) {
        await RecordingRescue.finished();
        toaster('This recording is not a WAV file and was not saved.');
        return;
      }

      debugPrint('REC: QC done, saving take');
      final takeId = await TakeRepository.saveTake(
        setId: set.id,
        leafType: leaf.type,
        leafId: leaf.id,
        filePath: path,
        durationMs: durationMs,
        recordedAt: _startedAt,
      );

      _startedAt = null;
      await RecordingRescue.finished();

      await TakeRepository.setQc(
        takeId: takeId,
        setId: set.id,
        passed: qc.passed,
        notes: qc.notes,
        report: qc.report,
      );
      debugPrint('REC: take $takeId saved, reloading');

      checked = qc;
    });
    debugPrint('REC: screen reloaded');

    // Once the screen is its own again: the popup over a busy overlay is two
    // things asking for attention at once.
    await _showQc(checked);

    // Then straight to this passage's takes, where the new one sits with
    // its grade and its Final star: the next thing to do is decide about
    // it, and the arrows that used to point the way there are gone.
    if (checked != null && !showingTakes.value) showingTakes.value = true;
  }

  /// The website's "Automated QC" popup: the grade, and each of the six
  /// checks with what was measured.
  Future<void> _showQc(QcOutcome? qc) async {
    if (qc == null) return;

    if (qc.checks.isEmpty) {
      // Nothing was measured - the file could not be read - so there is no
      // report to lay out, only the reason.
      toaster(qc.notes);
      return;
    }

    await QcResultDialog.show(
      status: qc.status,
      checks: [
        for (final check in qc.checks)
          QcDialogCheck(
            label: check.label,
            detail: check.shown,
            passed: check.passed,
          ),
      ],
    );
  }

  Future<void> runQc(Take take) async {
    if (!await File(take.audioPath).exists()) {
      toaster('The audio for this take is not on this device.');
      return;
    }

    QcOutcome? checked;
    var lostFinal = false;

    await withBusy('Checking audio...', () async {
      final qc = await QcService.run(
        take.audioPath,
        expectedDurationSeconds: await _sourceDurationSeconds(),
      );
      checked = qc;

      // Nothing was measured - the file could not be read - so nothing is
      // recorded against the take, as on the website. Writing "failed" here
      // would strip a Final mark because of a decoder, not the recording.
      if (qc.error != null) return;

      lostFinal = await TakeRepository.setQc(
        takeId: take.id,
        setId: set.id,
        passed: qc.passed,
        notes: qc.notes,
        report: qc.report,
      );
    });

    await _showQc(checked);

    // After the report, which says why: the take they had chosen is no
    // longer the passage's answer, and the Set cannot go on without one.
    if (lostFinal) {
      toaster(
        'This take is no longer Final - it did not pass QC this time. '
        'Mark another take Final, or record a new one.',
      );
    }
  }

  /// How long the source recording runs, when this device has it.
  ///
  /// The duration check measures a take against the reading it translates, so
  /// without the source there is nothing to measure against and the check
  /// stands down rather than guessing at a length.
  Future<double?> _sourceDurationSeconds() async {
    final path = leaf.sourceAudioPath;
    if (path.isEmpty || !await File(path).exists()) return null;

    // Only the length is wanted, and a WAV says its length in its header.
    // Loading the source through the waveform cache decoded the whole
    // recording for its bars first - and waited its turn behind every
    // other waveform being drawn - which was most of "Checking audio...".
    final duration = await WaveformCache.duration(path);
    if (duration <= Duration.zero) return null;

    return duration.inMilliseconds / 1000;
  }

  Future<void> makeFinal(Take take) async {
    if (!take.passedQc) {
      toaster('Only a take graded Good can be made Final.');
      return;
    }
    // Asked here as well as inside the save, so the reason is said in the
    // server's own words rather than as "something went wrong".
    final blocked = await TakeRepository.finalBlockedReason(
      setId: set.id,
      takeId: take.id,
      leafType: leaf.type,
      leafId: leaf.id,
    );
    if (blocked != null) {
      toaster(blocked);
      return;
    }

    await withBusy('Saving...', () async {
      await TakeRepository.finalizeTake(
        takeId: take.id,
        setId: set.id,
        leafType: leaf.type,
        leafId: leaf.id,
      );
    });
    await _hintAfterFirstFinal();
    _armIdleHint();
  }

  Future<void> unfinalize(Take take) async {
    final confirmed = await ConfirmDialog.ask(
      message:
          'Remove Final from this take? You can mark a different one Final '
          'afterward.',
      confirmLabel: 'Yes',
    );
    if (!confirmed) return;

    await withBusy('Saving...', () async {
      await TakeRepository.unfinalizeTake(takeId: take.id, setId: set.id);
    });
  }

  Future<void> deleteTake(Take take) async {
    if (take.id == finalTakeId.value) {
      toaster('Unmark it as final before deleting it.');
      return;
    }

    final confirmed = await ConfirmDialog.ask(
      message: 'Remove this take? This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );

    if (!confirmed) return;

    await withBusy('Deleting...', () async {
      await TakeRepository.deleteTake(takeId: take.id, setId: set.id);
    });
  }

  /// Every write goes through here so the screen is locked while it runs and
  /// always reloads from sqflite afterwards, rather than trusting local state
  /// to have stayed in step.
  Future<void> withBusy(String label, Future<void> Function() action) async {
    isBusy.value = true;
    busyLabel.value = label.tr;
    try {
      await action();
      await load();
    } catch (e) {
      toaster('Something went wrong: @error'.trParams({'error': '$e'}));
    } finally {
      isBusy.value = false;
    }
  }
}

/// Recording and QC for one passage — the screen the whole offline write path
/// exists to serve.
class LeafRecorderPage extends StatelessWidget {
  const LeafRecorderPage({
    super.key,
    required this.set,
    required this.leaves,
    this.startIndex = 0,
    this.startOnTakes = false,
  });

  /// Whether to open on the passage's takes rather than its recorder.
  final bool startOnTakes;

  final WorkSet set;

  /// The Set's passages in reading order. The page walks them itself rather
  /// than being pushed once per passage, so the arrows can step forward and
  /// back without stacking routes - and so leaving at either end returns to
  /// the Set exactly once.
  final List<SetLeaf> leaves;

  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LeafRecorderController>(
      // Page-scoped: created with this route and disposed with it, so the
      // recorder and its players are released when the passage is left.
      init: LeafRecorderController(
        set: set,
        leaves: leaves,
        startIndex: startIndex,
        startOnTakes: startOnTakes,
      ),
      global: false,
      // GetBuilder, not GetX: the Scaffold is built once and each piece of
      // it watches its own state. Recording a take must not rebuild the
      // page - the live waveform and the take players live in it.
      builder: (controller) {
        final page = Scaffold(
          backgroundColor: MainApp.pageBackground,
          appBar: AppBar(
            leading: IconButton(
              onPressed: controller.goUp,
              icon: const Icon(Icons.arrow_back),
            ),
            title: Obx(() => _title(controller)),
            // One dot per passage, the current one drawn long, under the
            // title where the eye goes for "where am I": what the arrows
            // used to say by floating over the page.
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(_dotsHeight),
              child: Obx(() => _dots(controller)),
            ),
            // Held while a take is being recorded or saved: leaving then
            // would abandon it half-written, the same reason the passage
            // arrows stop working.
            actions: [
              Obx(
                () => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: AppBarActions.build(
                    nameToggle: false,
                    enabled: controller.canNavigate,
                  ),
                ),
              ),
            ],
          ),
          body: Obx(
            () => controller.isLoading.value
                ? const SafeArea(child: RecorderSkeleton())
                : Stack(
                    children: [
                      Positioned.fill(
                        // A swipe across the page steps through the Set:
                        // forward to the takes and the next passage, back
                        // to the recorder and the passage before. A drag
                        // that starts on a waveform or a scrolling row
                        // still belongs to it - the inner gesture wins -
                        // so only a swipe on the scripts, the slots or
                        // the blank page moves on.
                        child: Listener(
                          // Every touch restarts the idle clock behind the
                          // swipe hint, and takes the hint down.
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) => controller.touched(),
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: (_) => _swipeDistance = 0,
                            onHorizontalDragUpdate: (details) =>
                                _swipeDistance += details.delta.dx,
                            onHorizontalDragEnd: (details) =>
                                _onSwipe(controller, details),
                            child: Obx(
                              () => controller.showingTakes.value
                                  ? _takesPane(controller)
                                  : _recordPane(controller),
                            ),
                          ),
                        ),
                      ),
                      // Its own layer: putting the dim up does not rebuild
                      // what is under it.
                      //
                      // Positioned on the outside, always. A Stack takes its
                      // size from its largest non-positioned child, and every
                      // other child here is positioned - so an Obx that
                      // collapsed to nothing would size the Stack to nothing
                      // and take the page with it.
                      Positioned.fill(
                        child: Obx(
                          () => controller.isBusy.value
                              ? _busyOverlay(controller)
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
          ),
        );

        // The same rule for the system gesture: from the takes it steps back
        // to the recorder, and only leaves the passage from there. The page
        // is built once above and handed in, so this does not redraw it.
        return Obx(
          () => PopScope(
            canPop: !controller.showingTakes.value,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              controller.goUp();
            },
            // The swipe hint dims the whole screen, app bar included, so
            // it sits over the Scaffold rather than inside its body.
            child: Stack(
              children: [
                page,
                Positioned.fill(
                  child: Obx(
                    () => controller.showSwipeHint.value
                        ? SwipeHint(onDone: controller.hintDone)
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The passage, and where it sits in the Set.
  Widget _title(LeafRecorderController controller) {
    final leaf = controller.leaf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          controller.showingTakes.value
              ? '@passage - Takes'.trParams({'passage': leaf.label})
              : leaf.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        Text(
          // Where this passage sits in the Set, so the arrows have somewhere
          // to count from. The verse range keeps its place beside it - it is
          // what tells the drafter what to read.
          [
            '${controller.currentIndex.value + 1} / '
                '${controller.leaves.length}',
            if (leaf.verseRange.isNotEmpty) leaf.verseRange,
          ].join('  -  '),
          style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
        ),
      ],
    );
  }

  /// A swipe across the page. Forward is a finger moving towards the
  /// start of the screen - the page is always laid out left to right,
  /// whatever the language - so a swipe to the left goes on and one to
  /// the right goes back, the way pages turn in a reader.
  void _onSwipe(LeafRecorderController controller, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _swipeDistance;
    _swipeDistance = 0;
    // A quick flick, or a slow drag far enough to be meant: either turns
    // the page. A short wobble does nothing.
    final flick = velocity.abs() >= _swipeVelocity;
    final drag = distance.abs() >= _swipeDistanceMin;
    if (!flick && !drag) return;
    // Forward is wherever reading runs to, as the arrows were: a finger
    // moving left in English and Hindi, moving right in Urdu, where the
    // next page lies to the left and is pulled in from there.
    final towardsStart = flick ? velocity < 0 : distance < 0;
    final forward = AppLocale.isRtl ? !towardsStart : towardsStart;
    debugPrint(
      'SWIPE ${forward ? 'forward' : 'back'} '
      '(v=${velocity.round()}, dx=${distance.round()})',
    );
    if (forward) {
      controller.goForward();
    } else {
      controller.goBack();
    }
  }

  /// Slower than this is a wobble, not a flick.
  static const double _swipeVelocity = 250;

  /// Shorter than this is a wobble, not a drag.
  static const double _swipeDistanceMin = 80;

  /// How far the finger has moved across the page in the current drag.
  /// Page-level, as the page is: one recorder is on screen at a time.
  static double _swipeDistance = 0;

  static const double _dotsHeight = 18;

  /// Where this passage sits in the Set, as a row of dots: one per
  /// passage, the current one drawn as a bar, and half of it filled while
  /// the recorder is showing - its takes are the second half of the same
  /// step. The bar takes the colour of the step the drafter is being
  /// walked towards, as the arrows used to pulse: blue for on, red for
  /// back to the recorder when every take has failed.
  Widget _dots(LeafRecorderController controller) {
    final takes = controller.takes;
    final onTakes = controller.showingTakes.value;
    final noFinal = controller.finalTakeId.value == null;
    final needsQc = noFinal && takes.any((take) => !take.hasQcReport);
    final allBad = takes.isNotEmpty && controller.needsNewTake;

    Color? hint;
    if (controller.isDraftingStage && controller.canNavigate) {
      if (onTakes && allBad) {
        hint = _stepRed;
      } else if (onTakes
          ? controller.finalTakeId.value != null
          : needsQc) {
        hint = _stepBlue;
      }
    }

    final current = controller.currentIndex.value;
    final count = controller.leaves.length;

    return SizedBox(
      height: _dotsHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 22 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: i == current
                    ? (hint ?? MainApp.primaryGreen)
                    : const Color(0xFFD1D5DB),
                // Half a bar for the recorder, the whole of it on the
                // takes: the two halves of one passage.
                gradient: i == current && !onTakes
                    ? LinearGradient(
                        colors: [
                          hint ?? MainApp.primaryGreen,
                          hint ?? MainApp.primaryGreen,
                          (hint ?? MainApp.primaryGreen).withValues(
                            alpha: 0.3,
                          ),
                          (hint ?? MainApp.primaryGreen).withValues(
                            alpha: 0.3,
                          ),
                        ],
                        stops: const [0, 0.5, 0.5, 1],
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  static const Color _stepBlue = Color(0xFF1D6FD0);
  static const Color _stepRed = Color(0xFFDC2626);

  /// The recorder: one passage, one button, and what has been recorded so far.
  /// Under this height the passage panel cannot share the screen with the
  /// slots and the recorder - a phone on its side. The pane then scrolls
  /// as a whole, with the panel given a height of its own.
  static const double _splitMinHeight = 480;

  Widget _recordPane(LeafRecorderController controller) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxHeight >= _splitMinHeight;
            final children = _recordPaneChildren(controller, split: split);
            if (split) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              );
            }
            return ListView(children: children);
          },
        ),
      ),
    );
  }

  List<Widget> _recordPaneChildren(
    LeafRecorderController controller, {
    required bool split,
  }) {
    // The reviewers' comments are not listed here. They are pinned on
    // the takes they were made about, where they can be heard against
    // the recording - which is where the website keeps them too.
    return [
      // What the passage is. It takes whatever height is left and
      // scrolls inside it, so the drafter reads and records without
      // leaving the screen - or, on a short screen, a height of its
      // own inside the scrolling pane.
      _panelBox(
        split,
        // Its own window on the controller, so the ripple starting
        // and stopping redraws the panel and not the recorder.
        Obx(
          () => ReferencePanel(
            leaf: controller.leaf,
            onSourceAudioPlayed: () =>
                controller.openedSourceAudio.value = true,
            onSourceAudioEnded: controller.markSourceHeard,
            mustListenSource: controller.sourceListenOwed,
            // The boxes under the scripts. Offered only while the
            // drafter is at the point of recording a first take -
            // afterwards, and for a reviewer, the scripts are just
            // there to read.
            readConfirm: controller.isDraftingStage && controller.takes.isEmpty
                ? (
                    source: controller.readSource.value,
                    target: controller.readTarget.value,
                    // One step at a time, as the website walks it:
                    // the source box once the audio has been heard
                    // through, the target box once the source is
                    // ticked.
                    highlightSource:
                        controller.sourceHeardOrAbsent &&
                        controller.needsReadSource,
                    highlightTarget:
                        controller.sourceHeardOrAbsent &&
                        !controller.needsReadSource &&
                        controller.needsReadTarget,
                    onRead: (target) => controller.markRead(target: target),
                  )
                : null,
            // The mic is held until the source has been heard, and a
            // greyed button cannot say which other button would
            // release it. The ripple points at the one that would -
            // and moves on to the script boxes once it has played.
            highlightAudio:
                controller.isDraftingStage &&
                controller.leaf.hasSourceAudio &&
                controller.takes.isEmpty &&
                !controller.heardSourceInFull.value,
          ),
        ),
      ),
      const SizedBox(height: 8),
      // The strip sits between the passage and the button that
      // records it: what has been laid down so far is what a drafter
      // checks before deciding to go again.
      //
      // Watches the takes alone, so one finishing redraws the strip
      // and not the recorder below it.
      //
      // A copy of the list, read here: handed over as it is, the
      // list is only looked into inside the strip's own build, where
      // nothing is watching, and a new take left the strip as it was
      // until the page was opened again.
      Obx(
        () => _TakeSlots(
          takes: controller.takes.toList(),
          finalTakeId: controller.finalTakeId.value,
          onTap: () => controller.showingTakes.value = true,
        ),
      ),
      const SizedBox(height: 8),
      // Sized to its contents rather than stretched: idle it is a
      // button and a line of text, and every pixel it is not using
      // is one the source above it can read in.
      //
      _recordCard(controller),
    ];
  }

  Widget _panelBox(bool split, Widget panel) =>
      split ? Expanded(child: panel) : SizedBox(height: 360, child: panel);

  /// The card the mic sits in - or the live waveform, once it is running.
  Widget _recordCard(LeafRecorderController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // The live waveform lives in here. Only starting and stopping
      // rebuilds it; nothing else on the page can reach it.
      child: Obx(
        () => controller.isRecording.value
            ? _recordingView(controller)
            : _idleView(controller),
      ),
    );
  }

  Widget _recordingView(LeafRecorderController controller) {
    // One line, matching the idle card it replaces: the clock takes the
    // place of the prompt, the live waveform runs where the words were, and
    // the button stays in the corner it was already in. Nothing moves when
    // recording starts except what is being said.
    return Row(
      children: [
        RecordingTimer(
          fontSize: 13,
          stopwatch: controller.recordingClock,
          color: controller.isPaused.value
              ? const Color(0xFFB45309)
              : const Color(0xFFDC2626),
        ),
        const SizedBox(width: 12),
        Expanded(
          // Sound is drawn left to right in every language. The clock and
          // the buttons either side of it mirror with the idle card, so
          // nothing changes ends when recording starts.
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: LiveWaveform(
              recorder: controller.recorder,
              color: MainApp.primaryGreen,
              height: 40,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _MicButton(
          icon: controller.isPaused.value
              ? Icons.fiber_manual_record_rounded
              : Icons.pause_rounded,
          color: const Color(0xFFB45309),
          size: 48,
          onPressed: controller.isBusy.value
              ? null
              : controller.isPaused.value
              ? controller.resumeRecording
              : controller.pauseRecording,
        ),
        const SizedBox(width: 8),
        // Red while it records: stopping is the one thing left to do.
        PulseHalo(
          active: !controller.isBusy.value && !controller.isPaused.value,
          color: const Color(0xFFDC2626),
          minSize: 78,
          maxSize: 132,
          child: _MicButton(
            icon: Icons.stop_rounded,
            color: const Color(0xFFDC2626),
            onPressed: controller.isBusy.value
                ? null
                : controller.stopRecording,
          ),
        ),
      ],
    );
  }

  Widget _idleView(LeafRecorderController controller) {
    // Somebody else's stage: no recorder at all, just what this screen is for.
    if (!controller.isDraftingStage) {
      return Text(
        'Listen to the final take and mark anything that needs to change.'.tr,
        style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
      );
    }

    final denied = controller.micDenied.value;
    final blocked = controller.blockedReason;

    // What it will do, then the button - the mic in the right corner, where
    // a thumb already is, with the line beside it rather than under it now
    // that the heading above the card is gone.
    return Row(
      children: [
        Expanded(
          child: Text(
            denied
                ? 'Microphone is off - tap to try again'.tr
                : blocked.isEmpty
                ? 'Tap to record a take'.tr
                : blocked.tr,
            style: TextStyle(
              fontSize: 12,
              color: denied ? const Color(0xFFDC2626) : MainApp.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 14),
        PulseHalo(
          // Everything before recording is done and nothing recorded so
          // far can be used: the ripple moves from the player and the boxes
          // to the mic, because reading the passage aloud is now the only
          // thing left to do. It goes once there is a take. Not asked of
          // the source audio itself - a passage with none has nothing to
          // hear, and its mic never pulsed.
          active:
              controller.canRecord &&
              !controller.isBusy.value &&
              controller.needsNewTake,
          // Starts clear of the button rather than on it: a disc the same
          // size as the control it sits behind shows nothing at all.
          minSize: 78,
          maxSize: 132,
          child: _MicButton(
            icon: Icons.mic,
            // Faded rather than hidden: the drafter has to be able to see
            // that the button is refused, and read why beside it.
            color: controller.canRecord
                ? MainApp.primaryGreen
                : const Color(0xFF9CA3AF),
            onPressed: controller.isBusy.value || !controller.canRecord
                ? null
                : controller.startRecording,
          ),
        ),
      ],
    );
  }

  /// Every take on this passage, which is the other half of the recorder.
  Widget _takesPane(LeafRecorderController controller) {
    final takes = controller.takes;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        children: [
          Row(
            children: [
              const Icon(
                Icons.layers_outlined,
                size: 16,
                color: Color(0xFF4B5563),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  takes.isEmpty
                      ? 'No takes yet'.tr
                      : 'All takes (@count/@max)'.trParams({
                          'count': '${takes.length}',
                          'max': '${LeafRecorderController.maxTakes}',
                        }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (takes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                'Nothing recorded on this passage yet. Step back to the '
                        'recorder to make the first take.'
                    .tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
              ),
            ),
          for (final slot in _orderTakes(takes, controller.finalTakeId.value))
            // Keyed by take id so the card keeps its state - and its place in
            // the element tree - when the order changes underneath it. That is
            // what lets the promoted take animate rather than blink into
            // position.
            _TakeSlot(
              key: ValueKey(slot.take.id),
              isFinal: slot.isFinal,
              child: _TakeCard(
                take: slot.take,
                marks: controller.commentsOn(slot.take),
                onMarkTap: controller.showComment,
                qaMarks: controller.disputedOn(slot.take),
                onQaTap: (question) =>
                    QaFeedbackSheet.show(Get.context!, question),
                index: slot.number,
                isFinal: slot.isFinal,
                blockedReason: slot.isFinal
                    ? null
                    : controller.finalBlocked[slot.take.id],
                // Until a take is Final, as on the website: QC on each
                // take still to be checked, the star on each that passed -
                // and neither on a take that was sent back.
                highlightQc:
                    controller.isDraftingStage &&
                    controller.finalTakeId.value == null &&
                    !slot.take.hasQcReport &&
                    controller.finalBlocked[slot.take.id] == null,
                highlightFinal:
                    controller.isDraftingStage &&
                    controller.finalTakeId.value == null &&
                    slot.take.passedQc &&
                    controller.finalBlocked[slot.take.id] == null,
                // Working on a take that already exists is not the same as
                // recording a new one: QC, finalizing and deleting are open
                // whenever the drafter holds the Set. Gating them on having
                // opened the source hid them completely on takes that came down
                // from the server, including the ones with no QC result yet.
                readOnly: !controller.isDraftingStage,
                onRunQc: () => controller.runQc(slot.take),
                onMakeFinal: () => controller.makeFinal(slot.take),
                onUnfinalize: () => controller.unfinalize(slot.take),
                onDelete: () => controller.deleteTake(slot.take),
              ),
            ),
          // Only once a reviewer has sent the Set back. On a first pass the
          // left arrow to the recorder is enough; this louder, centred button
          // is for "somebody rejected what is here - try again", and it is
          // light red rather than the full danger fill because it destroys
          // nothing, it only starts a fresh take. Refused, with the same
          // reason the recorder gives, once every slot is full.
          if (controller.set.workflowStatus == 'redo') ...[
            const SizedBox(height: 16),
            Center(
              child: PulseHalo(
                active: controller.needsNewTake && !controller.atTakeLimit,
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(10),
                child: _ReRecordButton(
                  onPressed: controller.atTakeLimit
                      ? () => toaster(
                          '@count takes is the limit - remove one on the Takes '
                                  'screen to record another.'
                              .trParams({
                                'count': '${LeafRecorderController.maxTakes}',
                              }),
                        )
                      : () => controller.showingTakes.value = false,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// The takes in the order they are shown: whichever one is Final first,
  /// then the rest newest first.
  ///
  /// [takes] arrives oldest first, which is where the numbers come from - the
  /// number is the take's place in the recording order, not on the screen, so
  /// Take 5 stays Take 5 when it is pinned to the top.
  List<({Take take, int number, bool isFinal})> _orderTakes(
    List<Take> takes,
    String? finalTakeId,
  ) {
    final ordered = [
      for (var i = takes.length - 1; i >= 0; i--)
        (take: takes[i], number: i + 1, isFinal: takes[i].id == finalTakeId),
    ];

    // Lifted out rather than sorted: Dart's sort is not promised to be
    // stable, and the newest-first order below the pinned take has to hold.
    final promoted = ordered.indexWhere((slot) => slot.isFinal);
    if (promoted > 0) ordered.insert(0, ordered.removeAt(promoted));

    return ordered;
  }

  Widget _busyOverlay(LeafRecorderController controller) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.25),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: MainApp.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(controller.busyLabel.value),
            ],
          ),
        ),
      ),
    );
  }
}

/// The record button, and the stop button it turns into.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.size = 64,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: onPressed == null ? 0 : 4,
      shadowColor: color.withValues(alpha: 0.5),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.47, color: Colors.white),
        ),
      ),
    );
  }
}

/// The passage's six take slots, filled from the left.
///
/// A count would say the same thing in fewer pixels, but not the same way:
/// six boxes show at a glance how much room is left and which take was
/// chosen, which is the question a drafter on take four is actually asking.
class _TakeSlots extends StatelessWidget {
  const _TakeSlots({
    required this.takes,
    required this.finalTakeId,
    required this.onTap,
  });

  final List<Take> takes;
  final String? finalTakeId;

  /// Opens the takes screen. The strip is the shortest route to it.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const max = LeafRecorderController.maxTakes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.format_list_numbered_rounded,
              size: 15,
              color: Color(0xFF4B5563),
            ),
            const SizedBox(width: 6),
            Text(
              'Takes recorded (@count/@max)'.trParams({
                'count': '${takes.length}',
                'max': '$max',
              }),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var slot = 1; slot <= max; slot++) ...[
              if (slot > 1) const SizedBox(width: 8),
              Expanded(child: _slot(slot)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _slot(int slot) {
    // Slots fill in recording order, so slot 3 is take 3 - the same number
    // the takes screen gives it.
    final take = slot <= takes.length ? takes[slot - 1] : null;
    final isFinal = take != null && take.id == finalTakeId;

    final Color background;
    final Color foreground;
    final Color border;

    if (isFinal) {
      background = const Color(0xFF1E8E3E);
      foreground = Colors.white;
      border = const Color(0xFF1E8E3E);
    } else if (take != null) {
      background = const Color(0xFFE7F6EC);
      foreground = const Color(0xFF1E8E3E);
      border = const Color(0xFFB7E1C4);
    } else {
      background = Colors.white;
      foreground = const Color(0xFF9CA3AF);
      border = const Color(0xFFE5E7EB);
    }

    // A fixed height rather than a square: six squares across a phone on
    // its side were each as tall as the whole script panel had left.
    return GestureDetector(
      onTap: take == null ? null : onTap,
      child: SizedBox(
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Center(
            child: take == null
                ? Text(
                    '$slot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  )
                : Icon(
                    isFinal ? Icons.star_rounded : Icons.check_rounded,
                    size: 18,
                    color: foreground,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The QC report, folded away until asked for.
///
/// Six passing checks are six lines of reassurance nobody reads; the one
/// that failed is the whole reason to open it. So the card shows the verdict
/// and keeps the detail one tap away.
class _QcReport extends StatelessWidget {
  const _QcReport({required this.checks, required this.accent});

  final List<QcCheck> checks;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final failed = checks.where((check) => !check.passed).length;

    // ExpansionTile's header is a ListTile, which paints its ink splash on
    // the nearest Material ancestor - here the Scaffold, underneath the take
    // card's own white Container, where the splash would be hidden. Its own
    // transparent Material puts that surface above the card instead.
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 6),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          dense: true,
          visualDensity: VisualDensity.compact,
          title: Text(
            failed == 0
                ? 'QC details (@count checks)'.trParams({
                    'count': '${checks.length}',
                  })
                : '@failed of @count checks failed'.trParams({
                    'failed': '$failed',
                    'count': '${checks.length}',
                  }),
            style: TextStyle(fontSize: 12, color: accent),
          ),
          children: [
            for (final check in checks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      check.passed
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 14,
                      color: check.passed
                          ? const Color(0xFF1E8E3E)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            // Kept in English where it is stored and sent;
                            // put into the reader's language only here.
                            check.label.tr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (check.detail.isNotEmpty)
                            Text(
                              check.shown,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: MainApp.mutedText,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One round action on a take.
///
/// [filled] is for the action that changes something for good - deleting, or
/// the take that is now final. A solid disc reads as a commitment where a
/// tinted one reads as an offer.
class _TakeAction extends StatelessWidget {
  const _TakeAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.filled = false,
    this.unavailable = false,
    this.highlight = false,
    this.highlightColor,
  });

  /// Whether this is the next thing to do to the take.
  final bool highlight;
  final Color? highlightColor;

  final IconData icon;
  final String tooltip;
  final Color color;
  final bool filled;

  /// Drawn faint, as something that cannot be done to this take. It still
  /// answers a tap - with the reason - because a button that does nothing
  /// at all reads as broken.
  final bool unavailable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip.tr,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 6),
        child: PulseHalo(
          active: highlight && !unavailable,
          color: highlightColor ?? color,
          minSize: 34,
          maxSize: 66,
          child: _button(),
        ),
      ),
    );
  }

  Widget _button() {
    return Builder(
      builder: (context) => SizedBox(
        child: Material(
          color: unavailable
              ? const Color(0xFFF7F7F8)
              : filled
              ? color
              : const Color(0xFFF1F2F4),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 19,
                color: unavailable
                    ? const Color(0xFFD1D5DB)
                    : filled
                    ? Colors.white
                    : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One take's place in the list, and the move it makes when it is chosen.
///
/// Marking a take Final lifts it above the others. Done without warning that
/// reads as the list flickering, so the promoted card slides up into its new
/// place and brightens as it lands - the eye follows the take it just chose
/// instead of hunting for where everything went.
class _TakeSlot extends StatefulWidget {
  const _TakeSlot({super.key, required this.isFinal, required this.child});

  final bool isFinal;
  final Widget child;

  @override
  State<_TakeSlot> createState() => _TakeSlotState();
}

class _TakeSlotState extends State<_TakeSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 420),
    vsync: this,
    // Settled by default: a take that is already Final when the screen opens
    // has not just moved, and should not perform.
    value: 1,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    // Its own height and a bit, coming up from where it used to sit.
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  late final Animation<double> _fade = Tween<double>(
    begin: 0.35,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    // Touched here so the controller is made while the widget is in the
    // tree. Left to its lazy initializer it could first be built by
    // `dispose()`, where `vsync: this` is no longer allowed to look upward.
    _controller;
  }

  @override
  void didUpdateWidget(_TakeSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the move upward is worth animating. Un-finalizing sends the card
    // back down among the others, which needs no announcing.
    if (widget.isFinal && !oldWidget.isFinal) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(opacity: _fade, child: widget.child),
      ),
    );
  }
}

class _TakeCard extends StatelessWidget {
  const _TakeCard({
    required this.take,
    required this.index,
    required this.isFinal,
    required this.readOnly,
    required this.onRunQc,
    required this.onMakeFinal,
    required this.onUnfinalize,
    required this.onDelete,
    this.marks = const [],
    this.onMarkTap,
    this.qaMarks = const [],
    this.onQaTap,
    this.blockedReason,
    this.highlightQc = false,
    this.highlightFinal = false,
  });

  /// Community questions whose answers were disliked, pinned where they
  /// were asked. Red until a new take is put forward.
  final List<CommunityQuestion> qaMarks;
  final ValueChanged<CommunityQuestion>? onQaTap;

  /// Whether running QC, or making this take Final, is the next step.
  final bool highlightQc;
  final bool highlightFinal;

  final Take take;

  /// Why this take may not be made Final - it was sent back - or null
  /// when it may.
  final String? blockedReason;

  /// Reviewers' comments pinned to this take, drawn on its waveform.
  final List<TakeComment> marks;
  final ValueChanged<TakeComment>? onMarkTap;
  final int index;
  final bool isFinal;
  final bool readOnly;
  final VoidCallback onRunQc;
  final VoidCallback onMakeFinal;
  final VoidCallback onUnfinalize;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // The report's own verdict, wherever there is one: Average and Bad are
    // different results, and "not run" is a third thing again. A take that
    // passed elsewhere without a report still reads as Good.
    final (statusLabel, statusColor) = switch ((
      take.status,
      take.qcSummary.toLowerCase(),
    )) {
      (_, 'good') || ('passed_qc', _) => ('Good', const Color(0xFF1E8E3E)),
      (_, 'average') => ('Average', const Color(0xFFB45309)),
      (_, 'bad') => ('Bad', const Color(0xFFDC2626)),
      ('trashed', _) => ('Deleted'.tr, const Color(0xFF4B4870)),
      _ => ('Not run'.tr, const Color(0xFF4B4870)),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
        border: isFinal
            ? Border.all(color: const Color(0xFF1E8E3E), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Take @index'.trParams({'index': '$index'}),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        if (isFinal) ...[
                          const SizedBox(width: 8),
                          const _Tag(label: 'Final', color: Color(0xFF1E8E3E)),
                        ],
                        // The take a reviewer sent back. It cannot be
                        // picked again; the reason is under the buttons.
                        if (take.wasSentBack || blockedReason != null) ...[
                          const SizedBox(width: 6),
                          const _Tag(
                            label: 'Sent back',
                            color: Color(0xFFDC2626),
                          ),
                        ],
                        if (take.isLocal) ...[
                          const SizedBox(width: 6),
                          const _Tag(
                            label: 'Not synced',
                            color: Color(0xFFB45309),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // The clip below shows the running time, so this line
                    // carries only the QC verdict.
                    _Tag(
                      label: 'QC: @status'.trParams({'status': statusLabel}),
                      color: statusColor,
                    ),
                  ],
                ),
              ),
              // The three things worth doing to a take, on the take itself.
              // They were behind a menu, which hid the QC check that decides
              // whether a take is usable at all.
              if (!readOnly) ...[
                _TakeAction(
                  // Says audio quality in one glyph. The chart it showed
                  // before read as statistics about the take rather than a
                  // verdict on how it sounds, which is what QC gives.
                  icon: Icons.manage_search_rounded,
                  tooltip: take.hasQcReport ? 'Run QC again' : 'Run QC',
                  // Blue while there is no report: this is the one button
                  // that has something left to do on the take.
                  color: take.hasQcReport
                      ? const Color(0xFF374151)
                      : const Color(0xFF1D6FD0),
                  highlight: highlightQc,
                  onPressed: onRunQc,
                ),
                _TakeAction(
                  icon: Icons.star_rounded,
                  tooltip: isFinal
                      ? 'Remove final'
                      : blockedReason != null
                      ? 'This take cannot be made Final'
                      : 'Make final',
                  // Filled and green once it is the final take, so the card
                  // says which one was chosen without reading the tag.
                  color: isFinal
                      ? const Color(0xFF1E8E3E)
                      : const Color(0xFF4B4870),
                  filled: isFinal,
                  unavailable: !isFinal && blockedReason != null,
                  highlight: highlightFinal && !isFinal,
                  highlightColor: MainApp.primaryGreen,
                  onPressed: isFinal ? onUnfinalize : onMakeFinal,
                ),
                _TakeAction(
                  icon: Icons.delete_rounded,
                  tooltip: 'Delete take',
                  color: const Color(0xFFDC2626),
                  filled: true,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          // Said on the card, and left there: as a message that fades it
          // was gone before it had been read, and the star beside it went
          // on looking like something to press.
          if (!readOnly && !isFinal && blockedReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 16,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      blockedReason!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Keyed by take id so a rebuild after QC or finalizing does not
          // tear down the player and re-extract the waveform.
          AudioClip(
            key: ValueKey(take.id),
            filePath: take.audioPath,
            allowSeek: true,
            // A red bubble at the moment each reviewer stopped, as on the
            // website - grey once the comment is resolved. Tapping one
            // says who and what.
            marks: [
              for (final comment in marks)
                ClipMark(
                  id: comment.id,
                  positionSeconds: comment.positionSeconds!,
                  color: comment.isOpen
                      ? MarkColors.comment
                      : MarkColors.resolved,
                  icon: Icons.wechat_rounded,
                ),
              for (final question in qaMarks)
                ClipMark(
                  id: 'qa-${question.id}',
                  positionSeconds: question.positionSeconds!,
                  color: MarkColors.comment,
                  icon: Icons.wechat_rounded,
                ),
            ],
            onMarkTap: (mark) {
              if (mark.id.startsWith('qa-')) {
                final id = mark.id.substring(3);
                final question = qaMarks.where((q) => q.id == id).firstOrNull;
                if (question != null) onQaTap?.call(question);
                return;
              }
              final comment = marks.where((c) => c.id == mark.id).firstOrNull;
              if (comment != null) onMarkTap?.call(comment);
            },
          ),
          if (take.qcChecks.isNotEmpty)
            _QcReport(checks: take.qcChecks, accent: statusColor)
          // A take checked where no report was kept still has its notes,
          // which are better than nothing to go on.
          else if (take.qcNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                take.qcNotes,
                style: TextStyle(fontSize: 11, height: 1.4, color: statusColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.tr,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Back to the recorder from the takes of a sent-back passage.
class _ReRecordButton extends StatelessWidget {
  const _ReRecordButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Text(
                'Re-record'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
