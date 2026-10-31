import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/paper_bits.dart';
import 'timeline.dart';

/// `<MomentCard>` from the component spec: cover, date, title and who wrote
/// cảm nghĩ. Its height is fixed up front so the timeline can be laid out
/// before anything renders.
class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.entry, this.onTap});

  final MomentEntry entry;
  final VoidCallback? onTap;

  static const _pad = 10.0;
  static const _cover = 110.0;
  static const _gap = 8.0;

  static TextStyle get titleStyle => AppText.title.copyWith(fontSize: 15, height: 1.2);

  /// [titleStyle] is a parameter so tests can measure without Google Fonts.
  static double heightFor(MomentEntry e, {required double width, required TextScaler textScaler, required TextStyle titleStyle}) {
    final title = TextPainter(
      text: TextSpan(text: e.moment.title, style: titleStyle),
      maxLines: 2,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: width - 2 * _pad);
    final titleHeight = title.height;
    title.dispose();

    final s = textScaler.scale(1);
    return _pad * 2 +
        _cover +
        _gap +
        18 * s + // date, one line
        _gap +
        titleHeight +
        (e.entryCount > 0 ? _gap + math.max(18, 13 * s) : 0);
  }

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final dateLine = [dotDate(e.date), if (e.anniversary != null) e.anniversary!.title].join(' · ');

    return Semantics(
      button: onTap != null,
      label: '${e.moment.title}, $dateLine',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.paper),
                child: Padding(
                  padding: const EdgeInsets.all(_pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: _cover,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PhotoBox(url: e.cover?.thumbUrl, radius: Radii.photo),
                            if (e.photoCount > 1) Positioned(right: 6, bottom: 6, child: _CountChip('+${e.photoCount - 1}')),
                          ],
                        ),
                      ),
                      const SizedBox(height: _gap),
                      Text(dateLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.script.copyWith(fontSize: 15, height: 1.2)),
                      const SizedBox(height: _gap),
                      Expanded(
                        child: Text(e.moment.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                      ),
                      if (e.entryCount > 0) ...[
                        const SizedBox(height: _gap),
                        _Reflections(entry: e),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Positioned(top: -7, left: 18, child: Tape(color: e.addedBy.color)),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(text, style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0)),
    );
  }
}

class _Reflections extends StatelessWidget {
  const _Reflections({required this.entry});

  final MomentEntry entry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, p) in entry.entryAuthors.indexed)
          Transform.translate(offset: Offset(-7.0 * i, 0), child: AvatarDot(color: p.color)),
        SizedBox(width: 6 - 7.0 * (entry.entryAuthors.length - 1)),
        Text('${entry.entryCount} cảm nghĩ', style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0, fontWeight: FontWeight.w400)),
      ],
    );
  }
}
