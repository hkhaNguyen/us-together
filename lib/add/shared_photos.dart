import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_pipeline.dart';

/// Photos shared into the app from another one: "Chia sẻ → us-together" in
/// Android's gallery. MainActivity holds them until they're asked for.
abstract final class SharedPhotos {
  static const _channel = MethodChannel('us_together/share');

  /// Hands [onPhotos] whatever was shared before the app was ready, then
  /// each new share while it runs. Android only; elsewhere it does nothing.
  static void listen(ValueChanged<List<PickedPhoto>> onPhotos) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    Future<void> take() async {
      final shared = await _channel.invokeListMethod<Uint8List>('takeShared') ?? const [];
      if (shared.isEmpty) return;
      onPhotos([for (final bytes in shared) await pickedFromBytes(bytes)]);
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') await take();
    });
    take();
  }

  static void stop() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler(null);
  }
}
