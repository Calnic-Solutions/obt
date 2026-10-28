import 'package:flutter/material.dart';

import 'package:livuka/main.dart';
import 'package:livuka/services/name_language.dart';

/// The Eng / Source switch for Set names.
///
/// Both options are always visible rather than one label that changes on tap:
/// a reader who cannot read the source script needs to see which side is
/// which before pressing, not after.
class NameLanguageToggle extends StatelessWidget {
  const NameLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NameLanguage.showSource,
      builder: (context, showSource, _) {
        // Two short words and a rule, no pill around them. The bar's width
        // belongs to the Set's name; a switch used once a session does not
        // need a button's worth of it. One tap anywhere flips it - with only
        // two states there is nothing to aim at - and the target is kept a
        // thumb's height though the letters are small.
        return InkWell(
          onTap: () => NameLanguage.set(!showSource),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Half(label: 'EN', selected: !showSource),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '|',
                    style: TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                  ),
                ),
                _Half(label: 'SRC', selected: showSource),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    // Latin in every language, like the "Eng" it replaces: it names a
    // choice of script, and is read as a badge rather than as a word.
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        letterSpacing: 0.3,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? MainApp.primaryGreen : const Color(0xFF94A3B8),
      ),
    );
  }
}

class NameLanguageBuilder extends StatelessWidget {
  const NameLanguageBuilder({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NameLanguage.showSource,
      builder: (context, _, _) => builder(context),
    );
  }
}
