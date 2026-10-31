import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/widgets/sakura_flower.dart';

void main() {
  testWidgets('paints every stage of the bloom, overshoot included', (tester) async {
    final bloom = AnimationController(vsync: const TestVSync(), duration: SakuraFlower.openDuration);
    addTearDown(bloom.dispose);
    await tester.pumpWidget(Center(child: SakuraFlower(bloom: bloom)));

    for (final t in [0.0, .05, .3, .5, .7, .85, 1.0]) {
      bloom.value = t;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 't=$t');
    }
    expect(tester.getSize(find.byType(SakuraFlower)), const Size.square(200));
  });
}
