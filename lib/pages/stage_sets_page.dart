import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/services/name_language.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/l10n/plural.dart';
import 'package:livuka/pages/back_translation_page.dart';
import 'package:livuka/pages/consultant_page.dart';
import 'package:livuka/pages/community_review_page.dart';
import 'package:livuka/pages/community_setup_page.dart';
import 'package:livuka/pages/community_test_page.dart';
import 'package:livuka/pages/set_detail_page.dart';
import 'package:livuka/services/work_queue.dart';

/// The Sets waiting at a stage, and which one is open.
class StageSetsController extends GetxController {
  StageSetsController(this.stage);

  final StageMeta stage;

  final isLoading = true.obs;
  final sets = <WorkSet>[].obs;
  final current = Rxn<WorkSet>();

  /// Recorded-passage counts for every Set in the queue, keyed by Set id.
  ///
  /// The picker and the card below it both read this. They used to disagree:
  /// the card counted the loaded leaves of whichever Set was open, and those
  /// arrive an await after the Set itself does - so picking a Set drew its
  /// name above the previous Set's counts, and a Set with nothing recorded
  /// could sit under "3 of 3 passages recorded". Two numbers from one place
  /// cannot contradict each other.
  final progress = <String, ({int done, int total})>{}.obs;

  ({int done, int total}) countsFor(WorkSet set) =>
      progress[set.id] ?? (done: 0, total: 0);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final queue = await WorkQueue.setsForStage(
        status: stage.status,
        role: stage.role,
      );
      sets.value = queue;

      if (queue.isEmpty) {
        current.value = null;
        progress.clear();
        return;
      }

      progress.value = await WorkQueue.recordedProgress([
        for (final set in queue) set.id,
      ]);

      // Already ordered by sort_order, so the first is the one to offer
      // unless the user has picked another - reopening the screen should not
      // silently move them off the Set they were working on.
      final open = current.value?.id;
      select(
        queue.firstWhere((set) => set.id == open, orElse: () => queue.first),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Opens a Set on this screen. Nothing is loaded: its counts came down
  /// with the queue, so the card is right from the first frame.
  void select(WorkSet set) => current.value = set;

  /// Opens a Set on the screen its stage works from, and refreshes on the
  /// way back so the queue reflects whatever was done in there.
  ///
  /// The community stages work against the Set as a whole rather than
  /// passage by passage, so they get their own screens built around the
  /// merged recording.
  ///
  /// The route is named explicitly because GetX derives a name from the
  /// closure's return type, and a switch over several page classes collapses
  /// to StatelessWidget - the same name this screen was pushed under, which
  /// its duplicate guard then refuses to navigate to at all.
  Future<void> open(WorkSet set) async {
    select(set);

    await Get.to(
      routeName: '/set/${set.id}',
      () => switch (set.workflowStatus) {
        'community_setup' => CommunitySetupPage(set: set),
        'community_test' => CommunityTestPage(set: set),
        'community_review' => CommunityReviewPage(set: set),
        'back_translation' => BackTranslationPage(set: set),
        'consultant' => ConsultantPage(set: set),
        _ => SetDetailPage(set: set),
      },
    );

    await load();
  }

  /// How this Set reads in the picker: where it is, and how far in.
  String labelFor(WorkSet set) {
    final counts = countsFor(set);
    // The name is isolated: see [NameLanguage.isolated] for the "Luke · 0"
    // it otherwise read as with a source-language name.
    final where = [
      set.bookName,
      NameLanguage.isolated(set.displayName),
    ].where((part) => part.isNotEmpty).join(' · ');

    if (counts.total == 0) return where;
    return '@where - @done of @total recorded'.trParams({
      'where': where,
      'done': '${counts.done}',
      'total': '${counts.total}',
    });
  }
}

/// The Set the user should be working on at this stage, and a way to reach
/// the others.
///
/// Sets follow the narrative in order, so the lowest-numbered one still
/// waiting is what opens - working them in order is what keeps a trail of
/// part-finished Sets from piling up behind. The picker is for the drafter
/// who came here for a particular one and knows it.
class StageSetsPage extends StatelessWidget {
  const StageSetsPage({super.key, required this.stage});

  final StageMeta stage;

