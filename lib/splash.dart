import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livuka/login.dart';
import 'package:livuka/services/session.dart';
import 'package:livuka/services/user_store.dart';
import 'package:livuka/services/vault.dart';
import 'package:livuka/Widgets/brand_hero.dart';

/// App loading stage: runs the mic animation for [_splashDuration] before
/// handing over to the login page.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Duration _splashDuration = Duration(seconds: 3);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_splashDuration, _start);
  }

  Future<void> _start() async {
    if (!mounted) return;

    // A load that never finished leaves the folder part filled. It used to
    // be emptied here; now that the work stays on the phone between
    // sign-ins, that would take a recording with it. The load is safe to
    // run again - it replaces the tables and fetches only what is missing
    // - so the folder is kept, and the sign-in page insists on the server
    // until it has.
    if (SessionService.dataLoadInterrupted) {
      debugPrint('DATA LOAD WAS INTERRUPTED: a server sign-in will finish it');
    }

    // An app that was closed, or died, while someone was signed in has
    // left their files plain. They go into the vault before anyone sees
    // the sign-in page; a start after a clean sign-out finds nothing to do.
    if (SessionService.userId != null) {
      try {
        await UserStore.use(SessionService.userId);
        await Vault.lock();
      } catch (e) {
        debugPrint('VAULT NOT LOCKED AT START: $e');
      }
      if (!mounted) return;
    }

    // Every start asks for a sign-in, whoever signed in last. The work
    // stays on the phone between them; the sign-in page decides whether
    // the server or the phone's own record of the last sign-in answers.
    Get.off(() => const LoginPage());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandBackdrop.base,
      body: BrandBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  // Scrolls on a phone on its side, where the smile alone
                  // is most of the height.
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BrandHero(),
                        const SizedBox(height: 22),
                        Text(
                          'Starting up...'.tr,
                          style: const TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // The website panel's footnote.
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  '© ${DateTime.now().year} LIVUKA',
                  style: const TextStyle(
                    color: Color(0x80C9CBE0),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
