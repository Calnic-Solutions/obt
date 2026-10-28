import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class VoiceMicScreen extends StatefulWidget {
  const VoiceMicScreen({super.key});

  @override
  State<VoiceMicScreen> createState() => _VoiceMicScreenState();
}

class _VoiceMicScreenState extends State<VoiceMicScreen>
    with TickerProviderStateMixin {
  late final AnimationController _barsController;

  @override
  void initState() {
    super.initState();
    _barsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _barsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.1,
          colors: [
            // Color(0xFF1E3B32), // lighter green center
            Color(0xFF0B1F1A), // dark green edges
            Color(0xFF0B1F1A),
          ],
        ),
      ),
      child: Center(
        child: Stack(
          children: [
            const _PulsingMicButton(),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(child: _EqualizerBars(controller: _barsController)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single expanding ripple ring: it is spawned once, only ever grows
/// outward from `buttonSize` to `maxRingSize`, fading as it grows, and is
/// then discarded. It never shrinks or snaps back to a smaller size.
class _Ripple {
  final Duration start;
  _Ripple(this.start);
}

/// Mic button that continuously spawns new ripple rings on a timer.
/// Each ripple lives independently: grows + fades once, then is removed.
/// Because new ripples are added *before* old ones are removed, there's
/// always something visible on screen — a true continuous sonar effect.
class _PulsingMicButton extends StatefulWidget {
  const _PulsingMicButton();

  @override
  State<_PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<_PulsingMicButton>
    with SingleTickerProviderStateMixin {
  static const double buttonSize = 100;
  static const double maxRingSize = 250;
  static const Duration rippleLife = Duration(milliseconds: 2200);
  // Spawning a new ripple every half-life means exactly 2 ripples are
  // ever alive at once: one just starting, one halfway expanded.
  static const Duration spawnEvery = Duration(milliseconds: 1100);

  late final Ticker _ticker;
  final List<_Ripple> _ripples = [];
  Duration _elapsed = Duration.zero;
  Duration _sinceLastSpawn = Duration.zero;
  Duration _previousTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Seed one ripple already halfway through its life so the screen
    // shows 2 rings immediately instead of fading in from empty.
    _ripples.addAll([_Ripple(-spawnEvery), _Ripple(Duration.zero)]);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = elapsed - _previousTick;
    _previousTick = elapsed;
    _elapsed = elapsed;
    _sinceLastSpawn += dt;

    if (_sinceLastSpawn >= spawnEvery) {
      _sinceLastSpawn = Duration.zero;
      _ripples.add(_Ripple(elapsed));
    }
    _ripples.removeWhere((r) => elapsed - r.start > rippleLife);
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: maxRingSize,
      height: maxRingSize,
      color: const Color(0xFF0B1F1A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final ripple in _ripples) _buildRing(ripple),
          _buildButton(),
        ],
      ),
    );
  }

  Widget _buildRing(_Ripple ripple) {
    final age = _elapsed - ripple.start;
    final progress = (age.inMilliseconds / rippleLife.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    // Size only ever increases with progress — never decreases.
    final size = buttonSize + (maxRingSize - buttonSize) * progress;
    final opacity = (1.0 - progress) * 0.5;

    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE8912A).withValues(alpha: opacity * 0.25),
          border: Border.all(
            color: const Color(0xFFE8912A).withValues(alpha: opacity),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.4),
          radius: 0.9,
          colors: [Color(0xFFFFC069), Color(0xFFE8912A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8912A).withValues(alpha: 0.55),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Icon(Icons.mic, color: Colors.brown.shade900, size: 40),
    );
  }
}

/// Animated equalizer / waveform bars under the mic button.
class _EqualizerBars extends StatelessWidget {
  final AnimationController controller;
  final int barCount;

  const _EqualizerBars({required this.controller}) : barCount = 5;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(barCount, (i) {
              // Offset each bar's phase so they don't move in lockstep.
              final phase = controller.value * 2 * pi + i * 1.3;
              final heightFactor = (sin(phase) + 1) / 2; // 0..1
              final height = 6 + heightFactor * 20;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8912A),
                  borderRadius: BorderRadius.circular(2),
                  gradient: heightFactor > 0.5
                      ? const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.deepOrange, Color(0xFFFFC069)],
                        )
                      : null,
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
