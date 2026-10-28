import 'package:get/get.dart' show Trans;

/// A sentence with a count in it, singular or plural.
///
/// Each form is a whole sentence of its own with an `@count` in it, never an
/// "s" added to a word: Urdu and Hindi change the verb with the number, not
/// only the noun, and some sentences do not change at all.
String trCount(int count, String one, String many) =>
    (count == 1 ? one : many).trParams({'count': '$count'});
