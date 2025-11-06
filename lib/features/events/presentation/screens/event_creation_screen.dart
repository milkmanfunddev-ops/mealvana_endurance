import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:location_iq/location_iq.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../../calendar/domain/event.dart';
import '../../../calendar/domain/event_subtype.dart';
import '../../../calendar/presentation/providers/calendar_controller.dart';
import '../../../calendar/presentation/widgets/sport_category_selector.dart';
import '../../../calendar/presentation/widgets/event_subtype_dropdown.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/utils/location_formatter.dart';
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
  EventType _selectedSportCategory = EventType.running;
  EventSubtype? _selectedSubtype;
  final _eventNameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  final _goalHoursController = TextEditingController();
  final _goalMinutesController = TextEditingController();
  final _registrationUrlController = TextEditingController();
  final _bibNumberController = TextEditingController();

  // Location search state
  final _locationFocusNode = FocusNode();
  List<LocationIQAutocompleteResult> _locationSearchResults = [];
  bool _isSearchingLocation = false;
  bool _isSelectingLocation = false; // Flag to prevent search during selection
  Timer? _locationSearchDebounce;

  @override
  void initState() {
    super.initState();
    // Set default subtype for running (Half Marathon)
    _selectedSubtype = EventSubtype.runningEvents.firstWhere(
      (subtype) => subtype.name == 'half_marathon',
    );

    // Add listener to location text field for autocomplete
    _locationController.addListener(_onLocationTextChanged);

    // Add focus listener to close dropdown when field loses focus
    _locationFocusNode.addListener(_onLocationFocusChanged);
  }

  /// Called when sport category changes - reset subtype to first option
  void _onSportCategoryChanged(EventType newCategory) {
    setState(() {
      _selectedSportCategory = newCategory;
      // Reset subtype to first option of the new category
      final subtypes = EventSubtype.getSubtypesForEventType(newCategory.dbValue);
      _selectedSubtype = subtypes.isNotEmpty ? subtypes.first : null;
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

  @override
  void dispose() {
    _locationController.removeListener(_onLocationTextChanged);
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _eventNameController.dispose();
    _locationController.dispose();
    _goalHoursController.dispose();
    _goalMinutesController.dispose();
    _registrationUrlController.dispose();
    _bibNumberController.dispose();
    _locationFocusNode.dispose();
    _locationSearchDebounce?.cancel();
    super.dispose();
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

    // Ensure subtype is selected
    if (_selectedSubtype == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a race distance'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
    // Note: Only calculate pace for single-sport running/cycling events
    double? goalPaceMinutesPerMile;
    if (goalTimeMinutes != null && _selectedSubtype!.distanceMiles != null) {
      final distanceMiles = _selectedSubtype!.distanceMiles!;
      if (distanceMiles > 0) {
        goalPaceMinutesPerMile = goalTimeMinutes / distanceMiles;
      }
    }

    try {
      // Create the event without creating an activity
      await ref.read(calendarControllerProvider.notifier).createEvent(
        activityId: null, // No activity yet
        eventType: _selectedSportCategory,
        eventSubtype: _selectedSubtype!.name,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // Sport Category Selection
              SportCategorySelector(
                selectedCategory: _selectedSportCategory,
                onCategoryChanged: _onSportCategoryChanged,
              ),

              const SizedBox(height: 24),

              // Event Subtype Selection (Race Distance)
              EventSubtypeDropdown(
                sportCategory: _selectedSportCategory,
                selectedSubtype: _selectedSubtype,
                onSubtypeChanged: (subtype) {
                  setState(() {
                    _selectedSubtype = subtype;
                  });
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
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.location_on),
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
    ),
    );
  }

}
