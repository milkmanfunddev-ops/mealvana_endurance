/// The crop step of a Tester's photo, as a seam (ADR 0003, ticket 05).
///
/// It lives in presentation rather than beside the picker in application,
/// because cropping means pushing a screen and a screen needs a
/// `BuildContext` — application depending on presentation would reverse the
/// FOA arrow (`presentation -> application -> domain <- data`).
///
/// A seam at all so the Meal photos page can be tested without driving a real
/// crop editor: what those tests are about is the page's rule that nothing
/// publishes until the Tester has seen the photograph and confirmed it. The
/// editor itself is checked on a device.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../screens/meal_photo_crop_screen.dart';

part 'dish_photo_cropper.g.dart';

/// Lets the Tester crop [bytes] to the picture's shape. Null when they
/// cancelled, which must leave the Meal exactly as it was (story 25).
typedef DishPhotoCropper =
    Future<Uint8List?> Function(BuildContext context, Uint8List bytes);

/// The real crop editor: the full-screen crop page, at the picture's aspect.
@riverpod
DishPhotoCropper dishPhotoCropper(Ref ref) {
  return (BuildContext context, Uint8List bytes) =>
      Navigator.of(context).push<Uint8List>(MealPhotoCropScreen.route(bytes));
}
