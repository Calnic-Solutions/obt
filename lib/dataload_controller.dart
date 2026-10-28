import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:livuka/Audio/audio_cache.dart';
import 'package:livuka/Audio/media_prefetch.dart';
import 'package:livuka/Widgets/download_problems_dialog.dart';
import 'package:livuka/home.dart';
import 'package:livuka/services/account_access.dart';
import 'package:livuka/services/Database/db.dart';
import 'package:livuka/services/activity_log.dart';
import 'package:livuka/services/services.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/vault.dart';

import 'package:livuka/main.dart';
import 'package:livuka/Widgets/brand_hero.dart';

/// The user's roles, however the server wrote them: a real JSON list, a
/// comma-separated string, or - as it turned out - a JSON list encoded as a
/// string, `["drafter","peer"]`, which split on commas alone came out as
/// `[drafter` and `peer]` and was shown to people that way.
List<String> roleKeysFrom(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }

  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return const [];

  if (text.startsWith('[')) {
    try {
      return roleKeysFrom(jsonDecode(text));
    } catch (_) {
      // Not JSON after all; fall through and split it as text.
    }
  }

  return [
    for (final part in text.split(','))
      if (part.replaceAll(RegExp(r'''[\[\]"' ]'''), '').isNotEmpty)
        part.replaceAll(RegExp(r'''[\[\]"' ]'''), ''),
  ];
}

/// What the loading screen is told: whose data, and whether the phone has
/// any of it yet.
class DataLoadArguments {
  const DataLoadArguments({
    required this.userId,
    required this.firstLoad,
    this.fetch = true,
  });

  final dynamic userId;

  /// False when the server was not reached: the files are unlocked and
  /// nothing is downloaded.
  final bool fetch;

  /// True for a user whose work is not on this phone yet. A returning user
  /// gets the same fetch, which brings down only what is new, under a
  /// heading that says so.
  final bool firstLoad;
}

class DrafterController extends GetxController {
  static Uri get dataCollectionUri => MainApp.buildmainUri('data-collection');

  final isCollecting = false.obs;
  final totalAudioClips = 0.obs;
  final storedAudioClips = 0.obs;

  /// The vault being opened: files turned back, of how many. Shown before
  /// the download, under its own heading.
  final unlocking = false.obs;
  final unlockedFiles = 0.obs;
  final vaultFiles = 0.obs;

  /// Turns the user's files back from the vault, with the progress shown.
  Future<void> unlockVault() async {
    unlocking.value = true;
    Vault.onProgress = (done, total) {
      unlockedFiles.value = done;
      vaultFiles.value = total;
    };
    try {
      await Vault.unlock();
    } catch (e) {
      debugPrint('VAULT UNLOCK ERROR: $e');
    } finally {
      Vault.onProgress = null;
      unlocking.value = false;
    }
  }

