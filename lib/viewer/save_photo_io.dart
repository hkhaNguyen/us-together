import 'dart:typed_data';

import 'package:gal/gal.dart';

Future<void> savePhoto(Uint8List bytes, String name) async {
  if (!await Gal.hasAccess()) await Gal.requestAccess();
  await Gal.putImageBytes(bytes, name: name);
}
