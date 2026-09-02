import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/meal_ref.dart';
import 'meal_card.dart';

/// `meal_picker` part body: a horizontal carousel of pickable [MealCard]s
/// under the part title. Single-pick pickers fold immediately; multi-pick
/// keep cards tappable until the client chip confirms the batch (02 §3).
class MealPickerCarousel extends StatelessWidget {
  const MealPickerCarousel({
    super.key,
    required this.title,
    required this.meals,
    required this.multi,
    required this.pickedIds,
    required this.onPick,
  });

  final String title;
  final List<MealRef> meals;
  final bool multi;

  /// Ids already picked in this picker (multi mode shows a tick).
  final Set<String> pickedIds;
  final ValueChanged<MealRef> onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          key: const ValueKey('meal_planning.picker_title'),
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: meals.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, i) {
              final meal = meals[i];
              final picked = pickedIds.contains(meal.id);
              return SizedBox(
                width: 240,
                child: MealCard(
                  key: ValueKey('meal_planning.picker_card_${meal.id}'),
                  meal: meal,
                  compact: true,
                  onTap: () => onPick(meal),
                  trailing: FaIcon(
                    picked
                        ? FontAwesomeIcons.circleCheck
                        : FontAwesomeIcons.circlePlus,
                    color: picked
                        ? AppColors.electrolyte
                        : (isDark
                              ? AppColors.cream.withValues(alpha: 0.6)
                              : AppColors.blackberry.withValues(alpha: 0.6)),
                    size: 20,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
