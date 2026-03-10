import 'package:flutter/material.dart';
import '../../../../../shared/domain/activity_type.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../application/by_hour_apportionment_service.dart';
import '../../../domain/food_item_data.dart';
import '../../../domain/time_slot_assignment.dart';
import '../../../domain/unassigned_tray_item.dart';
import 'placed_slot_food_widget.dart';

/// A single time slot row in the By Hour timeline.
///
/// Shows: time label (e.g., "0:15") + dot + vertical line + food item(s).
/// Empty slots show just the time label and dot (with lighter styling).
/// Serves as a DragTarget for both slot-to-slot moves and tray-to-slot drops.
/// Supports tap-to-place when a food is selected in the tray.
class TimeSlotRow extends StatelessWidget {
  const TimeSlotRow({
    super.key,
    required this.timeSlot,
    required this.assignments,
    required this.foodMap,
    required this.sectionColor,
    required this.category,
    required this.useImperial,
    required this.isLastInHour,
    required this.onSwapFood,
    required this.onDeleteFood,
    required this.onUpdateQuantity,
    required this.onMoveFoodToTimeSlot,
    this.activityType = ActivityType.running,
    this.selectedFoodId,
    this.onPlaceFromTray,
    this.onRemoveFromSlot,
    this.onAdjustSlotQuantity,
  });

  final TimeSlot timeSlot;
  final List<TimeSlotAssignment> assignments;
  final Map<String, FoodItemData> foodMap;
  final Color sectionColor;
  final String category;
  final bool useImperial;
  final bool isLastInHour;
  final ActivityType activityType;
  final void Function(String foodId, String foodName, String category)
  onSwapFood;
  final void Function(String foodId, String category) onDeleteFood;
  final void Function(String foodId, String category, double newQuantity)
  onUpdateQuantity;
  final void Function(
    String foodId,
    String category,
    TimeSlot sourceTimeSlot,
    TimeSlot newTimeSlot,
  )
  onMoveFoodToTimeSlot;

  /// Currently selected food ID for tap-to-place mode.
  final String? selectedFoodId;

  /// Called when a food is placed from tray (tap or drop).
  final void Function(String foodId, TimeSlot slot, double qty,
      TimingCategory? timingCategory, bool isSipThroughout)? onPlaceFromTray;

  /// Called when a food is removed from this slot (swipe-to-dismiss).
  final void Function(String foodId, TimeSlot slot)? onRemoveFromSlot;

  /// Called to adjust a placed food's slot quantity by delta.
  final void Function(String foodId, TimeSlot slot, double delta)?
      onAdjustSlotQuantity;

  @override
  Widget build(BuildContext context) {
    final hasItems = assignments.isNotEmpty;
    final timeColor = hasItems
        ? sectionColor
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final dotColor = hasItems
        ? sectionColor
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);

