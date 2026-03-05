import 'package:flutter/material.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../application/by_hour_sync_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/time_slot_assignment.dart';
import '../../../domain/unassigned_tray_item.dart';
import 'hour_bucket_widget.dart';
import 'unassigned_tray_widget.dart';

/// Renders the By-Hour view with an unassigned tray at top and hour buckets below.
///
/// The tray is derived (summary qty − assigned qty) and shown when items exist.
/// Users place foods manually via tap-to-place or drag-and-drop.
class ByHourView extends StatefulWidget {
  const ByHourView({
    super.key,
    required this.section,
    required this.byHourData,
    required this.sectionColor,
    required this.category,
    required this.useImperial,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onMoveFoodToTimeSlot,
    required this.onPlaceFoodInSlot,
    required this.onRemoveFoodFromSlot,
    this.activityType = ActivityType.running,
  });

  final PlanSection section;
  final ByHourData byHourData;
  final Color sectionColor;
  final String category;
  final bool useImperial;
  final ActivityType activityType;
  final void Function(String foodId, String foodName, String category) onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
      onUpdateQuantity;
  final void Function(
          String foodId, String category, TimeSlot sourceTimeSlot, TimeSlot newTimeSlot)
      onMoveFoodToTimeSlot;

  /// Called when a food is placed from the tray into a slot.
  final void Function(String foodId, String category, TimeSlot slot, double qty,
      TimingCategory? timingCategory, bool isSipThroughout) onPlaceFoodInSlot;

  /// Called when a food is removed from a slot (returns to tray).
  final void Function(String foodId, String category, TimeSlot slot)
      onRemoveFoodFromSlot;

  @override
  State<ByHourView> createState() => _ByHourViewState();
}

class _ByHourViewState extends State<ByHourView> {
  String? _selectedFoodId;

  @override
  Widget build(BuildContext context) {
    final totalHours = widget.byHourData.totalHours;

    // Build food map for quick lookup
    final foodMap = {
      for (final food in widget.section.foodItems) food.id: food,
    };

    // Derive unassigned tray items
    final unassignedItems = ByHourSyncService.calculateUnassignedItems(
      summaryFoods: widget.section.foodItems,
      byHourData: widget.byHourData,
    );

    // Clear selection if selected food is no longer in tray
    if (_selectedFoodId != null &&
        !unassignedItems.any((item) => item.foodId == _selectedFoodId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedFoodId = null);
      });
    }

    return Column(
      children: [
        // Unassigned tray at top
        UnassignedTrayWidget(
          items: unassignedItems,
          sectionColor: widget.sectionColor,
          selectedFoodId: _selectedFoodId,
          onSelectFood: (foodId) {
            setState(() => _selectedFoodId = foodId);
          },
          foodMap: foodMap,
        ),
        // Hour buckets
        ...List.generate(totalHours, (hourIndex) {
          final assignments = widget.byHourData.assignmentsForHour(hourIndex);
          final slotCount = widget.byHourData.slotCountForHour(hourIndex);

          return HourBucketWidget(
            hourIndex: hourIndex,
            slotCount: slotCount,
            assignments: assignments,
            foodMap: foodMap,
            sectionColor: widget.sectionColor,
            category: widget.category,
            useImperial: widget.useImperial,
            activityType: widget.activityType,
            onSwapFood: widget.onSwapFood,
            onDeleteFood: widget.onDeleteFood,
            onUpdateQuantity: widget.onUpdateQuantity,
            onMoveFoodToTimeSlot: widget.onMoveFoodToTimeSlot,
            selectedFoodId: _selectedFoodId,
            onPlaceFromTray: (foodId, slot, qty, timingCategory, isSip) {
              widget.onPlaceFoodInSlot(
                foodId,
                widget.category,
                slot,
                qty,
                timingCategory,
                isSip,
              );
              // Clear selection after placement
              setState(() => _selectedFoodId = null);
            },
            onRemoveFromSlot: (foodId, slot) {
              widget.onRemoveFoodFromSlot(foodId, widget.category, slot);
            },
          );
        }),
      ],
    );
  }
}
