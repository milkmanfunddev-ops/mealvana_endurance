import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Thrown by [stripPhotoMetadata] when the bytes cannot be decoded as an
/// image (empty input, HEIC on web, a truncated file).
class MealPhotoUnreadable implements Exception {
  const MealPhotoUnreadable(this.reason);

  final String reason;

  @override
  String toString() => 'MealPhotoUnreadable: $reason';
}

/// Re-encode a meal photo as a JPEG that carries no metadata.
///
/// The EXIF Orientation tag is applied to the pixels first, so a photo the
/// camera stored sideways comes out upright. Every EXIF tag (GPS, Make, Model,
/// DateTime, Orientation) is then dropped: the output has no APP1 segment.
/// PNG, WebP and GIF input are decoded the same way and come out as JPEG.
///
/// Top-level and synchronous so it can run under `compute`.
///
/// Throws [MealPhotoUnreadable] when [bytes] do not decode as an image.
Uint8List stripPhotoMetadata(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const MealPhotoUnreadable('empty input');
  }
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (e) {
    throw MealPhotoUnreadable('decode failed: $e');
  }
  if (decoded == null) {
    throw const MealPhotoUnreadable('unsupported or corrupt image');
  }
  final upright = img.bakeOrientation(decoded)..exif = img.ExifData();
  return img.encodeJpg(upright, quality: 90);
}
