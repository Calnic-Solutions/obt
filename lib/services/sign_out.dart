import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Audio/audio_bus.dart';
import 'package:livuka/login.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/auto_send.dart';
import 'package:livuka/services/network_watch.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/time_tracker.dart';
import 'package:livuka/services/vault.dart';

/// Leaves the session: the way out, whoever asked for it.
///
/// The same steps whether the person tapped Sign out or sat still for a
/// quarter of an hour: the sign-out is logged and sent if there is a
/// connection, every file goes into the vault, and the sign-in page is
/// shown. The data stays on the phone.
class SignOut {
  SignOut._();

  static bool _running = false;

  /// Whether a sign-out is under way, so nothing starts a second one.
  static bool get running => _running;

  static Future<void> run({String reason = 'user', String? notice}) async {
    if (_running) return;
    _running = true;
    AutoSend.instance.stop();

    // Whatever is sounding or being recorded stops here: the recorder
    // writes its take out as it ends, before the vault closes over it.
    AudioBus.instance.silence();

    // Held over whatever screen is up while the files are secured, so no
    // tap lands on a page whose files are being taken away under it.
    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text('Securing your files...'.tr)),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      // Noted now, and sent when a connection allows: with the phone's
      // work kept, the log is too, and goes with the next send.
      // The dashboard lists an idle sign-out on its own line, so it is
      // filed under that name rather than as one more "signed out".
      await ActivityLog.record(
        reason == 'idle' ? 'locked_idle' : 'signed_out',
        details: {'reason': reason},
      );
      if (NetworkWatch.online.value) {
        await TimeTracker.send();
        await ActivityLog.send();
      }

      // The work stays, but not readable: every file goes into the vault
      // until this user signs in again.
      await Vault.lock();
    } catch (e) {
      debugPrint('SIGN OUT ERROR: $e');
    } finally {
      _running = false;
    }

    // Takes the dialog with it, and every page under it.
    Get.offAll(() => const LoginPage());
    if (notice != null) {
      // Only once the sign-in page has built. Its controller is created in
      // its build, and GetX ties a controller to whatever route is on top
      // at that moment.
      WidgetsBinding.instance.addPostFrameCallback((_) => toaster(notice));
    }
  }
}

/// Signs out whoever has not touched the screen for [after].
///
/// A phone left on a table with the workbench open is a phone anyone can
/// pick up. So a quarter of an hour without a touch ends the session, and
/// the next person to pick it up finds the sign-in page. Sound counts as
/// company: a recording in progress, or a passage playing, is not left
/// alone, and a sign-out part way through either would cost a take or a
/// listen the gate was counting.
///
/// Time away from the app counts too. A timer may not fire while the app is
/// in the background, so the check is run again the moment it comes back.
class IdleLogout with WidgetsBindingObserver {
  IdleLogout._();

  static final IdleLogout instance = IdleLogout._();

  /// How long without a touch before the session ends.
  static const Duration after = Duration(minutes: 15);

  static const Duration _tick = Duration(seconds: 30);

  Timer? _timer;
  DateTime _lastActive = DateTime.now();
  bool _watching = false;

  /// Begins watching, from a sign-in.
  void start() {
    _lastActive = DateTime.now();
    if (_watching) return;
    _watching = true;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(_tick, (_) => _check());
  }

  /// Stops watching, at a sign-out.
  void stop() {
    if (!_watching) return;
    _watching = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  /// The screen was touched: the person is here.
  void touched() => _lastActive = DateTime.now();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the background: the time away is time without a touch.
    if (state == AppLifecycleState.resumed) _check();
  }

  bool get _busyWithSound => !AudioBus.instance.silent;

  Future<void> _check() async {
    if (!_watching || SignOut.running) return;
    if (DateTime.now().difference(_lastActive) < after) return;
    if (_busyWithSound) {
      // Playing or recording is company; the clock starts when it stops.
      _lastActive = DateTime.now();
      return;
    }

    debugPrint('IDLE LOGOUT: no touch for ${after.inMinutes} minutes');
    stop();
    await SignOut.run(
      reason: 'idle',
      notice: 'You were signed out after 15 minutes without activity.',
    );
  }
}