  @override
  Widget build(BuildContext context) {
    final color = WorkQueue.colorForRole(stage.role);

    // Set names are read all over this screen, including inside
    // child widgets that build after the GetX builder has returned
    // and so are invisible to it. Listening here rebuilds the whole
    // page when the language toggle moves, which is what the toggle
    // in the app bar above is for.
    return NameLanguageBuilder(
      builder: (context) => GetBuilder<StageSetsController>(
        // Page-scoped rather than global: the controller is created with this
        // route and disposed with it, so two stages never share one.
        init: StageSetsController(stage),
        global: false,
        // GetBuilder, not GetX: the Scaffold and its app bar are built once.
        // Only the body below watches the controller, so loading a Set does
        // not rebuild the bar above it.
        builder: (controller) => Scaffold(
          backgroundColor: MainApp.pageBackground,
          appBar: AppBar(
            actions: AppBarActions.build(),
            title: Row(
              children: [
                Icon(stage.icon, size: 20, color: color),
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
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Obx(() => _body(controller, color)),
        ),
      ),
    );
  }

  /// Drafting is the stage that holds a queue; the rest hold one Set.
  bool get _showsPicker =>
      const {'not_started', 'recorded', 'redo'}.contains(stage.status);

  Widget _body(StageSetsController controller, Color color) {
    if (controller.isLoading.value) {
      return StageQueueSkeleton(picker: _showsPicker);
    }

    final current = controller.current.value;
    if (current == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing assigned to you here yet.'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MainApp.mutedText),
          ),
        ),
      );
    }

    return PullToRefresh(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        children: [
          // Only while drafting. A drafter has many Sets in hand at once and
          // may know which one they are here for; every later stage takes
          // the Set it is handed, in the order it was handed over.
          if (_showsPicker && controller.sets.length > 1) ...[
            _SetPicker(controller: controller, accent: color),
            const SizedBox(height: 14),
          ],
          if (!_showsPicker && controller.sets.length > 1) ...[
            _RemainingNote(count: controller.sets.length - 1),
            const SizedBox(height: 14),
          ],
          _CurrentSetCard(
            set: current,
            counts: controller.countsFor(current),
            accent: color,
            onOpen: () => controller.open(current),
          ),
        ],
      ),
    );
  }
}

/// The pending queue as one control: what is waiting, and which is open.
/// The queue behind the current Set, where it cannot be jumped into.
class _RemainingNote extends StatelessWidget {
  const _RemainingNote({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 15, color: MainApp.mutedText),
        const SizedBox(width: 8),
        Text(
          trCount(
            count,
            '@count more Set after this one',
            '@count more Sets after this one',
          ),
          style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
        ),
      ],
    );
  }
}

class _SetPicker extends StatelessWidget {
  const _SetPicker({required this.controller, required this.accent});

  final StageSetsController controller;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Its own Obx, for the same reason as every other child widget here: the
    // page's builder cannot see what this one reads.
    return Obx(() => _picker(context));
  }

  Widget _picker(BuildContext context) {
    final sets = controller.sets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jump to a pending work item (@count pending)'.trParams({
            'count': '${sets.length}',
          }),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MainApp.mutedText,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: controller.current.value?.id,
              icon: Icon(Icons.expand_more_rounded, color: accent),
              borderRadius: BorderRadius.circular(10),
              // Set names are long. Fixed-height rows cut them off at the
              // word that tells them apart, so rows size to their text and
              // wrap - three lines is enough for the longest of them.
              itemHeight: null,
              items: [
                for (final set in sets)
                  DropdownMenuItem(
                    value: set.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        controller.labelFor(set),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
              ],
              // The closed control wraps too, rather than showing one line of
              // a name the list showed in full.
              selectedItemBuilder: (context) => [
                for (final set in sets)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        controller.labelFor(set),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
              ],
              // Choosing from the list opens that Set, rather than only
              // pointing the card below at it: the list is there to get to
              // a Set, and stopping one tap short of it is a step nobody
              // wants.
              onChanged: (id) {
                if (id == null) return;
                controller.open(sets.firstWhere((set) => set.id == id));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentSetCard extends StatelessWidget {
  const _CurrentSetCard({
    required this.set,
    required this.counts,
    required this.accent,
    required this.onOpen,
  });

  final WorkSet set;

  /// How many of this Set's passages have a final take, and how many there
  /// are. Handed in rather than worked out here, so this card and the picker
  /// above it always say the same thing about the same Set.
  final ({int done, int total}) counts;

  final Color accent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final info = set.queueInfo;
    final done = counts.done;
    final total = counts.total;
    final progress = total == 0 ? 0.0 : done / total;

    // The card itself opens the Set. It used to carry a button that did that
    // and nothing else, which made the rest of the card look like a label
    // rather than the thing to press - and a button under a card is one more
    // thing to aim at on a phone held in one hand.
    //
    // The card carries the same pulse the recorder puts on its buttons:
    // on a screen with one thing to do, it is worth saying which thing.
    // It is the Set to open whatever has been done in it - a peer's Set
    // arrives with every passage recorded - and only one that is finished
    // has nothing left to ask for. The website's first card, the same.
    return PulseHalo(
      active: set.workflowStatus != 'approved',
      borderRadius: BorderRadius.circular(16),
      child: _card(progress: progress, done: done, total: total, info: info),
    );
  }

  Widget _card({
    required double progress,
    required int done,
    required int total,
    required ({IconData icon, Color color, String label}) info,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MainApp.cardShadow,
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                    if (set.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        set.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MainApp.mutedText,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(info.icon, size: 14, color: info.color),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              info.label.tr,
                              // Two lines: "Sent back from Back Translator -
                              // needs changes" is the whole point of the
                              // pill, and one line cut it off at "from".
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: info.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Kept for the drafter, whose Set is part done and who
                    // needs to know how much is left. A stage that does not
                    // count passages shows nothing here.
                    if (total > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        (total == 1
                                ? '@done of @total passage recorded'
                                : '@done of @total passages recorded')
                            .trParams({'done': '$done', 'total': '$total'}),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB),
                          // Green like every other measure of work done in
                          // the app, rather than the stage's own colour -
                          // that colour says which stage this is, not how
                          // far the Set has got.
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            MainApp.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 22,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
