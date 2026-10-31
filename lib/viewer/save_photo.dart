// Saves image bytes where the platform keeps photos: the gallery on Android,
// a downloaded file on the web.
export 'save_photo_io.dart' if (dart.library.js_interop) 'save_photo_web.dart';
