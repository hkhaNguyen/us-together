// Paints the stand-in photos for the README screenshots, so no real photo
// ever ends up in them. Run by tool/screenshots/shoot.mjs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scene: sky from top to horizon, a sun or moon, then layered ground.
typedef _Scene = ({List<Color> sky, Color sun, List<Color> ground, bool stars, bool petals});

const _scenes = <_Scene>[
  (sky: [Color(0xFFF6B7A8), Color(0xFFFBE0C8)], sun: Color(0xFFFFF1D6), ground: [Color(0xFFD98E86), Color(0xFFB8686A)], stars: false, petals: true),
  (sky: [Color(0xFF9CC9E3), Color(0xFFE4F1F4)], sun: Color(0xFFFFFBEA), ground: [Color(0xFF5E9BB8), Color(0xFF3F7D9C)], stars: false, petals: false),
  (sky: [Color(0xFF2C3557), Color(0xFF6C6A8E)], sun: Color(0xFFF4EBD0), ground: [Color(0xFF3D3F5E), Color(0xFF26283F)], stars: true, petals: false),
  (sky: [Color(0xFFCFE0C3), Color(0xFFF2EEDB)], sun: Color(0xFFFFF6D8), ground: [Color(0xFF8CA777), Color(0xFF61805A)], stars: false, petals: false),
  (sky: [Color(0xFFE8A0B4), Color(0xFFF7D9C4)], sun: Color(0xFFFFE9C2), ground: [Color(0xFF9E6B8C), Color(0xFF6E4A68)], stars: false, petals: true),
  (sky: [Color(0xFFF3C98B), Color(0xFFFCE9CC)], sun: Color(0xFFFFF4DC), ground: [Color(0xFFD69A5C), Color(0xFFA86F45)], stars: false, petals: false),
];

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.seed);

  final _Scene scene;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    final w = size.width, h = size.height;
    final horizon = h * (.5 + r.nextDouble() * .15);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, horizon), scene.sky),
    );
    if (scene.stars) {
      final star = Paint()..color = const Color(0xCCFFFFFF);
      for (var i = 0; i < 60; i++) {
        canvas.drawCircle(Offset(r.nextDouble() * w, r.nextDouble() * horizon * .8), r.nextDouble() * 1.6 + .4, star);
      }
    }
    final sun = Offset(w * (.25 + r.nextDouble() * .5), horizon * (.35 + r.nextDouble() * .3));
    final sunR = w * (.08 + r.nextDouble() * .05);
    canvas
      ..drawCircle(sun, sunR * 3, Paint()..shader = ui.Gradient.radial(sun, sunR * 3, [scene.sun.withValues(alpha: .45), scene.sun.withValues(alpha: 0)]))
      ..drawCircle(sun, sunR, Paint()..color = scene.sun);
    // Two rolling layers of ground, the nearer one darker.
    for (final (i, color) in scene.ground.indexed) {
      final top = horizon + i * h * .12;
      final amp = h * (.03 + r.nextDouble() * .04);
      final phase = r.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += w / 40) {
        path.lineTo(x, top + math.sin(x / w * math.pi * (1.5 + i) + phase) * amp);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    if (scene.petals) {
      for (var i = 0; i < 14; i++) {
        final c = Offset(r.nextDouble() * w, r.nextDouble() * h);
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..rotate(r.nextDouble() * math.pi)
          ..drawOval(Rect.fromCenter(center: Offset.zero, width: w * .03, height: w * .018), Paint()..color = const Color(0xDDFBE4EB))
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => false;
}

void main() {
  testWidgets('paint demo photos', (tester) async {
    final out = Platform.environment['DEMO_PHOTOS_DIR'] ?? 'build/demo_photos';
    final key = GlobalKey();
    // Portrait and landscape, as phones take them.
    const sizes = [Size(400, 500), Size(480, 320), Size(400, 400)];
    for (var i = 0; i < 18; i++) {
      final size = sizes[i % sizes.length];
      await tester.pumpWidget(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: size, child: CustomPaint(painter: _ScenePainter(_scenes[i % _scenes.length], i))),
          ),
        ),
      );
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        File('$out/$i.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
