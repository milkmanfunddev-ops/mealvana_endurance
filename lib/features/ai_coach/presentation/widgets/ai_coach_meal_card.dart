import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../meal_logging/domain/meal_log_source.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../domain/ai_coach_ui_part.dart';

// ---------------------------------------------------------------------------
// AiCoachMealCard
// ---------------------------------------------------------------------------

/// Renders a single [AiCoachMealSuggestion] as a Kyle-styled card.
///
/// Displays: meal name, description, kcal + C/P/F macro line,
/// the recommended slot as a chip, and a "Log it" button.
///
/// Tapping "Log it" opens a bottom sheet ([_LogConfirmSheet]) that lets the
/// user confirm the slot (pre-selected to the suggestion) then logs the meal
/// via [MealLogController.logFromComponents] with [MealLogSource.describe].
class AiCoachMealCard extends ConsumerWidget {
  const AiCoachMealCard({super.key, required this.suggestion});

  final AiCoachMealSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final subColor = textColor.withValues(alpha: 0.6);
    final cardBg = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    final slotLabel = suggestion.slot?.label ?? '';

    return BaseCard(
      backgroundColor: cardBg,
      border: Border.all(
        color: AppColors.electrolyte.withValues(alpha: 0.25),
        width: 1,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: name + slot chip ─────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  suggestion.name,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 15,
                  ),
                ),
              ),
              if (slotLabel.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                _SlotChip(label: slotLabel),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.xxs),

          // ── Description ──────────────────────────────────────────────────
          Text(
            suggestion.description,
            style: AppTextStyles.bodySmall.copyWith(
              color: subColor,
              height: 1.5,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Macro row ────────────────────────────────────────────────────
          _MacroRow(suggestion: suggestion, textColor: textColor),

          const SizedBox(height: AppSpacing.md),

          // ── Log it button ─────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: _LogItButton(suggestion: suggestion),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SlotChip
// ---------------------------------------------------------------------------

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.circular),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.electrolyteDark,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MacroRow
// ---------------------------------------------------------------------------

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.suggestion, required this.textColor});
  final AiCoachMealSuggestion suggestion;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    // Wrap (not Row) so the macro labels reflow to a second line on narrow
    // cards or at large text scale instead of overflowing.
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // kcal with a small fire icon
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.fire,
              size: 11,
              color: AppColors.electrolyte,
            ),
            const SizedBox(width: 3),
            _MacroLabel(label: '${suggestion.kcal} kcal', textColor: textColor),
          ],
        ),
        _MacroLabel(
          label: '${suggestion.carbG.round()}g C',
          textColor: textColor,
        ),
        _MacroLabel(
          label: '${suggestion.proteinG.round()}g P',
          textColor: textColor,
        ),
        _MacroLabel(
          label: '${suggestion.fatG.round()}g F',
          textColor: textColor,
        ),
      ],
    );
  }
}

class _MacroLabel extends StatelessWidget {
  const _MacroLabel({required this.label, required this.textColor});
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.bodySmall.copyWith(
        color: textColor.withValues(alpha: 0.75),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _LogItButton
// ---------------------------------------------------------------------------

class _LogItButton extends ConsumerWidget {
  const _LogItButton({required this.suggestion});
  final AiCoachMealSuggestion suggestion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _openLogSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.electrolyte,
          borderRadius: BorderRadius.circular(AppRadius.circular),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.plus,
              size: 11,
              color: AppColors.blackberry,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              'Log it',
              style: AppTextStyles.buttonPrimary.copyWith(
                color: AppColors.blackberry,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLogSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LogConfirmSheet(suggestion: suggestion),
    );
  }
}

// ---------------------------------------------------------------------------
// _LogConfirmSheet
// ---------------------------------------------------------------------------

/// Bottom sheet that confirms slot selection then logs the meal.
class _LogConfirmSheet extends ConsumerStatefulWidget {
  const _LogConfirmSheet({required this.suggestion});
  final AiCoachMealSuggestion suggestion;

  @override
  ConsumerState<_LogConfirmSheet> createState() => _LogConfirmSheetState();
}

class _LogConfirmSheetState extends ConsumerState<_LogConfirmSheet> {
  late MealSlot _selectedSlot;

  @override
  void initState() {
    super.initState();
    _selectedSlot = widget.suggestion.slot ?? MealSlot.snack;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final bgColor = isDark ? AppColors.blackberry : AppColors.cream;

    final logState = ref.watch(mealLogControllerProvider);
    final isLoading = logState.isLoading;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.circular),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            widget.suggestion.name,
            style: AppTextStyles.sectionTitle.copyWith(color: textColor),
          ),

          const SizedBox(height: AppSpacing.xs),

          Text(
            '${widget.suggestion.kcal} kcal  ·  '
            '${widget.suggestion.carbG.round()}g C  ·  '
            '${widget.suggestion.proteinG.round()}g P  ·  '
            '${widget.suggestion.fatG.round()}g F',
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Slot selector
          Text(
            'Log to',
            style: AppTextStyles.bodySmall.copyWith(
              color: textColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          _SlotSelector(
            selected: _selectedSlot,
            onChanged: (slot) => setState(() => _selectedSlot = slot),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Confirm button
          GestureDetector(
            onTap: isLoading ? null : _confirmLog,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isLoading
                    ? AppColors.electrolyte.withValues(alpha: 0.5)
                    : AppColors.electrolyte,
                borderRadius: BorderRadius.circular(AppRadius.circular),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.blackberry,
                      ),
                    )
                  : Text(
                      'Confirm',
                      style: AppTextStyles.buttonPrimary.copyWith(
                        color: AppColors.blackberry,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLog() async {
    final today = _todayString();

    await ref
        .read(mealLogControllerProvider.notifier)
        .logFromComponents(
          name: widget.suggestion.name,
          slot: _selectedSlot,
          logDate: today,
          source: MealLogSource.describe,
          components: widget.suggestion.components,
        );

    if (!mounted) return;

    final logState = ref.read(mealLogControllerProvider);
    if (logState.hasError) {
      MealvanaSnackbar.showError(
        context,
        "Couldn't log that meal. Please try again.",
      );
    } else {
      Navigator.of(context).pop();
      MealvanaSnackbar.showSuccess(
        context,
        '${widget.suggestion.name} logged to ${_selectedSlot.label}',
      );
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// _SlotSelector
// ---------------------------------------------------------------------------

class _SlotSelector extends StatelessWidget {
  const _SlotSelector({required this.selected, required this.onChanged});

  final MealSlot selected;
  final ValueChanged<MealSlot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: MealSlot.values.map((slot) {
        final isSelected = slot == selected;
        return GestureDetector(
          onTap: () => onChanged(slot),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.electrolyte
                  : AppColors.electrolyte.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.circular),
              border: Border.all(
                color: isSelected
                    ? AppColors.electrolyte
                    : AppColors.electrolyte.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              slot.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected
                    ? AppColors.blackberry
                    : AppColors.electrolyteDark,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
