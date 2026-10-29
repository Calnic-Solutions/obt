import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:livuka/Widgets/shimmer.dart';

void main() {
  testWidgets('bones paint under a shimmer without errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Shimmer(
            delay: Duration.zero,
            child: Column(
              children: [
                BoneText(width: 120),
                PlayerBones(),
                Expanded(child: ScriptBones.source(kind: ScriptCardKind.frame)),
              ],
            ),
          ),
        ),
      ),
    );
    // A few frames of the sweep, so the painter runs with real positions.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('a skeleton stays hidden until its delay has passed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Shimmer(child: BoneText(width: 80))),
      ),
    );
    final visible = find.byType(Visibility);
    expect(tester.widget<Visibility>(visible).visible, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Visibility>(visible).visible, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a line of bone is exactly as tall as the line of text', (
    tester,
  ) async {
    const styles = [
      TextStyle(fontSize: 11),
      TextStyle(fontSize: 12),
      TextStyle(fontSize: 13, height: 1.4),
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
    ];
    for (final style in styles) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Passage 1', key: const Key('text'), style: style),
                BoneText(key: const Key('bone'), style: style, width: 60),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const Key('bone'))).height,
        tester.getSize(find.byKey(const Key('text'))).height,
        reason: '$style',
      );
    }
  });

  testWidgets('a bone shape takes exactly its widget\'s size', (tester) async {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      child: const Text('Not started', style: TextStyle(fontSize: 10)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(key: const Key('real'), child: child),
              BoneShape(key: const Key('bone'), child: child),
            ],
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('bone'))),
      tester.getSize(find.byKey(const Key('real'))),
    );
  });
}
