/// The two ways a Tester reaches the Meal photos page from a recipe screen
/// (ADR 0003): a camera icon on a Meal that has a photograph, and an
/// "Add photo" line where the picture would be on one that hasn't.
///
/// They live beside the page they open rather than in the recipe screen, which
/// is long already and changes for reasons of its own. Whether to draw them is
/// still the recipe screen's decision — neither widget reads the Tester flag,
/// so there is one place that answers "is this a Tester", not three.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import '../screens/meal_photos_screen.dart';

/// Opens the Meal photos page, named so the router and Vana's screen situation
/// can see it — a `MaterialPageRoute` push is invisible to them otherwise.
void openMealPhotos(BuildContext context, MealRef meal) {
  Navigator.of(
    context,
  ).push(MealPhotosScreen.route(mealId: meal.id, mealName: meal.name));
}

/// A Tester's entry point on a Meal that already has a photograph: small,
/// on the picture, and nothing an athlete would notice (stories 14, 16).
class MealPhotoChangeIcon extends ConsumerWidget {
  const MealPhotoChangeIcon({super.key, required this.meal});

  final MealRef meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final label = content.getValue(ContentKeys.mpPhotosChange);
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: const ValueKey('meal_planning.detail_photo_change'),
          onTap: () => openMealPhotos(context, meal),
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // Readable over any photograph, light or dark.
              color: AppColors.blackberry.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(
              FontAwesomeIcons.camera,
              size: 14,
              color: AppColors.cream,
            ),
          ),
        ),
      ),
    );
  }
}

/// A Tester's entry point on a Meal with no photograph, drawn where the picture
/// would be — the line that shows which meals still need one while a Tester is
/// cooking (story 17). An athlete's screen still starts at the meal's name.
class MealAddPhotoLine extends ConsumerWidget {
  const MealAddPhotoLine({super.key, required this.meal});

  final MealRef meal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    return InkWell(
      key: const ValueKey('meal_planning.detail_photo_add'),
      onTap: () => openMealPhotos(context, meal),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            FaIcon(FontAwesomeIcons.camera, size: 14, color: accent),
            const SizedBox(width: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpPhotosAdd),
              style: AppTextStyles.bodyMedium.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
