/// The passage as it should be read, rather than as it is filed.
///
/// Source scripts are stored as text files with a reference stamped at the
/// front of every verse:
///
///     متی # 4:1 # پھر روح القدس عیسیٰ کو ریگستان میں لے گیا
///
/// The book and reference are how the file is indexed, not part of the
/// passage. The web app strips them before showing the script, so a phone
/// that does not is a phone showing something different from the screen the
/// same person was reading an hour ago - which is the whole of the
/// difference between the two, the words themselves being identical. The
/// verse range is already on the passage itself, so nothing is lost.
library;

/// A verse marker: anything short before a hash, then a chapter:verse (or a
/// range), then a closing hash. Anchored to the start of a line, so a hash
/// inside the passage is left alone.
final RegExp _verseMarker = RegExp(
  r'^[ \t]*[^#\r\n]{0,40}#[ \t]*\d+[ \t]*:[ \t]*\d+(?:[ \t]*[-–][ \t]*\d+)?'
  r'[ \t]*#[ \t]*',
  multiLine: true,
);

/// Invisible direction marks some Urdu and Arabic source files carry around
/// punctuation - U+200E/F, U+061C, the embeddings and the isolates. They
/// show as nothing, but one sitting between the "26" and the "-27" of a
/// reference stops it being recognised as a reference at all.
final RegExp _bidiControls = RegExp(
  r'[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]',
  unicode: true,
);

/// The book name in front of a verse reference: everything on the line up
/// to, and not including, the `#` that opens `# 4:12 #`. Keyed off the shape
/// of the reference rather than the name, so it works whatever language the
/// book is named in.
final RegExp _bookName = RegExp(
  r'^.*?(?=#\s*\d+:\d+[a-zA-Z]?(?:-\d+[a-zA-Z]?)?\s*#)',
  multiLine: true,
);

/// The `# 1:14 #` reference left at the head of a line once the book name
/// in front of it has gone. The same shape [_bookName] keys off, so the
/// two always agree on what a reference is.
final RegExp _verseReference = RegExp(
  r'^[ \t]*#\s*\d+:\d+[a-zA-Z]?(?:\s*[-–]\s*\d+[a-zA-Z]?)?\s*#[ \t]*',
  multiLine: true,
);

/// [script] as it is shown: the website's `stripVerseMarkers` takes the
/// book name off every line, and the `# 1:14 #` reference behind it goes
/// too, so the passage reads as words alone. The verse range is already on
/// the passage itself, so nothing is lost.
String shownScript(String script) {
  if (script.isEmpty) return script;

  final cleaned = script
      .replaceAll(_bidiControls, '')
      .replaceAll(_bookName, '')
      .replaceAll(_verseReference, '');

  return cleaned.split('\n').map((line) => line.trimRight()).join('\n').trim();
}

/// Letters of the right-to-left scripts - Hebrew, Arabic and its
/// extensions (Urdu among them), Syriac, Thaana, N'Ko, Samaritan, Mandaic
/// and the presentation forms - as the website's `TextDirection` lists them.
final RegExp _rtlLetters = RegExp(
  r'[֐-׿؀-ۿ܀-ݏݐ-ݿހ-޿'
  r'߀-߿ࠀ-࠿ࢠ-ࣿיִ-ﭏﭐ-﷿'
  r'ﹰ-﻿]',
);

/// Latin letters, plain and accented.
final RegExp _latinLetters = RegExp(r'[A-Za-zÀ-ɏ]');

/// Whether [text] is laid out right to left: the website's
/// `TextDirection::isRtl`, which counts the letters of each kind and goes
/// with the greater. Read from the text because nothing else says - a
/// project's language carries no direction - and counted rather than
/// spotted, so an English passage quoting one Urdu word stays as it is.
bool scriptIsRtl(String text) {
  if (text.trim().isEmpty) return false;
  return _rtlLetters.allMatches(text).length >
      _latinLetters.allMatches(text).length;
}

/// [script] with its verse markers removed and its blank lines tidied. For
/// anywhere the bare words are wanted; the screens use [shownScript].
String plainScript(String script) {
  if (script.isEmpty) return script;

  final stripped = script.replaceAll(_verseMarker, '');

  return stripped.split('\n').map((line) => line.trimRight()).join('\n').trim();
}
