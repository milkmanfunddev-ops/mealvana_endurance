import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/activity.dart';
import '../../domain/event.dart';
import '../providers/calendar_controller.dart';

/// Event Edit Screen for modifying event and activity details.
class EventEditScreen extends ConsumerStatefulWidget {
  final Activity activity;
  final Event event;

  const EventEditScreen({
    super.key,
    required this.activity,
    required this.event,
  });

  @override
  ConsumerState<EventEditScreen> createState() => _EventEditScreenState();
}

class _EventEditScreenState extends ConsumerState<EventEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _eventNameController;
  late TextEditingController _locationController;
  late TextEditingController _bibNumberController;
  late TextEditingController _distanceController;
  late TextEditingController _paceController;
  late TextEditingController _notesController;

  // State
  late DateTime _scheduledDateTime;
  late EventType _selectedEventType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values
    _eventNameController = TextEditingController(text: widget.event.eventName);
    _locationController = TextEditingController(text: widget.event.location);
    _bibNumberController = TextEditingController(text: widget.event.bibNumber);
    _distanceController = TextEditingController(
      text: widget.activity.distanceMiles?.toString() ?? '',
    );
    _paceController = TextEditingController(
      text: widget.activity.paceTargetMinutesPerMile?.toStringAsFixed(2) ?? '',
    );
    _notesController = TextEditingController(text: widget.activity.notes);

    _scheduledDateTime = widget.activity.scheduledDateTime;
    _selectedEventType = widget.event.eventType;
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _bibNumberController.dispose();
    _distanceController.dispose();
    _paceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary600,
              onPrimary: AppTheme.baseWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primary600,
              onPrimary: AppTheme.baseWhite,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

    setState(() {
      _scheduledDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final calendarController = ref.read(calendarControllerProvider.notifier);

      // Parse numeric fields
      final distance = double.tryParse(_distanceController.text);
      final pace = double.tryParse(_paceController.text);

      // Update activity
      final updatedActivity = widget.activity.copyWith(
        title: _eventNameController.text.isNotEmpty
            ? _eventNameController.text
            : widget.activity.title,
        scheduledDateTime: _scheduledDateTime,
        distanceMiles: distance,
        paceTargetMinutesPerMile: pace,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await calendarController.updateActivity(updatedActivity);

      // Update event
      final updatedEvent = widget.event.copyWith(
        eventType: _selectedEventType,
        eventName: _eventNameController.text.isNotEmpty
            ? _eventNameController.text
            : null,
        location: _locationController.text.isNotEmpty
            ? _locationController.text
            : null,
        bibNumber: _bibNumberController.text.isNotEmpty
            ? _bibNumberController.text
            : null,
      );

      await calendarController.updateEvent(updatedEvent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        title: const Text('Edit Event'),
        leading: CustomAppBarBackButton(),
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Event Details Section
            _buildSectionHeader('Event Details'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _eventNameController,
              label: 'Event Name',
              icon: Icons.event,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an event name';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildEventTypeDropdown(),

            const SizedBox(height: 16),

            _buildDateTimeSelector(),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _locationController,
              label: 'Location (optional)',
              icon: Icons.location_on,
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _bibNumberController,
              label: 'Bib Number (optional)',
              icon: Icons.confirmation_number,
            ),

            const SizedBox(height: 32),

            // Activity Details Section
            _buildSectionHeader('Activity Details'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _distanceController,
              label: 'Distance (miles)',
              icon: Icons.straighten,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a distance';
                }
                final distance = double.tryParse(value);
                if (distance == null || distance <= 0) {
                  return 'Please enter a valid distance';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _paceController,
              label: 'Target Pace (min/mile)',
              icon: Icons.speed,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final pace = double.tryParse(value);
                  if (pace == null || pace <= 0) {
                    return 'Please enter a valid pace';
                  }
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _notesController,
              label: 'Notes (optional)',
              icon: Icons.notes,
              maxLines: 3,
            ),

            const SizedBox(height: 32),

            // Save Button
            PrimaryButton(
              onPressed: _isSaving ? null : _saveChanges,
              text: _isSaving ? 'Saving...' : 'Save Changes',
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.primary900,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primary600, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.baseWhite,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
    );
  }

  Widget _buildEventTypeDropdown() {
    return DropdownButtonFormField<EventType>(
      initialValue: _selectedEventType,
      decoration: InputDecoration(
        labelText: 'Event Type',
        prefixIcon: Icon(Icons.category, color: AppTheme.primary600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primary600, width: 2),
        ),
        filled: true,
        fillColor: AppTheme.baseWhite,
      ),
      items: EventType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(_formatEventType(type)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedEventType = value);
        }
      },
    );
  }

  Widget _buildDateTimeSelector() {
    return InkWell(
      onTap: _selectDateTime,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppTheme.primary600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event Date & Time',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(_scheduledDateTime),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Icon(Icons.edit, color: Colors.grey[600], size: 20),
          ],
        ),
      ),
    );
  }

  /// Format event type - uses the extension method for display name
  String _formatEventType(EventType type) {
    return type.displayName;
  }
}
