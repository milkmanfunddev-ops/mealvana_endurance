import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../domain/event_subtype.dart';

/// Kyle's Event Subtype Dropdown for race distances
///
/// Custom styled dropdown matching Kyle's design system with Blackberry/Cream theme.
/// Uses Font Awesome icons and follows 15px border radius standard.
class EventSubtypeDropdown extends StatelessWidget {
  const EventSubtypeDropdown({
    super.key,
    required this.sportCategory,
    required this.selectedSubtype,
    required this.onSubtypeChanged,
  });

  final ActivityType sportCategory;
  final EventSubtype? selectedSubtype;
  final ValueChanged<EventSubtype> onSubtypeChanged;

  @override
  Widget build(BuildContext context) {
    final subtypes = EventSubtype.getSubtypesForEventType(
      sportCategory.dbValue,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const ValueKey('event_create.race_distance_heading'),
          'Race Distance',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EventSubtype>(
          key: const ValueKey('event_create.race_distance_dropdown'),
          initialValue: selectedSubtype,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.electrolyte, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.dragonfruit),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.dragonfruit, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            // prefixIcon: FaIcon(
            //   _getIconForCategory(sportCategory),
            //   size: AppIconSizes.sm,
            //   color: AppColors.blackberry,
            // ),
          ),
          isExpanded: true,
          style: AppTextStyles.inputText.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: Theme.of(context).colorScheme.surface,
          items: subtypes.map((subtype) {
            return DropdownMenuItem<EventSubtype>(
              key: ValueKey(
                'event_create.race_distance_option_${subtype.name}',
              ),
              value: subtype,
              child: Text(
                subtype.displayName,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
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

  IconData _getIconForCategory(ActivityType category) {
    switch (category) {
      case ActivityType.running:
        return FontAwesomeIcons.personRunning.data;
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking.data;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming.data;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return FontAwesomeIcons.trophy.data;
      case ActivityType.brick:
        return FontAwesomeIcons.link.data; // Chain link icon for brick workouts
    }
  }
}
