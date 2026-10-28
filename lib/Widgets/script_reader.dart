import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/script_text_view.dart';
import 'package:livuka/main.dart';

/// A script on its own, full screen, with its text made larger or smaller.
///
/// The website's maximised script card. The passage card on the recorder
/// shares its screen with the player and the mic, which leaves a script a
/// few lines at a time; somebody reading a whole passage aloud wants it
/// laid out like a page, at whatever size their eyes need - the website
/// steps from 0.7x to 1.9x, and so does this. The size is for this visit
/// only: the card underneath keeps its own, as on the website, where the
/// zoom resets when the card is restored.
class ScriptReaderPage extends StatefulWidget {
  const ScriptReaderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  static Future<void> open({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String text,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ScriptReaderPage(title: title, icon: icon, text: text),
    ),
  );

  @override
  State<ScriptReaderPage> createState() => _ScriptReaderPageState();
}

class _ScriptReaderPageState extends State<ScriptReaderPage> {
  static const double _min = 0.7;
  static const double _max = 1.9;
  static const double _step = 0.15;

  double _zoom = 1;

  void _zoomBy(double delta) => setState(() {
    _zoom = ((_zoom + delta) * 100).round() / 100;
    _zoom = _zoom.clamp(_min, _max);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close'.tr,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Row(
          children: [
            Icon(widget.icon, size: 18, color: MainApp.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _ZoomButton(
            icon: Icons.zoom_out_rounded,
            tooltip: 'Zoom out',
            onPressed: _zoom > _min ? () => _zoomBy(-_step) : null,
          ),
          // The size, so a pair of taps can be seen to have done something
          // even on a script short enough not to reflow.
          SizedBox(
            width: 44,
            child: Text(
              '${(_zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MainApp.mutedText,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _ZoomButton(
            icon: Icons.zoom_in_rounded,
            tooltip: 'Zoom in',
            onPressed: _zoom < _max ? () => _zoomBy(_step) : null,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            // Scaled here rather than by font size, so the script view's
            // own direction and alignment rules are left untouched.
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(_zoom)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(fontSize: 16, height: 1.7),
                child: ScriptTextView(text: widget.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip.tr,
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      color: const Color(0xFF040134),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
    );
  }
}

/// The way into the full-screen reader, on a script card's header.
class ExpandScriptButton extends StatelessWidget {
  const ExpandScriptButton({
    super.key,
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Held to the heading's own height. Material 3 gives every icon button
    // a 40px minimum whatever constraints it is handed, and that minimum
    // was the whole height of the row the heading sat in - taken straight
    // out of the script below it.
    return SizedBox(
      width: 34,
      height: 22,
      child: IconButton(
        tooltip: 'Full screen'.tr,
        onPressed: () => ScriptReaderPage.open(
          context: context,
          title: title,
          icon: icon,
          text: text,
        ),
        icon: const Icon(Icons.open_in_full_rounded, size: 16),
        color: MainApp.mutedText,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          minimumSize: const Size(34, 22),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
