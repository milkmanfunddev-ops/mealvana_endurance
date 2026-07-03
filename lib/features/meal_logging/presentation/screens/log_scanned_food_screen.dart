import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/content_area.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../domain/meal_slot.dart';
import '../widgets/slot_chip_selector.dart';

/// The user's logging intent returned from [LogScannedFoodScreen].
///
/// Pure data — the caller (which owns the log date + meal-log controller) is
/// responsible for actually writing the log. This keeps the page presentation
/// only and avoids duplicating the logging pipeline.
class ScannedFoodLogRequest {
  const ScannedFoodLogRequest({required this.servings, required this.slot});

  final double servings;
  final MealSlot slot;
}

/// Food-logging confirmation page shown after scanning a barcode from the meal
/// log ("Discover") flow.
///
/// This is intentionally distinct from the nutrition-plan `FoodDetailScreen`
/// (which assigns a food to before/during/after-run categories in the plan's
/// food pool). When a user is simply *logging what they ate*, run categories
/// are irrelevant — they want servings, a meal slot, and a live nutrition
/// preview. This page pops a [ScannedFoodLogRequest] on confirm, or `null` if
/// the user backs out.
class LogScannedFoodScreen extends StatefulWidget {
  const LogScannedFoodScreen({
    super.key,
    required this.food,
    this.initialSlot = MealSlot.snack,
  });

  final Food food;
  final MealSlot initialSlot;

  @override
  State<LogScannedFoodScreen> createState() => _LogScannedFoodScreenState();
}

class _LogScannedFoodScreenState extends State<LogScannedFoodScreen> {
  static const double _minServings = 0.5;
  static const double _maxServings = 10.0;
  static const double _step = 0.5;

  double _servings = 1.0;
  late MealSlot _slot = widget.initialSlot;

  Food get _food => widget.food;

  String get _title => _food.displayName ?? _food.name;

  String get _servingsLabel => _servings == _servings.truncateToDouble()
      ? _servings.toInt().toString()
      : _servings.toStringAsFixed(1);

  /// A short "per serving" descriptor, e.g. "1 gel" or "30 g", when available.
  String? get _servingDescriptor {
    final amount = _food.servingAmount;
    final unit = _food.servingUnit;
    if (amount != null && unit != null && unit.isNotEmpty) {
      final amountLabel = amount == amount.truncateToDouble()
          ? amount.toInt().toString()
          : amount.toStringAsFixed(1);
      return 'Per serving: $amountLabel $unit';
    }
    final size = _food.servingSize;
    if (size != null && size.isNotEmpty) return 'Per serving: $size';
    return null;
  }

  void _decrement() {
    setState(() {
      _servings = (_servings - _step).clamp(_minServings, _maxServings);
    });
  }

  void _increment() {
    setState(() {
      _servings = (_servings + _step).clamp(_minServings, _maxServings);
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      ScannedFoodLogRequest(servings: _servings, slot: _slot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: const CustomAppBarBackButton(),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Log Food',
          style: AppTextStyles.sectionTitle.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: ContentArea(
        maxWidth: 600,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProductHeader(colorScheme),
                      const SizedBox(height: AppSpacing.lg),
                      _buildNutritionSummary(colorScheme),
                      const SizedBox(height: AppSpacing.lg),
                      _buildServingsControl(colorScheme),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Meal',
                        style: AppTextStyles.subtitle.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SlotChipSelector(
                        selectedSlot: _slot,
                        onSlotSelected: (s) => setState(() => _slot = s),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: KylePrimaryButton(
                  text: 'Log Food',
                  onPressed: _confirm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader(ColorScheme colorScheme) {
    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: AppIconSizes.foodIcon,
              height: AppIconSizes.foodIcon,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withValues(alpha: 0.2),
                borderRadius: AppRadius.smRadius,
              ),
              child: _food.imageAddress != null
                  ? ClipRRect(
                      borderRadius: AppRadius.smRadius,
                      child: Image.network(
                        _food.imageAddress!,
                        width: AppIconSizes.foodIcon,
                        height: AppIconSizes.foodIcon,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => FaIcon(
                          FontAwesomeIcons.utensils,
                          color: colorScheme.onSurfaceVariant,
                          size: AppIconSizes.controlIcon,
                        ),
                      ),
                    )
                  : FaIcon(
                      FontAwesomeIcons.utensils,
                      color: colorScheme.onSurfaceVariant,
                      size: AppIconSizes.controlIcon,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _title,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_servingDescriptor != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _servingDescriptor!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary(ColorScheme colorScheme) {
    final calories = _food.caloriesPerServing;
    final carbs = _food.carbsPerServing;
    final protein = _food.proteinPerServing;
    final fat = _food.fatPerServing;
    final sodium = _food.sodiumMg;

    String scaledInt(num? perServing) => perServing == null
        ? '—'
        : (perServing * _servings).round().toString();

    return BaseCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For $_servingsLabel ${_servings == 1 ? 'serving' : 'servings'}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _macroTile('Calories', scaledInt(calories), 'kcal',
                    kMacroColorCalories),
                _macroTile('Carbs', scaledInt(carbs), 'g', kMacroColorCarbs),
                _macroTile(
                    'Protein', scaledInt(protein), 'g', kMacroColorProtein),
                _macroTile('Fat', scaledInt(fat), 'g', kMacroColorFat),
              ],
            ),
            if (sodium != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sodium ${scaledInt(sodium)} mg',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _macroTile(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            unit,
            style: AppTextStyles.smallLabel.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildServingsControl(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Servings',
          style: AppTextStyles.subtitle.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              iconSize: 32,
              onPressed: _servings > _minServings ? _decrement : null,
            ),
            SizedBox(
              width: 72,
              child: Text(
                _servingsLabel,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              iconSize: 32,
              onPressed: _servings < _maxServings ? _increment : null,
            ),
          ],
        ),
      ],
    );
  }
}
