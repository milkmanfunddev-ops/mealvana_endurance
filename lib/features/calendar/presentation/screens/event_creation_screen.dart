import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/event.dart';
import '../providers/calendar_controller.dart';
import '../../../../shared/providers/device_id_provider.dart';
import '../../domain/activity.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Event Creation Screen for creating race events.
///
/// Full screen form (NOT a dialog) that collects:
/// - Event type (Marathon, Half Marathon, 10K, etc.)
/// - Event name
/// - Location
/// - Date and time
/// - Goal time
/// - Registration details (optional)
///
/// CRITICAL: NO carb loading configuration here.
/// Carb loading is configured separately from the Event Detail Screen.
class EventCreationScreen extends ConsumerStatefulWidget {
  const EventCreationScreen({super.key});

  @override
  ConsumerState<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends ConsumerState<EventCreationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form fields
  EventType _selectedEventType = EventType.halfMarathon;
  final _eventNameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  final _goalHoursController = TextEditingController();
  final _goalMinutesController = TextEditingController();
  final _registrationUrlController = TextEditingController();
  final _bibNumberController = TextEditingController();

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _goalHoursController.dispose();
    _goalMinutesController.dispose();
    _registrationUrlController.dispose();
    _bibNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleCreateEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Get device ID for user identification
    final deviceId = await ref.read(deviceIdProvider.future);

    // Combine date and time
    final scheduledDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Calculate goal time in minutes
    int? goalTimeMinutes;
    if (_goalHoursController.text.isNotEmpty || _goalMinutesController.text.isNotEmpty) {
      final hours = int.tryParse(_goalHoursController.text) ?? 0;
      final minutes = int.tryParse(_goalMinutesController.text) ?? 0;
      goalTimeMinutes = (hours * 60) + minutes;
    }

    // Calculate goal pace if goal time is provided
    double? goalPaceMinutesPerMile;
    if (goalTimeMinutes != null) {
      final distanceMiles = _getEventDistanceMiles(_selectedEventType);
      if (distanceMiles > 0) {
        goalPaceMinutesPerMile = goalTimeMinutes / distanceMiles;
      }
    }

    try {
      // Create the event without creating an activity
      await ref.read(calendarControllerProvider.notifier).createEvent(
        activityId: null, // No activity yet
        eventType: _selectedEventType,
        eventName: _eventNameController.text.trim(),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        registrationUrl: _registrationUrlController.text.trim().isEmpty
            ? null
            : _registrationUrlController.text.trim(),
        startTime: scheduledDateTime.toIso8601String(), // Store event date/time
        goalTimeMinutes: goalTimeMinutes,
        goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        hasCarbLoading: false, // Will be set separately
      );

      if (mounted) {
        // Pop back and let the calling screen show the success message
        Navigator.of(context).pop({
          'success': true,
          'eventName': _eventNameController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getEventDistanceMiles(EventType eventType) {
    switch (eventType) {
      case EventType.marathon:
        return 26.2;
      case EventType.halfMarathon:
        return 13.1;
      case EventType.tenK:
        return 6.2;
      case EventType.fiveK:
        return 3.1;
      case EventType.ultra50K:
        return 31.0;
      case EventType.ultra50M:
        return 50.0;
      case EventType.ultra100K:
        return 62.0;
      case EventType.ultra100M:
        return 100.0;
      case EventType.custom:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        title: const Text('New Event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Type Selection
              Text(
                'Event Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EventType>(
                value: _selectedEventType,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: EventType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(_getEventTypeDisplayName(type)),
                  );
                }).toList(),
                onChanged: (EventType? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedEventType = newValue;
                    });
                  }
                },
              ),

              const SizedBox(height: 24),

              // Event Name
              TextFormField(
                controller: _eventNameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name',
                  hintText: 'e.g., NYC Marathon 2025',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an event name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  hintText: 'e.g., New York, NY',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 24),

              // Date
              Text(
                'Event Date',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
              ),

              const SizedBox(height: 24),

              // Time
              Text(
                'Start Time',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectTime,
                icon: const Icon(Icons.access_time),
                label: Text(_selectedTime.format(context)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                ),
              ),

              const SizedBox(height: 24),

              // Goal Time
              Text(
                'Goal Time (optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _goalHoursController,
                      decoration: const InputDecoration(
                        labelText: 'Hours',
                        border: OutlineInputBorder(),
                        suffixText: 'h',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _goalMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        border: OutlineInputBorder(),
                        suffixText: 'm',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final minutes = int.tryParse(value);
                          if (minutes == null || minutes < 0 || minutes >= 60) {
                            return 'Must be 0-59';
                          }
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Advanced Section
              ExpansionTile(
                title: const Text('Additional Details (Optional)'),
                children: [
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _registrationUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Registration URL',
                      hintText: 'https://...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bibNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Bib Number',
                      hintText: 'e.g., 12345',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.confirmation_number),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Create Button
              PrimaryButton(
                onPressed: _handleCreateEvent,
                text: 'Create Event',
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getEventTypeDisplayName(EventType type) {
    switch (type) {
      case EventType.marathon:
        return 'Marathon (26.2 mi)';
      case EventType.halfMarathon:
        return 'Half Marathon (13.1 mi)';
      case EventType.tenK:
        return '10K (6.2 mi)';
      case EventType.fiveK:
        return '5K (3.1 mi)';
      case EventType.ultra50K:
        return 'Ultra 50K (31 mi)';
      case EventType.ultra50M:
        return 'Ultra 50 Mile';
      case EventType.ultra100K:
        return 'Ultra 100K (62 mi)';
      case EventType.ultra100M:
        return 'Ultra 100 Mile';
      case EventType.custom:
        return 'Custom Event';
    }
  }
}
