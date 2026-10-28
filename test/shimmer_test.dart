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
                SetRowBones(leading: true, statusLine: true),
                PlayerBones(),
                Expanded(child: ScriptBones(lines: 7)),
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
        home: Scaffold(body: Shimmer(child: SetRowBones())),
      ),
    );
    final visible = find.byType(Visibility);
    expect(tester.widget<Visibility>(visible).visible, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.widget<Visibility>(visible).visible, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
