import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A photo, or the paper-4 placeholder while there is none / it fails.
class PhotoBox extends StatelessWidget {
  const PhotoBox({super.key, this.url, this.radius = 0});

  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    const empty = SizedBox.expand();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: ColoredBox(
        color: Paper.c4,
        child: url == null
            ? empty
            : Image.network(url!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, _, _) => empty),
      ),
    );
  }
}

/// A strip of paper tape in the colour of whoever added the item.
class Tape extends StatelessWidget {
  const Tape({super.key, required this.color, this.width = 52, this.height = 14, this.degrees = -5});

  final Color color;
  final double width;
  final double height;
  final double degrees;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: degrees * math.pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: color.withValues(alpha: .62), borderRadius: BorderRadius.circular(Radii.tape)),
      ),
    );
  }
}

/// Small round avatar in a person's colour.
class AvatarDot extends StatelessWidget {
  const AvatarDot({super.key, required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Paper.c1, width: 2)),
    );
  }
}
