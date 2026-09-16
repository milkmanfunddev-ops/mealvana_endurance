/// Getting a photograph off the phone (ADR 0003, meal-imagery ticket 05).
///
/// Behind a provider so the Meal photos page can be driven in a test without a
/// camera. The page's own rules — preview before Confirm, Cancel changes
/// nothing, "Photo added" only after the ack — are what the tests are about;
/// the picker is a platform widget, and it gets checked on a device.
///
/// The crop step is its own seam and lives in the presentation layer
/// (`presentation/providers/dish_photo_cropper.dart`), because pushing a
/// screen needs a `BuildContext` and application must not reach upwards.
///
/// Preparation (crop to shape, shrink, strip EXIF) lives in `prepareDishPhoto`
/// and is always called by the controller, so nothing that can send bytes can
/// skip the step that removes the Tester's location. Only *where* it runs is a
/// seam — see [dishPhotoPreparer].
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/dish_photo_preparation.dart';

part 'dish_photo_capture.g.dart';

/// Takes a photo with the camera, or chooses one from the gallery. Null when
/// the Tester backed out of the picker.
typedef DishPhotoPicker = Future<Uint8List?> Function(ImageSource source);

/// The real picker.
///
/// No `imageQuality` or `maxWidth` here, unlike the meal-logging capture:
/// those re-encode on the platform side, and the Tester is about to crop the
/// photograph. Full-size bytes go to the crop editor, and `prepareDishPhoto`
/// does the one shrink and the one re-encode afterwards.
@riverpod
DishPhotoPicker dishPhotoPicker(Ref ref) {
  return (ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    return file == null ? null : await file.readAsBytes();
  };
}

/// Prepares picked bytes for publishing: crop, shrink, strip the EXIF.
typedef DishPhotoPreparer = Future<Uint8List> Function(Uint8List bytes);

/// The real one, on another isolate.
///
/// Decoding, resizing and re-encoding a photo straight off a phone camera is
/// tens of megapixels of work; on the UI isolate it would freeze the page,
/// including the spinner that is meant to show something is happening.
///
/// A seam only so that widget tests can run the very same [prepareDishPhoto]
/// inline: a real isolate never resolves inside `pumpAndSettle`'s fake-async
/// zone. What is prepared, and the guarantee that it always is, do not change.
@riverpod
DishPhotoPreparer dishPhotoPreparer(Ref ref) =>
    (Uint8List bytes) => compute(prepareDishPhoto, bytes);
