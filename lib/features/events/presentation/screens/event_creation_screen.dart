import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:location_iq/location_iq.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../calendar/domain/event_subtype.dart';
import '../../../calendar/presentation/widgets/sport_category_selector.dart';
import '../../../calendar/presentation/widgets/event_subtype_dropdown.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../domain/active_com_event.dart';
import '../../application/active_com_service.dart';
import '../providers/events_controller.dart';

/// Event Creation Screen for creating race events.
///
/// Updated with Kyle's Design System:
/// - AppColors for theme-aware colors
/// - AppTextStyles for typography
/// - BaseCard for consistent card styling
/// - KylePrimaryButton for actions
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
  ActivityType _selectedSportCategory = ActivityType.running;
  EventSubtype? _selectedSubtype;
  final _eventNameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  final _goalHoursController = TextEditingController();
  final _goalMinutesController = TextEditingController();
  final _registrationUrlController = TextEditingController();
  final _bibNumberController = TextEditingController();

  // Event name search state (Active.com)
  final _eventNameFocusNode = FocusNode();
  List<ActiveComEvent> _eventSearchResults = [];
  bool _isSearchingEvents = false;
  bool _isSelectingEvent = false; // Flag to prevent search during selection
  Timer? _eventSearchDebounce;

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

    // Add listener to event name field for Active.com autocomplete
    _eventNameController.addListener(_onEventNameTextChanged);
    _eventNameFocusNode.addListener(_onEventNameFocusChanged);

    // Add listener to location text field for autocomplete
    _locationController.addListener(_onLocationTextChanged);

    // Add focus listener to close dropdown when field loses focus
    _locationFocusNode.addListener(_onLocationFocusChanged);
  }

  /// Called when sport category changes - reset subtype to first option
  void _onSportCategoryChanged(ActivityType newCategory) {
    setState(() {
      _selectedSportCategory = newCategory;
      // Reset subtype to first option of the new category
      final subtypes = EventSubtype.getSubtypesForEventType(newCategory.dbValue);
      _selectedSubtype = subtypes.isNotEmpty ? subtypes.first : null;
    });
  }

  /// Called when event name field focus changes
  void _onEventNameFocusChanged() {
    if (!_eventNameFocusNode.hasFocus) {
      // Field lost focus, close the dropdown
      setState(() {
        _eventSearchResults = [];
        _isSearchingEvents = false;
      });
      _eventSearchDebounce?.cancel();
    }
  }

  /// Called when event name text changes - debounces search
  void _onEventNameTextChanged() {
    // Skip if we're programmatically setting the text during selection
    if (_isSelectingEvent) {
      return;
    }

    // Cancel previous timer
    _eventSearchDebounce?.cancel();

    final query = _eventNameController.text.trim();

    // Clear results if query is empty
    if (query.isEmpty) {
      setState(() {
        _eventSearchResults = [];
        _isSearchingEvents = false;
      });
      return;
    }

    // Only search if query is at least 3 characters
    if (query.length < 3) {
      setState(() {
        _eventSearchResults = [];
        _isSearchingEvents = false;
      });
      return;
    }

    // Set loading state
    setState(() {
      _isSearchingEvents = true;
    });

    // Debounce the search by 500ms
    _eventSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchActiveComEvents(query);
    });
  }

  /// Search for events using Active.com API
  Future<void> _searchActiveComEvents(String query) async {
    try {
      final activeComService = ref.read(activeComServiceProvider);
      final results = await activeComService.searchEvents(query);

      if (mounted) {
        setState(() {
          _eventSearchResults = results;
          _isSearchingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _eventSearchResults = [];
          _isSearchingEvents = false;
        });
        // Fail silently - user can still type manually
      }
    }
  }

  /// Called when user selects an event from Active.com search results
  void _selectActiveComEvent(ActiveComEvent event) {
    // Set flag to prevent search during selection
    _isSelectingEvent = true;

    // Cancel any pending searches
    _eventSearchDebounce?.cancel();

    setState(() {
      // Set event name
      _eventNameController.text = event.eventName;

      // Auto-fill location if available
      if (event.location != null && event.location!.isNotEmpty) {
        _locationController.text = event.location!;
      }

      // Auto-fill date and time if available
      if (event.eventDate != null) {
        _selectedDate = event.eventDate!;
      }
      if (event.startTime != null) {
        _selectedTime = TimeOfDay.fromDateTime(event.startTime!);
      }

      // Auto-fill registration URL if available
      if (event.registrationUrl != null && event.registrationUrl!.isNotEmpty) {
        _registrationUrlController.text = event.registrationUrl!;
      }

      // Auto-update sport type to match the event
      if (event.sportType != null) {
        _selectedSportCategory = event.sportType!;
        // Update subtype based on new sport type
        final subtypes = EventSubtype.getSubtypesForEventType(_selectedSportCategory.dbValue);

        // Try to match event subtype if available
        if (event.eventSubtype != null) {
          final matchingSubtype = subtypes.where((st) => st.name == event.eventSubtype).firstOrNull;
          _selectedSubtype = matchingSubtype ?? (subtypes.isNotEmpty ? subtypes.first : null);
        } else {
          _selectedSubtype = subtypes.isNotEmpty ? subtypes.first : null;
        }
      }

      // Clear search results
      _eventSearchResults = [];
      _isSearchingEvents = false;
    });

    // Unfocus the text field to dismiss keyboard and close dropdown
    _eventNameFocusNode.unfocus();

    // Reset the flag after a brief delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isSelectingEvent = false;
      }
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
    _eventNameController.removeListener(_onEventNameTextChanged);
    _eventNameFocusNode.removeListener(_onEventNameFocusChanged);
    _locationController.removeListener(_onLocationTextChanged);
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _eventNameController.dispose();
    _locationController.dispose();
    _goalHoursController.dispose();
    _goalMinutesController.dispose();
    _registrationUrlController.dispose();
    _bibNumberController.dispose();
    _eventNameFocusNode.dispose();
    _locationFocusNode.dispose();
    _eventSearchDebounce?.cancel();
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
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error searching locations: $e',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.dragonfruit,
            behavior: SnackBarBehavior.floating,
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.electrolyte,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.electrolyte,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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
        SnackBar(
          content: Text(
            'Please select a race distance',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // CRITICAL: Read controller BEFORE any async operations to avoid ref disposal issues
    final eventsController = ref.read(eventsControllerProvider.notifier);

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
      await eventsController.createEvent(
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
        // Pop back and let the calling screen handle provider refresh
        Navigator.of(context).pop({
          'success': true,
          'eventName': _eventNameController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error creating event: $e',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
              ),
            ),
            backgroundColor: AppColors.dragonfruit,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            FontAwesomeIcons.xmark,
            size: AppIconSizes.sm,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'New Event',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard and close dropdowns when tapping outside
          FocusScope.of(context).unfocus();
          setState(() {
            _eventSearchResults = [];
            _isSearchingEvents = false;
            _locationSearchResults = [];
            _isSearchingLocation = false;
          });
          _eventSearchDebounce?.cancel();
          _locationSearchDebounce?.cancel();
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPaddingHorizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Sport Category Selection
                SportCategorySelector(
                  selectedCategory: _selectedSportCategory,
                  onCategoryChanged: _onSportCategoryChanged,
                ),

                const SizedBox(height: AppSpacing.lg),

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

                const SizedBox(height: AppSpacing.lg),

                // Event Name with Active.com Autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _eventNameController,
                      focusNode: _eventNameFocusNode,
                      style: AppTextStyles.inputText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Event Name',
                        labelStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'e.g., NYC Marathon 2025',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: AppColors.electrolyte,
                            width: 2,
                          ),
                        ),
                        suffixIcon: _isSearchingEvents
                            ? const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.electrolyte,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an event name';
                        }
                        return null;
                      },
                    ),
                    // Event search results dropdown
                    if (_eventSearchResults.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Absorb taps on the dropdown to prevent closing
                        },
                        child: Container(
                          margin: const EdgeInsets.only(top: AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: AppRadius.inputRadius,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _eventSearchResults.length,
                            itemBuilder: (context, index) {
                              final event = _eventSearchResults[index];
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  FontAwesomeIcons.calendarDay,
                                  size: AppIconSizes.sm,
                                  color: AppColors.electrolyte,
                                ),
                                title: Text(
                                  event.eventName,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectActiveComEvent(event),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Location with Autocomplete
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _locationController,
                      focusNode: _locationFocusNode,
                      style: AppTextStyles.inputText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Location (optional)',
                        labelStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'e.g., New York, NY',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: AppColors.electrolyte,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          FontAwesomeIcons.locationDot,
                          size: AppIconSizes.sm,
                          color: AppColors.electrolyte,
                        ),
                        suffixIcon: _isSearchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.electrolyte,
                                  ),
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
                          margin: const EdgeInsets.only(top: AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            borderRadius: AppRadius.inputRadius,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
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
                                leading: Icon(
                                  FontAwesomeIcons.locationDot,
                                  size: AppIconSizes.sm,
                                  color: AppColors.electrolyte,
                                ),
                                title: Text(
                                  formattedLocation,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
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

                const SizedBox(height: AppSpacing.lg),

                // Date
                Text(
                  'Event Date',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: Icon(
                    FontAwesomeIcons.calendar,
                    size: AppIconSizes.sm,
                    color: AppColors.electrolyte,
                  ),
                  label: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    alignment: Alignment.centerLeft,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Time
                Text(
                  'Start Time',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: Icon(
                    FontAwesomeIcons.clock,
                    size: AppIconSizes.sm,
                    color: AppColors.electrolyte,
                  ),
                  label: Text(
                    _selectedTime.format(context),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    alignment: Alignment.centerLeft,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.inputRadius,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Goal Time
                Text(
                  'Goal Time (optional)',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _goalHoursController,
                        style: AppTextStyles.inputText.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Hours',
                          labelStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          suffixText: 'h',
                          suffixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                            borderSide: BorderSide(
                              color: AppColors.electrolyte,
                              width: 2,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _goalMinutesController,
                        style: AppTextStyles.inputText.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Minutes',
                          labelStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          suffixText: 'm',
                          suffixStyle: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadius.inputRadius,
                            borderSide: BorderSide(
                              color: AppColors.electrolyte,
                              width: 2,
                            ),
                          ),
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

                const SizedBox(height: AppSpacing.xl),

                // Advanced Section
                ExpansionTile(
                  title: Text(
                    'Additional Details (Optional)',
                    style: AppTextStyles.subtitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  tilePadding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _registrationUrlController,
                      style: AppTextStyles.inputText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Registration URL',
                        labelStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'https://...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: AppColors.electrolyte,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          FontAwesomeIcons.link,
                          size: AppIconSizes.sm,
                          color: AppColors.electrolyte,
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _bibNumberController,
                      style: AppTextStyles.inputText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Bib Number',
                        labelStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        hintText: 'e.g., 12345',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: AppColors.electrolyte,
                            width: 2,
                          ),
                        ),
                        prefixIcon: Icon(
                          FontAwesomeIcons.hashtag,
                          size: AppIconSizes.sm,
                          color: AppColors.electrolyte,
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xl),

                // Create Button
                KylePrimaryButton(
                  onPressed: _handleCreateEvent,
                  text: 'Create Event',
                  icon: FontAwesomeIcons.plus,
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
