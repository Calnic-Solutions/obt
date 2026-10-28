import 'package:flutter/material.dart';
import 'package:livuka/main.dart';

/// What a pin on a waveform means, said in colour.
///
/// The same scheme the website uses, so a Set looked at on a phone and the
/// same Set looked at in a browser are marked up identically:
///
/// * a **comment** is red, because a comment always means something is wrong
///   here, however it was left;
/// * a **question** is not the same kind of flag, so it is mustard - and a
///   question asked in writing takes the warning orange, so a voice question
///   and a text one are tellable apart on the waveform without opening
///   either (`.kind-question` and `.kind-question.is-text` on the website);
/// * a question a reviewer has **replied to** turns red like a comment: the
///   reviewer was not satisfied with the answer, and that now needs the
///   drafter the way a comment does.
class MarkColors {
  const MarkColors._();

  /// `--ob-danger`
  static const Color comment = Color(0xFFDC2626);

  /// `--ob-yellow-dark`
  static const Color voiceQuestion = Color(0xFFCA8A04);

  /// `--ob-warning` (#FBBF24 on the website since 2026-09-25)
  static const Color textQuestion = Color(0xFFFBBF24);

  /// `--ob-text-faint`: a mark that has been dealt with. Still there, so the
  /// history of the recording can be read off it, but no longer asking for
  /// anything.
  static const Color resolved = Color(0xFF98A2B3);

  /// Source recordings play in indigo and back translations in amber, so
  /// which of several players on a screen is which can be told at a glance.
  static const Color sourceAudio = Color(0xFF4F46E5);

  /// The foot of the source player's gradient (`--ob-source-dark`): its
  /// played bars and play button run from [sourceAudio] at the top down to
  /// this, which is what makes the website's indigo read as deep as it
  /// does. Any other accent shades to a darker version of itself.
  static const Color sourceAudioDark = Color(0xFF3730A3);

  /// `--ob-brand-dark`: the foot of every brand-coloured player's gradient.
  /// The same dark orange as [MainApp.brandDark]; it was still the old
  /// purple after the move to orange, and the play button faded into it.
  static const Color brandDark = MainApp.brandDark;

  /// The darker end of a player's gradient for [accent]: the website's own
  /// pair for the three accents it paints players with (brand, source,
  /// back translation), and a darker shade of itself for anything else.
  static Color shadeOf(Color accent) => switch (accent) {
    sourceAudio => sourceAudioDark,
    backTranslationAudio => backTranslationAudioDark,
    MainApp.primaryGreen => brandDark,
    _ => Color.lerp(accent, Colors.black, 0.28)!,
  };

  /// Wraps [child] so its opaque pixels take the accent's gradient, top to
  /// bottom - the website paints its played bars that way.
  static Widget shaded(Color accent, Widget child) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (bounds) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [accent, shadeOf(accent)],
    ).createShader(bounds),
    child: child,
  );
  static const Color backTranslationAudio = Color(0xFFD97706);

  /// The foot of the back-translation player's gradient (`#92400E` on the
  /// website's Back Translator and Consultant screens).
  static const Color backTranslationAudioDark = Color(0xFF92400E);

  /// The colour for one question's pin, and for the icon on its card - the
  /// two are the same mark seen twice, and reading differently would make
  /// them look like different things.
  static Color question({required bool hasAudio, required bool hasReply}) {
    if (hasReply) return comment;
    return hasAudio ? voiceQuestion : textQuestion;
  }
}
