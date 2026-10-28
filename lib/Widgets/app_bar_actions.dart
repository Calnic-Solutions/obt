import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/name_language_toggle.dart';
import 'package:livuka/Widgets/settings_drawer.dart';
import 'package:livuka/pages/manual_page.dart';
import 'package:livuka/home.dart';

/// What every app bar carries at its far end: the way home, and settings.
///
/// The website puts Home and its menu on every signed-in page rather than
/// writing them into any one of them, and for the same reason they are here
/// once. Four screens deep in a Set, the workbench was four back-arrows away
/// and the language switch - which lives in settings - could only be reached
/// from the workbench at all. Somebody handed a phone in the wrong language
/// had to find their way out of the Set first, in a language they could not
/// read.
///
/// The workbench itself shows no Home, being home.
class AppBarActions {
  AppBarActions._();

  /// The actions for a page's app bar.
  ///
  /// [nameToggle] adds the Eng / Source switch for Set names, on the pages
  /// that show one. [enabled] is false while leaving would cost something -
  /// mid-recording - and greys both out rather than hiding them, so the bar
  /// does not jump about as recording starts and stops.
  static List<Widget> build({bool nameToggle = true, bool enabled = true}) => [
    if (nameToggle) const NameLanguageToggle(),
    _icon(
      icon: Icons.home_outlined,
      tooltip: 'Home',
      onPressed: enabled ? goHome : null,
    ),
    // Three dots, as on the website: the plainest mark there is for "the
    // rest is in here", and half the width of a cog.
    _icon(
      icon: Icons.more_vert_rounded,
      tooltip: 'Settings',
      onPressed: enabled ? openSettings : null,
    ),
    const SizedBox(width: 2),
  ];

  /// A bare icon, packed close. Material's default gives every action a
  /// 48px square, and three of those took half a phone's app bar away from
  /// the title. 36 wide is still a comfortable tap, the bar's full height.
  static Widget _icon({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) => IconButton(
    tooltip: tooltip.tr,
    onPressed: onPressed,
    icon: Icon(icon, size: 22),
    color: const Color(0xFF040134),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 48),
  );

  /// Straight back to the workbench, however deep the screen was.
  static void goHome() {
    Get.until((route) => route.isFirst);

    // The counts on the workbench are read when it is built; work done in
    // the screens just closed has changed them.
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().refreshCounts();
    }
  }

  /// The settings panel, slid in from the right. Shown over the page rather
  /// than as a Scaffold's drawer, so every page opens the same one - and so
  /// it keeps to one side, which a Scaffold's end drawer does not.
  static Future<void> openSettings() async {
    final context = Get.context;
    if (context == null) return;

    // Read before the panel's own route goes on top: the handbook opens at
    // the chapter for the screen the panel was opened over.
    final manualSection = ManualPage.currentSection();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings'.tr,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      // Always the right-hand edge, in every language. The cog that opens it
      // is where a thumb found it, and a panel that comes in from the other
      // side the moment Urdu is chosen - while it is open, under the finger
      // that chose it - reads as the screen having jumped.
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.centerRight,
        child: SettingsDrawer(
          manualSection: manualSection,
          onSignOut: () {
            if (Get.isRegistered<HomeController>()) {
              Get.find<HomeController>().logout();
            }
          },
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        const fromEnd = Offset(1, 0);

        return SlideTransition(
          position: Tween<Offset>(begin: fromEnd, end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }
}
