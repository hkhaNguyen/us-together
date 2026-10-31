import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
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
            : Image.network(
                url!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                // On web, falls back to an <img> element if the bucket has no CORS.
                webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                errorBuilder: (_, _, _) => empty,
              ),
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

/// A person's picture in a circle, or their initial on their colour until
/// they've set one.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.person, this.size = 30, this.ring});

  final Person person;
  final double size;

  /// Outline drawn around it, e.g. a paper rim where avatars overlap.
  final BorderSide? ring;

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(
        person.name.characters.first,
        style: AppText.body.copyWith(fontSize: size * .4, height: 1, color: Paper.c1, fontWeight: FontWeight.w500),
      ),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: person.color,
        shape: BoxShape.circle,
        border: ring == null ? null : Border.fromBorderSide(ring!),
      ),
      child: person.avatarUrl == null
          ? (size < 24 ? null : initial)
          : Image.network(
              person.avatarUrl!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}
