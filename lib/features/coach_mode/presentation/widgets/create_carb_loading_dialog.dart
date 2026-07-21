import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../carb_loading/domain/carb_loading_plan_simple.dart';
import '../../../events/domain/event.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';

/// Dialog for coaches to create a carb loading plan for an athlete.
/// Allows event selection, protocol days, race date, and body weight input.
class CreateCarbLoadingDialog extends ConsumerStatefulWidget {
  final List<Event> events;
  final double? athleteWeightPounds;

  const CreateCarbLoadingDialog({
    super.key,
    required this.events,
    this.athleteWeightPounds,
  });

  @override
  ConsumerState<CreateCarbLoadingDialog> createState() =>
      _CreateCarbLoadingDialogState();
}

class _CreateCarbLoadingDialogState
    extends ConsumerState<CreateCarbLoadingDialog> {
  Event? _selectedEvent;
  int _protocolDays = 3;
  DateTime _raceDate = DateTime.now().add(const Duration(days: 14));
  // Imperial (canonical) and metric weight controllers — only the one
  // matching the coach's own unit preference (unitSystemProvider) is
  // shown/edited; the submitted value is always converted back to
  // canonical pounds.
  late TextEditingController _weightLbsCtl;
  late TextEditingController _weightKgCtl;

  @override
  void initState() {
    super.initState();
    _weightLbsCtl = TextEditingController(
      text: widget.athleteWeightPounds?.toStringAsFixed(0) ?? '',
    );
    _weightKgCtl = TextEditingController(
      text: widget.athleteWeightPounds != null
          ? UnitFormatter.poundsToKg(
              widget.athleteWeightPounds!,
            ).toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _weightLbsCtl.dispose();
    _weightKgCtl.dispose();
    super.dispose();
  }

  bool get _useMetric =>
      (ref.read(unitSystemProvider).value ?? UnitSystem.imperial) ==
      UnitSystem.metric;

  TextEditingController get _activeWeightCtl =>
      _useMetric ? _weightKgCtl : _weightLbsCtl;

  void _onEventSelected(Event? event) {
    setState(() {
      _selectedEvent = event;
      if (event?.eventDate != null) {
        _raceDate = event!.eventDate!;
      }
    });
  }

  Future<void> _pickRaceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _raceDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.electrolyte,
              onPrimary: AppColors.blackberry,
              surface: AppColors.blackberry,
              onSurface: AppColors.cream,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _raceDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Coach creates a plan for an athlete using the COACH's own unit
    // preference (unitSystemProvider resolves to the logged-in user).
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;
    final weightCtl = useMetric ? _weightKgCtl : _weightLbsCtl;

    final upcomingEvents =
        widget.events
            .where(
              (e) =>
                  e.eventDate != null && e.eventDate!.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));

    return AlertDialog(
      backgroundColor: AppColors.blackberry,
      title: const Text(
        'Create Carb Loading Plan',
        style: TextStyle(color: AppColors.cream, fontSize: 18),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event selection (optional)
              const Text(
                'Link to Event (optional)',
                style: TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              DropdownButtonFormField<Event?>(
                value: _selectedEvent,
                dropdownColor: AppColors.blackberryDark,
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'No event linked',
                  hintStyle: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.blackberryDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.blackberryLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.blackberryLight,
                    ),
                  ),
                ),
                items: [
                  const DropdownMenuItem<Event?>(
                    value: null,
                    child: Text('None'),
                  ),
                  ...upcomingEvents.map(
                    (event) => DropdownMenuItem<Event?>(
                      value: event,
                      child: Text(
                        '${event.eventName ?? "Event"} - ${event.eventDate!.month}/${event.eventDate!.day}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: _onEventSelected,
              ),

              const SizedBox(height: 16),

              // Race/Target date
              const Text(
                'Race / Target Date',
                style: TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: _pickRaceDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blackberryDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blackberryLight),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_raceDate.month}/${_raceDate.day}/${_raceDate.year}',
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.electrolyte,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Protocol days
              const Text(
                'Protocol Duration',
                style: TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildProtocolOption(2, '2 Days'),
                  const SizedBox(width: 8),
                  _buildProtocolOption(3, '3 Days'),
                ],
              ),

              const SizedBox(height: 16),

              // Body weight
              Text(
                useMetric ? 'Body Weight (kg)' : 'Body Weight (lbs)',
                style: const TextStyle(
                  color: AppColors.textDarkSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: weightCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(color: AppColors.cream, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter weight',
                  hintStyle: TextStyle(
                    color: AppColors.textDarkSecondary.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.blackberryDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.blackberryLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.blackberryLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.electrolyte),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textDarkSecondary,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canCreate() ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.electrolyte,
            foregroundColor: AppColors.blackberry,
          ),
          child: const Text('Create Plan'),
        ),
      ],
    );
  }

  bool _canCreate() {
    final weight = double.tryParse(_activeWeightCtl.text.trim());
    return weight != null && weight > 0;
  }

  void _submit() {
    final entered = double.tryParse(_activeWeightCtl.text.trim());
    if (entered == null || entered <= 0) return;
    // Persist canonical pounds regardless of the unit the coach entered.
    final weightPounds = _useMetric
        ? UnitFormatter.kgToPounds(entered)
        : entered;

    Navigator.of(context).pop({
      'eventId': _selectedEvent?.id,
      'protocolDays': _protocolDays,
      'raceDate': _raceDate,
      'bodyWeightPounds': weightPounds,
    });
  }

  Widget _buildProtocolOption(int days, String label) {
    final isSelected = _protocolDays == days;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _protocolDays = days),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.electrolyte.withValues(alpha: 0.15)
                : AppColors.blackberryDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.electrolyte
                  : AppColors.blackberryLight,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.electrolyte
                    : AppColors.textDarkSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
