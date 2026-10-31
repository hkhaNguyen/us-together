import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:exif/exif.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// A photo picked from the device, not uploaded yet. Its date can be
/// changed in the sheet before saving.
class PickedPhoto {
  PickedPhoto({required this.bytes, required this.takenAt});

  final Uint8List bytes;
  DateTime takenAt;
}

/// Opens the system picker; an empty list if they backed out.
Future<List<PickedPhoto>> pickPhotos() async {
  final files = await ImagePicker().pickMultiImage(requestFullMetadata: true);
  return [
    for (final f in files) await _read(f),
  ];
}

/// One picture's bytes (for an avatar); null if they backed out.
Future<Uint8List?> pickOnePhoto() async => (await ImagePicker().pickImage(source: ImageSource.gallery))?.readAsBytes();

Future<PickedPhoto> _read(XFile file) async {
  final bytes = await file.readAsBytes();
  DateTime? taken;
  try {
    final tags = await readExifFromBytes(bytes);
    taken = parseExifDate(tags['EXIF DateTimeOriginal']?.printable ?? tags['Image DateTime']?.printable);
  } catch (_) {
    // No or unreadable EXIF: fall back below.
  }
  if (taken == null) {
    try {
      taken = await file.lastModified();
    } catch (_) {
      taken = DateTime.now();
    }
  }
  return PickedPhoto(bytes: bytes, takenAt: taken);
}

/// "2024:10:30 18:22:01" → that local time; null if it isn't one.
DateTime? parseExifDate(String? value) {
  final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})').firstMatch(value?.trim() ?? '');
  if (m == null) return null;
  final [y, mo, d, h, mi, s] = [for (var i = 1; i <= 6; i++) int.parse(m[i]!)];
  if (y < 1900 || mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime(y, mo, d, h, mi, s);
}

/// Compresses on the device and uploads to photos/{id}/ in Storage.
class PhotoUploader {
  PhotoUploader(this._storage);

  final FirebaseStorage _storage;

  /// Short edge of the stored photo, and of the thumbnail (cropped square
  /// on polaroids, so the short edge is what matters).
  static const _fullShortEdge = 1500;
  static const _thumbShortEdge = 480;

  /// Returns the Firestore fields describing the uploaded files.
  Future<Map<String, Object>> upload(String id, PickedPhoto photo) async {
    Future<Uint8List> webp(int shortEdge, int quality) => FlutterImageCompress.compressWithList(
          photo.bytes,
          minWidth: shortEdge,
          minHeight: shortEdge,
          quality: quality,
          format: CompressFormat.webp,
        );
    final full = await webp(_fullShortEdge, 82);
    final thumb = await webp(_thumbShortEdge, 75);
    final (w, h) = await _size(thumb);

    final dir = _storage.ref('photos/$id');
    final meta = SettableMetadata(contentType: 'image/webp', cacheControl: 'private, max-age=31536000');
    final fullRef = dir.child('full.webp');
    final thumbRef = dir.child('thumb.webp');
    await Future.wait([fullRef.putData(full, meta), thumbRef.putData(thumb, meta)]);

    return {
      'fullUrl': await fullRef.getDownloadURL(),
      'thumbUrl': await thumbRef.getDownloadURL(),
      // The thumbnail's size: only the aspect ratio is used.
      'w': w,
      'h': h,
    };
  }

  /// A square-ish 320px picture under a new name each time, so no cache
  /// keeps showing the old one. Returns its download URL.
  Future<String> uploadAvatar(String personId, Uint8List bytes) async {
    final small = await FlutterImageCompress.compressWithList(bytes, minWidth: 320, minHeight: 320, quality: 80, format: CompressFormat.webp);
    final ref = _storage.ref('avatars/$personId-${DateTime.now().millisecondsSinceEpoch}.webp');
    await ref.putData(small, SettableMetadata(contentType: 'image/webp', cacheControl: 'private, max-age=31536000'));
    return ref.getDownloadURL();
  }

  /// Best effort: a leftover old file is harmless.
  Future<void> deleteByUrl(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  /// Removes both stored files of a photo; already-missing ones are fine.
  Future<void> deleteFiles(String id) async {
    for (final name in ['full.webp', 'thumb.webp']) {
      try {
        await _storage.ref('photos/$id/$name').delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
    }
  }

  /// The stored file behind a download URL.
  Future<Uint8List?> download(String url) => _storage.refFromURL(url).getData(30 * 1024 * 1024);

  static Future<(int, int)> _size(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (frame.image.width, frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}
