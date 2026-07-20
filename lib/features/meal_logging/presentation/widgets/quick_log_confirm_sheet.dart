import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/consumed_totals.dart';
import '../../domain/meal_slot.dart';
import 'slot_chip_selector.dart';

final DateFormat _timeFmt = DateFormat('h:mm a');

/// Result of [showQuickLogConfirmSheet] — the servings/time/category choice
/// confirmed for a one-tap quick-log action on `LogMealScreen`.
class QuickLogConfirmResult {
  const QuickLogConfirmResult({
    required this.servings,
    required this.eatenAt,
    this.slot,
  });

  final double servings;
  final DateTime eatenAt;
  final MealSlot? slot;
}

/// Shows the quick-confirm sheet used by every tap-to-quick-log action on
/// `LogMealScreen` (food/ingredient, recipe, saved meal, recent, quick
/// assembly).
///
/// Each confirmation here commits a single terminal `meal_logs` row via the
/// caller's own `MealLogController` call (`logFromComponents`/`logRecipe`/
/// `logSavedMeal`) — this sheet only decides servings/time/category, it does
/// not write anything itself.
///
/// [showServingsStepper] is false for items with no natural per-serving
/// scale (saved meals, quick assemblies) — only time + optional category are
/// asked for those. [previewTotals], when provided, renders a live macro
/// preview above the servings stepper.
Future<QuickLogConfirmResult?> showQuickLogConfirmSheet(
  BuildContext context, {
  required String title,
  required String logDate,
  bool showServingsStepper = true,
  double initialServings = 1.0,
  ConsumedTotals Function(double servings)? previewTotals,
  MealSlot? initialSlot,
}) {
  double servings = initialServings;
  final parsed = DateTime.parse(logDate);
  final now = DateTime.now();
  DateTime eatenAt = DateTime(parsed.year, parsed.month, parsed.day, now.hour, now.minute);
  MealSlot? slot = initialSlot;

  return showModalBottomSheet<QuickLogConfirmResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final preview = previewTotals?.call(servings);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.blackberry : AppColors.cream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.md,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  title,
                  style: AppTextStyles.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${preview.calories} kcal  ·  '
                    'C ${preview.carbsG.toStringAsFixed(0)}g  '
                    'P ${preview.proteinG.toStringAsFixed(0)}g  '
                    'F ${preview.fatG.toStringAsFixed(0)}g',
                    style: AppTextStyles.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (showServingsStepper) ...[
                  Text('Servings', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: servings > 0.5
                            ? () => setModalState(
                                () => servings = (servings - 0.5).clamp(0.5, 10.0),
                              )
                            : null,
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          servings == servings.truncateToDouble()
                              ? servings.toInt().toString()
                              : servings.toStringAsFixed(1),
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: servings < 10
                            ? () => setModalState(
                                () => servings = (servings + 0.5).clamp(0.5, 10.0),
                              )
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text('Time eaten', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(eatenAt),
                      helpText: 'Time eaten',
                    );
                    if (picked == null) return;
                    setModalState(() {
                      eatenAt = DateTime(
                        eatenAt.year,
                        eatenAt.month,
                        eatenAt.day,
                        picked.hour,
                        picked.minute,
                      );
                    });
                  },
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _timeFmt.format(eatenAt),
                          style: Theme.of(ctx).textTheme.bodyLarge,
                        ),
                        const Spacer(),
                        Text(
                          'Change',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Meal type (optional)', style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                OptionalSlotChipSelector(
                  selectedSlot: slot,
                  onSlotSelected: (s) => setModalState(() => slot = s),
                ),
                const SizedBox(height: AppSpacing.lg),
                KylePrimaryButton(
                  text: 'Log it',
                  onPressed: () => Navigator.of(ctx).pop(
                    QuickLogConfirmResult(
                      servings: servings,
                      eatenAt: eatenAt,
                      slot: slot,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
