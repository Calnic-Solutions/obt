import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:livuka/main.dart';
import 'package:livuka/Widgets/mark_colors.dart';
import 'package:livuka/Widgets/speed_selector.dart';

/// Loading drawn as the shape of what is coming.
///
/// A spinner in the middle of an empty screen says only "wait". A grey
/// outline of the card, the list or the player that is about to appear says
/// what is being waited for and where it will land, and a soft light moving
/// across it says the wait is alive. Every page's loading state is built
/// from the pieces here, each shaped to the content it stands in for.
///
/// Only what is being loaded is drawn this way. Headings, icons and buttons
/// that are fixed in the page are drawn as themselves, so the page's own
/// words are never shown as grey bars - and so they cannot be a pixel out
/// from the page that replaces them.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.delay = _defaultDelay});

  final Widget child;

  /// How long a load may take before anything is shown for it.
  ///
  /// Most reads on this phone finish in a few frames - the data is already
  /// on the device - and a skeleton that flashes up and vanishes for every
  /// one of them is noise, not help. So nothing is drawn for this long; the
  /// shapes appear only for a load that is still running after it, which
  /// is the only kind anyone is actually waiting on.
  final Duration delay;

  static const Duration _defaultDelay = Duration(milliseconds: 350);

  static const Color base = Color(0xFFE5E7EB);
  static const Color highlight = Color(0xFFF7F7F9);

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// The box the light crosses, so every bone under it can tell where it
  /// sits in the sweep.
  final GlobalKey _bounds = GlobalKey();

  /// Whether the delay has passed and the shapes are showing.
  bool _shown = false;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    if (widget.delay <= Duration.zero) {
      _reveal();
    } else {
      _hold = Timer(widget.delay, _reveal);
    }
  }

  void _reveal() {
    if (!mounted) return;
    setState(() => _shown = true);
    _sweep.repeat();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Laid out from the first frame, so the page does not jump when the
    // shapes appear; just not painted until the wait has earned them.
    return Visibility(
      visible: _shown,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: _ShimmerScope(
        sweep: _sweep,
        bounds: _bounds,
        child: KeyedSubtree(key: _bounds, child: widget.child),
      ),
    );
  }
}

/// How the bones under a [Shimmer] find its light.
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.sweep,
    required this.bounds,
    required super.child,
  });

  final Animation<double> sweep;
  final GlobalKey bounds;

  static _ShimmerScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();

  @override
  bool updateShouldNotify(_ShimmerScope old) =>
      sweep != old.sweep || bounds != old.bounds;
}

/// One grey shape: a line of text, a button, a picture.
///
/// Only the bones carry the moving light - the white cards they sit in are
/// drawn as themselves, so a card under a shimmer still reads as a card. The
/// light is one band crossing the whole [Shimmer], and each bone shows the
/// part of it that is passing over its own place on the screen.
class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 12, this.radius = 6});

  /// A round one - an avatar, an icon disc, a play button.
  const Bone.circle({super.key, required double size})
    : width = size,
      height = size,
      radius = size / 2;

  /// As big as the box it is given - for [BoneShape], which hands it the
  /// exact size of the widget it stands in for.
  const Bone.fill({super.key, this.radius = 6}) : width = null, height = null;

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scope = _ShimmerScope.maybeOf(context);
    final shape = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Shimmer.base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    if (scope == null) return shape;

    return AnimatedBuilder(
      animation: scope.sweep,
      child: shape,
      builder: (context, child) {
        // Where this bone sits across the lit area. Before the first
        // layout there is no answer yet, and the band simply starts at
        // the bone's own left edge.
        var left = 0.0;
        var span = 320.0;
        final mine = context.findRenderObject();
        final whole = scope.bounds.currentContext?.findRenderObject();
        if (mine is RenderBox &&
            whole is RenderBox &&
            mine.hasSize &&
            whole.hasSize) {
          left = mine.localToGlobal(Offset.zero, ancestor: whole).dx;
          span = whole.size.width;
        }
        final t = scope.sweep.value;
        // Painted straight onto the canvas with the band as its shader:
        // one rounded rectangle, no offscreen layer. A mask over each bone
        // cost a layer per bone per frame, and a page of fifty bones was
        // work the phone could feel.
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _BonePainter(
              radius: radius,
              bandLeft: -left + span * (t * 2 - 1),
              bandWidth: span,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

/// One bone, lit by the slice of the band passing over it.
class _BonePainter extends CustomPainter {
  const _BonePainter({
    required this.radius,
    required this.bandLeft,
    required this.bandWidth,
  });

  final double radius;
  final double bandLeft;
  final double bandWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Shimmer.base, Shimmer.highlight, Shimmer.base],
        stops: [0.35, 0.5, 0.65],
      ).createShader(Rect.fromLTWH(bandLeft, 0, bandWidth, size.height));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BonePainter old) =>
      old.bandLeft != bandLeft ||
      old.bandWidth != bandWidth ||
      old.radius != radius;
}

