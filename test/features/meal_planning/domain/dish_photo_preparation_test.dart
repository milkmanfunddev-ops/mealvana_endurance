/// Photo preparation, on a real photograph that really carries GPS.
///
/// The fixture is a 2400x1800 JPEG stamped with an iPhone's make and model,
/// the time it was taken, and coordinates in Birmingham — the shape of thing a
/// Tester's camera roll actually holds. Every assertion here is about what
/// leaves the phone, because once bytes reach the function they are public.
///
/// Rebuild the fixture with `test/features/meal_planning/fixtures/README.md`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mealvana_endurance/features/meal_planning/domain/dish_photo_preparation.dart';

import '../helpers/exif.dart';

const _fixture =
    'test/features/meal_planning/fixtures/dish_photo_with_gps.jpg';

void main() {
  late Uint8List original;

  setUpAll(() {
    original = File(_fixture).readAsBytesSync();
  });

  test('the fixture really is a large photo carrying GPS, or this proves nothing', () {
    final decoded = img.decodeImage(original)!;
    expect(decoded.width, 2400);
    expect(decoded.height, 1800);
    expect(decoded.hasExif, isTrue);
    expect(carriesExifSegment(original), isTrue);
    // The GPS IFD is the one that matters: this is a home address.
    expect(decoded.exif.gpsIfd.isEmpty, isFalse);
  });

  test('a prepared photo carries no EXIF and no GPS', () {
    final prepared = prepareDishPhoto(original);

    // Nothing in the bytes at all — not merely an empty directory.
    expect(carriesExifSegment(prepared), isFalse);

    final decoded = img.decodeImage(prepared)!;
    expect(decoded.exif.isEmpty, isTrue);
    expect(decoded.exif.gpsIfd.isEmpty, isTrue);
  });

  test('a prepared photo is cropped to the shape athletes see it in', () {
    final decoded = img.decodeImage(prepareDishPhoto(original))!;

    // 4:3 in, 16:10 out — the sides are trimmed, not squashed.
    expect(
      decoded.width / decoded.height,
      closeTo(kDishPhotoAspectRatio, 0.01),
    );
  });

  test('a prepared photo is shrunk to the limit', () {
    final decoded = img.decodeImage(prepareDishPhoto(original))!;
    final longEdge = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;

    expect(longEdge, kDishPhotoMaxLongEdge);
    // And it is genuinely smaller than what came off the camera.
    expect(prepareDishPhoto(original).length, lessThan(original.length));
  });

  test('a photo already inside the limit is not blown up to fill it', () {
    final small = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 320, height: 200)),
    );

    final decoded = img.decodeImage(prepareDishPhoto(small))!;

    expect(decoded.width, 320);
    expect(decoded.height, 200);
  });

  test('a prepared photo is a JPEG whatever went in', () {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 800, height: 800)),
    );

    final prepared = prepareDishPhoto(png);

    // SOI + APP0/APP1 marker: the file really is JPEG, not a renamed PNG.
    expect(prepared[0], 0xFF);
    expect(prepared[1], 0xD8);
    expect(img.decodeJpg(prepared), isNotNull);
  });

  test('bytes that are not an image are refused before anything is sent', () {
    expect(
      () => prepareDishPhoto(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<DishPhotoUnreadable>()),
    );
  });
}
