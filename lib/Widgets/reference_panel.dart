import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:get/get.dart';

import 'package:livuka/services/script_text.dart';
import 'package:livuka/Widgets/script_reader.dart';
import 'package:livuka/Widgets/script_text_view.dart';
import 'package:livuka/Widgets/audio_clip.dart';
import 'package:livuka/Widgets/pulse_halo.dart';
import 'package:livuka/main.dart';
import 'package:livuka/services/work_queue.dart';

/// Everything a passage was given to work from, above the recorder.
///
/// It used to be a drawer, which meant the reading and the record button
/// could never be on screen together: the drafter opened the panel, read,
/// closed it, and recorded from memory. Here the source stays in front of
/// them while they read it aloud, which is what the screen is for.
///
/// The recording stays put at the top; the scripts scroll under it, inside
/// whatever height the recorder leaves them.
class ReferencePanel extends StatefulWidget {
  const ReferencePanel({
    super.key,
    required this.leaf,
    this.onSourceAudioPlayed,
    this.onSourceAudioEnded,
    this.mustListenSource,
    this.highlightAudio = false,
    this.readConfirm,
  });

  final SetLeaf leaf;

  /// "I have read" under each script, when the page wants them: which are
  /// already ticked, which one is next, and what to do when one is.
  final ReadConfirm? readConfirm;

  /// Fires once the source recording actually starts playing, which is what
  /// the drafting gate counts as having heard it.
  final VoidCallback? onSourceAudioPlayed;

  /// Fires when the source recording reaches its end - heard right through,
  /// which is not the same as started.
  final VoidCallback? onSourceAudioEnded;

  /// Whether the source still has to be heard right through; see
  /// [AudioClip.mustListen].
  final bool? mustListenSource;

  /// Ripples the source player while it is what the recorder is waiting on.
  final bool highlightAudio;

  @override
  State<ReferencePanel> createState() => _ReferencePanelState();
}

class _ReferencePanelState extends State<ReferencePanel> {
  SetLeaf get leaf => widget.leaf;
  ReadConfirm? get readConfirm => widget.readConfirm;
  VoidCallback? get onSourceAudioPlayed => widget.onSourceAudioPlayed;
  VoidCallback? get onSourceAudioEnded => widget.onSourceAudioEnded;
  bool get highlightAudio => widget.highlightAudio;

  /// Under this height there is no room to pin anything: the player alone
  /// is taller. The whole panel then scrolls as one column instead - a
  /// phone on its side, or a very small one.
  static const double _pinnedMinHeight = 300;

