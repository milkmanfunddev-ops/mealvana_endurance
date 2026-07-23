/// Shared helpers used by both the tabbed log sheet and the legacy
/// [RecentSavedPickerScreen] route.
///
/// Extracted here to avoid duplicating business logic across files.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/meal_component.dart';
import '../../domain/meal_log.dart';
import '../../domain/meal_slot.dart';
import '../widgets/slot_chip_selector.dart';

export '../../domain/meal_slot.dart';
export '../../domain/meal_component.dart';
export '../../domain/meal_log.dart';

// ---------------------------------------------------------------------------
// syntheticFromLog
// ---------------------------------------------------------------------------

/// Builds a single [MealComponent] from a past [MealLog] entry so it can be
/// re-logged via [MealLogController.logFromComponents].
MealComponent syntheticFromLog(MealLog log) {
  return MealComponent(
    name: log.name,
    portion: '1 serving',
    calories: log.calories,
    carbG: log.carbsG,
    proteinG: log.proteinG,
    fatG: log.fatG,
    sodiumMg: log.sodiumMg,
  );
}

// ---------------------------------------------------------------------------
// Slot picker bottom sheet
// ---------------------------------------------------------------------------

/// Shows the shared "Which meal?" slot selector sheet.
///
/// [onSelected] is called with the chosen [MealSlot] when the user taps 'Log'.
void showSlotPickerSheet(
  BuildContext context, {
  required void Function(MealSlot) onSelected,
  MealSlot initialSlot = MealSlot.breakfast,
}) {
  MealSlot selected = initialSlot;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
                'Which meal?',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              SlotChipSelector(
                selectedSlot: selected,
                onSlotSelected: (s) => setModalState(() => selected = s),
              ),
              const SizedBox(height: AppSpacing.lg),
              KylePrimaryButton(
                text: 'Log',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onSelected(selected);
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// todayDateString helper
// ---------------------------------------------------------------------------

String todayDateString() {
  final now = DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}
