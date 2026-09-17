import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/data/dish_photo.dart';
import '../../domain/meal_photo.dart';

// A Meal's Dish photo on meal surfaces (ADR 0003). The design lives in the
// library component `DishPhoto*` (`docs/ssot/spec/design/components/dish-photo.md`);
// these only unpack a [MealPhoto] into its fields, so the library depends on no
// feature and every meal surface keeps one call shape.

/// A Meal's Dish photo at thumbnail size in a row, or nothing at all.
class MealPhotoThumb extends StatelessWidget {
  const MealPhotoThumb({
    super.key,
    required this.photo,
    required this.size,
    this.gap = 12,
    this.borderRadius,
  });

  final MealPhoto? photo;
  final double size;
  final double gap;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) => DishPhotoThumb(
    url: photo?.url,
    credit: photo?.credit,
    size: size,
    gap: gap,
    borderRadius: borderRadius,
  );
}

/// A Meal's Dish photo at size, above a recipe, or nothing.
class MealPhotoHero extends StatelessWidget {
  const MealPhotoHero({
    super.key,
    required this.photo,
    this.aspectRatio = 16 / 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final MealPhoto? photo;
  final double aspectRatio;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => DishPhotoHero(
    url: photo?.url,
    credit: photo?.credit,
    aspectRatio: aspectRatio,
    borderRadius: borderRadius,
  );
}

/// One credit line under a Meal's Dish photo, and nothing when it has none.
class MealPhotoCreditLine extends StatelessWidget {
  const MealPhotoCreditLine({
    super.key,
    required this.photo,
    required this.onOpen,
  });

  final MealPhoto? photo;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) => DishPhotoCreditLine(
    credit: photo?.credit,
    creditUrl: photo?.creditUrl,
    onOpen: onOpen,
    linkKey: const ValueKey('meal_planning.detail_photo_credit'),
  );
}
