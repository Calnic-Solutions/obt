import 'package:get/get.dart' show Trans;

/// What a QC check means to the person who made the recording.
///
/// The checks measure in decibels and seconds, and the report keeps those
/// numbers for the log and the server. The screen says instead what the
/// check found and, when it failed, what to do about it next time: the
/// drafter is not an engineer, and "-42 dBFS" tells them nothing about
/// where to sit.
class QcFeedback {
  QcFeedback._();

  /// The sentence for [key] - a check's name as the analyzer files it -
  /// having [passed] or not. Empty for a check this does not know, so the
  /// caller can fall back on the measured detail.
  static String of(String key, {required bool passed}) {
    final text = switch (key) {
      'clipping' =>
        passed
            ? 'Clear audio with no distortion from excessive volume.'
            : 'Audio distortion detected due to excessive volume. Reduce '
                  'speaking volume or increase the distance from the '
                  'microphone.',
      'edge_silence' =>
        passed
            ? 'Recording begins and ends naturally, with minimal silence.'
            : 'Excessive silence detected at the beginning or end. Start '
                  'promptly and stop shortly after the final word.',
      'noise_floor' =>
        passed
            ? 'A quiet recording environment ensures clear speech.'
            : 'Background noise is affecting speech clarity. Record in a '
                  'quieter environment away from fans, traffic, and other '
                  'people.',
      'duration' =>
        passed
            ? 'Recording duration matches the expected passage length.'
            : 'Recording duration differs significantly from the expected '
                  'length. Check passage completeness and avoid extra content.',
      'sample_format' =>
        passed
            ? 'Audio format meets the project requirements.'
            : 'Audio format does not meet project requirements. Record '
                  'directly through the app to ensure compatibility.',
      'truncation' =>
        passed
            ? 'The complete passage is captured, including the final word.'
            : 'The recording may have ended before speech was complete. '
                  'Allow a brief pause after the final word before stopping.',
      'voice_presence' =>
        passed
            ? 'Speech is clearly audible throughout the recording.'
            : 'Little or no speech was detected. Improve speech clarity and '
                  'maintain an appropriate distance from the microphone.',
      'volume_consistency' =>
        passed
            ? 'Speech volume remains consistent throughout the recording.'
            : 'Significant volume variations detected. Maintain a steady '
                  'speaking volume from beginning to end.',
      'background_noise' =>
        passed
            ? 'Speech remains clear without distracting competing sounds.'
            : 'Competing sounds are affecting speech clarity. Choose a '
                  'quieter recording environment for better results.',
      _ => '',
    };
    return text.isEmpty ? '' : text.tr;
  }
}
