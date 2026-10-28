import 'package:flutter/foundation.dart';

import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/listen_gate.dart';
import 'package:livuka/services/media_session.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/sync_service.dart';
import 'package:livuka/services/user_store.dart';

/// Empties the phone of the signed-in user's work.
///
/// Each user has a folder of their own, so this touches only theirs: their
/// recordings on disk, their tables, their session and their media sign-in
/// go together, and nothing that wipes one may skip another. Done when the
/// server shuts the account out, or when a download was cut off part way;
/// signing out does not do it.
Future<void> wipeDevice() async {
  try {
    await AudioCacheService.clearCache();
    for (final dir in [await UserStore.work(), await UserStore.vault()]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    await DatabaseHelper.instance.wipe();
    await ListenGate.clear();
    await SyncService.clearState();
    await SessionService.clear();
    await MediaSession.clear();
    MainApp.roles = [];
  } catch (e) {
    debugPrint('DEVICE WIPE ERROR: $e');
  }
}
