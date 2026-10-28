import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/work_queue.dart';

/// Says that this Set has come back, and from where.
///
/// A Set arriving for a second time looks exactly like one arriving for the
/// first, and the difference matters: somebody further down the line listened
/// to this and returned it. Naming the stage saves the reader working out who
/// that was from the comments alone.
///
/// Draws nothing when the Set is on its way forward, which is most of the
/// time - it appears only when `redo_from_stage` names a stage.
class SentBackBanner extends StatelessWidget {
  const SentBackBanner({super.key, required this.set});

  final WorkSet set;

  @override
  Widget build(BuildContext context) {
    final from = set.redoFromLabel;
    if (from.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      // No panel behind it: the red icon and words on the page itself. A
      // box of any colour made a line of information look like an alert.
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.rotate_left, size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sent back from @stage'.trParams({'stage': from.tr}),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MainApp.sendBackRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
