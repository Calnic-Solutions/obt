import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';

/// The card that reports a finished sync with the server.
///
/// Every other message in the app is a plain toast that fades in a moment.
/// This one is different: it says what a round trip to the server did, and
/// a person who has just slid the button and looked away should still find
/// the answer waiting. So it is a card at the foot of the screen, over the
/// send button, with the mascot, a heading, the sentences the sync put
/// together, and a close button. It stays for half a minute or until it is
/// closed.
class SyncToast {
  SyncToast._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  /// How long the card stays when nobody closes it.
  static const Duration stay = Duration(seconds: 30);

  /// Shows [message] under the "Done Synchronization." heading, replacing
  /// any card already up. Falls back to a debug print when there is no
  /// screen to draw over yet.
  static void show(String message) {
    // The app navigator's own overlay. GetX's overlay context came back
    // null on the workbench, and the card went to the log instead.
    final overlay = Get.key.currentState?.overlay;
    if (overlay == null) {
      debugPrint('SYNC TOAST (no screen yet): $message');
      return;
    }

    hide();
    final entry = OverlayEntry(
      builder: (_) => _SyncToastCard(message: message, onClose: hide),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(stay, hide);
  }

  /// Takes the card down, now.
  static void hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _SyncToastCard extends StatefulWidget {
  const _SyncToastCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  State<_SyncToastCard> createState() => _SyncToastCardState();
}

class _SyncToastCardState extends State<_SyncToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clear of the slide-to-sync track at the foot of the home screen: its
    // own padding and height, plus the gap the red box in the design leaves
    // above it, over the system inset.
    final bottom = MediaQuery.paddingOf(context).bottom + 92;

    return Positioned(
      left: 18,
      right: 18,
      bottom: bottom,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _rise, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _rise,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F040134),
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Color(0x0D040134),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // The light app icon, the smile on off-white: the whole
                  // logo, with its wordmark, was too small to read at this
                  // size, and the navy tile sat heavy on the white card.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SvgPicture.asset(
                      'assets/brand/livuka-app-icon-light.svg',
                      width: 44,
                      height: 44,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Done Synchronization.'.tr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MainApp.titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: MainApp.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Close'.tr,
                    onPressed: widget.onClose,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: MainApp.mutedText,
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
}
