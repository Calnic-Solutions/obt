import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:livuka/main.dart';
import 'package:livuka/Widgets/shimmer.dart';

/// The phone handbook, shown inside the app.
///
/// The page travels with the app (`docs/mobile-user-manual.html`, bundled
/// as an asset) and opens in a WebView, so it needs no browser and no
/// connection - the demos are drawn by the page's own script. Only the
/// fonts come from the web, and the page reads fine without them.
class ManualPage extends StatefulWidget {
  const ManualPage({super.key, this.section});

  static const String asset = 'docs/mobile-user-manual.html';

  /// The chapter to open at - a section id in the handbook - or null for
  /// the top of the page.
  final String? section;

  /// The chapter for the stage the workbench last opened, kept while the
  /// person is anywhere inside it. The Set screens under a stage carry no
  /// stage of their own in their route, so the workbench says which one was
  /// entered and clears it on the way back.
  static String? stageSection;

  /// The handbook's chapter id for a Set status, as its tiles on the
  /// workbench map to them.
  static String? sectionForStatus(String status) => switch (status) {
    'not_started' || 'recorded' => 'draft',
    'redo' => 'sentback',
    'community_setup' => 'csetup',
    'community_test' => 'ctest',
    'peer' => 'peercheck',
    'community_review' => 'creview',
    'back_translation' => 'backtranslation',
    'consultant' => 'consultantcheck',
    'approved' => 'finished',
    // Liked answers that came with a comment: shown with the Sent back
    // chapter, which is where the handbook explains reading feedback.
    'feedback' => 'sentback',
    _ => null,
  };

  /// The chapter for the screen the person is on right now: the stage they
  /// are inside, the sending screen, or the Home screen's own chapter.
  static String currentSection() {
    if (Get.currentRoute.contains('SyncStatusPage')) return 'sync';
    return stageSection ?? 's2';
  }

  @override
  State<ManualPage> createState() => _ManualPageState();
}

class _ManualPageState extends State<ManualPage> {
  late final WebViewController _web;
  bool _loading = true;

  /// Whether the page has had its roles and opening chapter. Android fires
  /// onPageFinished again for every change of the page's own hash, and a
  /// second ObtManualOpen would drag the reader back to where they started.
  bool _prepared = false;

  @override
  void initState() {
    super.initState();
    // Debug builds only: lets chrome://inspect reach the handbook, which is
    // the one way to read its console from outside the phone.
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      AndroidWebViewController.enableDebugging(true);
    }
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      // The page's own back arrow: the app's bar is not shown over it,
      // so the handbook's header stays at the top as the page scrolls.
      ..addJavaScriptChannel(
        'ObtManual',
        onMessageReceived: (message) {
          if (message.message == 'back') Get.back();
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (_prepared) return;
            _prepared = true;
            // Only the chapters for the roles this person holds: a drafter
            // who is not a consultant never sees the consultant's steps.
            // The page shows everything until told, as it does in a browser.
            _web.runJavaScript('ObtManualRoles(${jsonEncode(MainApp.roles)})');
            // Then straight to the chapter for the screen this was opened
            // from, once the roles have decided which chapters exist.
            if (widget.section case final section?) {
              _web.runJavaScript(
                'typeof ObtManualOpen === "function" && '
                'ObtManualOpen(${jsonEncode(section)})',
              );
            }
            if (mounted) setState(() => _loading = false);
          },
          // Links inside the manual are anchors on the same page; anything
          // else stays out of the app.
          onNavigationRequest: (request) =>
              request.url.startsWith('file:') ||
                  request.url.startsWith('flutter-asset:') ||
                  request.url.startsWith('about:')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      )
      ..loadFlutterAsset(ManualPage.asset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _web),
            // The page's own shape - header, search, a chapter - until the
            // WebView has drawn it, so the handoff is a fade and not a jump.
            if (_loading)
              const ColoredBox(color: Colors.white, child: ReadingSkeleton()),
          ],
        ),
      ),
    );
  }
}