    final hasTapTarget = selectedFoodId != null && !hasItems;

    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        return details.data is TimeSlotAssignment || details.data is TrayDragData;
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is TimeSlotAssignment) {
          onMoveFoodToTimeSlot(
            data.foodItemId,
            category,
            data.timeSlot,
            timeSlot,
          );
        } else if (data is TrayDragData) {
          onPlaceFromTray?.call(
            data.foodId,
            timeSlot,
            data.quantity,
            data.timingCategory,
            false,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: hasTapTarget
              ? () {
                  final food = foodMap[selectedFoodId];
                  if (food != null) {
                    final stepSize = food.isIndivisible ? 1.0 : 0.5;
                    final timingCategory =
                        ByHourApportionmentService.resolveTimingCategory(food);
                    onPlaceFromTray?.call(
                      selectedFoodId!,
                      timeSlot,
                      stepSize,
                      timingCategory,
                      false,
                    );
                  }
                }
              : null,
          child: Container(
            decoration: isDropTarget || hasTapTarget
                ? BoxDecoration(
                    color: sectionColor.withValues(alpha: isDropTarget ? 0.08 : 0.04),
                    borderRadius: AppRadius.smRadius,
                  )
                : null,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time label
                  SizedBox(
                    width: 44,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        timeSlot.displayLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: timeColor,
                          fontSize: 13,
                          fontWeight: hasItems
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  // Dot + vertical line
                  SizedBox(
                    width: 20,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                        if (!isLastInHour)
                          Expanded(
                            child: Container(
                              width: 1,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.15),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Food items
                  Expanded(
                    child: hasItems
                        ? _buildFoodItems(context)
                        : SizedBox(
                            height: 32,
                            child: hasTapTarget
                                ? Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Tap to place',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: sectionColor.withValues(alpha: 0.5),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFoodItems(BuildContext context) {
    final entries = _buildSlotEntries();
    return Column(
      children: entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: _buildDraggableFoodItem(context, entry),
        );
      }).toList(),
    );
  }

  List<_SlotFoodEntry> _buildSlotEntries() {
    final entries = <_SlotFoodEntry>[];
    final liquidIndices = <int>[];
    final electrolyteIndices = <int>[];

    for (final assignment in assignments) {
      final sourceFood = foodMap[assignment.foodItemId];
      if (sourceFood == null) continue;

      final displayFood = _adjustFoodForDisplay(sourceFood, assignment);
      final subtitle = _buildCarbSubtitle(assignment, sourceFood, displayFood);
      final entry = _SlotFoodEntry(
        assignment: assignment,
        sourceFood: sourceFood,
        displayFood: displayFood,
        subtitle: subtitle,
      );
      entries.add(entry);

      if (_isHydrationAssignment(assignment, sourceFood)) {
        liquidIndices.add(entries.length - 1);
      } else if (_isElectrolyteAssignment(assignment, sourceFood)) {
        electrolyteIndices.add(entries.length - 1);
      }
    }

    // Pair electrolytes with liquids in the same slot for a cleaner timeline.
    // Electrolyte info goes in the title (e.g., "2 cups Sports Drink + 1 Electrolyte Tablet")
    // and the subtitle keeps just the carb info (e.g., "28 g carbs").
    if (liquidIndices.isNotEmpty && electrolyteIndices.isNotEmpty) {
      final electrolyteSummary = _buildElectrolyteSummary(
        electrolyteIndices.map((idx) => entries[idx]).toList(),
      );
      if (electrolyteSummary.isNotEmpty) {
        final firstLiquidIdx = liquidIndices.first;
        final firstLiquid = entries[firstLiquidIdx];
        final updatedFood = _withQuantitySuffix(
          firstLiquid.displayFood,
          '+ $electrolyteSummary',
        );
        entries[firstLiquidIdx] = firstLiquid.copyWith(
          displayFood: updatedFood,
        );
      }

      for (final idx in electrolyteIndices) {
        entries[idx] = entries[idx].copyWith(isSecondary: true);
      }
    }

    return entries;
  }

  bool _isHydrationAssignment(
    TimeSlotAssignment assignment,
    FoodItemData food,
  ) {
    final timing = assignment.timingCategory ?? food.timingCategory;
    return timing == TimingCategory.sipThroughout ||
        timing == TimingCategory.fuelDrink ||
        food.isDrink;
  }

  bool _isElectrolyteAssignment(
    TimeSlotAssignment assignment,
    FoodItemData food,
  ) {
    final timing = assignment.timingCategory ?? food.timingCategory;
    return timing == TimingCategory.electrolyte;
  }

  String _buildElectrolyteSummary(List<_SlotFoodEntry> electrolyteEntries) {
    if (electrolyteEntries.isEmpty) return '';
    final parts = electrolyteEntries.map((entry) {
      final qty = _formatQuantity(_parseQuantity(entry.displayFood.quantity));
      return entry.displayFood.displayAtQuantity(qty);
    }).toList();
    return parts.join(' + ');
  }

  bool _isFuelAssignment(TimeSlotAssignment assignment, FoodItemData food) {
    final timing = assignment.timingCategory ?? food.timingCategory;
    return timing == TimingCategory.fuelDrink ||
        timing == TimingCategory.quickConsume;
  }

  String? _buildCarbSubtitle(
    TimeSlotAssignment assignment,
    FoodItemData sourceFood,
    FoodItemData displayFood,
  ) {
    final isHydrationOrFuel =
        _isHydrationAssignment(assignment, sourceFood) ||
        _isFuelAssignment(assignment, sourceFood);
    if (!isHydrationOrFuel) return null;

    final carbs = displayFood.nutritionalInfo?.carbs ?? 0;
    if (carbs <= 0) return null;
    return '$carbs g carbs';
  }

  double _parseQuantity(String quantity) {
    final match = RegExp(r'^([\d.]+)').firstMatch(quantity);
    return match != null ? (double.tryParse(match.group(1)!) ?? 1.0) : 1.0;
  }

  String _formatQuantity(double value) {
    if ((value - value.roundToDouble()).abs() < 0.01) {
      return value.round().toString();
    }
    if ((value * 10 - (value * 10).round()).abs() < 0.01) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  /// Creates a display copy of FoodItemData with adjusted quantity and scaled nutrition.
  FoodItemData _adjustFoodForDisplay(
    FoodItemData food,
    TimeSlotAssignment assignment,
  ) {
    if (assignment.adjustedQuantity == null) return food;

    final originalQty = ByHourApportionmentService.parseQuantity(food);
    if (originalQty <= 0) return food;

    final adjustedQty = _roundFriendlyQuantity(
      assignment.adjustedQuantity!,
      isIndivisible: food.isIndivisible,
    );
    final scale = adjustedQty / originalQty;

    // Build adjusted quantity string using centralized display logic
    final qtyStr = _formatQuantity(adjustedQty);
    final adjustedQuantityStr = food.displayAtQuantity(qtyStr);

    final ni = food.nutritionalInfo;
    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: adjustedQuantityStr,
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      templateId: food.templateId,
      scaleMultiplier: food.scaleMultiplier,
      timingCategory: food.timingCategory,
      nutritionalInfo: ni != null
          ? NutritionalInfo(
              calories: ((ni.calories ?? 0) * scale).round(),
              carbs: ((ni.carbs ?? 0) * scale).round(),
              protein: ((ni.protein ?? 0) * scale).round(),
              fat: ((ni.fat ?? 0) * scale).round(),
              sodium: ((ni.sodium ?? 0) * scale).round(),
              fluids: (ni.fluids ?? 0) * scale,
            )
          : null,
    );
  }

  Widget _buildDraggableFoodItem(BuildContext context, _SlotFoodEntry entry) {
    if (entry.isSecondary) {
      return const SizedBox.shrink();
    }

    // Use PlacedSlotFoodWidget for compact inline display with +/- and unassign
    final placedWidget = PlacedSlotFoodWidget(
      food: entry.displayFood,
      assignment: entry.assignment,
      sectionColor: sectionColor,
      onAdjustQuantity: (delta) {
        onAdjustSlotQuantity?.call(
          entry.assignment.foodItemId,
          entry.assignment.timeSlot,
          delta,
        );
      },
      onUnassign: () {
        onRemoveFromSlot?.call(
          entry.assignment.foodItemId,
          entry.assignment.timeSlot,
        );
      },
    );

    // Wrap with LongPressDraggable for slot-to-slot moves
    return LongPressDraggable<TimeSlotAssignment>(
      data: entry.assignment,
      delay: const Duration(milliseconds: 300),
      hapticFeedbackOnStart: true,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.6,
            child: placedWidget,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: placedWidget),
      child: Row(
        children: [
          // 6-dot drag handle
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Icon(
              Icons.drag_indicator,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          Expanded(child: placedWidget),
        ],
      ),
    );
  }

  /// Creates a display copy of FoodItemData with a suffix appended to the quantity string.
  /// E.g., "2 cups Sports Drink" + "+ 1 Electrolyte Tablet" → "2 cups Sports Drink + 1 Electrolyte Tablet"
  FoodItemData _withQuantitySuffix(FoodItemData food, String suffix) {
    return FoodItemData(
      id: food.id,
      name: food.name,
      quantity: '${food.quantity} $suffix',
      imageAddress: food.imageAddress,
      description: food.description,
      timing: food.timing,
      nutritionalInfo: food.nutritionalInfo,
      instructions: food.instructions,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      displayOverride: food.displayOverride,
      servingSize: food.servingSize,
      isDrink: food.isDrink,
      isIndivisible: food.isIndivisible,
      templateId: food.templateId,
      scaleMultiplier: food.scaleMultiplier,
      timingCategory: food.timingCategory,
    );
  }

  double _roundFriendlyQuantity(double value, {required bool isIndivisible}) {
    if (value <= 0) return isIndivisible ? 1 : 0.5;
    if (isIndivisible) return value.round().clamp(1, 999).toDouble();

    final half = (value * 2).round() / 2;
    final third = (value * 3).round() / 3;
    final halfDiff = (value - half).abs();
    final thirdDiff = (value - third).abs();
    final rounded = thirdDiff + 0.08 < halfDiff ? third : half;
    return (rounded * 100).round() / 100;
  }
}

class _SlotFoodEntry {
  const _SlotFoodEntry({
    required this.assignment,
    required this.sourceFood,
    required this.displayFood,
    this.subtitle,
    this.isSecondary = false,
  });

  final TimeSlotAssignment assignment;
  final FoodItemData sourceFood;
  final FoodItemData displayFood;
  final String? subtitle;
  final bool isSecondary;

  _SlotFoodEntry copyWith({
    TimeSlotAssignment? assignment,
    FoodItemData? sourceFood,
    FoodItemData? displayFood,
    String? subtitle,
    bool? isSecondary,
  }) {
    return _SlotFoodEntry(
      assignment: assignment ?? this.assignment,
      sourceFood: sourceFood ?? this.sourceFood,
      displayFood: displayFood ?? this.displayFood,
      subtitle: subtitle ?? this.subtitle,
      isSecondary: isSecondary ?? this.isSecondary,
    );
  }
}
