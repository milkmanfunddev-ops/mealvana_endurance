import 'package:flutter/material.dart';

import '../../domain/meal_slot.dart';
import 'slot_palette.dart';

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
        final color = slotColor(slot);
        return ChoiceChip(
          key: ValueKey('slot_chip.${slot.name}'),
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
