import 'package:get/get.dart';

import 'package:livuka/l10n/hi.dart';
import 'package:livuka/l10n/ur.dart';

/// The interface in Urdu and Hindi.
///
/// The English sentence is the key. A sentence with no entry here simply
/// shows in English, so a string added to a screen and not yet translated is
/// a gap somebody can see rather than a blank or a code - and the screens
/// stay readable as English in the source.
///
/// A sentence with something changeable in it - a count, a name - is written
/// once with `@name` placeholders and filled through `trParams`, because word
/// order differs: Urdu and Hindi put the verb last, and a sentence glued
/// together from English halves comes out in English order.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'ur': ur, 'hi': hi};
}
