import 'package:flutter/material.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../application/by_hour_sync_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/nutrition_plan.dart';
import '../../../domain/time_slot_assignment.dart';
import 'global_sip_section_widget.dart';
import 'hour_bucket_widget.dart';
import 'unassigned_tray_widget.dart';

/// Renders the By-Hour view with global sip section, unassigned tray, and hour buckets.
///
/// Layout:
/// 1. Global Sip Throughout (drinks + electrolytes, hourIndex == -1)
/// 2. Unassigned Tray (non-drink foods only)
/// 3. Hour buckets (Hour 1, Hour 2, ...)
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
    this.onAdjustSlotQuantity,
    this.onMoveSipFoodToSlot,
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

  /// Called to adjust a placed food's slot quantity by delta.
  final void Function(
      String foodId, String category, TimeSlot slot, double delta)?
      onAdjustSlotQuantity;

  /// Called when a sip food is moved from global sip into a specific hour slot.
  final void Function(String foodId, String category, TimeSlot targetSlot,
      double qty, TimingCategory? timingCategory)? onMoveSipFoodToSlot;

  @override
  State<ByHourView> createState() => _ByHourViewState();
}

class _ByHourViewState extends State<ByHourView> {
  /// Selected food from the unassigned tray.
  String? _selectedTrayFoodId;

  /// Selected food from the global sip section.
  String? _selectedSipFoodId;

  /// Combined selected food ID (mutually exclusive between tray and sip).
  String? get _selectedFoodId => _selectedTrayFoodId ?? _selectedSipFoodId;

  @override
  Widget build(BuildContext context) {
    final totalHours = widget.byHourData.totalHours;

    // Build food map for quick lookup
    final foodMap = {
      for (final food in widget.section.foodItems) food.id: food,
    };

    // Get global sip assignments (hourIndex == -1)
    final globalSipAssignments = widget.byHourData.globalSipAssignments;

    // Derive unassigned tray items — exclude foods that are in global sip
    final globalSipFoodIds = globalSipAssignments
        .map((a) => a.foodItemId)
        .toSet();

    final unassignedItems = ByHourSyncService.calculateUnassignedItems(
      summaryFoods: widget.section.foodItems,
      byHourData: widget.byHourData,
    ).where((item) => !globalSipFoodIds.contains(item.foodId)).toList();

    // Clear tray selection if selected food is no longer in tray
    if (_selectedTrayFoodId != null &&
        !unassignedItems.any((item) => item.foodId == _selectedTrayFoodId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedTrayFoodId = null);
      });
    }

    // Clear sip selection if selected food is no longer in sip
    if (_selectedSipFoodId != null &&
        !globalSipAssignments.any((a) => a.foodItemId == _selectedSipFoodId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedSipFoodId = null);
      });
    }

    return Column(
      children: [
        // Global Sip Throughout section
        GlobalSipSectionWidget(
          sipAssignments: globalSipAssignments,
          foodMap: foodMap,
          sectionColor: widget.sectionColor,
          selectedFoodId: _selectedSipFoodId,
          onSelectFood: (foodId) {
            setState(() {
              _selectedSipFoodId = foodId;
              _selectedTrayFoodId = null; // clear tray selection
            });
          },
          onAdjustSlotQuantity: (foodId, slot, delta) {
            widget.onAdjustSlotQuantity?.call(
              foodId,
              widget.category,
              slot,
              delta,
            );
          },
          onUnassignFood: (foodId, slot) {
            widget.onRemoveFoodFromSlot(foodId, widget.category, slot);
          },
        ),
        // Unassigned tray (non-drink foods only)
        UnassignedTrayWidget(
          items: unassignedItems,
          sectionColor: widget.sectionColor,
          selectedFoodId: _selectedTrayFoodId,
          onSelectFood: (foodId) {
            setState(() {
              _selectedTrayFoodId = foodId;
              _selectedSipFoodId = null; // clear sip selection
            });
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
              // Check if the food is from global sip section
              if (globalSipFoodIds.contains(foodId) &&
                  widget.onMoveSipFoodToSlot != null) {
                widget.onMoveSipFoodToSlot!(
                  foodId,
                  widget.category,
                  slot,
                  qty,
                  timingCategory,
                );
              } else {
                widget.onPlaceFoodInSlot(
                  foodId,
                  widget.category,
                  slot,
                  qty,
                  timingCategory,
                  isSip,
                );
              }
              // Clear both selections after placement
              setState(() {
                _selectedTrayFoodId = null;
                _selectedSipFoodId = null;
              });
            },
            onRemoveFromSlot: (foodId, slot) {
              widget.onRemoveFoodFromSlot(foodId, widget.category, slot);
            },
            onAdjustSlotQuantity: (foodId, slot, delta) {
              widget.onAdjustSlotQuantity?.call(
                foodId,
                widget.category,
                slot,
                delta,
              );
            },
          );
        }),
      ],
    );
  }
}
