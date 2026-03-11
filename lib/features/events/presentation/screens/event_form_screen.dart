import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:location_iq/location_iq.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/location_service.dart';
import '../../../../shared/utils/location_formatter.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../calendar/domain/event_subtype.dart';
import '../../../calendar/presentation/widgets/sport_category_selector.dart';
import '../../../calendar/presentation/widgets/event_subtype_dropdown.dart';
import '../../domain/event.dart';
import '../../domain/public_event.dart';
import '../../application/public_events_service.dart';
import '../providers/events_controller.dart';

/// Unified Event Form Screen for creating and editing events.
///
/// Updated with Kyle's Design System:
/// - AppColors for theme-aware colors
/// - AppTextStyles for typography
/// - BaseCard for consistent card styling
/// - KylePrimaryButton for actions
///
/// - If [event] is null, this is CREATE mode
/// - If [event] is provided, this is EDIT mode
class EventFormScreen extends ConsumerStatefulWidget {
  final Event? event; // null = create mode, non-null = edit mode
  final String? forUserId; // If provided, create event for this user (coach creating for athlete)

  const EventFormScreen({
    super.key,
    this.event,
    this.forUserId,
  });

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
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
  late ActivityType _selectedSportType;
  EventSubtype? _selectedEventSubtype;
  bool _isSaving = false;

  // Event name search state (Public Events)
  final _eventNameFocusNode = FocusNode();
  List<PublicEvent> _eventSearchResults = [];
  bool _isSearchingEvents = false;
  bool _isSelectingEvent = false;
  Timer? _eventSearchDebounce;

  // Location search state
  final _locationFocusNode = FocusNode();
  List<LocationIQAutocompleteResult> _locationSearchResults = [];
  bool _isSearchingLocation = false;
  bool _isSelectingLocation = false;
  Timer? _locationSearchDebounce;

  // Computed properties
  bool get isEditMode => widget.event != null;
  bool get isCreateMode => widget.event == null;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current values (edit mode) or empty (create mode)
    _eventNameController = TextEditingController(text: widget.event?.eventName);
    _locationController = TextEditingController(text: widget.event?.location);
    _bibNumberController = TextEditingController(text: widget.event?.bibNumber);
    _registrationUrlController = TextEditingController(text: widget.event?.registrationUrl);

    // Parse goal time (stored as total minutes)
    if (widget.event?.goalTimeMinutes != null) {
      final hours = widget.event!.goalTimeMinutes! ~/ 60;
      final minutes = widget.event!.goalTimeMinutes! % 60;
      _goalTimeHoursController = TextEditingController(text: hours > 0 ? hours.toString() : '');
      _goalTimeMinutesController = TextEditingController(text: minutes > 0 ? minutes.toString() : '');
    } else {
      _goalTimeHoursController = TextEditingController();
      _goalTimeMinutesController = TextEditingController();
    }

    // Parse goal pace (stored as minutes per mile with decimal)
    if (widget.event?.goalPaceMinutesPerMile != null) {
      final minutes = widget.event!.goalPaceMinutesPerMile!.floor();
      final seconds = ((widget.event!.goalPaceMinutesPerMile! - minutes) * 60).round();
      _goalPaceMinutesController = TextEditingController(text: minutes.toString());
      _goalPaceSecondsController = TextEditingController(text: seconds.toString());
    } else {
      _goalPaceMinutesController = TextEditingController();
      _goalPaceSecondsController = TextEditingController();
    }

    // Initialize start time and event type
    if (isEditMode) {
      _startTime = widget.event!.startTime != null ? DateTime.parse(widget.event!.startTime!) : null;
      _selectedSportType = widget.event!.eventType;
      // Convert string to EventSubtype
      if (widget.event!.eventSubtype != null) {
        final subtypes = EventSubtype.getSubtypesForEventType(widget.event!.eventType.dbValue);
        _selectedEventSubtype = subtypes.firstWhere(
          (st) => st.name == widget.event!.eventSubtype,
          orElse: () => subtypes.first,
        );
      }
    } else {
      // Create mode defaults
      _startTime = DateTime.now().add(const Duration(days: 30));
      _selectedSportType = ActivityType.running;
      // Default to half marathon for running
      final subtypes = EventSubtype.getSubtypesForEventType(_selectedSportType.dbValue);
      _selectedEventSubtype = subtypes.firstWhere(
        (st) => st.name == 'half_marathon',
        orElse: () => subtypes.first,
      );
    }

