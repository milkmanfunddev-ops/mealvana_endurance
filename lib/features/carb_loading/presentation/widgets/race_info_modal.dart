import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/shared/widgets/secondary_button.dart';
import '../../domain/carb_loading_plan_simple.dart';

/// Modal for collecting race information when creating carb loading plan
class RaceInfoModal extends StatefulWidget {
  final Function(DateTime raceDate, RaceDistance raceDistance, TrainingVolume trainingVolume) onCreatePlan;
  final DateTime? initialRaceDate;
  final RaceDistance? initialRaceDistance;
  final TrainingVolume? initialTrainingVolume;
  final bool isEditing;

  const RaceInfoModal({
    super.key,
    required this.onCreatePlan,
    this.initialRaceDate,
    this.initialRaceDistance,
    this.initialTrainingVolume,
    this.isEditing = false,
  });

  @override
  State<RaceInfoModal> createState() => _RaceInfoModalState();
}

class _RaceInfoModalState extends State<RaceInfoModal> {
  DateTime? _selectedDate;
  RaceDistance _selectedDistance = RaceDistance.marathon;
  TrainingVolume _selectedTrainingVolume = TrainingVolume.moderate;

  final _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialRaceDate;
    _selectedDistance = widget.initialRaceDistance ?? RaceDistance.marathon;
    _selectedTrainingVolume = widget.initialTrainingVolume ?? TrainingVolume.moderate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              widget.isEditing ? 'Edit Race Information' : 'Race Information',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isEditing
                ? 'Update your race information to adjust your carb loading plan.'
                : 'Tell us about your upcoming race to create a personalized carb loading plan.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 24),

            // Race Distance Selection
            Text(
              'Race Distance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RaceDistance>(
                  value: _selectedDistance,
                  isExpanded: true,
                  items: RaceDistance.values.map((distance) {
                    return DropdownMenuItem<RaceDistance>(
                      value: distance,
                      child: Text(distance.displayName),
                    );
                  }).toList(),
                  onChanged: (distance) {
                    if (distance != null) {
                      setState(() {
                        _selectedDistance = distance;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Training Volume Selection
            Text(
              'Training Volume',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<TrainingVolume>(
                  value: _selectedTrainingVolume,
                  isExpanded: true,
                  items: TrainingVolume.values.map((volume) {
                    return DropdownMenuItem<TrainingVolume>(
                      value: volume,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(volume.displayName),
                          Text(
                            volume.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (volume) {
                    if (volume != null) {
                      setState(() {
                        _selectedTrainingVolume = volume;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Race Date Selection
            Text(
              'Race Date',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showDatePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedDate != null
                          ? _dateFormat.format(_selectedDate!)
                          : 'Select race date',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _selectedDate != null
                            ? Colors.black
                            : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Helper text
            if (_selectedDate != null) ...[
              const SizedBox(height: 8),
              Text(
                _getHelperText(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _getHelperTextColor(),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: () => Navigator.of(context).pop(),
                    text: 'Cancel',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryButton(
                    onPressed: _selectedDate != null ? _createPlan : null,
                    text: widget.isEditing ? 'Update Plan' : 'Create Plan',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDatePicker() async {
    final initialDate = _selectedDate ?? DateTime.now().add(const Duration(days: 14));
    final firstDate = DateTime.now().add(const Duration(days: 3)); // Min 3 days from now
    final lastDate = DateTime.now().add(const Duration(days: 365)); // Max 1 year from now

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF4285F4),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
      });
    }
  }

  String _getHelperText() {
    if (_selectedDate == null) return '';

    final daysUntilRace = _selectedDate!.difference(DateTime.now()).inDays;
    final carbLoadingStartDate = _selectedDate!.subtract(const Duration(days: 2));
    final daysUntilCarbLoading = carbLoadingStartDate.difference(DateTime.now()).inDays;

    if (daysUntilRace < 3) {
      return 'Race date should be at least 3 days from now for proper carb loading';
    } else if (daysUntilCarbLoading <= 0) {
      return 'Carb loading should start now (2 days before race)';
    } else {
      return 'Carb loading starts in $daysUntilCarbLoading days (${_dateFormat.format(carbLoadingStartDate)})';
    }
  }

  Color _getHelperTextColor() {
    if (_selectedDate == null) return Colors.grey;

    final daysUntilRace = _selectedDate!.difference(DateTime.now()).inDays;

    if (daysUntilRace < 3) {
      return Colors.red;
    } else {
      return const Color(0xFF4285F4);
    }
  }

  void _createPlan() {
    if (_selectedDate != null) {
      Navigator.of(context).pop();
      widget.onCreatePlan(_selectedDate!, _selectedDistance, _selectedTrainingVolume);
    }
  }
}