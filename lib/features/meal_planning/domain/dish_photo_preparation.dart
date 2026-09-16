/// Getting a camera or gallery photo ready to publish (ADR 0003, ticket 05).
///
/// A pure function on bytes: no Flutter, no picker, no network. The controller
/// calls it before handing the repository anything, so the fake repository in
/// the seam-2 test sees exactly the bytes the edge function would.
///
/// It does three things, and the order matters:
///   1. crops to the recipe screen's picture shape, so a photo fits cards and
///      the hero without surprises (story 22);
///   2. shrinks the long edge to [maxLongEdge], so uploads are quick and
///      athletes' cards load fast (story 27);
///   3. re-encodes as JPEG **with the EXIF block cleared**, which is what
///      removes GPS (story 26).
///
/// Step 3 is deliberate, not a side effect of re-encoding. `encodeJpg` writes
/// an APP1 segment back out whenever `image.exif` is non-empty, and `decodeImage`
/// fills it in from the file — so a photo straight off an iPhone would keep the
/// Tester's home coordinates through a naive round trip. [_stripMetadata] is
/// the one line standing between a cooked dinner and a home address.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The shape a Dish photo is shown in — `MealPhotoHero`'s aspect, and the
/// crop editor's. Kept here so the crop UI, the preparation and the tests all
/// name one number.
const double kDishPhotoAspectRatio = 16 / 10;

/// The longest edge we publish. A 16:10 photo at this width is ~1600x1000,
/// which is more than any surface draws and still well inside the bucket's
/// 5 MiB limit.
const int kDishPhotoMaxLongEdge = 1600;

/// JPEG quality. 85 is the usual "no visible loss on a photograph" point and
/// roughly halves the file against 100.
const int kDishPhotoQuality = 85;

/// The picked bytes could not be read as an image at all.
///
/// Separate from a transport failure: nothing has been sent, and the Tester
/// should be told to pick a different photo rather than to try again.
class DishPhotoUnreadable implements Exception {
  const DishPhotoUnreadable();

  @override
  String toString() => 'DishPhotoUnreadable';
}

/// [bytes] as a publishable Dish photo: cropped to [aspectRatio], no longer
/// than [maxLongEdge] on its long edge, JPEG, and carrying no metadata.
///
/// Cropping here as well as in the crop editor is not redundant. The editor is
/// a convenience the Tester drives; this is the guarantee. A photo that
/// reached us some other way — a gallery pick the editor was cancelled on, a
/// future caller — is still published at the right shape.
///
/// Throws [DishPhotoUnreadable] when [bytes] are not a decodable image.
Uint8List prepareDishPhoto(
  Uint8List bytes, {
  double aspectRatio = kDishPhotoAspectRatio,
  int maxLongEdge = kDishPhotoMaxLongEdge,
  int quality = kDishPhotoQuality,
}) {
  // `decodeImage` does not merely answer null on bytes that are not an image:
  // it sniffs formats in turn, and a short or malformed file walks one of the
  // decoders off the end of the buffer (a RangeError out of the PSD header
  // reader, for one). A Tester picking a PDF or a truncated download must be
  // told to choose another photo, not crash the page.
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const DishPhotoUnreadable();
  }
  if (decoded == null) throw const DishPhotoUnreadable();

  final shaped = _shrink(_cropToAspect(decoded, aspectRatio), maxLongEdge);
  _stripMetadata(shaped);
  // yuv420 is the subsampling every phone camera and stock library already
  // uses for photographs; it costs nothing visible here and roughly halves
  // the bytes against the package's yuv444 default.
  return img.encodeJpg(shaped, quality: quality, chroma: img.JpegChroma.yuv420);
}

/// The largest centred rectangle of [aspectRatio] that fits inside [src].
///
/// Centred rather than top-anchored: a plate is generally in the middle of the
/// frame, and a Tester who wanted a different part of the photo has already
/// said so in the crop editor.
img.Image _cropToAspect(img.Image src, double aspectRatio) {
  final current = src.width / src.height;
  // Already the right shape, to within a pixel — don't re-sample for nothing.
  if ((current - aspectRatio).abs() < 0.001) return src;

  final int width, height;
  if (current > aspectRatio) {
    // Too wide: keep the full height and trim the sides.
    height = src.height;
    width = (src.height * aspectRatio).round();
  } else {
    // Too tall: keep the full width and trim top and bottom.
    width = src.width;
    height = (src.width / aspectRatio).round();
  }
  return img.copyCrop(
    src,
    x: (src.width - width) ~/ 2,
    y: (src.height - height) ~/ 2,
    width: width,
    height: height,
  );
}

/// [src] with its long edge at [maxLongEdge], or untouched when it is already
/// smaller — a small photo is never blown up to fill the limit.
img.Image _shrink(img.Image src, int maxLongEdge) {
  final longEdge = src.width > src.height ? src.width : src.height;
  if (longEdge <= maxLongEdge) return src;
  return src.width >= src.height
      ? img.copyResize(
          src,
          width: maxLongEdge,
          interpolation: img.Interpolation.average,
        )
      : img.copyResize(
          src,
          height: maxLongEdge,
          interpolation: img.Interpolation.average,
        );
}

/// Drop every EXIF directory, GPS included.
///
/// `encodeJpg` writes an APP1 segment for whatever `image.exif` holds, and a
/// decoded camera photo holds plenty — make, model, the time it was taken and,
/// on a phone with location on, exactly where the Tester was standing. An
/// empty [img.ExifData] makes the encoder skip the segment entirely.
void _stripMetadata(img.Image image) => image.exif = img.ExifData();
