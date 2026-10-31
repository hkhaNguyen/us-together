import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/widgets/avatar_cropper.dart';

void main() {
  // A 400×200 photo in a 300px window: at zoom 1 it's laid out 600×300.
  const window = 300.0;
  const fitted = Size(600, 300);

  test('centred at zoom 1, the circle takes the middle square of the photo', () {
    final view = Matrix4.translationValues(-150, 0, 0);
    expect(cropRect(view, window: window, fitted: fitted, imageWidth: 400), const Rect.fromLTWH(100, 0, 200, 200));
  });

  test('zoomed 2× into the top-left corner, it takes a quarter-size square there', () {
    final view = Matrix4.diagonal3Values(2, 2, 1);
    expect(cropRect(view, window: window, fitted: fitted, imageWidth: 400), const Rect.fromLTWH(0, 0, 100, 100));
  });
}
