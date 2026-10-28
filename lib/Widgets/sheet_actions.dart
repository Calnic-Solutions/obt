import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';

/// The foot of a popup sheet: the way out on one side, and - when the reader
/// wrote what the sheet is showing - the way to take it back on the other.
///
/// Close is there because swiping a sheet down is something people have to
/// be shown, and a panel with no visible way out reads as stuck. Delete sits
/// at the start, away from it: the thumb that comes to dismiss the sheet
/// should not land on the one button that cannot be undone.
class SheetActions extends StatelessWidget {
  const SheetActions({super.key, this.onDelete, this.deleteLabel = 'Delete'});

  /// Null when there is nothing the reader may delete - somebody else wrote
  /// it - and the row is then the Close button alone.
  final VoidCallback? onDelete;
  final String deleteLabel;

  static const Color _danger = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (onDelete != null)
            TextButton.icon(
              onPressed: () {
                // The sheet goes first, so the "are you sure?" that follows
                // is asked over the page rather than over a panel about
                // something that may be about to vanish.
                Get.back<void>();
                onDelete!();
              },
              style: TextButton.styleFrom(
                foregroundColor: _danger,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(deleteLabel.tr),
            ),
          const Spacer(),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: MainApp.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Get.back<void>(),
              child: Text(
                'Close'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