  /// From this width the two scripts sit side by side, as the website lays
  /// them out: a phone on its side, or a tablet. Narrower, one above the
  /// other.
  static const double _sideBySideMinWidth = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pinned = constraints.maxHeight >= _pinnedMinHeight;
        final wide = constraints.maxWidth >= _sideBySideMinWidth;
        final children = [
          // Pinned, and on its own above the scripts rather than inside
          // their panel: a bordered player inside a bordered panel was two
          // frames round one thing. The recording is what the drafter
          // plays and replays while reading, and a player that scrolls out
          // of reach is one they have to go looking for mid-take.
          _player(),
          const SizedBox(height: 8),
          // Each script in a card of its own, scrolling on its own.
          //
          // Wide: the two share the row, half each, the same height.
          //
          // Narrow: one above the other. Each card is as tall as its text
          // wants, up to what is left under the player; a short script
          // leaves the room under the cards empty rather than holding it
          // inside the card. When the two together want more than there
          // is, the one that fits in half keeps its height and the other
          // scrolls in the rest; two long ones split it equally. With no
          // target script yet its card is a heading and a line saying so.
          if (wide)
            _wideFlex(
              pinned,
              _sameHeight(
                pinned,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _sourceCard(_fitFor(pinned))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: leaf.hasTargetScript
                          ? _targetCard(_fitFor(pinned))
                          : _ScriptCard(
                              icon: Icons.translate,
                              label: 'Target script',
                              fit: _fitFor(pinned),
                              child: Text(
                                'No target script yet.'.tr,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MainApp.mutedText,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            )
          else if (pinned)
            Expanded(
              child: _ShareHeight(
                gap: 8,
                children: [
                  _sourceCard(_CardFit.loose),
                  if (leaf.hasTargetScript)
                    _targetCard(_CardFit.loose)
                  else
                    const _EmptyScriptCard(
                      icon: Icons.translate,
                      label: 'Target script',
                      text: 'No target script yet.',
                    ),
                ],
              ),
            )
          else ...[
            _sourceCard(_CardFit.natural),
            const SizedBox(height: 8),
            if (leaf.hasTargetScript)
              _targetCard(_CardFit.natural)
            else
              const _EmptyScriptCard(
                icon: Icons.translate,
                label: 'Target script',
                text: 'No target script yet.',
              ),
          ],
        ];

        if (pinned) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }

  /// Side by side, the row takes the height left under the player when
  /// the panel is pinned.
  Widget _wideFlex(bool pinned, Widget row) =>
      pinned ? Expanded(child: row) : row;

  /// Side by side, the cards fill the row's height when the panel is
  /// pinned; scrolling with the panel they are as tall as their text.
  static _CardFit _fitFor(bool pinned) =>
      pinned ? _CardFit.expand : _CardFit.natural;

  /// Side by side in a scrolling panel, the shorter card is drawn as tall
  /// as the longer one; pinned, the row already has its height.
  Widget _sameHeight(bool pinned, Widget row) =>
      pinned ? row : IntrinsicHeight(child: row);

  Widget _player() {
    return leaf.hasSourceAudio
        ? _AudioBox(
            path: leaf.sourceAudioPath,
            onPlayed: onSourceAudioPlayed,
            onEnded: onSourceAudioEnded,
            mustListen: widget.mustListenSource,
            highlight: highlightAudio,
          )
        : const _AbsentBox(
            icon: Icons.volume_up_rounded,
            label: 'Source audio',
            child: _Absent(
              icon: Icons.volume_off_rounded,
              text: 'No source audio yet.',
            ),
          );
  }

  Widget _sourceCard(_CardFit fit) {
    return _ScriptCard(
      icon: Icons.description_outlined,
      label: 'Source script',
      fit: fit,
      expandText: leaf.hasSourceScript ? shownScript(leaf.sourceScript) : null,
      footer: leaf.hasSourceScript && readConfirm != null
          ? _HaveRead(
              ticked: readConfirm!.source,
              highlight: readConfirm!.highlightSource,
              onTick: () => readConfirm!.onRead(false),
            )
          : null,
      child: leaf.hasSourceScript
          ? ScriptTextView(text: shownScript(leaf.sourceScript))
          : const _Absent(
              icon: Icons.description_outlined,
              text: 'No source script yet.',
            ),
    );
  }

  Widget _targetCard(_CardFit fit) {
    return _ScriptCard(
      icon: Icons.translate,
      label: 'Target script',
      fit: fit,
      expandText: shownScript(leaf.targetScript),
      footer: readConfirm == null
          ? null
          : _HaveRead(
              ticked: readConfirm!.target,
              highlight: readConfirm!.highlightTarget,
              onTick: () => readConfirm!.onRead(true),
            ),
      child: ScriptTextView(text: shownScript(leaf.targetScript)),
    );
  }
}

/// The state of the two "I have read" boxes, handed in by the page:
/// which are ticked, which one is the next thing to do (it pulses, as the
/// website's highlighted script box does), and what to do when one is.
typedef ReadConfirm = ({
  bool source,
  bool target,
  bool highlightSource,
  bool highlightTarget,
  void Function(bool target) onRead,
});

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.child,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final Widget child;

  /// The last section carries no gap under it - the panel's own padding is
  /// the space, and doubling it reads as a stray blank row when scrolled to
  /// the bottom.
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MainApp.mutedText),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.tr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MainApp.mutedText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// One script in a bordered card: its heading pinned at the top, the text
/// scrolling under it.
///
/// How tall it is depends on [fit]: as tall as its text, scrolling with
/// the panel around it; as tall as its parent, scrolling inside; or as
/// tall as its text up to what its parent allows, and scrolling inside
/// past that.
///
/// The [footer] - the "I have read" box - is pinned under the text like
/// the heading is pinned over it, so the box is there to tick without
/// scrolling to the end of a long passage first.
class _ScriptCard extends StatelessWidget {
  const _ScriptCard({
    required this.icon,
    required this.label,
    required this.child,
    this.expandText,
    this.footer,
    this.fit = _CardFit.expand,
  });

  final IconData icon;
  final String label;
  final Widget child;
  final String? expandText;
  final Widget? footer;
  final _CardFit fit;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      children: [
        Icon(icon, size: 14, color: MainApp.mutedText),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label.tr,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MainApp.mutedText,
            ),
          ),
        ),
        if (expandText case final text?)
          ExpandScriptButton(title: label, icon: icon, text: text),
      ],
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          heading,
          const SizedBox(height: 4),
          switch (fit) {
            _CardFit.natural => child,
            _CardFit.expand => Expanded(
              child: SingleChildScrollView(child: child),
            ),
            _CardFit.loose => Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(child: child),
            ),
          },
          ?footer,
        ],
      ),
    );
  }
}