/// One line of text that is still loading.
///
/// Exactly as tall as a real line of [style] - measured with the app's own
/// font, in the text style around it - with a bar through its middle. A bar
/// guessed at the font size was a few pixels short of the line it stood in
/// for, and a column of them came up short by a line's worth.
///
/// [width] fixes how long the bar is; without it the bar spans the width it
/// is given, cut to [widthFactor].
class BoneText extends StatelessWidget {
  const BoneText({super.key, this.style, this.width, this.widthFactor = 1});

  final TextStyle? style;
  final double? width;
  final double widthFactor;

  /// The height one line of [style] takes here, as a [Text] would draw it.
  static double lineHeight(BuildContext context, [TextStyle? style]) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Hg',
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final line = lineHeight(context, style);
    final font = MediaQuery.textScalerOf(context)
        .scale(effective.fontSize ?? 14);
    final bar = math.min(line, (font * 0.8).roundToDouble());

    if (width != null) {
      return SizedBox(
        width: width,
        height: line,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Bone(width: width, height: bar, radius: bar / 2),
        ),
      );
    }
    return SizedBox(
      height: line,
      child: LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: AlignmentDirectional.centerStart,
          child: Bone(
            width: constraints.maxWidth * widthFactor,
            height: bar,
            radius: bar / 2,
          ),
        ),
      ),
    );
  }
}

/// A paragraph that is still loading: [lines] lines of [style], set solid
/// as a [Text] sets them, the last one shorter, as a paragraph ends.
class BoneParagraph extends StatelessWidget {
  const BoneParagraph({
    super.key,
    this.lines = 3,
    this.style,
    this.lastWidth = 0.6,
  });

  final int lines;
  final TextStyle? style;

  /// The last line's share of the width.
  final double lastWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++)
          BoneText(
            style: style,
            widthFactor: i == lines - 1 && lines > 1 ? lastWidth : 1,
          ),
      ],
    );
  }
}

/// A bone the exact size of [child], which is laid out but never drawn.
///
/// For the pills, tags and buttons whose words depend on what is loading:
/// the real widget, with a typical label, decides how much room the shape
/// takes, so it takes the same room as the one that replaces it.
class BoneShape extends StatelessWidget {
  const BoneShape({super.key, required this.child, this.radius = 6});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: IgnorePointer(child: child),
        ),
        Positioned.fill(child: Bone.fill(radius: radius)),
      ],
    );
  }
}

/// The white card the app draws round most things, holding bones.
class BoneCard extends StatelessWidget {
  const BoneCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: MainApp.cardShadow,
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// The pieces pages are made of.
// ---------------------------------------------------------------------------

/// The row over a [ContinuousPlayer]'s waveform: the heading, the
/// full-screen button and the speed pill - the last two as themselves,
/// greyed, since neither depends on what is loading.
class PlayerControlsRow extends StatelessWidget {
  const PlayerControlsRow({super.key, required this.header});

  final Widget header;

  @override
  Widget build(BuildContext context) {
    // Held left to right like the player's own row.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: Directionality(
              textDirection: Directionality.of(context),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: header,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The player's own button, configured the same, so the row is the
          // height the player's is.
          IconButton(
            onPressed: null,
            icon: const Icon(Icons.open_in_full_rounded),
            iconSize: 16,
            color: MainApp.mutedText,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 30),
          ),
          const SizedBox(width: 4),
          SpeedSelector(value: 1, onChanged: (_) {}, enabled: false),
        ],
      ),
    );
  }
}

/// The play button, the waveform beside it and the two clocks under it, as
/// a [ContinuousPlayer] lays them out once loaded.
class PlayerWaveBones extends StatelessWidget {
  const PlayerWaveBones({super.key, this.waveTop = 0});

  /// The pins' lane above the waveform, when the recording has pins.
  final double waveTop;

  static const double _waveHeight = 40;
  static const double _waveInset = 46;

