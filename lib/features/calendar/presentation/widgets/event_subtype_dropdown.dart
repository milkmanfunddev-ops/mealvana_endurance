import 'package:flutter/material.dart';
import '../../domain/event.dart';
import '../../domain/event_subtype.dart';

/// A dropdown widget for selecting specific race distances/types
///
/// Displays the appropriate race options based on the selected sport category.
/// Shows formatted labels with distances and organizes options clearly.
class EventSubtypeDropdown extends StatelessWidget {
  const EventSubtypeDropdown({
    super.key,
    required this.sportCategory,
    required this.selectedSubtype,
    required this.onSubtypeChanged,
  });

  final EventType sportCategory;
  final EventSubtype? selectedSubtype;
  final ValueChanged<EventSubtype> onSubtypeChanged;

  @override
  Widget build(BuildContext context) {
    final subtypes = EventSubtype.getSubtypesForEventType(sportCategory.dbValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Race Distance',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EventSubtype>(
          value: selectedSubtype,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            prefixIcon: Icon(
              _getIconForCategory(sportCategory),
              color: Colors.grey.shade600,
            ),
          ),
          isExpanded: true,
          items: subtypes.map((subtype) {
            return DropdownMenuItem<EventSubtype>(
              value: subtype,
              child: Text(
                subtype.displayName,
                style: const TextStyle(fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: (EventSubtype? newValue) {
            if (newValue != null) {
              onSubtypeChanged(newValue);
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a race distance';
            }
            return null;
          },
        ),
      ],
    );
  }

  IconData _getIconForCategory(EventType category) {
    switch (category) {
      case EventType.running:
        return Icons.directions_run;
      case EventType.cycling:
        return Icons.directions_bike;
      case EventType.swimming:
        return Icons.pool;
      case EventType.triathlon:
        return Icons.flash_on;
      case EventType.duathlon:
        return Icons.sync_alt;
      case EventType.multisport:
        return Icons.sports_score;
    }
  }
}
