import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/widgets/kyle_design/inputs/two_option_pill_slider.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/time_slot_assignment.dart';
import 'macro_summary_row.dart';
import 'dismissible_food_item.dart';
import 'by_hour_view.dart';

/// Main container for during-activity sections that supports Summary / By Hour toggle.
///
/// When durationMinutes >= 60, shows a TwoOptionPillSlider to switch between:
/// - **Summary**: Flat list of food items (existing behavior)
/// - **By Hour**: Time-slotted view with hourly buckets
///
/// For durations < 60 min, only shows the summary view (no toggle).
class DuringPhaseSectionWidget extends ConsumerStatefulWidget {
  const DuringPhaseSectionWidget({
    super.key,
    required this.section,
    required this.sectionColor,
    required this.sectionTitle,
    required this.category,
    required this.durationMinutes,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onAddFood,
    required this.onInitializeByHour,
    required this.onMoveFoodToTimeSlot,
    this.subtitle,
    this.showSwipeHint = false,
  });

  final PlanSection section;
  final Color sectionColor;
  final String sectionTitle;
  final String category;
  final int durationMinutes;
  final bool useImperial;
  final String? subtitle;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;
  final void Function(String category) onAddFood;

  /// Called on first toggle to By Hour to initialize byHourData
  final void Function(String category, int durationMinutes) onInitializeByHour;

  /// Called when a food item is dragged to a new time slot
  final void Function(String foodId, String category, TimeSlot newTimeSlot)
      onMoveFoodToTimeSlot;

  final bool showSwipeHint;

  @override
  ConsumerState<DuringPhaseSectionWidget> createState() =>
      _DuringPhaseSectionWidgetState();
}

class _DuringPhaseSectionWidgetState
    extends ConsumerState<DuringPhaseSectionWidget> {
  /// True = By Hour view, False = Summary view
  bool _showByHour = false;

  /// Whether the summary food list is expanded
  bool _summaryExpanded = true;

  @override
  void initState() {
    super.initState();
    // Default to By Hour if byHourData already exists
    if (widget.section.byHourData != null && widget.durationMinutes >= 60) {
      _showByHour = true;
    }
  }

  bool get _canShowByHour => widget.durationMinutes >= 60;

  void _onToggleByHour() {
    if (!_canShowByHour) return;

    setState(() {
      _showByHour = !_showByHour;
    });

    // Initialize byHourData on first toggle
    if (_showByHour && widget.section.byHourData == null) {
      widget.onInitializeByHour(widget.category, widget.durationMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: widget.sectionColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (widget.subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              widget.subtitle!,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          MacroSummaryRow(
            foods: widget.section.foodItems,
            section: widget.section,
            category: widget.category,
            useImperial: widget.useImperial,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_showByHour && widget.section.byHourData != null)
            _buildByHourContent()
          else
            _buildSummaryContent(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.sectionTitle,
            style: AppTextStyles.sectionTitle.copyWith(
              color: widget.sectionColor,
              fontSize: 18,
            ),
          ),
        ),
        if (_canShowByHour) ...[
          SizedBox(
            width: 180,
            child: TwoOptionPillSlider(
              leftLabel: 'Summary',
              rightLabel: 'By Hour',
              isLeftSelected: !_showByHour,
              onLeftTap: () {
                if (_showByHour) _onToggleByHour();
              },
              onRightTap: () {
                if (!_showByHour) _onToggleByHour();
              },
              textStyle: AppTextStyles.smallLabel.copyWith(fontSize: 12),
              selectedTextColor: Colors.white,
              unselectedTextColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
              trackColor:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              thumbColor: widget.sectionColor,
              height: 32,
              thumbInset: 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryContent(BuildContext context) {
    final foodSummary = widget.section.foodItems
        .map((f) => f.displayName ?? f.name)
        .join(' + ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible food list
        InkWell(
          onTap: () {
            setState(() {
              _summaryExpanded = !_summaryExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  _summaryExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  color: widget.sectionColor,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    foodSummary,
                    style: AppTextStyles.smallLabel.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_summaryExpanded) ...[
          const SizedBox(height: AppSpacing.sm),
          ...widget.section.foodItems.asMap().entries.map((entry) {
            final index = entry.key;
            final food = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < widget.section.foodItems.length - 1
                    ? AppSpacing.sm
                    : 0,
              ),
              child: DismissibleFoodItem(
                food: food,
                category: widget.category,
                onSwap: () => widget.onSwapFood(
                    food.id, food.name, widget.category),
                onDelete: () =>
                    widget.onDeleteFood(food.id, widget.category),
                onQuantityChange: (newQuantity) =>
                    widget.onUpdateQuantity(
                        food.id, widget.category, newQuantity),
                showSwipeHint: widget.showSwipeHint,
                useImperial: widget.useImperial,
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          KyleAddFoodButton(
            text: 'ADD FORMULA',
            onPressed: () => widget.onAddFood(widget.category),
          ),
        ],
      ],
    );
  }

  Widget _buildByHourContent() {
    return ByHourView(
      section: widget.section,
      byHourData: widget.section.byHourData!,
      sectionColor: widget.sectionColor,
      category: widget.category,
      useImperial: widget.useImperial,
      onSwapFood: widget.onSwapFood,
      onDeleteFood: widget.onDeleteFood,
      onUpdateQuantity: widget.onUpdateQuantity,
      onAddFood: widget.onAddFood,
      onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
    );
  }
}
