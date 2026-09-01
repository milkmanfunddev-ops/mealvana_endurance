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

/// A row of choice chips that lets the user select an optional [MealSlot],
/// including an explicit "Any time" chip that clears the selection.
///
/// Used wherever the build-a-meal redesign makes the meal category optional
/// (the draft editor, Edit Meal, and the AI review screen) — as opposed to
/// [SlotChipSelector], which is kept for the few flows that still want a
/// required, always-set slot (e.g. the legacy recipe/recent-saved pickers).
class OptionalSlotChipSelector extends StatelessWidget {
  const OptionalSlotChipSelector({
    super.key,
    required this.selectedSlot,
    required this.onSlotSelected,
  });

  final MealSlot? selectedSlot;
  final ValueChanged<MealSlot?> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        ChoiceChip(
          key: const ValueKey('slot_chip.any_time'),
          label: const Text('Any time'),
          selected: selectedSlot == null,
          onSelected: (_) => onSlotSelected(null),
          selectedColor: slotColor(null).withValues(alpha: 0.85),
          labelStyle: TextStyle(
            color: selectedSlot == null ? Colors.white : null,
            fontWeight: selectedSlot == null
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        ...MealSlot.values.map((slot) {
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
        }),
      ],
    );
  }
}
