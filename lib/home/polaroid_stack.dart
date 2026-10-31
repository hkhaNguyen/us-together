import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/paper_bits.dart';
import 'timeline.dart';

/// `<Polaroid>` from the component spec: loose photos of one day, stacked
/// with a 6px offset, "×N" when there are several.
class PolaroidStack extends StatelessWidget {
  const PolaroidStack({
    super.key,
    required this.entry,
    required this.tape,
    this.onTap,
  });

  final PhotoStackEntry entry;

  /// Tape fades in after the polaroid lands.
  final Animation<double> tape;
  final VoidCallback? onTap;

  static const width = 112.0;
  static const _pad = 7.0;
  static const _tail = 20.0;

  /// The title line is always one line, however long the title is.
  static double heightFor(TextScaler textScaler) =>
      _pad + (width - 2 * _pad) + 5 + textScaler.scale(15) + _tail;

  @override
  Widget build(BuildContext context) {
    final photos = entry.photos;
    final caption = [
      ?photos.first.title,
      if (photos.length > 1) '×${photos.length}',
    ].join(' · ');
    const backs = [(Offset(6, 8), -7.0), (Offset(-5, 12), 5.0)];

    return Semantics(
      button: onTap != null,
      label: caption.isEmpty ? 'Ảnh' : 'Ảnh: $caption',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (offset, degrees)
                in backs.take(math.min(photos.length - 1, 2)).toList().reversed)
              Positioned.fill(
                child: Transform.translate(
                  offset: offset,
                  child: Transform.rotate(
                    angle: degrees * math.pi / 180,
                    child: _sheet(Shadows.paperSm),
                  ),
                ),
              ),
            Positioned.fill(
              child: _sheet(
                Shadows.paper,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Hero(
                        tag: 'photo-${photos.first.id}',
                        child: PhotoBox(url: photos.first.thumbUrl),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppText.script.copyWith(
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -6,
              left: (width - 44) / 2,
              child: FadeTransition(
                opacity: tape,
                child: Tape(
                  color: entry.addedBy.color,
                  width: 44,
                  height: 13,
                  degrees: -4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(List<BoxShadow> shadow, {Widget? child}) => Container(
    padding: const EdgeInsets.fromLTRB(_pad, _pad, _pad, _tail),
    decoration: BoxDecoration(color: Paper.polaroid, boxShadow: shadow),
    child: child,
  );
}
