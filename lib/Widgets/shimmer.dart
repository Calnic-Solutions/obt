import 'dart:async';

import 'package:flutter/material.dart';

import 'package:livuka/main.dart';

/// Loading drawn as the shape of what is coming.
///
/// A spinner in the middle of an empty screen says only "wait". A grey
/// outline of the card, the list or the player that is about to appear says
/// what is being waited for and where it will land, and a soft light moving
/// across it says the wait is alive. Every page's loading state is built
/// from the pieces here, each shaped to the content it stands in for.
///
/// Only what is being loaded is drawn this way. Headings and labels that are
/// fixed in the page are drawn as themselves, so the page's own words are
/// never shown as grey bars.
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

  final double? width;
  final double height;
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

/// Lines of text, the last one shorter, as a paragraph ends.
class BoneLines extends StatelessWidget {
  const BoneLines({
    super.key,
    this.lines = 3,
    this.height = 11,
    this.gap = 8,
    this.lastWidth = 0.6,
  });

  final int lines;
  final double height;
  final double gap;

  /// The last line's share of the width.
  final double lastWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < lines; i++) ...[
            Bone(
              width: i == lines - 1
                  ? constraints.maxWidth * lastWidth
                  : constraints.maxWidth,
              height: height,
            ),
            if (i < lines - 1) SizedBox(height: gap),
          ],
        ],
      ),
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
  final EdgeInsets padding;
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

/// A recording card - heading, waveform, the play button and the clock -
/// as [MergedRecordingCard] lays one out.
class PlayerBones extends StatelessWidget {
  const PlayerBones({super.key, this.flat = false});

  /// Without the card: for a page that pins its players in a bar of its own.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Bone.circle(size: 16),
            SizedBox(width: 6),
            Bone(width: 120, height: 13),
          ],
        ),
        const SizedBox(height: 12),
        const Bone(height: 44, radius: 8),
        const SizedBox(height: 10),
        Row(
          children: const [
            Bone.circle(size: 40),
            SizedBox(width: 12),
            Bone(width: 72, height: 11),
            Spacer(),
            Bone(width: 44, height: 24, radius: 12),
          ],
        ),
      ],
    );
    if (flat) return body;
    return BoneCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: body,
    );
  }
}

/// A script card: its small heading and a paragraph of text.
class ScriptBones extends StatelessWidget {
  const ScriptBones({super.key, this.lines = 6, this.flat = false});

  final int lines;
  final bool flat;

  static const double _line = 12;
  static const double _gap = 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // In a box of fixed height - a frame on a phone held sideways -
        // only the lines that fit are drawn. Lines past the bottom would
        // overflow the card, and a skeleton must never paint outside the
        // shape it stands in for.
        var shown = lines;
        if (constraints.hasBoundedHeight) {
          final room = constraints.maxHeight - (flat ? 0 : 32) - 16 - 14 + _gap;
          shown = (room / (_line + _gap)).floor().clamp(0, lines);
        }
        final body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                Bone.circle(size: 16),
                SizedBox(width: 6),
                Bone(width: 96, height: 13),
              ],
            ),
            if (shown > 0) ...[
              const SizedBox(height: 14),
              BoneLines(lines: shown, height: _line, gap: _gap),
            ],
          ],
        );
        if (flat) return body;
        return BoneCard(padding: const EdgeInsets.all(16), child: body);
      },
    );
  }
}

/// A row in a list of Sets: a name, a line under it, something at the end.
class SetRowBones extends StatelessWidget {
  const SetRowBones({super.key, this.leading = false, this.statusLine = false});

  /// A round icon at the start, as the Feedback list has.
  final bool leading;

  /// A third line under the name, as the Approved list's download state.
  final bool statusLine;

  @override
  Widget build(BuildContext context) {
    return BoneCard(
      child: Row(
        children: [
          if (leading) ...[
            const Bone.circle(size: 40),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Bone(width: 190, height: 14),
                const SizedBox(height: 7),
                const Bone(width: 120, height: 11),
                if (statusLine) ...[
                  const SizedBox(height: 10),
                  const Bone(width: 90, height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Bone.circle(size: 26),
        ],
      ),
    );
  }
}

/// A passage on the Set screen: its name, a state pill and the button.
class PassageBones extends StatelessWidget {
  const PassageBones({super.key});

  @override
  Widget build(BuildContext context) {
    return BoneCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Bone(width: 150, height: 14),
                SizedBox(height: 8),
                Bone(width: 84, height: 20, radius: 10),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const Bone(width: 92, height: 36, radius: 10),
        ],
      ),
    );
  }
}

