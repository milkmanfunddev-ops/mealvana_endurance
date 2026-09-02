import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../data/meal_library_remote_data_source.dart';
import '../../domain/meal_ref.dart';
import '../../domain/meal_type.dart';
import 'meal_card.dart';

/// Inline swap candidates for one plan meal: searches `meal_library` for
/// the same meal type, excluding what is already planned. Picking one
/// reports the [MealRef] — the caller runs the remote-ack `swap_meal`.
class SwapPicker extends ConsumerStatefulWidget {
  const SwapPicker({
    super.key,
    required this.mealType,
    this.excludeIds = const {},
    required this.onPick,
  });

  final MealType mealType;
  final Set<String> excludeIds;
  final ValueChanged<MealRef> onPick;

  @override
  ConsumerState<SwapPicker> createState() => _SwapPickerState();
}

class _SwapPickerState extends ConsumerState<SwapPicker> {
  late Future<List<MealRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref
        .read(mealLibraryRemoteDataSourceProvider)
        .searchMeals(mealType: widget.mealType, limit: 8);
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.65);

    return FutureBuilder<List<MealRef>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.electrolyte,
                ),
              ),
            ),
          );
        }
        final meals = snapshot.data ?? const <MealRef>[];

        if (meals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              content.getValue(ContentKeys.mpChipOther),
              key: const ValueKey('meal_planning.swap_picker.empty'),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final meal in meals)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: MealCard(
                  meal: meal,
                  compact: true,
                  onTap: () => widget.onPick(meal),
                ),
              ),
          ],
        );
      },
    );
  }
}
