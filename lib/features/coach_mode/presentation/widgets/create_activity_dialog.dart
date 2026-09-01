import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';

/// Dialog result for creating an activity for an athlete
class CreateActivityResult {
  final String title;
  final String activityType;
  final DateTime scheduledDateTime;
  final int? durationMinutes;
  final double? distanceMiles;

  const CreateActivityResult({
    required this.title,
    required this.activityType,
    required this.scheduledDateTime,
    this.durationMinutes,
    this.distanceMiles,
  });
}

/// Dialog for coach to create an activity for an athlete
class CreateActivityDialog extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const CreateActivityDialog({super.key, this.initialDate});

  @override
  ConsumerState<CreateActivityDialog> createState() =>
      _CreateActivityDialogState();
}

class _CreateActivityDialogState extends ConsumerState<CreateActivityDialog> {
  final _titleController = TextEditingController();
  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  late DateTime _scheduledDate;
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 7, minute: 0);
  String _activityType = 'running';

  @override
  void initState() {
    super.initState();
    _scheduledDate = widget.initialDate ?? DateTime.now();
  }

  /// The coach's own preference — `unitSystemProvider` resolves to the
  /// logged-in user, not the athlete the activity is being created for.
  bool get _useMetric =>
      (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
      UnitSystem.metric;

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackberry,
      title: const Text(
        'Create Activity',
        style: TextStyle(color: AppColors.cream, fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField('Title', _titleController, hint: 'e.g., Long Run'),
              const SizedBox(height: 12),
              _buildActivityTypeDropdown(),
              const SizedBox(height: 12),
              _buildDatePicker(),
              const SizedBox(height: 12),
              _buildTimePicker(),
              const SizedBox(height: 12),
              _buildField(
                'Duration (min)',
                _durationController,
                keyboardType: TextInputType.number,
                hint: 'e.g., 60',
              ),
              const SizedBox(height: 12),
              _buildField(
                _useMetric ? 'Distance (km)' : 'Distance (mi)',
                _distanceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                hint: 'e.g., 10.0',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textDarkSecondary),
          ),
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
        hintStyle: TextStyle(
          color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
        ),
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

  Widget _buildActivityTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.blackberryDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activityType,
          isExpanded: true,
          dropdownColor: AppColors.blackberry,
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
          items: ActivityType.values
              .where((t) => t != ActivityType.brick)
              .map(
                (t) => DropdownMenuItem(
                  value: t.dbValue,
                  child: Text(t.displayName),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _activityType = val);
          },
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _scheduledDate,
          firstDate: DateTime(2020),
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
        if (picked != null) setState(() => _scheduledDate = picked);
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
          'Date: ${_scheduledDate.month}/${_scheduledDate.day}/${_scheduledDate.year}',
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _scheduledTime,
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
        if (picked != null) setState(() => _scheduledTime = picked);
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
          'Time: ${_scheduledTime.format(context)}',
          style: const TextStyle(color: AppColors.cream, fontSize: 14),
        ),
      ),
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final scheduledDateTime = DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );

    Navigator.of(context).pop(
      CreateActivityResult(
        title: title,
        activityType: _activityType,
        scheduledDateTime: scheduledDateTime,
        durationMinutes: int.tryParse(_durationController.text),
        // The field is labelled in the coach's units; the result is always
        // miles, matching Activity.distanceMiles.
        distanceMiles: _distanceEnteredAsMiles(),
      ),
    );
  }

  double? _distanceEnteredAsMiles() {
    final entered = double.tryParse(_distanceController.text);
    if (entered == null) return null;
    return _useMetric ? entered * UnitFormatter.kMilePerKm : entered;
  }
}
