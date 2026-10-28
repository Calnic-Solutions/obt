import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';

/// A stage hand-off: the button that moves a Set on, or sends it back.
///
/// One shape for both so the pair reads as a choice between two things of
/// equal weight, told apart by colour alone - green on, dark red back.
///
/// Refused, it drops the colour entirely rather than fading it. A pale red
/// button still looks like a red button, and a reviewer who cannot send a Set
/// back yet should see a control that is plainly not available rather than
/// one that looks available and does nothing.
class StageActionButton extends StatelessWidget {
  const StageActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.sendBack = false,
    this.muted = false,
    this.highlight = false,
  });

  /// Whether this is the next thing to do: it pulses, in its own colour,
  /// for as long as it can be pressed.
  final bool highlight;

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Whether this returns the Set to an earlier stage.
  final bool sendBack;

  /// Offered, but nothing has been said yet to justify it. Drawn like a
  /// refused button and still tappable: pressing it is how somebody finds
  /// out what it is waiting for, which a dead control cannot tell them.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !muted;
    final colour = sendBack ? MainApp.sendBackRed : MainApp.primaryGreen;

    // Tall enough for two lines, and that is the point: "Send back to the
    // Drafter" beside "Send to Community Setup" on a narrow phone used to be
    // shrunk until both fitted on one line each, which left them too small
    // to read. Wrapped onto a second line they keep a readable size - and
    // the Urdu and Hindi, which run longer still, have somewhere to go.
    return PulseHalo(
      active: highlight && enabled,
      color: colour,
      borderRadius: BorderRadius.circular(10),
      child: _button(enabled, colour),
    );
  }

  Widget _button(bool enabled, Color colour) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? colour : const Color(0xFFF8FAFC),
          foregroundColor: enabled ? Colors.white : const Color(0xFF94A3B8),
          disabledBackgroundColor: const Color(0xFFF8FAFC),
          disabledForegroundColor: const Color(0xFF94A3B8),
          elevation: 0,
          // Close to the edge, so the words get the width rather than the
          // margins.
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: enabled ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.tr,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
