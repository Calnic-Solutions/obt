import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'package:livuka/home.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/network_watch.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/sync_service.dart';
import 'package:livuka/services/user_store.dart';
import 'package:livuka/services/vault.dart';
import 'package:livuka/services/work_queue.dart';

/// Sends finished work to the server on its own, without fetching anything.
///
/// Finished work: a Set that has been handed on - sent to the next role,
/// sent back, approved - with everything that belongs to it: its takes and
/// their recordings, the Final choices, comments, questions and answers,
/// back translations, and the stage move itself. A Set still being worked
/// on is left on the phone until the person hands it on or slides the
/// workbench control, which sends everything.
///
/// Three moments. A hand-off - a Set sent on to the next stage, or back -
/// goes the moment it is made when there is a signal, so the next person
/// is not kept waiting for a sync button. Every five minutes while the app
/// is open, whatever is still waiting is tried again. And every quarter of
/// an hour while the app is closed, where the phone allows it, the same -
/// for every account that has signed in on this phone, not only the last.
///
/// Only ever a send. Nothing comes down here: new work arrives when the
/// person asks for it with the Send and Receive control on the workbench,
/// which also runs the conflict check that a send-alone does without.
class AutoSend with WidgetsBindingObserver {
  AutoSend._();

  static final AutoSend instance = AutoSend._();

  /// How often the open app tries what is waiting.
  static const Duration every = Duration(minutes: 5);

  /// How often the closed app is woken to try. Fifteen minutes is the
  /// least Android allows a periodic job; iOS decides for itself.
  static const Duration everyInBackground = Duration(minutes: 15);

  static const String _taskName = 'oralogos.auto-send';

  Timer? _timer;
  bool _watching = false;
  bool _busy = false;

  // --------------------------------------------------------- foreground

  /// Begins the five-minute tries and the heartbeat, from a sign-in.
  void start() {
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(every, (_) => _tick());
    unawaited(_heartbeat());
  }

  /// Ends them, at a sign-out. The closed-app job carries on.
  void stop() {
    if (!_watching) return;
    _watching = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    unawaited(_heartbeat(clear: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back in front: what the closed-app job may not have managed is
    // tried now, and the job told to stand aside again.
    if (state == AppLifecycleState.resumed) {
      unawaited(_heartbeat());
      unawaited(_tick());
    }
  }

  Future<void> _tick() async {
    await _heartbeat();
    if (!NetworkWatch.online.value) return;
    await sendNow(reason: 'timer');
  }

  /// Sends the signed-in user's waiting work now, if there is any and the
  /// workbench is not already sending. Returns what went.
  Future<SyncResult?> sendNow({required String reason}) async {
    if (_busy || !SessionService.isLoggedIn) return null;
    if (Get.isRegistered<HomeController>() &&
        Get.find<HomeController>().isSending.value) {
      return null;
    }
    _busy = true;
    try {
      if (!await SyncService.hasHandedOnWork()) return null;
      debugPrint('AUTO SEND ($reason): sending');
      final result = await SyncService.send(onlyHandedOn: true);
      await SyncService.sendLogs();
      if (Get.isRegistered<HomeController>()) {
        await Get.find<HomeController>().refreshCounts();
      }
      debugPrint(
        'AUTO SEND ($reason): sent=${result.sent} rows=${result.rows} '
        'files=${result.files} failed=${result.failedSets}',
      );
      return result;
    } catch (e) {
      debugPrint('AUTO SEND ($reason) FAILED: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// A Set has just been handed on. Sent straight away when the phone has
  /// a network; otherwise it waits for the next try, as it always did.
  /// Quietly, either way: only a send the person asked for with the
  /// workbench control reports back with a card.
  Future<void> afterHandOff(StageAction action) async {
    if (!NetworkWatch.online.value) return;
    await sendNow(reason: 'hand-off');
  }

  // --------------------------------------------------------- background

  /// Registers the closed-app job. Called once at start-up; registering
  /// again keeps the job that is there.
  static Future<void> registerBackgroundJob() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await Workmanager().initialize(autoSendDispatcher);
      await Workmanager().registerPeriodicTask(
        _taskName,
        _taskName,
        frequency: everyInBackground,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('AUTO SEND: background job not registered: $e');
    }
  }

  /// Sends every account's waiting work, one account at a time - the
  /// closed-app job, and the open app's try when nobody is signed in.
  ///
  /// Each account is made the session in turn, its folder opened, its
  /// recordings turned back from the vault as the send needs them, and
  /// the folder sealed again after. The session that was current before
  /// is put back at the end.
  static Future<void> sendForAllAccounts({required bool fromBackground}) async {
    final before = SessionService.email;
    final accounts = SessionService.accounts;
    debugPrint(
      'AUTO SEND (${fromBackground ? 'background' : 'idle'}): '
      '${accounts.length} account(s)',
    );
    for (final email in accounts.keys) {
      try {
        if (!await SessionService.switchTo(email)) continue;
        await UserStore.use(SessionService.userId);
        if (!await SyncService.hasHandedOnWork()) {
          await SyncService.sendLogs();
          continue;
        }
        final result = await SyncService.send(onlyHandedOn: true);
        await SyncService.sendLogs();
        debugPrint(
          'AUTO SEND ($email): sent=${result.sent} rows=${result.rows} '
          'files=${result.files} failed=${result.failedSets}',
        );
      } catch (e) {
        debugPrint('AUTO SEND ($email) FAILED: $e');
      } finally {
        // Whatever the send turned back goes under lock again: nobody is
        // signed in to read it.
        try {
          await Vault.lock();
        } catch (e) {
          debugPrint('AUTO SEND ($email): not sealed: $e');
        }
      }
    }
    if (before != null) {
      await SessionService.switchTo(before);
      await UserStore.use(SessionService.userId);
    }
  }

  // ---------------------------------------------------------- heartbeat

  /// The open app leaves a note of the time; the closed-app job reads it
  /// and stands aside while the note is fresh, so the two never send the
  /// same work at once from two processes.
  static const Duration _fresh = Duration(minutes: 7);

  static Future<File> _heartbeatFile() async => File(
    p.join((await getApplicationSupportDirectory()).path, 'auto-send.alive'),
  );

  static Future<void> _heartbeat({bool clear = false}) async {
    try {
      final file = await _heartbeatFile();
      if (clear) {
        if (await file.exists()) await file.delete();
      } else {
        await file.writeAsString('${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      debugPrint('AUTO SEND: heartbeat not written: $e');
    }
  }

  static Future<bool> appIsOpen() async {
    try {
      final file = await _heartbeatFile();
      if (!await file.exists()) return false;
      final at = int.tryParse(await file.readAsString()) ?? 0;
      return DateTime.now().millisecondsSinceEpoch - at < _fresh.inMilliseconds;
    } catch (_) {
      return false;
    }
  }
}

/// The closed-app job's whole life, in an engine of its own.
@pragma('vm:entry-point')
void autoSendDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      // The open app sends for itself, and holds the session: the job
      // stands aside rather than switching accounts under it.
      if (await AutoSend.appIsOpen()) return true;

      await SessionService.init();
      UserStore.init();
      // A plain knock, not the app's probe: that one signs a locked-out
      // account out through screens this engine does not have.
      try {
        await http
            .head(MainApp.buildmainUri(''))
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('AUTO SEND (background): server unreachable: $e');
        return true;
      }
      await AutoSend.sendForAllAccounts(fromBackground: true);
    } catch (e) {
      debugPrint('AUTO SEND (background) FAILED: $e');
    }
    return true;
  });
}