  @override
  Widget build(BuildContext context) {
    const clock = TextStyle(fontSize: 11);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: EdgeInsets.only(top: waveTop),
                // The 38px play icon's box; the disc inside it is 32.
                child: const SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(child: Bone.circle(size: 32)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: waveTop + _waveHeight,
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Bone(height: _waveHeight, radius: 8),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: _waveInset),
            child: Row(
              children: [
                BoneText(style: clock, width: 28),
                Spacer(),
                BoneText(style: clock, width: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A [MergedRecordingCard] with a recording to play, still loading: its
/// heading as itself, its controls greyed, the waveform and clocks grey.
class PlayerBones extends StatelessWidget {
  const PlayerBones({
    super.key,
    this.flat = false,
    this.title = 'Target Recording',
    this.icon = Icons.headphones,
    this.accent = MainApp.primaryGreen,
    this.hint = '',
    this.marks = false,
  });

  /// Source audio, as every page names and colours it.
  const PlayerBones.source({super.key, this.flat = false, this.marks = false})
    : title = 'Source audio',
      icon = Icons.volume_up_rounded,
      accent = MarkColors.sourceAudio,
      hint = '';

  /// Without the card: for a page that draws the card itself.
  final bool flat;
  final String title;
  final IconData icon;
  final Color accent;
  final String hint;

  /// Whether the recording will carry pins, which put a lane over the
  /// waveform.
  final bool marks;

  /// [ContinuousPlayer]'s lane for its pins: two of its 15px rows.
  static const double pinLane = 30;

  /// The heading [MergedRecordingCard] hands its player.
  static Widget heading({
    required String title,
    required IconData icon,
    required Color accent,
    String hint = '',
  }) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 6),
        Text(
          title.tr,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    );
    if (hint.isEmpty) return row;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        const SizedBox(height: 2),
        Text(
          hint.tr,
          maxLines: 1,
          softWrap: false,
          style: const TextStyle(fontSize: 11, color: MainApp.mutedText),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlayerControlsRow(
          header: heading(title: title, icon: icon, accent: accent, hint: hint),
        ),
        PlayerWaveBones(waveTop: marks ? pinLane : 0),
      ],
    );
    if (flat) return body;
    return BoneCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: body,
    );
  }
}

/// An [AudioClip] still loading: the control row, the play button and
/// waveform, and the clocks, at the clip's own sizes.
class AudioClipBones extends StatelessWidget {
  const AudioClipBones({super.key, this.header});