  /// The one moment the app goes to the network: the data load at sign-in.
  /// Everything after it reads sqflite, so nothing else watches the
  /// connection - there is nothing it could do differently if it knew.
  ///
  /// Returns the lockout when the server refused because the account was
  /// made inactive, or its app access switched off, between the sign-in
  /// and this call; the caller signs the user out again.
  Future<AccountLockout?> fetchAfterLogin({required dynamic userId}) async {
    isCollecting.value = true;

    try {
      if (!await hasInternet()) {
        return null;
      }

      // Marked before anything is written. Everything between here and the
      // clearing of this flag is a device that is neither empty nor ready:
      // the tables land one at a time and the recordings arrive one by one,
      // so an app closed in the middle leaves a Set with half its passages
      // and no way to tell which half. The next start-up reads this, throws
      // the lot away and asks the user to sign in again. Set only once the
      // server has been reached: a phone that could not ask has changed
      // nothing, and its data is as whole as it was.
      await SessionService.markDataLoadStarted();

      final response = await http
          .get(
            dataCollectionUri,
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Bearer ${SessionService.token}',
            },
          )
          .timeout(const Duration(seconds: 60));

      final lockout = AccountLockout.from(response);
      if (lockout != null) return lockout;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        if (data is Map) {
          MainApp.roles = roleKeysFrom(data['RoleKey']);
          await SessionService.saveRoles(MainApp.roles);

          final jsonMap = Map<String, dynamic>.from(data);
          AudioCacheService.resetDownloadStats();
          storedAudioClips.value = 0;
          AudioCacheService.onProgress = (count) =>
              storedAudioClips.value = count;

          final total =
              data['totalAudioClips'] ??
              data['total'] ??
              data['total_clips'] ??
              data['TotalAudioClips'];
          final stored =
              data['storedAudioClips'] ??
              data['stored'] ??
              data['stored_clips'] ??
              data['StoredAudioClips'];

          final countedAudio = AudioNeeds.from(jsonMap)
              .count(jsonMap, DatabaseHelper.collectionTables);
          totalAudioClips.value = total != null
              ? int.tryParse(total.toString()) ?? countedAudio
              : countedAudio;

          final uid = int.tryParse(userId?.toString() ?? '') ?? 0;
          try {
            // The files first, several at a time, and anything that does
            // not arrive asked about. The rows written after find them on
            // the phone.
            await MediaPrefetch.run(
              jsonMap,
              askAboutFailed: DownloadProblemsDialog.ask,
            );
            await DatabaseHelper.instance.insertDataLoad(
              type: 'CollectData',
              userId: uid,
              json: jsonMap,
            );
            // What an earlier sign-in left behind and this one has no
            // use for.
            await MediaPrefetch.prune(jsonMap);
          } finally {
            AudioCacheService.onProgress = null;
          }

          storedAudioClips.value = AudioCacheService.downloadedCount;
          if (stored != null) {
            final apiStored = int.tryParse(stored.toString());
            if (apiStored != null && apiStored > 0) {
              storedAudioClips.value = apiStored;
            }
          }

          // Only here: the tables are written and the media is on the phone.
          // Anything short of this point is a load that did not happen.
          await SessionService.markDataLoadFinished();
          await ActivityLog.record(
            'data_downloaded',
            details: {'files': AudioCacheService.downloadedNow},
          );
        }
      }
    } catch (e) {
      debugPrint('POST LOGIN DATA FETCH ERROR: $e');
    } finally {
      AudioCacheService.onProgress = null;
      isCollecting.value = false;
    }
    return null;
  }
}

class DataLoadingScreen extends StatefulWidget {
  const DataLoadingScreen({super.key});

  @override
  State<DataLoadingScreen> createState() => _DataLoadingScreenState();
}

class _DataLoadingScreenState extends State<DataLoadingScreen> {
  late final DrafterController controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    controller = Get.find<DrafterController>();
    _startLoad();
  }

  Future<void> _startLoad() async {
    if (_started) return;
    _started = true;

    final args = Get.arguments;
    final userId = args is DataLoadArguments ? args.userId : (args ?? 0);
    final fetch = args is DataLoadArguments ? args.fetch : true;

    // Nothing is turned back from the vault here: each Set's files are,
    // as its screen opens. A refresh counts a sealed file as on the phone.
    if (!fetch) {
      Get.offAll(() => const HomePage());
      return;
    }

    final lockout = await controller.fetchAfterLogin(userId: userId);

    if (!mounted) return;
    // Shut out between the sign-in and the load: nothing came down, and
    // what the sign-in wrote is cleared again on the way back.
    if (lockout != null) {
      await AccountAccess.lockOut(lockout);
      return;
    }
    // The connection probe may have done the same on its own; the sign-in
    // page is already showing and the workbench must not be put over it.
    if (!SessionService.isLoggedIn) return;
    Get.offAll(() => const HomePage());
  }

  bool get _firstLoad {
    final args = Get.arguments;
    return args is DataLoadArguments ? args.firstLoad : true;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final unlocking = controller.unlocking.value;
      final heading = unlocking
          ? 'Preparing your files...'
          : _firstLoad
          ? 'Collecting your data...'
          : 'Checking for updates...';
      final total = unlocking
          ? controller.vaultFiles.value
          : controller.totalAudioClips.value;
      final saved = unlocking
          ? controller.unlockedFiles.value
          : controller.storedAudioClips.value;
      final progress = total > 0 ? (saved / total).clamp(0.0, 1.0) : 0.0;
      final percent = total > 0 ? ((saved / total) * 100).round() : 0;

      return Scaffold(
        backgroundColor: BrandBackdrop.base,
        body: BrandBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandHero(size: 200, verbs: false),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 260,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              heading.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Color(0xFFCD572D),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: total > 0 ? progress : null,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFCD572D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          total == 0
                              ? 'Preparing...'.tr
                              : (unlocking
                                        ? '@saved / @total files ready'
                                        : '@saved / @total files downloaded')
                                    .trParams({
                                  'saved': '$saved',
                                  'total': '$total',
                                }),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
