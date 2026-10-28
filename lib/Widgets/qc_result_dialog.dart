import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';

/// One line of the popup: what was measured, and how it came out.
class QcDialogCheck {
  const QcDialogCheck({
    required this.label,
    required this.detail,
    required this.passed,
  });

  final String label;
  final String detail;
  final bool passed;
}

/// The "Automated QC" popup, the same one the website raises after a check.
///
/// A toast saying "QC average" told a drafter that something was wrong and
/// not what - the reason was a tap away, folded up inside the take's card.
/// This puts all six checks in front of them at the moment they are thinking
/// about the take, with the measurement beside each, so "too quiet at the
/// end" is read off the screen rather than gone looking for.
///
/// The grade keeps the website's three colours: green for Good, amber for
/// Average, red for Bad.
class QcResultDialog extends StatelessWidget {
  const QcResultDialog({super.key, required this.status, required this.checks});

  /// `Good`, `Average` or `Bad`, as the analyser reports it.
  final String status;
  final List<QcDialogCheck> checks;

  static Future<void> show({
    required String status,
    required List<QcDialogCheck> checks,
  }) => Get.dialog<void>(QcResultDialog(status: status, checks: checks));

  static const Color _good = Color(0xFF16A34A);
  static const Color _average = Color(0xFFD97706);
  static const Color _bad = Color(0xFFDC2626);

  Color get _overall => switch (status) {
    'Good' => _good,
    'Average' => _average,
    _ => _bad,
  };

  @override
  Widget build(BuildContext context) {
    final isGood = status == 'Good';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 52,
                  color: Color(0xFF3FC3EE),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Automated QC'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF545454),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                // Good, Average and Bad stay as the team says them.
                isGood
                    ? 'QC: @status - passed automatically'.trParams({
                        'status': status,
                      })
                    : 'QC: @status'.trParams({'status': status}),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _overall,
                ),
              ),
              const SizedBox(height: 6),
              for (final check in checks) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          check.passed
                              ? Icons.check_circle
                              : Icons.cancel_rounded,
                          size: 20,
                          color: check.passed ? _good : _bad,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // Stored and sent in English; put into the
                              // reader's language only here.
                              check.label.tr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // The measurement: numbers and units, read left
                            // to right whatever the language.
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Text(
                                  check.detail,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.35,
                                    color: MainApp.mutedText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFEEF0F3)),
              ],
              const SizedBox(height: 10),
              Text(
                'This is a mechanical check, not a judgement on the '
                        'translation - use your own judgement too.'
                    .tr,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: MainApp.primaryGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => Get.back<void>(),
                    child: Text(
                      'OK'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
