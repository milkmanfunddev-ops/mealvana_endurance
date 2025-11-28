import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/shared/widgets/app_date_picker.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/hero_image.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/increment_decrement_widget.dart';
import '../providers/macro_targets_controller.dart';
import '../providers/cycling_input_controller.dart';
import '../widgets/pre_run_timing_selector.dart';
import '../../../weather/presentation/widgets/weather_indicator_badge.dart';
import '../../../weather/presentation/screens/weather_detail_screen.dart';
import '../../../weather/domain/weather_forecast.dart';

/// Cycling Input Screen - Cycling-specific nutrition plan input
/// Users enter cycling details and generate their nutrition plan
///
/// FOA COMPLIANT: This screen contains ONLY UI logic, no business logic
class CyclingInputScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final double? initialDistance;
  final double? initialSpeed;
  final int? activityId; // Link to calendar activity
  final int? eventId; // Link to calendar event

  const CyclingInputScreen({
    super.key,
    this.initialDate,
    this.initialDistance,
    this.initialSpeed,
    this.activityId,
    this.eventId,
  });

  @override
  ConsumerState<CyclingInputScreen> createState() => _CyclingInputScreenState();
}

class _CyclingInputScreenState extends ConsumerState<CyclingInputScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Initialize form state with widget parameters if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(cyclingInputControllerProvider.notifier);
      final currentState = ref.read(cyclingInputControllerProvider);

      // Only initialize with widget.initialDate if controller doesn't already have a user-set date
      // This preserves the date when switching between tabs
      final now = DateTime.now();
      final isDefaultDate = currentState.selectedDate.year == now.year &&
          currentState.selectedDate.month == now.month &&
          currentState.selectedDate.day == now.day;

      if (isDefaultDate && widget.initialDate != null) {
        controller.initializeWithDate(widget.initialDate);
      }

      // Set initial values from widget parameters if provided (only if not already set)
      if (widget.initialDistance != null && currentState.distance == 50.0) {
        controller.updateDistance(widget.initialDistance!);
      }
      if (widget.initialSpeed != null && currentState.speedMph == 16.0) {
        controller.updateSpeed(widget.initialSpeed!);
      }

      // Auto-fetch location and weather on screen load
      if (currentState.location == null) {
        controller.fetchCurrentLocation();
      } else {
        // Location exists, but we might need fresh weather for today
        controller.fetchWeatherForecast();
      }
    });
  }

  Future<void> _handleGenerateButtonPress() async {
    if (!_formKey.currentState!.validate()) return;

    // UI-only logic: dismiss keyboard
    FocusScope.of(context).unfocus();

    // ALL business logic is in the cycling controller
    await ref.read(cyclingInputControllerProvider.notifier).generateMacros(
      activityId: widget.activityId,
      eventId: widget.eventId,
    );

    // Check if generation was successful by looking at the state
    final currentState = ref.read(macroTargetsControllerProvider).value;

    // If we have macro targets and no error, navigate
    if (currentState?.macroTargets != null && currentState?.errorMessage == null) {
      if (mounted) {
        context.push('/adjust-macros');
      }
    } else if (currentState?.errorMessage != null) {
      // Show error if there is one
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentState?.errorMessage ?? currentState?.errorGeneric ?? 'Something went wrong. Please try again.'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    }
  }

  int _calculateDurationMinutes(double distance, double speedMph) {
    if (speedMph <= 0) return 0;
    return (distance / speedMph * 60).round();
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(macroTargetsControllerProvider);
    final cyclingForm = ref.watch(cyclingInputControllerProvider);

    return controllerState.when(
      data: (state) => _buildScreen(context, state, cyclingForm),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error loading content: $error'),
        ),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, MacroTargetsState state, CyclingFormState cyclingForm) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),

                  // Hero Image
                  LargeHeroImage(
                    imagePath: 'assets/images/woman_cycling.png',
                  ),

                  SizedBox(height: 20.h),

                  // Date and Time Picker
                  _buildDateTimePicker(context, cyclingForm),

                  SizedBox(height: 20.h),

                  // Distance Input with Increment/Decrement
                  IncrementDecrementWidget(
                    label: 'Distance',
                    value: cyclingForm.distance.toString(),
                    formatValue: (value) => _formatDistance(double.parse(value)),
                    onIncrement: () => ref.read(cyclingInputControllerProvider.notifier).updateDistance(cyclingForm.distance + 1.0),
                    onDecrement: () {
                      if (cyclingForm.distance > 1.0) {
                        ref.read(cyclingInputControllerProvider.notifier).updateDistance(cyclingForm.distance - 1.0);
                      }
                    },
                  ),

                  SizedBox(height: 20.h),

                  // Speed Input with Increment/Decrement
                  IncrementDecrementWidget(
                    label: 'Average Speed',
                    value: cyclingForm.speedMph.toString(),
                    formatValue: (value) => _formatSpeed(double.parse(value)),
                    onIncrement: () => ref.read(cyclingInputControllerProvider.notifier).updateSpeed(cyclingForm.speedMph + 1.0),
                    onDecrement: () {
                      if (cyclingForm.speedMph > 1.0) {
                        ref.read(cyclingInputControllerProvider.notifier).updateSpeed(cyclingForm.speedMph - 1.0);
                      }
                    },
                  ),

                  SizedBox(height: 12.h),

                  // Duration Display (calculated)
                  Text(
                    'Duration: ~${_calculateDurationMinutes(cyclingForm.distance, cyclingForm.speedMph)} min',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.primary600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Intensity Target Dropdown
                  _buildDropdown(
                    label: 'Intensity Target',
                    value: cyclingForm.intensityTarget,
                    items: const {
                      'zone_1': 'Zone 1 - Recovery',
                      'zone_2': 'Zone 2 - Endurance',
                      'zone_3': 'Zone 3 - Tempo',
                      'zone_4': 'Zone 4 - Threshold',
                      'zone_5': 'Zone 5 - VO2 Max',
                    },
                    onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateIntensityTarget(value!),
                  ),

                  SizedBox(height: 20.h),

                  // Session Goal Dropdown
                  _buildDropdown(
                    label: 'Session Goal',
                    value: cyclingForm.sessionGoal,
                    items: const {
                      'endurance': 'Endurance',
                      'tempo': 'Tempo',
                      'intervals': 'Intervals',
                    },
                    onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateSessionGoal(value!),
                  ),

                  SizedBox(height: 20.h),

                  // Terrain & Aero Load Dropdown
                  _buildDropdown(
                    label: 'Terrain & Aero Load',
                    value: cyclingForm.terrain,
                    items: const {
                      'flat_indoor': 'Flat - Indoor',
                      'flat_outdoor': 'Flat - Outdoor',
                      'rolling_outdoor': 'Rolling - Outdoor',
                      'hilly_outdoor': 'Hilly - Outdoor',
                    },
                    onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateTerrain(value!),
                  ),

                  SizedBox(height: 20.h),

                  // Elevation Gain Input
                  IncrementDecrementWidget(
                    label: 'Elevation Gain',
                    value: cyclingForm.elevationGainFt.toString(),
                    formatValue: (value) => '${int.parse(value)} ft',
                    onIncrement: () => ref.read(cyclingInputControllerProvider.notifier).updateElevationGain(cyclingForm.elevationGainFt + 100),
                    onDecrement: () {
                      if (cyclingForm.elevationGainFt >= 100) {
                        ref.read(cyclingInputControllerProvider.notifier).updateElevationGain(cyclingForm.elevationGainFt - 100);
                      }
                    },
                  ),

                  SizedBox(height: 20.h),

                  // Pre-Ride Timing Selector
                  PreRunTimingSelector(
                    label: 'Pre-Ride Timing',
                    selectedMinutes: cyclingForm.preRideMinutes,
                    onChanged: (int newValue) {
                      ref.read(cyclingInputControllerProvider.notifier).updatePreRideMinutes(newValue);
                    },
                  ),

                  SizedBox(height: 20.h),

                  // Environment Section (Collapsible)
                  _buildEnvironmentSection(cyclingForm),

                  SizedBox(height: 40.h),

                  // Generate Plan Button - ONLY calls controller, no business logic
                  PrimaryButton(
                    text: 'Generate Nutrition Plan',
                    onPressed: state.isGeneratingMacros ? null : _handleGenerateButtonPress,
                    width: 280.w,
                    height: 56.h,
                  ),

                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (state.isGeneratingMacros)
            const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker(BuildContext context, CyclingFormState cyclingForm) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary900, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final currentForm = ref.read(cyclingInputControllerProvider);
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: currentForm.selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  ref.read(cyclingInputControllerProvider.notifier).updateDateTime(picked, currentForm.selectedTime);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date',
                    style: AppTheme.subtitleStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.baseGrey,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: AppTheme.primary900),
                      SizedBox(width: 8.w),
                      Text(
                        DateFormat('MMM d, yyyy').format(cyclingForm.selectedDate),
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 40.h,
            color: AppTheme.baseGrey.withValues(alpha: 0.3),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: InkWell(
              onTap: () async {
                final currentForm = ref.read(cyclingInputControllerProvider);
                final picked = await showTimePicker(
                  context: context,
                  initialTime: currentForm.selectedTime,
                );
                if (picked != null) {
                  ref.read(cyclingInputControllerProvider.notifier).updateDateTime(currentForm.selectedDate, picked);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time',
                    style: AppTheme.subtitleStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.baseGrey,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: AppTheme.primary900),
                      SizedBox(width: 8.w),
                      Text(
                        cyclingForm.selectedTime.format(context),
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.subtitleStyle.copyWith(
            fontSize: 16.sp,
            color: AppTheme.primary900,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.primary900, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                color: AppTheme.primary900,
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.primary900,
                size: 24.w,
              ),
              items: items.entries.map<DropdownMenuItem<String>>((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnvironmentSection(CyclingFormState cyclingForm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => ref.read(cyclingInputControllerProvider.notifier).toggleEnvironmentSection(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Environment',
                style: AppTheme.subtitleStyle.copyWith(
                  fontSize: 16.sp,
                  color: AppTheme.primary900,
                ),
              ),
              Icon(
                cyclingForm.showEnvironment ? Icons.expand_less : Icons.expand_more,
                color: AppTheme.primary900,
              ),
            ],
          ),
        ),
        if (cyclingForm.showEnvironment) ...[
          SizedBox(height: 20.h),

          // Temperature Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Temperature',
                    style: AppTheme.subtitleStyle.copyWith(
                      fontSize: 14.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                  // Weather Badge (inline with temperature label)
                  // Show for forecast or historical, hide for defaults
                  if (cyclingForm.weatherForecast != null &&
                      cyclingForm.weatherForecast!.source != WeatherSource.defaultValue)
                    WeatherIndicatorBadge(
                      forecast: cyclingForm.weatherForecast!,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeatherDetailScreen(
                              forecast: cyclingForm.weatherForecast!,
                              location: cyclingForm.location,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                '${cyclingForm.temperatureC.round()}°C (${(cyclingForm.temperatureC * 9/5 + 32).round()}°F)',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 14.sp,
                  color: AppTheme.primary600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary600,
                  inactiveTrackColor: AppTheme.primary600.withValues(alpha: 0.3),
                  thumbColor: AppTheme.primary600,
                  overlayColor: AppTheme.primary600.withValues(alpha: 0.2),
                  trackHeight: 4.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.r),
                ),
                child: Slider(
                  value: cyclingForm.temperatureC,
                  min: -5,
                  max: 40,
                  divisions: 45,
                  onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateTemperature(value),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Cold (-5°C)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                  Text('Hot (40°C)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                ],
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Humidity Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Humidity',
                style: AppTheme.subtitleStyle.copyWith(
                  fontSize: 14.sp,
                  color: AppTheme.primary900,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '${cyclingForm.humidityPct.round()}%',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 14.sp,
                  color: AppTheme.primary600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppTheme.primary600,
                  inactiveTrackColor: AppTheme.primary600.withValues(alpha: 0.3),
                  thumbColor: AppTheme.primary600,
                  overlayColor: AppTheme.primary600.withValues(alpha: 0.2),
                  trackHeight: 4.h,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.r),
                ),
                child: Slider(
                  value: cyclingForm.humidityPct,
                  min: 20,
                  max: 100,
                  divisions: 16,
                  onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateHumidity(value),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Dry (20%)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                  Text('Humid (100%)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                ],
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Wind Condition Dropdown
          _buildDropdown(
            label: 'Wind',
            value: cyclingForm.windCondition,
            items: const {
              'still': 'Still',
              'breezy': 'Breezy',
              'windy': 'Windy',
            },
            onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateWindCondition(value!),
          ),

          SizedBox(height: 20.h),

          // Sun Exposure Dropdown
          _buildDropdown(
            label: 'Sun Exposure',
            value: cyclingForm.sunExposure,
            items: const {
              'full_sun': 'Full Sun',
              'mixed': 'Mixed',
              'shade': 'Shade',
            },
            onChanged: (value) => ref.read(cyclingInputControllerProvider.notifier).updateSunExposure(value!),
          ),
        ],
      ],
    );
  }

  // Helper methods for formatting
  String _formatDistance(double distance) {
    if (distance == distance.round()) {
      return '${distance.round()} miles';
    }
    return '${distance.toStringAsFixed(1)} miles';
  }

  String _formatSpeed(double speed) {
    if (speed == speed.round()) {
      return '${speed.round()} mph';
    }
    return '${speed.toStringAsFixed(1)} mph';
  }
}
