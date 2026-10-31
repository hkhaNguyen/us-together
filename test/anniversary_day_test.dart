import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/home/anniversary_day.dart';

void main() {
  test('the heart pops in, beats, and rests at full size', () {
    expect(AnniversaryDay.heartScale(0), 0);
    // Pop: overshoots past 1 on its way in.
    final pop = [for (var t = .05; t <= .24; t += .01) AnniversaryDay.heartScale(t)];
    expect(pop.reduce((a, b) => a > b ? a : b), greaterThan(1));
    // Beats stay within 1…1.08 and it ends exactly at 1.
    for (var t = .25; t < .8; t += .01) {
      expect(AnniversaryDay.heartScale(t), inInclusiveRange(1, 1.081));
    }
    expect(AnniversaryDay.heartScale(1), closeTo(1, 1e-9));
  });

  test('the halo fades in to .55 and stays', () {
    expect(AnniversaryDay.haloOpacity(0), 0);
    expect(AnniversaryDay.haloOpacity(1), closeTo(.55, 1e-9));
  });
}
