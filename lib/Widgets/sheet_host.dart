import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a panel as a bottom sheet.
///
/// Always scroll-controlled, and never taller than most of the screen: on a
/// phone on its side a sheet has a third of the height it has upright, and
/// a panel that cannot scroll then loses its foot.
Future<T?> showAppSheet<T>(
  Widget child, {
  bool dismissible = true,

  /// Whether [child] scrolls itself. If not, it is given a scroll view
  /// here, so it can never overflow the sheet.
  bool scrolls = false,
}) {
  return Get.bottomSheet<T>(
    ConstrainedBox(
      constraints: BoxConstraints(maxHeight: Get.height * 0.85),
      child: scrolls ? child : SingleChildScrollView(child: child),
    ),
    isDismissible: dismissible,
    isScrollControlled: true,
  );
}
