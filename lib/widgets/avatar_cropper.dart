import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Full-screen step after picking an avatar: drag and zoom the photo under a
/// round window, then "Xong" pops with a 512×512 PNG of what's inside it.
class AvatarCropper extends StatefulWidget {
  const AvatarCropper({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  static const _out = 512;
  static const _maxZoom = 5.0;

  final _view = TransformationController();
  ui.Image? _image;
  var _zoom = 1.0;
  var _saving = false;

  /// Square window size and the photo's size inside it at zoom 1, from the
  /// last layout; the crop is worked out from these.
  var _window = 0.0;
  var _fitted = Size.zero;
  var _centred = false;

  @override
  void initState() {
    super.initState();
    _view.addListener(() {
      final z = _view.value.getMaxScaleOnAxis();
      if ((z - _zoom).abs() > .001) setState(() => _zoom = z);
    });
    _decode();
  }

  /// Decoded small: an avatar never needs a 12-megapixel original.
  Future<void> _decode() async {
    final codec = await ui.instantiateImageCodecWithSize(
      await ui.ImmutableBuffer.fromUint8List(widget.bytes),
      getTargetSize: (w, h) {
        final s = math.min(1.0, 1600 / math.max(w, h));
        return ui.TargetImageSize(width: (w * s).round(), height: (h * s).round());
      },
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  void dispose() {
    _view.dispose();
    _image?.dispose();
    super.dispose();
  }

  /// Zoom about the window's centre, keeping the photo covering the window.
  void _setZoom(double z) {
    final m = _view.value;
    final current = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final c = _window / 2;
    // The photo point now under the centre stays under it.
    final px = (c - t.x) / current, py = (c - t.y) / current;
    final tx = (c - px * z).clamp(_window - _fitted.width * z, 0.0);
    final ty = (c - py * z).clamp(_window - _fitted.height * z, 0.0);
    _view.value = Matrix4.diagonal3Values(z, z, 1)..setTranslationRaw(tx, ty, 0);
  }

  Future<void> _done() async {
    final image = _image!;
    setState(() => _saving = true);
    final src = cropRect(_view.value, window: _window, fitted: _fitted, imageWidth: image.width);

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, _out.toDouble(), _out.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final cropped = await recorder.endRecording().toImage(_out, _out);
    final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    if (mounted) Navigator.pop(context, png!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Scaffold(
      backgroundColor: Paper.c9,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: Paper.c4),
                    child: const Text('huỷ'),
                  ),
                  Expanded(
                    child: Text('Ảnh đại diện', textAlign: TextAlign.center, style: AppText.title.copyWith(fontSize: 18, color: Paper.c1)),
                  ),
                  FilledButton(
                    onPressed: image == null || _saving ? null : _done,
                    style: FilledButton.styleFrom(backgroundColor: Sakura.c6, foregroundColor: Colors.white),
                    child: Text(_saving ? 'đang cắt…' : 'Xong'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: image == null
                  ? const Center(child: CircularProgressIndicator(color: Paper.c4))
                  : LayoutBuilder(builder: (context, box) {
                      final window = math.min(math.min(box.maxWidth - 48, box.maxHeight - 140), 420.0);
                      // At zoom 1 the photo just covers the window.
                      final base = math.max(window / image.width, window / image.height);
                      final fitted = Size(image.width * base, image.height * base);
                      if (!_centred || window != _window) {
                        _window = window;
                        _fitted = fitted;
                        _centred = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _view.value = Matrix4.translationValues(-(fitted.width - window) / 2, -(fitted.height - window) / 2, 0);
                        });
                      }
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox.square(
                            dimension: window,
                            child: Stack(
                              children: [
                                ClipRect(
                                  child: InteractiveViewer(
                                    transformationController: _view,
                                    constrained: false,
                                    minScale: 1,
                                    maxScale: _maxZoom,
                                    child: SizedBox.fromSize(size: fitted, child: RawImage(image: image, fit: BoxFit.fill)),
                                  ),
                                ),
                                const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _RoundWindow()))),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.s4),
                          Text('kéo để chọn vị trí · chụm hoặc lăn chuột để phóng to',
                              textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 12, color: Paper.c5)),
                          SizedBox(
                            width: window,
                            child: Row(
                              children: [
                                const Icon(Icons.photo_size_select_small, size: 18, color: Paper.c5),
                                Expanded(
                                  child: Slider(
                                    value: _zoom.clamp(1, _maxZoom),
                                    min: 1,
                                    max: _maxZoom,
                                    activeColor: Sakura.c4,
                                    inactiveColor: Paper.c7,
                                    onChanged: _saving ? null : _setZoom,
                                  ),
                                ),
                                const Icon(Icons.photo_size_select_large, size: 22, color: Paper.c5),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }
}

/// The square [window] (a [view] of the photo laid out at [fitted] size), in
/// the photo's own pixels.
@visibleForTesting
Rect cropRect(Matrix4 view, {required double window, required Size fitted, required int imageWidth}) {
  final z = view.getMaxScaleOnAxis();
  final t = view.getTranslation();
  final k = imageWidth / fitted.width;
  return Rect.fromLTWH(-t.x / z * k, -t.y / z * k, window / z * k, window / z * k);
}

/// Dims everything outside the circle and outlines it.
class _RoundWindow extends CustomPainter {
  const _RoundWindow();

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas
      ..drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(circle)
          ..addOval(circle),
        Paint()..color = Paper.c9.withValues(alpha: .6),
      )
      ..drawOval(
        circle.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Paper.c1.withValues(alpha: .9),
      );
  }

  @override
  bool shouldRepaint(_RoundWindow old) => false;
}