/// A script that is not there yet: its heading, and under it the reason,
/// set in from the edge to line up with the heading's words. One icon, on
/// the heading - a second one on the reason read as a mistake.
class _EmptyScriptCard extends StatelessWidget {
  const _EmptyScriptCard({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // As tall as its two lines, whatever height it is offered: given
        // room, it took all of it and read as a long script's card.
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: MainApp.mutedText),
              const SizedBox(width: 6),
              Text(
                label.tr,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MainApp.mutedText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            // Under the heading's words, not under its icon.
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Text(
              text.tr,
              style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

/// The source recording in a card of its own, above the scripts' panel.
class _AudioBox extends StatelessWidget {
  const _AudioBox({
    required this.path,
    this.onPlayed,
    this.onEnded,
    this.mustListen,
    this.highlight = false,
  });

  final String path;
  final VoidCallback? onPlayed;
  final VoidCallback? onEnded;
  final bool? mustListen;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: AudioClip(
        key: ValueKey(path),
        filePath: path,
        allowSeek: true,
        highlight: highlight,
        title: 'Source audio',
        header: AudioClip.label(Icons.volume_up_rounded, 'Source audio'),
        // Indigo, as source audio is everywhere else.
        accent: MarkColors.sourceAudio,
        onEnded: onEnded,
        mustListen: mustListen,
        // Started playing is what counts as heard: the gate is about having
        // listened, not about having tapped a button.
        onPosition: onPlayed == null
            ? null
            : (position) {
                if (position > Duration.zero) onPlayed!();
              },
      ),
    );
  }
}

/// The frame the player would have had, round a "none yet" line.
class _AbsentBox extends StatelessWidget {
  const _AbsentBox({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: _Section(icon: icon, label: label, last: true, child: child),
    );
  }
}

class _Absent extends StatelessWidget {
  const _Absent({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: MainApp.mutedText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text.tr,
              style: const TextStyle(fontSize: 12, color: MainApp.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}

/// "I have read" under a script. Ticks once and stays ticked - a
/// confirmation, not a toggle, the way it is on the website.
class _HaveRead extends StatelessWidget {
  const _HaveRead({
    required this.ticked,
    required this.onTick,
    this.highlight = false,
  });

  final bool ticked;
  final VoidCallback onTick;

  /// Pulses the box while ticking it is the next thing to do.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: ticked ? null : onTick,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Its own box, drawn a little larger than Material's: the
              // whole row is the target, and a 44px row is a thumb's.
              PulseHalo(
                active: highlight && !ticked,
                minSize: 24,
                maxSize: 52,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: ticked,
                    onChanged: ticked ? null : (_) => onTick(),
                    activeColor: MainApp.primaryGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'I have read'.tr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ticked ? MainApp.mutedText : MainApp.titleColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How a script card takes its height.
enum _CardFit {
  /// As tall as its text; the panel around it scrolls.
  natural,

  /// As tall as its parent; the text scrolls inside.
  expand,

  /// As tall as its text, up to what the parent allows; past that the
  /// text scrolls inside.
  loose,
}

/// Lays the script cards out one above the other in the height under the
/// player, giving each the height its text wants.
///
/// A Column of Expanded cards gave each a fixed share whether it needed
/// it or not, so a three-line script sat in a card half the screen tall.
/// Here each card is measured first at the full height on offer. When
/// they fit together, each keeps its own height and what is left stays
/// empty under them. When they do not, the one that fits in half keeps
/// its height and the other scrolls in the rest; two long ones split the
/// height equally, as before.
class _ShareHeight extends MultiChildRenderObjectWidget {
  const _ShareHeight({required this.gap, required super.children});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderShareHeight(gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShareHeight renderObject,
  ) {
    renderObject.gap = gap;
  }
}

class _ShareParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderShareHeight extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ShareParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ShareParentData> {
  _RenderShareHeight({required double gap}) : _gap = gap; // ignore: prefer_initializing_formals

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ShareParentData) {
      child.parentData = _ShareParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final children = getChildrenAsList();
    final gaps = _gap * (children.length - 1).clamp(0, children.length);
    final available = (constraints.maxHeight - gaps).clamp(0.0, double.infinity);

    // Measured: how tall each would be with the whole height to itself.
    final wanted = <double>[];
    for (final child in children) {
      child.layout(
        BoxConstraints(
          minWidth: width,
          maxWidth: width,
          maxHeight: available,
        ),
        parentUsesSize: true,
      );
      wanted.add(child.size.height);
    }

    // Allotted: their own heights when they fit together; otherwise the
    // short one its own and the long one the rest, or an equal split.
    final allotted = List<double>.of(wanted);
    if (children.length == 2 && wanted[0] + wanted[1] > available) {
      final half = available / 2;
      if (wanted[0] <= half) {
        allotted[1] = available - wanted[0];
      } else if (wanted[1] <= half) {
        allotted[0] = available - wanted[1];
      } else {
        allotted[0] = half;
        allotted[1] = half;
      }
    }

    var y = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (allotted[i] != wanted[i]) {
        child.layout(
          BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: allotted[i],
          ),
          parentUsesSize: true,
        );
      }
      (child.parentData! as _ShareParentData).offset = Offset(0, y);
      y += child.size.height + _gap;
    }

    // The whole height on offer, so what the cards leave stays empty
    // under them rather than pulling the recorder up.
    size = constraints.biggest;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