    // Add listener for event name autocomplete
    _eventNameController.addListener(_onEventNameTextChanged);
    _eventNameFocusNode.addListener(_onEventNameFocusChanged);

    // Add listener for location autocomplete
    _locationController.addListener(_onLocationTextChanged);
    _locationFocusNode.addListener(_onLocationFocusChanged);
  }

  @override
  void dispose() {
    _eventNameController.removeListener(_onEventNameTextChanged);
    _eventNameFocusNode.removeListener(_onEventNameFocusChanged);
    _locationController.removeListener(_onLocationTextChanged);
    _locationFocusNode.removeListener(_onLocationFocusChanged);
    _eventNameController.dispose();
    _locationController.dispose();
    _bibNumberController.dispose();
    _registrationUrlController.dispose();
    _goalTimeHoursController.dispose();
    _goalTimeMinutesController.dispose();
    _goalPaceMinutesController.dispose();
    _goalPaceSecondsController.dispose();
    _eventNameFocusNode.dispose();
    _locationFocusNode.dispose();
    _eventSearchDebounce?.cancel();
    _locationSearchDebounce?.cancel();
    super.dispose();
  }

  /// Called when event name field focus changes
  void _onEventNameFocusChanged() {
    if (!_eventNameFocusNode.hasFocus) {
      setState(() {
        _eventSearchResults = [];
        _isSearchingEvents = false;
      });
      _eventSearchDebounce?.cancel();
    }
  }

  /// Called when event name text changes - debounces search
  void _onEventNameTextChanged() {
    if (_isSelectingEvent) {
      return;
    }

    _eventSearchDebounce?.cancel();

    final query = _eventNameController.text.trim();

    if (query.isEmpty || query.length < 3) {
      setState(() {
        _eventSearchResults = [];
        _isSearchingEvents = false;
      });
      return;
    }

    setState(() {
      _isSearchingEvents = true;
    });

    _eventSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchActiveComEvents(query);
    });
  }

  /// Search for events using Public Events table
  Future<void> _searchActiveComEvents(String query) async {
    try {
      final publicEventsService = ref.read(publicEventsServiceProvider);
      final results = await publicEventsService.searchEvents(
        query: query,
        limit: 10,
      );

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
      }
    }
  }

  /// Called when user selects an event from Public Events search results
  void _selectActiveComEvent(PublicEvent event) {
    _isSelectingEvent = true;
    _eventSearchDebounce?.cancel();

    setState(() {
      _eventNameController.text = event.eventName;

      // Auto-fill location if available
      if (event.location != null && event.location!.isNotEmpty) {
        _locationController.text = event.location!;
      } else if (event.city != null || event.state != null) {
        _locationController.text = event.formattedLocation;
      }

      // Auto-fill date and time if available
      if (event.eventDate != null) {
        if (_startTime != null) {
          _startTime = DateTime(
            event.eventDate!.year,
            event.eventDate!.month,
            event.eventDate!.day,
            _startTime!.hour,
            _startTime!.minute,
          );
        } else {
          _startTime = event.eventDate!;
        }
      }
      if (event.startTime != null) {
        // Parse time string (HH:MM:SS) to TimeOfDay
        final timeParts = event.startTime!.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 7;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          if (_startTime != null) {
            _startTime = DateTime(
              _startTime!.year,
              _startTime!.month,
              _startTime!.day,
              hour,
              minute,
            );
          }
        }
      }

      // Auto-fill registration URL if available
      if (event.registrationUrl != null && event.registrationUrl!.isNotEmpty) {
        _registrationUrlController.text = event.registrationUrl!;
      }

      // Auto-update sport type to match the event
      _selectedSportType = event.eventType;
      // Update subtype based on new sport type
      final subtypes = EventSubtype.getSubtypesForEventType(_selectedSportType.dbValue);

      // Try to match event subtype if available
      if (event.eventSubtype != null) {
        final matchingSubtype = subtypes.where((st) => st.name == event.eventSubtype).firstOrNull;
        _selectedEventSubtype = matchingSubtype ?? (subtypes.isNotEmpty ? subtypes.first : null);
      } else {
        _selectedEventSubtype = subtypes.isNotEmpty ? subtypes.first : null;
      }

      // Clear search results
      _eventSearchResults = [];
      _isSearchingEvents = false;
    });

    _eventNameFocusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isSelectingEvent = false;
      }
    });
  }

  /// Called when location field focus changes
  void _onLocationFocusChanged() {
    if (!_locationFocusNode.hasFocus) {
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      _locationSearchDebounce?.cancel();
    }
  }

  /// Called when location text changes - debounces search
  void _onLocationTextChanged() {
    if (_isSelectingLocation) {
      return;
    }

    _locationSearchDebounce?.cancel();

    final query = _locationController.text.trim();

    if (query.isEmpty || query.length < 3) {
      setState(() {
        _locationSearchResults = [];
        _isSearchingLocation = false;
      });
      return;
    }

    setState(() {
      _isSearchingLocation = true;
    });

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
      }
    }
  }

  /// Called when user selects a location from search results
  void _selectLocation(LocationIQAutocompleteResult location) {
    _isSelectingLocation = true;
    _locationSearchDebounce?.cancel();

    final formattedLocation = LocationFormatter.formatCityState(location);

    setState(() {
      _locationController.text = formattedLocation;
      _locationSearchResults = [];
      _isSearchingLocation = false;
    });

    _locationFocusNode.unfocus();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _isSelectingLocation = false;
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showAppDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now().add(const Duration(days: 30)),
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

    if (picked != null) {
      setState(() {
        if (_startTime != null) {
          // Preserve time component
          _startTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _startTime!.hour,
            _startTime!.minute,
          );
        } else {
          _startTime = DateTime(picked.year, picked.month, picked.day, 7, 0);
        }
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime != null
          ? TimeOfDay.fromDateTime(_startTime!)
          : const TimeOfDay(hour: 7, minute: 0),
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

    if (picked != null) {
      setState(() {
        if (_startTime != null) {
          _startTime = DateTime(
            _startTime!.year,
            _startTime!.month,
            _startTime!.day,
            picked.hour,
            picked.minute,
          );
        } else {
          final now = DateTime.now();
          _startTime = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startTime == null) {
      MealvanaSnackbar.showWarning(context, 'Please select an event date');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Calculate goal time in minutes
      int? goalTimeMinutes;
      if (_goalTimeHoursController.text.isNotEmpty || _goalTimeMinutesController.text.isNotEmpty) {
        final hours = int.tryParse(_goalTimeHoursController.text) ?? 0;
        final minutes = int.tryParse(_goalTimeMinutesController.text) ?? 0;
        goalTimeMinutes = (hours * 60) + minutes;
      }

      // Calculate goal pace in minutes per mile
      double? goalPaceMinutesPerMile;
      if (_goalPaceMinutesController.text.isNotEmpty || _goalPaceSecondsController.text.isNotEmpty) {
        final minutes = int.tryParse(_goalPaceMinutesController.text) ?? 0;
        final seconds = int.tryParse(_goalPaceSecondsController.text) ?? 0;
        goalPaceMinutesPerMile = minutes + (seconds / 60);
      }

      if (isEditMode) {
        // Update existing event
        final updatedEvent = widget.event!.copyWith(
          eventName: _eventNameController.text.trim(),
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          bibNumber: _bibNumberController.text.trim().isEmpty ? null : _bibNumberController.text.trim(),
          registrationUrl: _registrationUrlController.text.trim().isEmpty ? null : _registrationUrlController.text.trim(),
          startTime: _startTime!.toIso8601String(),
          eventType: _selectedSportType,
          eventSubtype: _selectedEventSubtype?.name,
          goalTimeMinutes: goalTimeMinutes,
          goalPaceMinutesPerMile: goalPaceMinutesPerMile,
        );

        await ref.read(eventsControllerProvider.notifier).updateEvent(updatedEvent);

        if (mounted) {
          Navigator.of(context).pop({'success': true, 'eventName': updatedEvent.eventName});
        }
      } else {
        // Create new event
        final eventId = await ref.read(eventsControllerProvider.notifier).createEvent(
          activityId: null,
          forUserId: widget.forUserId,
          eventType: _selectedSportType,
          eventSubtype: _selectedEventSubtype?.name,
          eventName: _eventNameController.text.trim(),
          location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          registrationUrl: _registrationUrlController.text.trim().isEmpty ? null : _registrationUrlController.text.trim(),
          startTime: _startTime!.toIso8601String(),
          goalTimeMinutes: goalTimeMinutes,
          goalPaceMinutesPerMile: goalPaceMinutesPerMile,
          hasCarbLoading: false,
        );

        if (mounted) {
          // Pop and return result - let calling screen handle navigation
          Navigator.of(context).pop({
            'success': true,
            'eventName': _eventNameController.text.trim(),
            'eventId': eventId,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        MealvanaSnackbar.showError(
          context,
          'Error ${isEditMode ? 'updating' : 'creating'} event: $e',
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
          isEditMode ? 'Edit Event' : 'New Event',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              FontAwesomeIcons.house,
              size: AppIconSizes.sm,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Home',
            onPressed: () => context.go('/main'),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () {
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
                  const SizedBox(height: AppSpacing.md),

                // Sport Category Selection
                SportCategorySelector(
                  selectedCategory: _selectedSportType,
                  onCategoryChanged: (newCategory) {
                    setState(() {
                      _selectedSportType = newCategory;
                      // Reset subtype to first option of the new category
                      final subtypes = EventSubtype.getSubtypesForEventType(newCategory.dbValue);
                      _selectedEventSubtype = subtypes.isNotEmpty ? subtypes.first : null;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Event Subtype Selection (Race Distance)
                EventSubtypeDropdown(
                  sportCategory: _selectedSportType,
                  selectedSubtype: _selectedEventSubtype,
                  onSubtypeChanged: (subtype) {
                    setState(() {
                      _selectedEventSubtype = subtype;
                    });
                  },
                ),

                const SizedBox(height: AppSpacing.lg),

                // Event Name with Public Events Autocomplete
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
                        onTap: () {},
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
                              // Build subtitle with location and date
                              final subtitleParts = <String>[];
                              if (event.city != null || event.state != null || event.location != null) {
                                subtitleParts.add(event.formattedLocation);
                              }
                              if (event.eventDate != null) {
                                subtitleParts.add(DateFormat('MMM d, yyyy').format(event.eventDate!));
                              }
                              final subtitle = subtitleParts.isNotEmpty ? subtitleParts.join(' - ') : null;
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
                                subtitle: subtitle != null
                                    ? Text(
                                        subtitle,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
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
                        onTap: () {},
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
                    _startTime != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_startTime!)
                        : 'Select date',
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
                    _startTime != null
                        ? TimeOfDay.fromDateTime(_startTime!).format(context)
                        : 'Select time',
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

                    // Goal Time
                    Text(
                      'Goal Time',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _goalTimeHoursController,
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
                            controller: _goalTimeMinutesController,
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

                    const SizedBox(height: AppSpacing.md),

                    // Goal Pace
                    Text(
                      'Goal Pace (per mile)',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _goalPaceMinutesController,
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
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: TextFormField(
                            controller: _goalPaceSecondsController,
                            style: AppTextStyles.inputText.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Seconds',
                              labelStyle: AppTextStyles.bodyMedium.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              suffixText: 's',
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
                                final seconds = int.tryParse(value);
                                if (seconds == null || seconds < 0 || seconds >= 60) {
                                  return 'Must be 0-59';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Registration URL
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

                    // Bib Number
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

                // Save Button
                KylePrimaryButton(
                  onPressed: _isSaving ? null : _handleSave,
                  text: isEditMode ? 'Save Changes' : 'Create Event',
                  icon: isEditMode ? FontAwesomeIcons.check : FontAwesomeIcons.plus,
                  isLoading: _isSaving,
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
