import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Playback speed, offered wherever a recording plays.
///
/// A checker listening to the same passage for the fifth time does not need
/// it at speaking pace, and a reviewer skimming a long Set has no other way
/// to move through it - the waveform can be seeked, but only by guessing.
class SpeedSelector extends StatelessWidget {
  const SpeedSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.dark = false,
    this.large = false,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// Drawn for a dark surface. The full-screen player is one, and a white
  /// pill on it is the brightest thing on the screen for no reason.
  final bool dark;

  /// A thumb-sized target rather than a caption-sized one, for the same
  /// player's transport row, where everything is worked one-handed.
  final bool large;

  /// Exactly these, and the same on the web: a Set checked on a phone and in
  /// a browser is skimmed at the same paces.
  static const List<double> speeds = [1, 2, 3, 5];
  static const Color _accent = Color(0xFF1D6FD0);

  static String label(double speed) {
    final rounded = speed.round();
    return speed == rounded ? '${rounded}x' : '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      enabled: enabled,
      initialValue: value,
      tooltip: 'Playback speed'.tr,
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      color: dark ? const Color(0xFF141A22) : null,
      itemBuilder: (context) => [
        for (final speed in speeds)
          PopupMenuItem<double>(
            value: speed,
            height: 36,
            // The menu item paints its own selection: a plain check mark is
            // easy to miss at this size, and the current speed is the one
            // thing someone opening this menu is looking for.
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              height: 36,
              alignment: AlignmentDirectional.centerStart,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: speed == value ? _accent : Colors.transparent,
              child: Text(
                label(speed),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: speed == value
                      ? Colors.white
                      : (dark ? const Color(0xFFE5E7EB) : Colors.black87),
                ),
              ),
            ),
          ),
      ],
      child: Container(
        height: large ? 56 : null,
        constraints: large ? const BoxConstraints(minWidth: 64) : null,
        alignment: large ? Alignment.center : null,
        padding: large
            ? const EdgeInsetsDirectional.fromSTEB(16, 0, 10, 0)
            : const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 5),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF141A22) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: dark
                ? const Color(0xFF243040)
                : (enabled ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(value),
              style: TextStyle(
                fontSize: large ? 15 : 12,
                fontWeight: FontWeight.w600,
                color: dark
                    ? (enabled
                          ? const Color(0xFFE5E7EB)
                          : const Color(0xFF8B95A5))
                    : (enabled
                          ? const Color(0xFF374151)
                          : const Color(0xFF9CA3AF)),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: large ? 20 : 16,
              color: dark
                  ? const Color(0xFF8B95A5)
                  : (enabled
                        ? const Color(0xFF4B4870)
                        : const Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}
