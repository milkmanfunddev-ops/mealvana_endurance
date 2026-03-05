import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../../shared/widgets/kyle_design/inputs/two_option_pill_slider.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../domain/food_item_data.dart';
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
    required this.onPlaceFoodInSlot,
    required this.onRemoveFoodFromSlot,
    this.onAdjustSlotQuantity,
    this.onMoveSipFoodToSlot,
    this.subtitle,
    this.sportIcon,
    this.sportIconColor,
    this.showSwipeHint = false,
    this.activityType = ActivityType.running,
  });

  final PlanSection section;
  final Color sectionColor;
  final String sectionTitle;
  final String category;
  final int durationMinutes;
  final bool useImperial;
  final String? subtitle;
  final IconData? sportIcon;
  final Color? sportIconColor;

  /// Activity type for sport-aware UI (e.g., solid food warning badge on running)
  final ActivityType activityType;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;
  final void Function(String category) onAddFood;

  /// Called on first toggle to By Hour to initialize byHourData
  final void Function(String category, int durationMinutes) onInitializeByHour;

  /// Called when a food item is dragged to a new time slot
  final void Function(
          String foodId, String category, TimeSlot sourceTimeSlot, TimeSlot newTimeSlot)
      onMoveFoodToTimeSlot;

  /// Called when a food is placed from the unassigned tray into a slot.
  final void Function(String foodId, String category, TimeSlot slot, double qty,
      TimingCategory? timingCategory, bool isSipThroughout) onPlaceFoodInSlot;

  /// Called when a food is removed from a slot (returns to tray).
  final void Function(String foodId, String category, TimeSlot slot)
      onRemoveFoodFromSlot;

  /// Called to adjust a placed food's slot quantity by delta.
  final void Function(
      String foodId, String category, TimeSlot slot, double delta)?
      onAdjustSlotQuantity;

  /// Called when a sip food is moved from global sip into a specific hour slot.
  final void Function(String foodId, String category, TimeSlot targetSlot,
      double qty, TimingCategory? timingCategory)? onMoveSipFoodToSlot;

  final bool showSwipeHint;

  @override
  ConsumerState<DuringPhaseSectionWidget> createState() =>
      _DuringPhaseSectionWidgetState();
}

class _DuringPhaseSectionWidgetState
    extends ConsumerState<DuringPhaseSectionWidget> {
  /// True = By Hour view, False = Summary view
  bool _showByHour = false;

  @override
  void initState() {
    super.initState();
    // _showByHour defaults to false — user toggles to By Hour manually
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
        if (widget.sportIcon != null) ...[
          FaIcon(
            widget.sportIcon!,
            color: widget.sportIconColor ?? widget.sectionColor,
            size: 16,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
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
              thumbColor: AppColors.orange,
              height: 32,
              thumbInset: 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onSwap: () =>
                  widget.onSwapFood(food.id, food.name, widget.category),
              onDelete: () =>
                  widget.onDeleteFood(food.id, widget.category),
              onQuantityChange: (newQuantity) => widget.onUpdateQuantity(
                  food.id, widget.category, newQuantity),
              showSwipeHint: widget.showSwipeHint,
              useImperial: widget.useImperial,
            ),
          );
        }),
        const SizedBox(height: AppSpacing.md),
        KyleAddFoodButton(
          text: 'ADD FOOD',
          onPressed: () => widget.onAddFood(widget.category),
        ),
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
      activityType: widget.activityType,
      onSwapFood: widget.onSwapFood,
      onDeleteFood: widget.onDeleteFood,
      onUpdateQuantity: widget.onUpdateQuantity,
      onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
      onPlaceFoodInSlot: widget.onPlaceFoodInSlot,
      onRemoveFoodFromSlot: widget.onRemoveFoodFromSlot,
      onAdjustSlotQuantity: widget.onAdjustSlotQuantity,
      onMoveSipFoodToSlot: widget.onMoveSipFoodToSlot,
    );
  }
}
