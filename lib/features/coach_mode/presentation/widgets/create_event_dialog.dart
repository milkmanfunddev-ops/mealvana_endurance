import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/domain/activity_type.dart';

/// Dialog result for creating an event for an athlete
class CreateEventResult {
  final String eventName;
  final String eventType;
  final String? eventSubtype;
  final DateTime eventDate;
  final String? location;
  final int? goalTimeMinutes;

  const CreateEventResult({
    required this.eventName,
    required this.eventType,
    required this.eventDate,
    this.eventSubtype,
    this.location,
    this.goalTimeMinutes,
  });
}

/// Event subtypes for running events
const _runningSubtypes = [
  '5k',
  '10k',
  'half_marathon',
  'marathon',
  '50k',
  '50_mile',
  '100k',
  '100_mile',
  'other',
];

String _formatSubtype(String subtype) {
  switch (subtype) {
    case '5k':
      return '5K';
    case '10k':
      return '10K';
    case 'half_marathon':
      return 'Half Marathon';
    case 'marathon':
      return 'Marathon';
    case '50k':
      return '50K';
    case '50_mile':
      return '50 Mile';
    case '100k':
      return '100K';
    case '100_mile':
      return '100 Mile';
    case 'other':
      return 'Other';
    default:
      return subtype;
  }
}

/// Dialog for coach to create an event for an athlete
class CreateEventDialog extends StatefulWidget {
  const CreateEventDialog({super.key});

  @override
  State<CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<CreateEventDialog> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _goalTimeController = TextEditingController();
  DateTime _eventDate = DateTime.now().add(const Duration(days: 30));
  String _eventType = 'running';
  String? _eventSubtype;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _goalTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackberry,
      title: const Text(
        'Create Event',
        style: TextStyle(color: AppColors.cream, fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Event Name', _nameController,
                  hint: 'e.g., Boston Marathon'),
              const SizedBox(height: 12),
              _buildEventTypeDropdown(),
              const SizedBox(height: 12),
              if (_eventType == 'running') ...[
                _buildSubtypeDropdown(),
                const SizedBox(height: 12),
              ],
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildField('Location', _locationController,
                  hint: 'e.g., Boston, MA'),
              const SizedBox(height: 12),
              _buildField('Goal Time (min)', _goalTimeController,
                  keyboardType: TextInputType.number, hint: 'e.g., 240'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textDarkSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.electrolyte,
            foregroundColor: AppColors.blackberryDark,
          ),
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppColors.cream, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textDarkSecondary),
        hintStyle:
            TextStyle(color: AppColors.textDarkSecondary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: AppColors.blackberryDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blackberryLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.blackberryLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.electrolyte),
        ),
      ),
    );
  }

  Widget _buildEventTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.blackberryDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _eventType,
          isExpanded: true,
          dropdownColor: AppColors.blackberry,
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
          items: ActivityType.values
              .where((t) => t != ActivityType.brick)
              .map((t) => DropdownMenuItem(
                    value: t.dbValue,
                    child: Text(t.displayName),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _eventType = val;
                _eventSubtype = null;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubtypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.blackberryDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _eventSubtype,
          isExpanded: true,
          dropdownColor: AppColors.blackberry,
          hint: const Text('Distance',
              style: TextStyle(color: AppColors.textDarkSecondary)),
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
          items: _runningSubtypes
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(_formatSubtype(s)),
                  ))
              .toList(),
          onChanged: (val) => setState(() => _eventSubtype = val),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _eventDate,
          firstDate: DateTime.now(),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.electrolyte,
                  surface: AppColors.blackberry,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => _eventDate = picked);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.blackberryDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blackberryLight),
        ),
        child: Text(
          'Event Date: ${_eventDate.month}/${_eventDate.day}/${_eventDate.year}',
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.of(context).pop(CreateEventResult(
      eventName: name,
      eventType: _eventType,
      eventSubtype: _eventSubtype,
      eventDate: _eventDate,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      goalTimeMinutes: int.tryParse(_goalTimeController.text),
    ));
  }
}
