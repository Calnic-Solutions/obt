import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/app_bar_actions.dart';
import 'package:livuka/Widgets/shimmer.dart';
import 'package:livuka/Widgets/confirm_dialog.dart';
import 'package:livuka/home.dart';
import 'package:livuka/l10n/plural.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/sync_service.dart';
import 'package:livuka/services/work_queue.dart';

/// What is waiting to go, what did not go, and why.
///
/// A phone that works offline for days has to be able to answer "has my
/// work gone up?" without anybody guessing. So this lists it Set by Set:
/// how many recordings and comments are still only here, whether a hand-off
/// is waiting, and - when the server said no - the server's own reason,
/// kept until the Set finally goes. Nothing on this screen is ever removed
/// except by the server accepting it or the user saying, in so many words,
/// to give it up.
class SyncStatusPage extends StatefulWidget {
  const SyncStatusPage({super.key, this.clear});

  /// Whether whoever opened this already knows nothing is waiting to
  /// send - the settings drawer reads that first - so the page can be
  /// drawn in that shape while it loads.
  final bool? clear;

  @override
  State<SyncStatusPage> createState() => _SyncStatusPageState();
}

class _SyncStatusPageState extends State<SyncStatusPage>
    with WidgetsBindingObserver {
  List<PendingSet> _pending = const [];
  String? _lastSynced;
  bool _loading = true;

  /// Re-reads whenever a send, a discard or a problem changes what there
  /// is to show - the page used to read once as it opened, and a send that
  /// finished behind it left it saying the work was still waiting.
  Worker? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = ever(SyncService.version, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _changes?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background, where the closed-app send may have run.
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final pending = await SyncService.pendingBySet();
    final last = await SyncService.lastSyncedAt();
    // Failed first: they are why somebody opened this screen.
    pending.sort((a, b) {
      final byProblem = (b.problem == null ? 0 : 1).compareTo(
        a.problem == null ? 0 : 1,
      );
      return byProblem != 0 ? byProblem : a.name.compareTo(b.name);
    });

    if (!mounted) return;
    setState(() {
      _pending = pending;
      _lastSynced = last;
      _loading = false;
    });
  }

  Future<void> _sendNow() async {
    Get.back();
    await Get.find<HomeController>().sendUpdates();
  }

  Future<void> _export(PendingSet set) async {
    final saved = await SyncService.exportRecordings(set.setId);
    toaster(
      saved == 0
          ? 'There were no recordings to save for this Set.'
          : trCount(
              saved,
              'Saved @count recording to Downloads.',
              'Saved @count recordings to Downloads.',
            ),
    );
  }

  Future<void> _discard(PendingSet set) async {
    final confirmed = await ConfirmDialog.ask(
      message:
          'Give up the unsent work on this Set? It will not be sent. '
          'Save the recordings to Downloads first if you want to keep them.',
      confirmLabel: 'Give up',
      destructive: true,
    );
    if (!confirmed) return;

    await SyncService.discard(set.setId);
    await _load();
  }

  static String _when(String? iso) {
    final at = DateTime.tryParse(iso ?? '')?.toLocal();
    if (at == null) return 'never'.tr;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _pending.fold<int>(0, (sum, set) => sum + set.total);

    return Scaffold(
      backgroundColor: MainApp.pageBackground,
      appBar: AppBar(
        actions: AppBarActions.build(nameToggle: false),
        title: Text(
          'Sync status'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      bottomNavigationBar: _loading || _pending.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: MainApp.primaryGreen,
                    ),
                    // Always offered. Whether there is a signal is found out
                    // by trying, when the user asks - not by the screen
                    // asking the server on its own as it opens.
                    onPressed: _sendNow,
                    icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                    label: Text(
                      'Send now (@count)'.trParams({'count': '$waiting'}),
                    ),
                  ),
                ),
              ),
            ),
      body: _loading
          ? SyncStatusSkeleton(clear: widget.clear)
          : PullToRefresh(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _summary(waiting),
                  const SizedBox(height: 14),
                  for (final set in _pending) ...[
                    _setCard(set),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summary(int waiting) {
    final clear = waiting == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: clear ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            clear ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
            color: clear ? const Color(0xFF15803D) : const Color(0xFFB45309),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clear
                      ? 'Everything has been sent.'.tr
                      : trCount(
                          waiting,
                          '@count change is only on this phone.',
                          '@count changes are only on this phone.',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last full sync: @when'.trParams({
                    'when': _when(_lastSynced),
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    color: MainApp.mutedText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setCard(PendingSet set) {
    final problem = set.problem;
    final parts = [
      if (set.recordings > 0)
        trCount(set.recordings, '@count recording', '@count recordings'),
      if (set.comments > 0)
        trCount(
          set.comments,
          '@count comment / question',
          '@count comments / questions',
        ),
      if (set.other > 0)
        trCount(set.other, '@count other change', '@count other changes'),
      if (set.movedTo != null)
        'hand-off to @stage'.trParams({
          'stage': WorkQueue.labelForStatus(set.movedTo!).isEmpty
              ? set.movedTo!
              : WorkQueue.labelForStatus(set.movedTo!).tr,
        }),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: MainApp.cardShadow,
        border: problem == null
            ? null
            : Border.all(color: const Color(0xFFDC2626), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                problem == null
                    ? Icons.schedule_rounded
                    : Icons.error_outline_rounded,
                size: 18,
                color: problem == null
                    ? const Color(0xFFB45309)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  set.name.isEmpty
                      ? 'Set @id'.trParams({'id': set.setId})
                      : set.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                problem == null ? 'Waiting'.tr : 'Not sent'.tr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: problem == null
                      ? const Color(0xFFB45309)
                      : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            parts.join(' · '),
            style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
          ),
          if (problem != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                problem.message.tr,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (problem.fatal
                      ? '@when · your work on this Set is still on this phone.'
                      : '@when · your work on this Set is still on this '
                            'phone and will be tried again.')
                  .trParams({'when': _when(problem.at)}),
              style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                if (set.recordings > 0)
                  OutlinedButton.icon(
                    onPressed: () => _export(set),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text('Save recordings'.tr),
                  ),
                if (problem.fatal)
                  TextButton(
                    onPressed: () => _discard(set),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: Text('Give up this work'.tr),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
