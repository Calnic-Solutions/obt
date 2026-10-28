import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import 'package:livuka/Widgets/livuka_smile.dart';

/// The field the brand sits on, as the website's sign-in panel paints it
/// (`.ob-login-brand`): flat LIVUKA navy with a faint dot grid. The brand
/// kit asks for the on-dark logo on a plain navy, not on gradients or
/// photos; the dots only give the empty space a little texture. The two
/// products are one product to the people using them, and a phone that
/// opens on a different field from the browser beside it reads as a
/// different app.
class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});

  final Widget child;

  /// The navy itself: what a Scaffold shows behind it before the first
  /// frame.
  static const Color base = Color(0xFF040134);

  @override
  Widget build(BuildContext context) {
    // Light status-bar icons: the phone's own dark ones vanish on the navy.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: base,
        child: Stack(
          fit: StackFit.expand,
          children: [CustomPaint(painter: _DotsPainter()), child],
        ),
      ),
    );
  }
}

/// The smile at play with the wordmark under it, rising into place as the
/// website's sign-in panel does (`obLoginRise`: half a second, up from
/// 16px below, fading in).
class BrandHero extends StatelessWidget {
  const BrandHero({super.key, this.size = 220, this.verbs = true});

  /// The room the hero is given; the smile is drawn a little narrower.
  final double size;

  /// Whether the tagline, "Every Language. Beyond Words.", and the line
  /// under it that spells out the name are shown.
  final bool verbs;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.ease,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LivukaSmile(width: size * 0.7),
          const SizedBox(height: 22),
          const BrandWordmark(fontSize: 34),
          if (verbs) ...[
            const SizedBox(height: 10),
            // The brand's own lines, as the website's sign-in panel has
            // them, in the phone's language.
            Text(
              'Every Language. Beyond Words.'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.15,
                color: Color(0xFFC9CBE0),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 280,
              child: Text(
                'Language • Intelligence • Voice • Understanding • '
                        'Knowledge • Augmentation'
                    .tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: Color(0x99C9CBE0),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The "livuka." wordmark from the brand kit, with the smile as its U -
/// never retyped, which the kit forbids. Navy for a white bar, white for
/// the navy field.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 30, this.onLight = false});

  /// How tall the letters stand, as a font size would set them. The file
  /// has room above them for the eyes, so the picture is taller than this.
  final double fontSize;
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      onLight
          ? 'assets/brand/livuka-wordmark.svg'
          : 'assets/brand/livuka-wordmark-on-dark.svg',
      height: fontSize * 1.6,
      semanticsLabel: 'LIVUKA',
    );
  }
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // rgba(201, 203, 224, .08) under the panel's .6 opacity.
    final paint = Paint()..color = const Color(0x0CC9CBE0);
    for (var y = 0.0; y < size.height; y += 18) {
      for (var x = 0.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => false;
}
