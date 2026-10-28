import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livuka/Audio/wave_analyzer.dart';
import 'package:livuka/services/Database/db.dart';

/// The result of an automated QC run, in the shape the `takes` row wants.
class QcOutcome {
  const QcOutcome({
    required this.status,
    required this.notes,
    required this.report,
    this.checks = const [],
    this.error,
  });

  /// The report's own verdict: "Good", "Average" or "Bad". Only "Good"
  /// counts as a pass - one failed check is worth another listen, and the
  /// take cannot be made final on it.
  final String status;

  /// One line per failed check, which is what goes into `takes.qc_notes`.
  /// Empty when everything passed.
  final String notes;

  /// The whole report, stored on the take exactly as the server stores one.
  final Map<String, dynamic> report;

  final List<QcCheckResult> checks;

  /// Set when the file could not be analysed at all (wrong format, truncated
  /// header). Distinct from a clean fail: nothing was actually measured.
  final String? error;

  bool get passed => status == 'Good';

  /// What to tell whoever made a recording with no voice in it, where
  /// there is no QC report to say it: a back translation, a comment.
  static const String noVoiceNotice =
      'No voice was detected. Speak clearly, close to the phone, and '
      'record again.';
}

/// Runs the [WavAnalyzer] checks on a recording.
///
/// This is the whole QC gate: the app is offline-first, so a drafter in the
/// field cannot wait for a server to grade a take before moving on. The same
/// thresholds the analyzer already encodes decide whether a take reaches
/// `passed_qc` on the device, and the report is stored with the take like any
/// other write. A take that falls short stays `recorded` - it is a recording
/// waiting for a better one, not a state of its own.
class QcService {
  QcService._();

  /// Analysis decodes every sample, so a few minutes of 44.1 kHz audio is far
  /// too much work for the UI thread — it runs on a background isolate.
  static Future<QcOutcome> run(
    String filePath, {
    double? expectedDurationSeconds,
  }) async {
    try {
      // The project's `enhanced_qc` setting, as the last data load brought
      // it down: 'yes' adds the Background noise check, as on the website.
      final enhanced =
          (await DatabaseHelper.instance.setting('enhanced_qc'))
              ?.toString()
              .trim()
              .toLowerCase() ==
          'yes';

      final request = _QcRequest(filePath, expectedDurationSeconds, enhanced);
      final started = DateTime.now();

      // The isolate normally answers in well under a second. Under a
      // debugger a freshly spawned isolate can be left paused and never
      // answer at all, which showed as "Checking audio..." forever - so
      // after a generous wait the analysis runs here instead. It is a
      // single pass over the samples, cheap enough for the UI isolate.
      AudioQcResult result;
      try {
        result = await compute(
          _analyze,
          request,
        ).timeout(const Duration(seconds: 15));
      } on TimeoutException {
        debugPrint('QC: isolate did not answer in 15s, analysing inline');
        result = await _analyze(request);
      }
      debugPrint(
        'QC: ${result.status} in '
        '${DateTime.now().difference(started).inMilliseconds} ms',
      );

      final failed = result.checks.where((check) => !check.passed);

      return QcOutcome(
        status: result.status,
        notes: failed
            .map((check) => '${check.label}: ${check.english}')
            .join('\n'),
        report: result.toJson(),
        checks: result.checks,
      );
    } catch (e) {
      debugPrint('QC ERROR ($filePath): $e');
      final message = e.toString().replaceFirst('Exception: ', '');

      // Nothing was measured, so there is no report to store - only the
      // reason, which the drafter needs in order to know it is the file and
      // not the recording that is wrong.
      return QcOutcome(
        status: 'Bad',
        notes: 'Could not analyse this recording: $message',
        report: const {},
        error: message,
      );
    }
  }
}

/// For the recordings QC does not grade - a back translation, a spoken
/// comment - the one question worth asking of them anyway.
class RecordingCheck {
  RecordingCheck._();

  /// What to say when [isSilent] is true.
  static const String silentMessage = QcOutcome.noVoiceNotice;

  /// Whether the recording at [filePath] has no voice in it. A microphone
  /// that is muted, or handed to something else, still writes a file of
  /// the right length - and whoever recorded it has no way to know until
  /// somebody else presses play. False when the file cannot be read: that
  /// is a different fault, and not one to guess at here.
  static Future<bool> isSilent(String filePath) async {
    try {
      final result = await compute(
        _analyze,
        _QcRequest(filePath, null, false),
      ).timeout(const Duration(seconds: 15));
      // Nobody speaking, which is more than nothing sounding: a room
      // with a fan in it is not a recording of anyone.
      return result.checks.any(
        (check) => check.key == 'voice_presence' && !check.passed,
      );
    } catch (e) {
      debugPrint('SILENCE CHECK FAILED ($filePath): $e');
      return false;
    }
  }
}

class _QcRequest {
  const _QcRequest(this.path, this.expectedDurationSeconds, this.enhancedQc);

  final String path;
  final double? expectedDurationSeconds;
  final bool enhancedQc;
}

Future<AudioQcResult> _analyze(_QcRequest request) {
  return WavAnalyzer.analyze(
    request.path,
    config: AudioQcConfig(
      expectedDurationSeconds: request.expectedDurationSeconds,
      enhancedQc: request.enhancedQc,
    ),
  );
}
