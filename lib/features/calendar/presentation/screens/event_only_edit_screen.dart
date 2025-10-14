import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/event.dart';
import '../providers/calendar_controller.dart';

/// Event-only Edit Screen for modifying event details (NOT activity details).
/// This screen allows editing event properties regardless of whether an activity exists.
class EventOnlyEditScreen extends ConsumerStatefulWidget {
  final Event event;

  const EventOnlyEditScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EventOnlyEditScreen> createState() => _EventOnlyEditScreenState();
}

class _EventOnlyEditScreenState extends ConsumerState<EventOnlyEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _eventNameController;
  late TextEditingController _locationController;
  late TextEditingController _bibNumberController;
  late TextEditingController _registrationUrlController;
  late TextEditingController _goalTimeHoursController;
  late TextEditingController _goalTimeMinutesController;
  late TextEditingController _goalPaceMinutesController;
  late TextEditingController _goalPaceSecondsController;

  // State
  late DateTime? _startTime;
  late EventType _selectedEventType;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values
    _eventNameController = TextEditingController(text: widget.event.eventName);
    _locationController = TextEditingController(text: widget.event.location);
    _bibNumberController = TextEditingController(text: widget.event.bibNumber);
    _registrationUrlController = TextEditingController(text: widget.event.registrationUrl);

    // Parse goal time (stored as total minutes)
    if (widget.event.goalTimeMinutes != null) {
      final hours = widget.event.goalTimeMinutes! ~/ 60;
      final minutes = widget.event.goalTimeMinutes! % 60;
      _goalTimeHoursController = TextEditingController(text: hours > 0 ? hours.toString() : '');
      _goalTimeMinutesController = TextEditingController(text: minutes > 0 ? minutes.toString() : '');
    } else {
      _goalTimeHoursController = TextEditingController();
      _goalTimeMinutesController = TextEditingController();
    }

    // Parse goal pace (stored as minutes per mile with decimal)
    if (widget.event.goalPaceMinutesPerMile != null) {
      final minutes = widget.event.goalPaceMinutesPerMile!.floor();
      final seconds = ((widget.event.goalPaceMinutesPerMile! - minutes) * 60).round();
      _goalPaceMinutesController = TextEditingController(text: minutes.toString());
      _goalPaceSecondsController = TextEditingController(text: seconds.toString());
    } else {
      _goalPaceMinutesController = TextEditingController();
      _goalPaceSecondsController = TextEditingController();
    }

    _startTime = widget.event.startTime != null ? DateTime.parse(widget.event.startTime!) : null;
    _selectedEventType = widget.event.eventType;
  }

  @override
  void dispose() {
    _eventNameController.dispose();
    _locationController.dispose();
    _bibNumberController.dispose();
    _registrationUrlController.dispose();
    _goalTimeHoursController.dispose();
    _goalTimeMinutesController.dispose();
    _goalPaceMinutesController.dispose();
    _goalPaceSecondsController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now().add(const Duration(days: 30)),
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
      initialTime: _startTime != null ? TimeOfDay.fromDateTime(_startTime!) : const TimeOfDay(hour: 8, minute: 0),
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
      _startTime = DateTime(
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

      // Parse goal time (convert to total minutes)
      int? goalTimeMinutes;
      final hours = int.tryParse(_goalTimeHoursController.text) ?? 0;
      final minutes = int.tryParse(_goalTimeMinutesController.text) ?? 0;
      if (hours > 0 || minutes > 0) {
        goalTimeMinutes = (hours * 60) + minutes;
      }

      // Parse goal pace (convert to minutes per mile with decimal)
      double? goalPaceMinutesPerMile;
      final paceMinutes = int.tryParse(_goalPaceMinutesController.text);
      final paceSeconds = int.tryParse(_goalPaceSecondsController.text) ?? 0;
      if (paceMinutes != null && paceMinutes > 0) {
        goalPaceMinutesPerMile = paceMinutes + (paceSeconds / 60.0);
      }

      // Update event
      final updatedEvent = widget.event.copyWith(
        eventType: _selectedEventType,
        eventName: _eventNameController.text.isNotEmpty ? _eventNameController.text : null,
        location: _locationController.text.isNotEmpty ? _locationController.text : null,
        bibNumber: _bibNumberController.text.isNotEmpty ? _bibNumberController.text : null,
        registrationUrl: _registrationUrlController.text.isNotEmpty ? _registrationUrlController.text : null,
        startTime: _startTime?.toIso8601String(),
        goalTimeMinutes: goalTimeMinutes,
        goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        updatedAt: DateTime.now(),
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
            // Basic Event Details Section
            _buildSectionHeader('Event Details'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _eventNameController,
              label: 'Event Name',
              icon: Icons.event,
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

            const SizedBox(height: 32),

            // Goals Section
            _buildSectionHeader('Goals'),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _goalTimeHoursController,
                    label: 'Hours',
                    icon: Icons.timer,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _goalTimeMinutesController,
                    label: 'Minutes',
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _goalPaceMinutesController,
                    label: 'Pace (min)',
                    icon: Icons.speed,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _goalPaceSecondsController,
                    label: 'Pace (sec)',
                    icon: Icons.speed_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Registration Section
            _buildSectionHeader('Registration'),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _bibNumberController,
              label: 'Bib Number (optional)',
              icon: Icons.confirmation_number,
            ),

            const SizedBox(height: 16),

            _buildTextField(
              controller: _registrationUrlController,
              label: 'Registration URL (optional)',
              icon: Icons.link,
              keyboardType: TextInputType.url,
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
      value: _selectedEventType,
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
                    _startTime != null
                        ? DateFormat('EEEE, MMM d, yyyy \'at\' h:mm a').format(_startTime!)
                        : 'Not set',
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

  String _formatEventType(EventType type) {
    switch (type) {
      case EventType.fiveK:
        return '5K';
      case EventType.tenK:
        return '10K';
      case EventType.halfMarathon:
        return 'Half Marathon';
      case EventType.marathon:
        return 'Marathon';
      case EventType.ultra50K:
        return 'Ultra 50K';
      case EventType.ultra50M:
        return 'Ultra 50M';
      case EventType.ultra100K:
        return 'Ultra 100K';
      case EventType.ultra100M:
        return 'Ultra 100M';
      case EventType.custom:
        return 'Custom Event';
    }
  }
}
