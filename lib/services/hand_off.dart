import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/auto_send.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/take_repository.dart';
import 'package:livuka/services/work_queue.dart';

/// Moves a Set from one stage to the next - the one way any screen does it.
///
/// Every hand-off asks first, and some of them do more than change a status:
/// leaving peer check throws the rejected takes away, a community-review
/// send-back clears the final take the disliked answer was about, and a new
/// back translation closes the consultant's comments on the old one. Those
/// used to be the business of whichever screen happened to hold the button,
/// which is how one screen came to ask and the next did not.
///
/// Everything lands in sqflite and nowhere else. Only one person holds a Set
/// at a time, so there is nobody to disagree with: the change is made here
/// and sent when there is a signal to send it over.
class HandOff {
  HandOff._();

  /// Asks, moves the Set, and leaves the screen. False when the user said no
  /// or the write failed - the caller's buttons come back to life.
  static Future<bool> run({
    required WorkSet set,
    required StageAction action,

    /// Work that belongs to the stage being left and has to be written
    /// before the Set moves - the back translation being submitted.
    Future<void> Function()? beforeMove,
  }) async {
    if (!await ConfirmDialog.askStage(action)) return false;

    try {
      final from = set.workflowStatus;
      await beforeMove?.call();

      // Before the status changes: these read the Set as the stage it is
      // leaving, and a failure here must leave it where it was.
      if (!action.isSendBack && action.toStatus == 'community_setup') {
        await TakeRepository.trashUnusedTakes(setId: set.id);
        // A new community round starts with no questions.
        await TakeRepository.closeCommunityRound(setId: set.id);
      }

      // The drafter sending a round forward - to peer check, or straight
      // back to the back translator. The website's `sendToPeer`.
      final drafterSends =
          !action.isSendBack &&
          const {'not_started', 'recorded', 'redo'}.contains(from);
      if (drafterSends) {
        // Whatever was said about the last back translation was said about
        // the recording before this one.
        await TakeRepository.clearBackTranslationRound(setId: set.id);

        // The takes that lost - graded Average or Bad, or the one a
        // reviewer's comment was pinned to - go with it. Whatever the Set
        // resumes at, nobody will pick those again.
        await TakeRepository.trashLosingTakes(setId: set.id);

        // Resuming at back translation skips every stage that looks at
        // takes, so the attempts that were not chosen will never be opened
        // again. A restart at peer check keeps them: the peer may yet send
        // the Set back, and the drafter compares against them.
        if (action.toStatus == 'back_translation') {
          await TakeRepository.trashUnusedTakes(setId: set.id);
        }
      }
      if (action.isSendBack && from == 'community_review') {
        await TakeRepository.clearFinalsForReviewSendBack(setId: set.id);
      }
      if (action.isSendBack && (from == 'peer' || from == 'back_translation')) {
        await TakeRepository.clearFinalsForOpenComments(
          setId: set.id,
          stageKey: from,
        );
      }
      if (!action.isSendBack && action.toStatus == 'consultant') {
        await TakeRepository.resolveBackTranslationComments(setId: set.id);
      }

      await TakeRepository.transitionSet(
        setId: set.id,
        from: from,
        to: action.toStatus,
        sentBack: action.isSendBack,
      );
      await ActivityLog.record(
        action.isSendBack ? 'sent_back' : 'stage_moved',
        setId: set.id,
        details: {'from': from, 'to': action.toStatus},
      );

      // Back to the role's list first, as the website's redirect to
      // `workbench.role` does, so the next Set to work on is in view. Then
      // the message: on the desktop it is a dialog, and a plain "back"
      // after it closed that dialog and left the finished Set on screen.
      Get.until(
        (route) =>
            (route.settings.name?.startsWith('/stage/') ?? false) ||
            route.isFirst,
      );
      toaster(
        '@action - saved. It will be sent with your next sync.'.trParams({
          'action': action.label.tr,
        }),
      );
      // And sent now, when there is a signal - the next person should not
      // have to wait for a sync button to be slid.
      unawaited(AutoSend.instance.afterHandOff(action));
      return true;
    } catch (e) {
      debugPrint('HAND-OFF FAILED (${set.id} -> ${action.toStatus}): $e');
      toaster('Could not send it: @error'.trParams({'error': '$e'}));
      return false;
    }
  }
}