/// A question card with its answer and buttons, as the community pages
/// show one.
class QuestionBones extends StatelessWidget {
  const QuestionBones({super.key});

  @override
  Widget build(BuildContext context) {
    return BoneCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Bone(width: 70, height: 10),
          SizedBox(height: 10),
          BoneLines(lines: 2, height: 12, gap: 8, lastWidth: 0.75),
          SizedBox(height: 14),
          Bone(height: 44, radius: 10),
          SizedBox(height: 12),
          Row(
            children: [
              Bone(width: 96, height: 34, radius: 10),
              SizedBox(width: 10),
              Bone(width: 96, height: 34, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Whole pages.
// ---------------------------------------------------------------------------

/// The Workbench's tiles: an icon disc, a name, a count - in the same grid
/// the real tiles use, so nothing moves when they arrive.
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
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MainApp.cardShadow,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Bone.circle(size: 52),
                SizedBox(height: 14),
                Bone(width: 88, height: 13),
                SizedBox(height: 8),
                Bone(width: 48, height: 11),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A stage's queue: the Set that is up next, in its card.
class StageQueueSkeleton extends StatelessWidget {
  const StageQueueSkeleton({super.key, this.picker = false});

  /// Whether the drafter's "jump to" list sits above the card.
  final bool picker;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        children: [
          if (picker) ...[
            const Bone(width: 200, height: 11),
            const SizedBox(height: 8),
            const Bone(height: 48, radius: 10),
            const SizedBox(height: 14),
          ],
          BoneCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            radius: 16,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Bone(width: 210, height: 15),
                      SizedBox(height: 8),
                      Bone(width: 130, height: 11),
                      SizedBox(height: 12),
                      Bone(width: 150, height: 24, radius: 12),
                      SizedBox(height: 14),
                      Bone(width: 160, height: 11),
                      SizedBox(height: 8),
                      Bone(height: 6, radius: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Bone.circle(size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of Sets, one card per row.
class SetListSkeleton extends StatelessWidget {
  const SetListSkeleton({
    super.key,
    this.rows = 5,
    this.leading = false,
    this.statusLine = false,
  });

  final int rows;
  final bool leading;
  final bool statusLine;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: rows,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) =>
            SetRowBones(leading: leading, statusLine: statusLine),
      ),
    );
  }
}

/// A page built round a recording: the player first, then what the stage
/// adds under it - question cards, or the two scripts.
class RecordingPageSkeleton extends StatelessWidget {
  const RecordingPageSkeleton({
    super.key,
    this.questions = 2,
    this.scripts = false,
    this.leadingCard = false,
  });

  /// How many question cards follow the player.
  final int questions;

  /// Whether the source and target scripts follow instead.
  final bool scripts;

  /// A card above the player - the consultant's back translation.
  final bool leadingCard;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (leadingCard) ...[
            const ScriptBones(lines: 4),
            const SizedBox(height: 12),
          ],
          const PlayerBones(),
          const SizedBox(height: 18),
          if (scripts) ...[
            const ScriptBones(lines: 6),
            const SizedBox(height: 12),
            const PlayerBones(),
            const SizedBox(height: 12),
            const ScriptBones(lines: 5),
          ] else
            for (var i = 0; i < questions; i++) ...[
              const QuestionBones(),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// The Set screen: its passages, then the recording and its buttons - or,
/// for a reviewer, the two scripts with the players pinned under them.
class SetDetailSkeleton extends StatelessWidget {
  const SetDetailSkeleton({super.key, this.reviewer = false});

  final bool reviewer;

  @override
  Widget build(BuildContext context) {
    if (reviewer) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          // The real page's rule: under this height nothing is pinned and
          // the whole page scrolls, scripts first, players after.
          if (constraints.maxHeight < 480) {
            final scripts = landscape
                ? const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: ScriptBones(lines: 5)),
                      SizedBox(width: 10),
                      Expanded(child: ScriptBones(lines: 5)),
                    ],
                  )
                : const Column(
                    children: [
                      ScriptBones(lines: 5),
                      SizedBox(height: 10),
                      ScriptBones(lines: 5),
                    ],
                  );
            return Shimmer(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                children: [
                  scripts,
                  const SizedBox(height: 10),
                  const PlayerBones(),
                  const SizedBox(height: 10),
                  const PlayerBones(),
                ],
              ),
            );
          }
          final frames = landscape
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: ScriptBones(lines: 7)),
                    SizedBox(width: 10),
                    Expanded(child: ScriptBones(lines: 7)),
                  ],
                )
              : const Column(
                  children: [
                    Expanded(child: ScriptBones(lines: 7)),
                    SizedBox(height: 10),
                    Expanded(child: ScriptBones(lines: 7)),
                  ],
                );
          return Shimmer(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: frames,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                  child: const Column(
                    children: [
                      PlayerBones(flat: true),
                      SizedBox(height: 14),
                      PlayerBones(flat: true),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        children: const [
          PassageBones(),
          SizedBox(height: 10),
          PassageBones(),
          SizedBox(height: 10),
          PassageBones(),
          SizedBox(height: 16),
          PlayerBones(),
        ],
      ),
    );
  }
}

/// The recorder: the source player and two scripts above, the take slots
/// and the mic card below, in the proportions of the real screen.
class RecorderSkeleton extends StatelessWidget {
  const RecorderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The real pane's rule: under this height the passage panel cannot
        // share the screen with the slots and the recorder, so the pane
        // scrolls with the panel at a height of its own.
        final split = constraints.maxHeight >= 480;
        final panel = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PlayerBones(),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  if (wide) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: ScriptBones(lines: 6)),
                        SizedBox(width: 12),
                        Expanded(child: ScriptBones(lines: 6)),
                      ],
                    );
                  }
                  return const Column(
                    children: [
                      Expanded(child: ScriptBones(lines: 5)),
                      SizedBox(height: 8),
                      Expanded(child: ScriptBones(lines: 5)),
                    ],
                  );
                },
              ),
            ),
          ],
        );
        final children = [
          split ? Expanded(child: panel) : SizedBox(height: 360, child: panel),
          const SizedBox(height: 8),
          Row(
            children: const [
              Bone(width: 64, height: 44, radius: 10),
              SizedBox(width: 8),
              Bone(width: 64, height: 44, radius: 10),
              SizedBox(width: 8),
              Bone(width: 64, height: 44, radius: 10),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: const [
                Expanded(child: Bone(height: 12)),
                SizedBox(width: 16),
                Bone.circle(size: 64),
              ],
            ),
          ),
        ];
        return Shimmer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
            child: split
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  )
                : ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: children,
                  ),
          ),
        );
      },
    );
  }
}

/// The Sync status screen: the summary strip, then a card per Set.
class SyncStatusSkeleton extends StatelessWidget {
  const SyncStatusSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Bone.circle(size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Bone(width: 180, height: 13),
                      SizedBox(height: 6),
                      Bone(width: 130, height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const SetRowBones(statusLine: true),
          const SizedBox(height: 10),
          const SetRowBones(statusLine: true),
        ],
      ),
    );
  }
}

/// A page of reading - the handbook before its WebView has drawn.
class ReadingSkeleton extends StatelessWidget {
  const ReadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: const [
          Row(
            children: [
              Bone.circle(size: 40),
              SizedBox(width: 12),
              Bone(width: 180, height: 16),
            ],
          ),
          SizedBox(height: 16),
          Bone(height: 44, radius: 22),
          SizedBox(height: 28),
          Bone(width: 220, height: 20),
          SizedBox(height: 14),
          BoneLines(lines: 4, height: 12, gap: 10),
          SizedBox(height: 18),
          Bone(height: 120, radius: 12),
          SizedBox(height: 18),
          BoneLines(lines: 5, height: 12, gap: 10, lastWidth: 0.4),
        ],
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
