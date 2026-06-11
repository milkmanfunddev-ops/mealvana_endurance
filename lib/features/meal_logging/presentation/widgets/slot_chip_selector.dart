import 'package:flutter/material.dart';

import '../../domain/meal_slot.dart';

Color _slotColor(MealSlot slot) {
  switch (slot) {
    case MealSlot.breakfast:
      return const Color(0xFFFF9500); // orange
    case MealSlot.lunch:
      return const Color(0xFF00C896); // electrolyte green
    case MealSlot.dinner:
      return const Color(0xFF6B4FA0); // blackberry purple
    case MealSlot.snack:
      return const Color(0xFFFF2D55); // dragonfruit
  }
}

/// A row of choice chips that lets the user select a [MealSlot].
class SlotChipSelector extends StatelessWidget {
  const SlotChipSelector({
    super.key,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final MealSlot selectedSlot;
  final ValueChanged<MealSlot> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: MealSlot.values.map((slot) {
        final isSelected = slot == selectedSlot;
        final color = _slotColor(slot);
        return ChoiceChip(
          label: Text(slot.label),
          selected: isSelected,
          onSelected: (_) => onSlotSelected(slot),
          selectedColor: color.withValues(alpha: 0.85),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : null,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(),
    );
  }
}
