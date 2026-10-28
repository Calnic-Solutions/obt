import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/work_queue.dart';

/// The app's one shape for "are you sure?".
///
/// A mark at the top, the question in a sentence, and two filled buttons of
/// equal weight. Filled rather than the plain text actions Material gives a
/// dialog by default: these decisions delete a recording or hand a Set to
/// another person, and a control that reads as a label is one people confirm
/// without meaning to.
///
/// The dangerous side is always red and always on the left, so the answer to
/// "which button did I just press" never depends on the wording.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.icon = Icons.help_outline,
    this.destructive = false,
  });

  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final IconData icon;

  /// Whether saying yes takes something away. Colours the confirm button red
  /// rather than green.
  final bool destructive;

  /// Asks, and answers true only when the confirm button was the one pressed.
  static Future<bool> ask({
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    IconData icon = Icons.help_outline,
    bool destructive = false,
  }) async {
    final answer = await Get.dialog<bool>(
      ConfirmDialog(
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        icon: icon,
        destructive: destructive,
      ),
      // A tap outside is not an answer to a question like this one.
      barrierDismissible: false,
    );

    return answer == true;
  }

  /// Before a comment, question or reply is withdrawn.
  static Future<bool> askDeleteComment() => ask(
    message: "Delete this comment? This can't be undone.",
    confirmLabel: 'Delete',
    icon: Icons.delete_outline,
    destructive: true,
  );

  /// Asks the question a stage hand-off carries with it.
  static Future<bool> askStage(StageAction action) => ask(
    message: action.confirmMessage,
    confirmLabel: action.confirmLabel,
    icon: action.isSendBack ? Icons.rotate_left : Icons.send,
    destructive: action.isSendBack,
  );

  @override
  Widget build(BuildContext context) {
    final confirmColour = destructive
        ? MainApp.sendBackRed
        : MainApp.primaryGreen;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: confirmColour.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(icon, size: 28, color: confirmColour),
            ),
            const SizedBox(height: 18),
            Text(
              message.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Color(0xFF040134),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _Button(
                    label: confirmLabel.tr,
                    background: confirmColour,
                    onPressed: () => Get.back(result: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Button(
                    label: cancelLabel.tr,
                    background: const Color(0xFF94A3B8),
                    onPressed: () => Get.back(result: false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.background,
    required this.onPressed,
  });

  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
