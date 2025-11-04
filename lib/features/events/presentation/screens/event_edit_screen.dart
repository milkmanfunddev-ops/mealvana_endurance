import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:location_iq/location_iq.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../activities/domain/activity.dart';
import '../../domain/event.dart';
import '../../../activities/presentation/providers/activities_controller.dart';
import '../providers/events_controller.dart';

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

  // Location search state
  final _locationFocusNode = FocusNode();
  List<LocationIQAutocompleteResult> _locationSearchResults = [];
  bool _isSearchingLocation = false;
  bool _isSelectingLocation = false; // Flag to prevent search during selection
  Timer? _locationSearchDebounce;

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

    // Add listener to location text field for autocomplete
    _locationController.addListener(_onLocationTextChanged);

    // Add focus listener to close dropdown when field loses focus
    _locationFocusNode.addListener(_onLocationFocusChanged);
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationTextChanged);
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _eventNameController.dispose();
    _locationController.dispose();
    _bibNumberController.dispose();
    _distanceController.dispose();
    _paceController.dispose();
    _notesController.dispose();
    _locationFocusNode.dispose();
    _locationSearchDebounce?.cancel();
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

  /// Called when location field focus changes
  void _onLocationFocusChanged() {
    if (!_locationFocusNode.hasFocus) {
      // Field lost focus, close the dropdown
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      _locationSearchDebounce?.cancel();
    }
  }

  /// Called when location text changes - debounces search
  void _onLocationTextChanged() {
    // Skip if we're programmatically setting the text during selection
    if (_isSelectingLocation) {
      return;
    }

    // Cancel previous timer
    _locationSearchDebounce?.cancel();

    final query = _locationController.text.trim();

    // Clear results if query is empty
    if (query.isEmpty) {
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      return;
    }

    // Only search if query is at least 3 characters
    if (query.length < 3) {
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      return;
    }

    // Set loading state
    setState(() {
      _isSearchingLocation = true;
    });

    // Debounce the search by 500ms
    _locationSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocations(query);
    });
  }

  /// Search for locations using LocationIQ
  Future<void> _searchLocations(String query) async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final results = await locationService.searchLocations(query, limit: 5);

      if (mounted) {
        setState(() {
          _locationSearchResults = results;
          _isSearchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationSearchResults = [];
          _isSearchingLocation = false;
        });
        // Optionally show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching locations: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Called when user selects a location from search results
  void _selectLocation(LocationIQAutocompleteResult location) {
    // Set flag to prevent search during selection
    _isSelectingLocation = true;

    // Cancel any pending searches
    _locationSearchDebounce?.cancel();

    // Format location to show only city and state
    final formattedLocation = LocationFormatter.formatCityState(location);

    setState(() {
      _locationController.text = formattedLocation;
      _locationSearchResults = [];
      _isSearchingLocation = false;
    });

    // Unfocus the text field to dismiss keyboard and close dropdown
    _locationFocusNode.unfocus();

    // Reset the flag after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isSelectingLocation = false;
      }
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Parse numeric fields
      final distance = double.tryParse(_distanceController.text);
      final pace = double.tryParse(_paceController.text);

      // Update activity using ActivitiesController directly
      final updatedActivity = widget.activity.copyWith(
        title: _eventNameController.text.isNotEmpty
            ? _eventNameController.text
            : widget.activity.title,
        scheduledDateTime: _scheduledDateTime,
        distanceMiles: distance,
        paceTargetMinutesPerMile: pace,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      final activitiesController = ref.read(activitiesControllerProvider.notifier);
      await activitiesController.updateActivity(updatedActivity);

      // Update event using EventsController directly
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

      final eventsController = ref.read(eventsControllerProvider.notifier);
      await eventsController.updateEvent(updatedEvent);

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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard and close dropdown when tapping outside
          FocusScope.of(context).unfocus();
          setState(() {
            _locationSearchResults = [];
            _isSearchingLocation = false;
          });
          _locationSearchDebounce?.cancel();
        },
        child: Form(
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

            // Location with Autocomplete
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _locationController,
                  focusNode: _locationFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'e.g., New York, NY',
                    prefixIcon: Icon(Icons.location_on, color: AppTheme.primary600),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppTheme.primary600, width: 2),
                    ),
                    filled: true,
                    fillColor: AppTheme.baseWhite,
                    suffixIcon: _isSearchingLocation
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                // Location search results dropdown
                if (_locationSearchResults.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      // Absorb taps on the dropdown to prevent closing
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _locationSearchResults.length,
                        itemBuilder: (context, index) {
                          final location = _locationSearchResults[index];
                          final formattedLocation = LocationFormatter.formatCityState(location);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on, size: 20),
                            title: Text(
                              formattedLocation,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectLocation(location),
                          );
                        },
                      ),
                    ),
                  ),
              ],
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
