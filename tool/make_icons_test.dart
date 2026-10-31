// Renders the app icons from the same SakuraFlower the app draws.
// Run after changing the flower:  flutter test tool/make_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/theme/tokens.dart';
import 'package:us_together/widgets/sakura_flower.dart';

/// Everything is laid out on a 512 canvas and scaled on export. The flower's
/// petals fill about 70% of its own box, which sets the sizes below.
const _canvas = 512.0;

Widget _icon({required double box, Color background = Colors.transparent, bool simple = false}) => ColoredBox(
      color: background,
      child: Center(
        child: SakuraFlower(bloom: const AlwaysStoppedAnimation(1), size: _canvas * box, simple: simple),
      ),
    );

void main() {
  testWidgets('render app icons', (tester) async {
    final boundaryKey = GlobalKey();

    Future<void> render(Widget icon, Map<String, int> files) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: RepaintBoundary(key: boundaryKey, child: SizedBox.square(dimension: _canvas, child: icon))),
        ),
      );
      final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      for (final MapEntry(key: path, value: px) in files.entries) {
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: px / _canvas);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }

    const res = 'android/app/src/main/res';
    const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

    // Full-bleed on paper: the browser/iPhone icon and Android's legacy one.
    // iOS fills transparency with black, so these must be opaque.
    await render(_icon(box: 1, background: Paper.c3), {
      'web/icons/Icon-192.png': 192,
      'web/icons/Icon-512.png': 512,
      for (final MapEntry(key: d, value: x) in densities.entries) '$res/mipmap-$d/ic_launcher.png': (48 * x).round(),
    });

    // Maskable: the OS may cut a circle or squircle, so the flower keeps to
    // the middle 80% safe zone.
    await render(_icon(box: .8, background: Paper.c3), {
      'web/icons/Icon-maskable-192.png': 192,
      'web/icons/Icon-maskable-512.png': 512,
    });

    // Android adaptive icon foreground (108dp, safe zone 66dp ≈ 61%); its
    // background is the paper colour in values/colors.xml.
    await render(_icon(box: .82), {
      for (final MapEntry(key: d, value: x) in densities.entries) '$res/mipmap-$d/ic_launcher_foreground.png': (108 * x).round(),
    });

    // Browser tab: small, so the simple flower.
    await render(_icon(box: 1, simple: true), {'web/favicon.png': 48});
  });
}
