import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/download_problems_dialog.dart';
import 'package:livuka/Widgets/slide_to_sync.dart';
import 'package:livuka/Widgets/sync_toast.dart';
import 'package:livuka/services/account_access.dart';
import 'package:livuka/main.dart';
import 'package:livuka/pages/feedback_page.dart';
import 'package:livuka/pages/manual_page.dart';
import 'package:livuka/pages/stage_sets_page.dart';
import 'package:livuka/pages/sync_status_page.dart';
import 'package:livuka/services/data_collection.dart';
import 'package:livuka/services/network_watch.dart';
import 'package:livuka/services/recording_rescue.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/sync_service.dart';
import 'package:livuka/services/sign_out.dart';
import 'package:livuka/services/work_queue.dart';
import 'package:livuka/Widgets/brand_hero.dart';

class HomeController extends GetxController {
  final stages = <WorkStage>[].obs;
  final isLoading = true.obs;

  /// Opens the settings drawer from the app bar.
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Rows this device has written or changed since the last data load.
  final unsent = 0.obs;
  final isSending = false.obs;

  /// Sets whose work the server refused last time. Shown on the app bar so
  /// a failure is never something only a vanished toast knew about.
  final problems = 0.obs;

  /// What the send is doing right now - it has two halves, and the second
  /// one can take as long as the first when the server has new audio.
  final busyLabel = ''.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(NetworkWatch.start());
    _recoverRecording().then((_) => loadStages());
  }

  /// A take that was being recorded when the app last died, put back.
  Future<void> _recoverRecording() async {
    final passage = await RecordingRescue.recover();
    if (passage == null) return;

    toaster(
      passage.isEmpty
          ? 'A recording that was interrupted has been recovered. You will '
                'find it among the takes.'
          : 'A recording that was interrupted has been recovered for '
                    '@passage. You will find it among the takes.'
                .trParams({'passage': passage}),
    );
  }

  Future<void> loadStages() async {
    isLoading.value = true;
    try {
      await _readCounts();
    } catch (e) {
      debugPrint('WORKBENCH LOAD ERROR: $e');
      stages.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// The same read without the full-screen spinner.
  ///
  /// Coming back from a Set is the commonest way the numbers go stale - a
  /// take recorded in there is a change waiting to be sent, and the button
  /// said nothing about it until the user thought to pull the page down. The
  /// counts should be right on return, but the workbench should not blink to
  /// say so.
  Future<void> refreshCounts() async {
    try {
      await _readCounts();
    } catch (e) {
      debugPrint('WORKBENCH REFRESH ERROR: $e');
    }
  }

  /// Which read is the latest. Two can overlap - the Home button and the
  /// tile that was opened both ask on the way back - and the one that
  /// started first must not be the one that has the last word.
  int _reading = 0;

  Future<void> _readCounts() async {
    final mine = ++_reading;

    // The stages and the send button first: they are quick, and they are
    // what work done in a Set has just changed. The feedback tile keeps
    // what it said until its own, slower read comes back.
    final counted = await WorkQueue.stageCounts();
    if (mine != _reading) return;
    final feedback = WorkQueue.feedbackStage.status;
    stages.value = [
      ...counted,
      ...stages.where((stage) => stage.meta.status == feedback),
    ];

    unsent.value = await SyncService.pendingCount();
    problems.value = (await SyncService.problems()).length;

    final praised = await WorkQueue.feedbackStageCount();
    if (mine != _reading) return;
    stages.value = [...counted, ?praised];
  }

  /// Sends this device's work to the server, and fetches what is new -
  /// when the user asks for it, and at no other time.
  ///
  /// This is the ONLY place the app talks to the server after sign-in.
  /// Nothing goes up or comes down on a timer, on resume, on a connection
  /// returning, or from any other screen: a drafter in the field decides
  /// when their work leaves the phone, and a data load that starts under a
  /// screen somebody is recording on pulls the passage out from under them.
  Future<void> sendUpdates() async {
    if (isSending.value) return;

    if (!await hasInternet()) {
      // Not "no connection" but "no account": the probe found the user
      // shut out, handed in their work and signed them out. Nothing to say
      // on a screen that is no longer theirs.
      if (!SessionService.isLoggedIn) return;
      toaster(
        'Not sent. Your work stays on this phone until there is a '
        'connection.',
      );
      return;
    }

    isSending.value = true;
    busyLabel.value = 'Sending...'.tr;

    // Acted on after the try below has let go of the screen: the lockout
    // wipes the phone and leaves this page, and the finally clause must not
    // run against a device that has already been emptied under it.
    AccountLockout? lockout;

    try {
      // Asked first, so a Set that changed hands while this phone was out of
      // signal is caught before anything is sent over the top of it.
      busyLabel.value = 'Checking with the server...'.tr;
      final Map<String, dynamic>? snapshot;
      try {
        snapshot = await DataCollection.fetch();
      } on AccountLockedOut catch (e) {
        lockout = e.lockout;
        return;
      }

      final result = await SyncService.send(
        serverSnapshot: snapshot,
        onProgress: (label) => busyLabel.value = label,
      );
      // With no work to send, the send above stops short of the logs.
      if (result.isEmpty) await SyncService.sendLogs();

      // Straight back the other way, whatever happened. The server may have
      // work from the web or from another phone, and what was just accepted
      // comes back with its real ids. Rows still unsent are held back, and a
      // recording already on the phone is kept rather than fetched again.
      busyLabel.value = 'Checking for updates...'.tr;
      final refresh = await DataCollection.refresh(
        onProgress: (label) => busyLabel.value = label,
        askAboutFailed: DownloadProblemsDialog.ask,
      );
      if (refresh.lockout != null) {
        lockout = refresh.lockout;
        return;
      }
      await refreshCounts();

      final got = !refresh.ok
          ? 'The update check failed: @reason'.trParams({
              'reason': refresh.message.tr,
            })
          : refresh.newFiles == 0
          ? 'Nothing new to download.'.tr
          : (refresh.newFiles == 1
                    ? 'Downloaded @count new file.'
                    : 'Downloaded @count new files.')
                .trParams({'count': '${refresh.newFiles}'});

      // The round trip's report. Not the moment's toast every other message
      // gets: a card at the foot of the screen that waits to be read.
      if (result.isEmpty) {
        SyncToast.show(
          refresh.ok && refresh.newFiles == 0
              ? 'Everything is up to date.'.tr
              : got,
        );
        return;
      }

      final sent = result.rows == 0 ? '' : _sentSummary(result);

      // Whole sentences, each translated as one, set side by side.
      if (result.sent) {
        SyncToast.show([sent, got].where((part) => part.isNotEmpty).join(' '));
        return;
      }

      // Not everything went. Nothing is lost - it is still on the phone -
      // and the reason is worth more than a toast that fades, so the status
      // screen opens on it.
      final notSent = result.failedSets == 0
          ? 'Not sent.'.tr
          : (result.failedSets == 1
                    ? '@count Set was not sent.'
                    : '@count Sets were not sent.')
                .trParams({'count': '${result.failedSets}'});
      toaster(
        [
          sent,
          notSent,
          result.message.tr,
        ].where((part) => part.isNotEmpty).join(' '),
      );
      if (result.failedSets > 0) {
        Get.to(() => const SyncStatusPage());
      }
    } catch (e) {
      debugPrint('SEND FAILED: $e');
      toaster('Not sent. Something went wrong. Your work is still here.');
    } finally {
      isSending.value = false;
      busyLabel.value = '';
      problems.value = (await SyncService.problems()).length;
    }

    // The account has been shut out of the app - made inactive, or its app
    // access switched off - since sign-in. The website refuses every
    // download from here on, and still takes the work: so it is handed in,
    // the user is signed out, and the phone is emptied.
    if (lockout != null) {
      isLoading.value = true;
      await AccountAccess.lockOut(lockout);
      stages.clear();
    }
  }

  /// "Sent 3 changes and 1 recording." - one sentence per shape, because
  /// neither the plural nor the "and" falls in the same place in Urdu or
  /// Hindi.
  String _sentSummary(SyncResult result) {
    final oneRow = result.rows == 1;
    final key = result.files == 0
        ? (oneRow ? 'Sent @rows change.' : 'Sent @rows changes.')
        : result.files == 1
        ? (oneRow
              ? 'Sent @rows change and @files recording.'
              : 'Sent @rows changes and @files recording.')
        : (oneRow
              ? 'Sent @rows change and @files recordings.'
              : 'Sent @rows changes and @files recordings.');

    return key.trParams({'rows': '${result.rows}', 'files': '${result.files}'});
  }

  /// Everything this screen shows comes from sqflite, so a refresh is a
  /// re-read. Nothing is sent anywhere: sending is a deliberate act, and the
  /// screen that will do it does not exist yet.
  Future<void> refreshAll() => loadStages();

  /// Signing out leaves the work where it is.
  ///
  /// The phone is one person's, and the sign-in asked for at every start is
  /// the lock on it - so leaving need not cost the Sets, the recordings or
  /// the scripts, which would only have to come down again. They are let go
  /// of when somebody else signs in, which is the one moment it is certain
  /// they are not wanted.
  Future<void> logout() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Sign out'.tr),
        content: Text('Are you sure you want to sign out?'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: Text('Sign Out'.tr),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // The stages are left standing: the page is still on screen while the
    // files are secured, and an emptied workbench read as work gone.
    IdleLogout.instance.stop();
    await SignOut.run();
  }
}

/// Sends the device's work, and says how much is waiting.
///
/// Nothing uploads on its own, so this is the only way work leaves the phone
/// - which makes the count part of the button rather than a detail
/// elsewhere: a drafter should be able to see there is something to send
/// without opening anything.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    // Its own Obx. The count and the spinner are read here, in this widget's
    // build, which runs after the parent's Obx builder has returned - so the
    // parent was never told it depended on them, and the button only caught
    // up when something else forced the whole page to rebuild.
    return Obx(() {
      final waiting = controller.unsent.value;
      final sending = controller.isSending.value;

      // The same control does both errands, and says which one it is about
      // to run. With work waiting it sends; with nothing waiting the only
      // thing left to do is ask the server whether it has anything for us -
      // which is worth offering, since a phone that was out of signal at
      // sign-in has nothing to send and everything to fetch.
      final hasWork = waiting > 0;

      // Not offered where it cannot be done. With no network on the phone
      // the slide could only end in "Not sent", so it is not there to be
      // slid - and comes back by itself when a network does. What is
      // waiting is still said: that there is work on the phone which has
      // gone nowhere is worth knowing most of all when it cannot go.
      if (!NetworkWatch.online.value && !sending) {
        if (!hasWork) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 16,
                color: MainApp.mutedText,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  (waiting == 1
                          ? 'No network. @count change is waiting to be sent.'
                          : 'No network. @count changes are waiting to be '
                                'sent.')
                      .trParams({'count': '$waiting'}),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
        child: SlideToSync(
          label: hasWork
              ? 'Send (@count)'.trParams({'count': '$waiting'})
              : 'Check for updates'.tr,
          busy: sending,
          busyLabel: controller.busyLabel.value.isEmpty
              ? 'Sending...'
              : controller.busyLabel.value,
          onComplete: controller.sendUpdates,
        ),
      );
    });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<HomeController>()) {
      Get.put(HomeController());
    }

    final controller = Get.find<HomeController>();
    final screenWidth = MediaQuery.of(context).size.width;

    // A send is two requests and a database write, and it carries audio: it
    // can run for minutes. Leaving the screen part way through would strand
    // it - the upload would keep going with nobody to hear the result, and
    // the refresh that follows rewrites the tables the next screen is about
    // to read. So while it runs, the screen is held: no back gesture, no
    // taps through to anything behind the overlay.
    // Built once, outside the Obx, and handed to it. The same widget
    // instance going back in is one Flutter skips rebuilding, so starting a
    // send raises the sheet without redrawing the workbench under it.
    final workbench = _scaffold(context, controller, screenWidth);

    return Obx(() {
      final sending = controller.isSending.value;

      return PopScope(
        canPop: !sending,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          toaster('Still sending. Please wait until this finishes.');
        },
        child: Stack(
          children: [workbench, if (sending) _sendingOverlay(controller)],
        ),
      );
    });
  }

  /// The blocking sheet over the workbench while a send runs.
  ///
  /// An overlay rather than disabling each control in turn: there are five
  /// ways off this screen - two app-bar icons, a stage card, pull to refresh,
  /// the back gesture - and one that was missed is one that strands the
  /// upload.
  ///
  /// Its own Material, because it hangs above the Scaffold rather than inside
  /// it. Without one there is no surface to raise the card off and no text
  /// style to inherit, which is why the heading came out in the framework's
  /// bare red.
  Widget _sendingOverlay(HomeController controller) {
    // The same dark screen and pulsing microphone as the data load after
    // sign-in. It is the same errand - the phone and the server catching up
    // with each other - and one picture for it, rather than a spinner in a
    // white card here and the mic there, says so.
    return Positioned.fill(
      child: Material(
        color: BrandBackdrop.base,
        child: BrandBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandHero(size: 200, verbs: false),
                  const SizedBox(height: 26),
                  Text(
                    // Translated on the way out as well: a label that came
                    // through untranslated showed here in English.
                    controller.busyLabel.value.isEmpty
                        ? 'Sending...'.tr
                        : controller.busyLabel.value.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep this screen open until it finishes.'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    HomeController controller,
    double screenWidth,
  ) {
    return Scaffold(
      key: controller.scaffoldKey,
      backgroundColor: MainApp.pageBackground,
      appBar: AppBar(
        // The mic belongs to this screen alone. Every other app bar names a
        // Set or a passage and has a back arrow in that corner; here there is
        // nothing to go back to, so the icon stands for the app itself.
        // Set in from the edge: with no back arrow on this bar, the title
        // would otherwise sit tight against the screen's edge.
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The app's own icon and wordmark, as the website's header has
            // them, in place of a mic and a long name.
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: SvgPicture.asset(
                'assets/brand/livuka-app-icon.svg',
                width: 28,
                height: 28,
              ),
            ),
            const SizedBox(width: 10),
            const BrandWordmark(fontSize: 21, onLight: true),
          ],
        ),
        actions: [
          // One way in rather than three icons side by side. The tables, the
          // account and signing out all live behind this, which leaves the
          // bar to say what the screen is.
          IconButton(
            tooltip: 'Settings'.tr,
            // The same panel every other page opens, so it comes in from the
            // same side everywhere. A Scaffold's own end drawer swaps sides
            // with the language.
            onPressed: AppBarActions.openSettings,
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 24,
              color: Color(0xFF040134),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Bottom left, floating over the stage cards. Sending is the one thing
      // on this screen that is not opening a stage, and it is done at the end
      // of a session rather than on the way in - so it sits where a thumb
      // rests, out of the way of the grid.
      // Across the foot of the screen rather than floating in a corner:
      // a drag needs the width, and a track a thumb can reach either end
      // of.
      bottomNavigationBar: SafeArea(child: _SendButton(controller: controller)),
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: controller.refreshAll,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Obx(() {
              // Tiles no wider than a palm: two across on a narrow phone,
              // three on a wide one, and more on a tablet rather than
              // three huge cards.
              final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: screenWidth < 420 ? 220 : 260,
                childAspectRatio: screenWidth < 420 ? 1.0 : 1.5,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              );
              // The first read, with nothing to show yet: grey tiles in the
              // grid's own shape under the real heading. A later read keeps
              // the tiles it has - pull to refresh already draws its own
              // ring, and a second ring in the middle said the same thing
              // twice.
              final firstLoad =
                  controller.isLoading.value && controller.stages.isEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A section label rather than a page title: the app bar
                  // above already names the app, and a second heading the
                  // size of one only pushed the work itself down the screen.
                  // Same icon-then-label shape as every other heading here.
                  Row(
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        size: 16,
                        color: MainApp.mutedText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Workbench'.tr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MainApp.titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: firstLoad
                        ? WorkbenchSkeleton(gridDelegate: gridDelegate)
                        : controller.stages.isEmpty
                        ? const _EmptyWorkbench()
                        : GridView.builder(
                            itemCount: controller.stages.length,
                            gridDelegate: gridDelegate,
                            itemBuilder: (context, index) =>
                                _StageCard(stage: controller.stages[index]),
                          ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({required this.stage});

  final WorkStage stage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: MainApp.cardShadowColor,
      surfaceTintColor: Colors.transparent,
      child: InkWell(
        // Named for the same reason as the Set route: a conditional page
        // gives GetX nothing but StatelessWidget to name the route after,
        // and two such routes look like one to its duplicate guard.
        onTap: () async {
          // The handbook, asked for anywhere inside this stage, opens at
          // this stage's chapter.
          ManualPage.stageSection = ManualPage.sectionForStatus(
            stage.meta.status,
          );
          await Get.to(
            routeName: '/stage/${stage.meta.status}',
            () => stage.meta.status == WorkQueue.feedbackStage.status
                ? const FeedbackPage()
                : StageSetsPage(stage: stage.meta, count: stage.count),
          );
          ManualPage.stageSection = null;
          // Work done in there changes both numbers on this screen.
          await Get.find<HomeController>().refreshCounts();
        },
        child: Stack(
          children: [
            // Any badge sits in the top-right corner, out of the way, and
            // the icon, name and count stay centred as on every other tile.
            // Beside the icon, "CC Checked" pushed the icon off centre and
            // left the tile looking lopsided next to its neighbours.
            if (stage.waitingSince case final since?)
              Positioned(
                top: 8,
                right: 8,
                child: _TileBadge(
                  text: WorkQueue.timeAgo(since),
                  color: stage.color,
                ),
              )
            else if (stage.meta.badge case final badge?)
              Positioned(
                top: 8,
                right: 8,
                child: _TileBadge(text: badge, color: stage.color),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: stage.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(stage.icon, size: 24, color: stage.color),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stage.label.tr,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.countLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MainApp.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small pill on a workbench tile, in the tile's own colour.
class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.tr,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Whether the device can reach the network right now.
///
/// Work is never blocked by being offline — it queues either way — so this is
/// there to answer "why hasn't my work gone up yet", not to stop anyone.
class _EmptyWorkbench extends StatelessWidget {
  const _EmptyWorkbench();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.info_outline, size: 32, color: MainApp.mutedText),
        const SizedBox(height: 10),
        Text(
          'Nothing assigned to you yet.\nAsk your admin.'.tr,
          textAlign: TextAlign.center,
          style: const TextStyle(color: MainApp.mutedText),
        ),
      ],
    );
  }
}