  /// The clip's heading, when it has one - fixed, so drawn as itself.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    const clock = TextStyle(fontSize: 11);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: header == null
                    ? const SizedBox.shrink()
                    : Directionality(
                        textDirection: Directionality.of(context),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: header,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                height: 30,
                child: Icon(
                  Icons.open_in_full_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 4),
              SpeedSelector(value: 1, onChanged: (_) {}, enabled: false),
            ],
          ),
          const Row(
            children: [
              SizedBox(
                width: 25,
                height: 25,
                child: Center(child: Bone.circle(size: 20)),
              ),
              SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: Center(child: Bone(height: 40, radius: 8)),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 29, top: 2),
            child: Row(
              children: [
                BoneText(style: clock, width: 30),
                Spacer(),
                BoneText(style: clock, width: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Which of the app's three script cards a [ScriptBones] stands in for.
enum ScriptCardKind {
  /// [SourceContentCard] / [TargetContentCard] in a scrolling list.
  list,

  /// The same cards in a fixed frame of the peer check screen.
  frame,

  /// The recorder's bordered script card.
  recorder,
}

/// A script card still loading: its heading and expand button as
/// themselves, the script as lines of the script's own size.
class ScriptBones extends StatelessWidget {
  const ScriptBones({
    super.key,
    required this.title,
    required this.icon,
    this.kind = ScriptCardKind.list,
    this.lines = 6,
    this.bottom = 12,
  });

  const ScriptBones.source({
    super.key,
    this.kind = ScriptCardKind.list,
    this.lines = 6,
  }) : title = 'Source script',
       icon = Icons.description_outlined,
       bottom = 12;

  const ScriptBones.target({
    super.key,
    this.kind = ScriptCardKind.list,
    this.lines = 6,
  }) : title = 'Target script',
       icon = Icons.translate,
       bottom = 14;

  final String title;
  final IconData icon;
  final ScriptCardKind kind;
  final int lines;

  /// The list card's bottom padding: 12 under the source, 14 under the
  /// target.
  final double bottom;

  static const TextStyle _script = TextStyle(fontSize: 12);

  EdgeInsets get _padding => switch (kind) {
    ScriptCardKind.list => EdgeInsets.fromLTRB(16, 8, 16, bottom),
    ScriptCardKind.frame => const EdgeInsets.fromLTRB(16, 8, 16, 8),
    ScriptCardKind.recorder => const EdgeInsets.fromLTRB(12, 6, 12, 4),
  };

  @override
  Widget build(BuildContext context) {
    final small = kind != ScriptCardKind.list;
    final titleStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: small ? 12 : 14,
      color: MainApp.mutedText,
    );
    final heading = Row(
      children: [
        Icon(icon, size: small ? 14 : 16, color: MainApp.mutedText),
        const SizedBox(width: 6),
        Expanded(child: Text(title.tr, style: titleStyle)),
        // [ExpandScriptButton]: a 16px icon centred in 34 by 22.
        const SizedBox(
          width: 34,
          height: 22,
          child: Center(
            child: Icon(
              Icons.open_in_full_rounded,
              size: 16,
              color: MainApp.mutedText,
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // In a box of fixed height only the lines that fit are drawn: a
        // skeleton must never paint outside the shape it stands in for.
        var shown = lines;
        if (constraints.hasBoundedHeight) {
          final line = BoneText.lineHeight(context, _script);
          final head = math.max(22.0, BoneText.lineHeight(context, titleStyle));
          final room = constraints.maxHeight - _padding.vertical - head - 4;
          shown = (room / line).floor().clamp(0, lines);
        }
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            heading,
            const SizedBox(height: 4),
            if (shown > 0)
              Padding(
                // The frame's scroller keeps clear of its scrollbar.
                padding: kind == ScriptCardKind.frame
                    ? const EdgeInsetsDirectional.only(end: 12)
                    : EdgeInsets.zero,
                child: BoneParagraph(lines: shown, style: _script),
              ),
          ],
        );
        final decoration = switch (kind) {
          ScriptCardKind.recorder => BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          _ => BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: MainApp.cardShadow,
          ),
        };
        return Container(
          width: double.infinity,
          padding: _padding,
          clipBehavior: Clip.antiAlias,
          decoration: decoration,
          child: body,
        );
      },
    );
  }
}

/// A page built round a recording: a scrolling list in the stage pages'
/// shared padding, holding whatever the page puts in it - the page knows
/// its own cards, and builds their loading shapes from its own widgets.
class RecordingPageSkeleton extends StatelessWidget {
  const RecordingPageSkeleton({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: children,
      ),
    );
  }
}

/// A stage page's bottom bar while the page loads: the line saying what
/// stands in the way, and the buttons stacked under it - so the bar's room
/// is there from the start rather than arriving with the page.
class StageBarBones extends StatelessWidget {
  const StageBarBones({
    super.key,
    required this.buttons,
    this.reasonLines = 0,
    this.reasonStyle = const TextStyle(fontSize: 11),
    this.buttonHeight = 48,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 14),
    this.white = false,
  });

  /// The single forward button of the community stages' bars.
  const StageBarBones.forward({super.key, this.reasonLines = 0})
    : buttons = 1,
      reasonStyle = const TextStyle(fontSize: 11),
      buttonHeight = 48,
      padding = const EdgeInsets.fromLTRB(16, 10, 16, 10),
      white = true;

  final int buttons;
  final int reasonLines;
  final TextStyle reasonStyle;
  final double buttonHeight;
  final EdgeInsetsGeometry padding;

  /// Whether the bar is a white strip of its own, as the community stages'
  /// are.
  final bool white;

  @override
  Widget build(BuildContext context) {
    if (buttons == 0) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        color: white ? Colors.white : null,
        padding: padding,
        child: Shimmer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (reasonLines > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BoneParagraph(
                    lines: reasonLines,
                    style: reasonStyle,
                    lastWidth: 0.5,
                  ),
                ),
              for (var i = 0; i < buttons; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Bone(width: double.infinity, height: buttonHeight, radius: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Whole pages.
// ---------------------------------------------------------------------------

/// The Workbench's tiles: an icon disc, a name, a count - in the same grid
/// and the same tile the real ones use, so nothing moves when they arrive.
class WorkbenchSkeleton extends StatelessWidget {
  const WorkbenchSkeleton({
    super.key,
    required this.gridDelegate,
    this.tiles = 4,
  });

  final SliverGridDelegate gridDelegate;
  final int tiles;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: gridDelegate,
        itemCount: tiles,
        itemBuilder: (context, index) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          elevation: 3,
          shadowColor: MainApp.cardShadowColor,
          surfaceTintColor: Colors.transparent,
          child: const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Bone.circle(size: 52),
                  SizedBox(height: 12),
                  BoneText(
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    width: 88,
                  ),
                  SizedBox(height: 4),
                  BoneText(style: TextStyle(fontSize: 12), width: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Sync status screen: the summary strip, then a card per Set.
class SyncStatusSkeleton extends StatelessWidget {
  const SyncStatusSkeleton({super.key, this.clear});

  /// Whether nothing is waiting, when that is already known: the strip is
  /// then the green one with its words, and there are no cards under it.
  final bool? clear;

  @override
  Widget build(BuildContext context) {
    const heading = TextStyle(fontWeight: FontWeight.w700);
    final known = clear;
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Tinted green or amber when it is known which; neutral until then.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: switch (known) {
                true => const Color(0xFFDCFCE7),
                false => const Color(0xFFFEF3C7),
                null => const Color(0xFFF1F2F4),
              },
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                known == true
                    ? const Icon(
                        Icons.cloud_done_outlined,
                        color: Color(0xFF15803D),
                      )
                    // A plain Icon: 24.
                    : const Bone.circle(size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      known == true
                          ? Text('Everything has been sent.'.tr, style: heading)
                          : const BoneText(style: heading, widthFactor: 0.8),
                      const SizedBox(height: 2),
                      const BoneText(
                        style: TextStyle(fontSize: 12),
                        width: 150,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (known != true) const SizedBox(height: 14),
          for (
            var i = 0;
            i <
                (known == true
                    ? 0
                    : known == false
                    ? 1
                    : 2);
            i++
          ) ...[
            const BoneCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Bone.circle(size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: BoneText(
                          style: TextStyle(fontWeight: FontWeight.w700),
                          widthFactor: 0.7,
                        ),
                      ),
                      BoneText(
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        width: 50,
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  BoneText(style: TextStyle(fontSize: 12), width: 160),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// The handbook before its WebView has drawn: its header as itself, and the
/// top of the chapter it opens at.
class ReadingSkeleton extends StatelessWidget {
  const ReadingSkeleton({super.key});

  static const Color _page = Color(0xFFF4F6F7);

  @override
  Widget build(BuildContext context) {
    final header = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE1E6E6))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Placed against the handbook's own header as it draws on a phone:
          // the back arrow, the mascot, then the title.
          Row(
            children: [
              const SizedBox(width: 2),
              const Icon(Icons.arrow_back, size: 20),
              const SizedBox(width: 16),
              SvgPicture.asset(
                'assets/brand/livuka-smile.svg',
                width: 44,
                height: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'LIVUKA Phone Handbook',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE1E6E6)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 18,
                        color: MainApp.mutedText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Search the manual',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: MainApp.mutedText,
                          ),
                        ),
                      ),
                      // The search's previous and next match.
                      const Icon(
                        Icons.keyboard_arrow_up,
                        size: 20,
                        color: MainApp.mutedText,
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: MainApp.mutedText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE1E6E6)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Steps',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return ColoredBox(
      color: _page,
      child: Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            header,
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 42, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Bone.circle(size: 34),
                      SizedBox(width: 14),
                      BoneText(style: TextStyle(fontSize: 24), width: 200),
                    ],
                  ),
                  SizedBox(height: 5),
                  BoneText(style: TextStyle(fontSize: 13.5), width: 220),
                  SizedBox(height: 14),
                  BoneParagraph(
                    lines: 4,
                    style: TextStyle(fontSize: 16, height: 1.62),
                  ),
                  // The chapter's step cards, as tall as three lines each.
                  SizedBox(height: 12),
                  Bone(height: 120, radius: 9),
                  SizedBox(height: 11),
                  Bone(height: 120, radius: 9),
                  SizedBox(height: 11),
                  Bone(height: 96, radius: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pull to refresh, without the ring.
// ---------------------------------------------------------------------------

/// Pull down to read again - shown as a thin band of the same moving light
/// along the top of the list while the read runs, rather than Material's
/// spinning ring.
///
/// The list keeps what it has: a refresh is a second look at data already
/// on screen, and swapping it for grey shapes would hide the very thing the
/// person is looking at. The band says only that the look is under way.
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  RefreshIndicatorStatus? _status;

  /// Only while the read itself runs. The status settles on "done" after
  /// a refresh and stays there, so a band keyed to anything but the read
  /// would never go out; and the drag, arming and snap before it are the
  /// person's own gesture, which needs no light of its own.
  bool get _busy => _status == RefreshIndicatorStatus.refresh;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator.noSpinner(
          onRefresh: widget.onRefresh,
          onStatusChange: (status) {
            if (mounted) setState(() => _status = status);
          },
          child: widget.child,
        ),
        if (_busy)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Shimmer(
              delay: Duration.zero,
              child: Bone(height: 3, radius: 0),
            ),
          ),
      ],
    );
  }
}
