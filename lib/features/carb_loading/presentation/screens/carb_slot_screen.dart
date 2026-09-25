import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../../meal_logging/presentation/screens/log_meal_screen.dart';
import '../../domain/carb_loading_pace_engine.dart' show CarbDayRel;
import '../../domain/meal_type.dart';

/// The slot interior page (surfaces/carb-loading-dashboard.md): a
/// COMPOSITION of shipping surfaces per the 2026-09-24 ruling — the
/// Log-a-Meal path does the searching/scanning/logging; ONLY the slot
/// header and the Logged section are new pixels. SC-1/SC-3 land here.
///
/// Logging writes ordinary `meal_logs` rows tagged with this slot (Path A):
/// they count toward the day total like any other log, the slot card sums
/// its tagged rows, and deleting the plan never touches them.
class CarbSlotScreen extends ConsumerWidget {
  const CarbSlotScreen({super.key, required this.slot, required this.dateStr});

  final MealType slot;
  final String dateStr;

  static void open(BuildContext context, MealType slot, String dateStr) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CarbSlotScreen(slot: slot, dateStr: dateStr),
      ),
    );
  }

  /// The six-slot taxonomy's log tag for this slot.
  MealSlot get logSlot => switch (slot) {
    MealType.breakfast => MealSlot.breakfast,
    MealType.morningSnack => MealSlot.morningSnack,
    MealType.lunch => MealSlot.lunch,
    MealType.afternoonSnack => MealSlot.afternoonSnack,
    MealType.dinner => MealSlot.dinner,
    MealType.eveningSnack => MealSlot.eveningSnack,
    MealType.snacks => MealSlot.snack,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carbAsync = ref.watch(carbDashboardForDateProvider(dateStr));
    final carb = carbAsync.value;
    final card = carb?.slots.where((s) => s.slot == slot).firstOrNull;
    final cream = AppColors.cream;
    final isToday = card == null || card.dayRel == CarbDayRel.today;

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _backButton(context),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          slot.displayName,
                          style: TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 19,
                            color: cream,
                          ),
                        ),
                        if (card != null)
                          Text(
                            '${card.clockStr} · ${card.headerFigure} carbs',
                            style: TextStyle(
                              fontFamily: 'Apercu',
                              fontSize: 11.5,
                              color: cream.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isToday)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('carb_slot.add_food'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      foregroundColor: AppColors.blackberry,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    onPressed: () => openLogMealScreen(
                      context,
                      logDate: dateStr,
                      source: 'carb_slot',
                      initialSlot: logSlot,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Food',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Text(
                'LOGGED',
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: cream.withValues(alpha: 0.45),
                ),
              ),
            ),
            Expanded(
              child: card == null || card.items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        'Nothing logged in this slot yet.',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 13,
                          color: cream.withValues(alpha: 0.5),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        for (final item in card.items)
                          _loggedRow(
                            context,
                            ref,
                            item.id,
                            item.name,
                            item.gramsStr,
                            isToday,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loggedRow(
    BuildContext context,
    WidgetRef ref,
    String logId,
    String name,
    String grams,
    bool isToday,
  ) {
    final cream = AppColors.cream;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        // Editing (servings stepper, remove, re-slot) is the SHIPPING edit
        // surface's job — no bespoke editor here (composition ruling).
        onTap: isToday ? () => _edit(context, ref, logId) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cream.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Compadre',
                    fontSize: 14.5,
                    color: cream,
                  ),
                ),
              ),
              Text(
                grams,
                style: TextStyle(
                  fontFamily: 'Apercu Mono',
                  fontSize: 12,
                  color: AppColors.orange,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 15,
                  color: cream.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context, WidgetRef ref, String logId) {
    final logs = ref.read(mealLogsForDateProvider(dateStr)).value ?? const [];
    for (final log in logs) {
      if (log.id == logId) {
        context.push('/meal-log/edit', extra: {'log': log});
        return;
      }
    }
  }

  Widget _backButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          child: Icon(Icons.chevron_left, size: 20, color: AppColors.cream),
        ),
      ),
    );
  }
}
