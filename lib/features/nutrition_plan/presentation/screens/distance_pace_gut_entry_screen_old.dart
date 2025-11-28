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
import '../providers/running_input_controller.dart';
import '../widgets/pre_run_timing_selector.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../weather/presentation/widgets/weather_indicator_badge.dart';
import '../../../weather/presentation/screens/weather_detail_screen.dart';
import '../../../weather/domain/weather_forecast.dart';

/// Main Nutrition Plan Screen - Main input screen matching Alex's design
/// Users enter run details and generate their nutrition plan
///
/// FOA COMPLIANT: This screen contains ONLY UI logic, no business logic
class DistancePaceGutEntryScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final double? initialDistance;
  final double? initialGoalPace;
  final int? activityId; // Link to calendar activity/event
  final int? eventId; // Link to calendar event (for provider invalidation)

  const DistancePaceGutEntryScreen({
    super.key,
    this.initialDate,
    this.initialDistance,
    this.initialGoalPace,
    this.activityId,
    this.eventId,
  });

  @override
  ConsumerState<DistancePaceGutEntryScreen> createState() => _DistancePaceGutEntryScreenState();
}

class _DistancePaceGutEntryScreenState extends ConsumerState<DistancePaceGutEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Initialize form state with widget parameters if provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(runningInputControllerProvider.notifier);
      final currentState = ref.read(runningInputControllerProvider);

      // Only initialize with widget.initialDate if controller doesn't already have a user-set date
      final now = DateTime.now();
      final isDefaultDate = currentState.selectedDate.year == now.year &&
          currentState.selectedDate.month == now.month &&
          currentState.selectedDate.day == now.day;

      if (isDefaultDate && widget.initialDate != null) {
        controller.initializeWithDate(widget.initialDate);
      }

      // Set initial values from widget parameters if provided
      if (widget.initialDistance != null && currentState.distance == 12.0) {
        controller.updateDistance(widget.initialDistance!);
      }
      if (widget.initialGoalPace != null && currentState.paceMinutes == 9.0) {
        controller.updatePace(widget.initialGoalPace!);
      }

      // Auto-fetch location and weather on screen load
      if (currentState.location == null) {
        controller.fetchCurrentLocation();
      } else {
        controller.fetchWeatherForecast();
      }

      // Load user's gut training preference
      ref.read(macroTargetsControllerProvider.notifier).loadUserPreferences();
    });
  }

  Future<void> _handleGenerateButtonPress() async {
    if (!_formKey.currentState!.validate()) return;

    // UI-only logic: dismiss keyboard
    FocusScope.of(context).unfocus();

    // ALL business logic is in the running controller
    await ref.read(runningInputControllerProvider.notifier).generateMacros(
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

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(macroTargetsControllerProvider);
    final runningForm = ref.watch(runningInputControllerProvider);

    return controllerState.when(
      data: (state) => _buildScreen(context, state, runningForm),
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

  Widget _buildScreen(BuildContext context, MacroTargetsState state, RunningFormState runningForm) {
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

              // Hero Image without blue background
              LargeHeroImage(),

              SizedBox(height: 20.h),

              // Date and Time Picker
              _buildDateTimePicker(context),

              SizedBox(height: 20.h),

              // Distance Input with Increment/Decrement
              IncrementDecrementWidget(
                label: 'Distance',
                value: runningForm.distance.toString(),
                formatValue: (value) => _formatDistance(double.parse(value)),
                onIncrement: () => ref.read(runningInputControllerProvider.notifier).updateDistance(runningForm.distance + 1.0),
                onDecrement: () {
                  if (runningForm.distance > 1.0) {
                    ref.read(runningInputControllerProvider.notifier).updateDistance(runningForm.distance - 1.0);
                  }
                },
              ),

              SizedBox(height: 20.h),

              // Pace Input with Increment/Decrement
              IncrementDecrementWidget(
                label: 'Average Pace',
                value: runningForm.paceMinutes.toString(),
                formatValue: (value) => _formatPace(double.parse(value)),
                onIncrement: () => ref.read(runningInputControllerProvider.notifier).updatePace(runningForm.paceMinutes + 0.25),
                onDecrement: () {
                  if (runningForm.paceMinutes > 1.0) {
                    ref.read(runningInputControllerProvider.notifier).updatePace(runningForm.paceMinutes - 0.25);
                  }
                },
              ),

              SizedBox(height: 20.h),

              // Pre-run Timing Selector
              PreRunTimingSelector(
                label: state.preRunLabel,
                selectedMinutes: runningForm.preRunMinutes,
                onChanged: (int newValue) {
                  ref.read(runningInputControllerProvider.notifier).updatePreRunMinutes(newValue);
                },
              ),
              
              SizedBox(height: 20.h),
              
              // Gut Training Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.gutTrainingLabel,
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
                      child: DropdownButton<GutTraining>(
                        value: runningForm.gutTraining,
                        onChanged: (GutTraining? newValue) {
                          if (newValue != null) {
                            ref.read(runningInputControllerProvider.notifier).updateGutTraining(newValue);
                          }
                        },
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: AppTheme.primary900,
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppTheme.primary900,
                          size: 24.w,
                        ),
                        items: GutTraining.values.map<DropdownMenuItem<GutTraining>>((GutTraining value) {
                          final description = value == GutTraining.high ? '1.0 g/kg/h' :
                                             value == GutTraining.moderate ? '0.8 g/kg/h' :
                                             '0.7 g/kg/h';
                          return DropdownMenuItem<GutTraining>(
                            value: value,
                            child: Text(
                              '${value.name[0].toUpperCase()}${value.name.substring(1)} - $description',
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
              ),
              
              SizedBox(height: 20.h),
              
              // Sweat Rate Category Slider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sweat Rate',
                    style: AppTheme.subtitleStyle.copyWith(
                      fontSize: 16.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                  SizedBox(height: 16.h),
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
                      value: runningForm.sweatRate.index.toDouble(),
                      min: 0,
                      max: 2,
                      divisions: 2,
                      onChanged: (value) {
                        ref.read(runningInputControllerProvider.notifier).updateSweatRate(SweatRateCat.values[value.round()]);
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: SweatRateCat.values.map((category) => Text(
                      category.displayName,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 14.sp,
                        color: runningForm.sweatRate == category ? AppTheme.primary600 : AppTheme.baseGrey,
                        fontWeight: runningForm.sweatRate == category ? FontWeight.w600 : FontWeight.normal,
                      ),
                    )).toList(),
                  ),
                ],
              ),
              
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
                          fontSize: 16.sp,
                          color: AppTheme.primary900,
                        ),
                      ),
                      // Weather Badge - Show for forecast or historical, hide for defaults
                      if (runningForm.weatherForecast != null &&
                          runningForm.weatherForecast!.source != WeatherSource.defaultValue)
                        WeatherIndicatorBadge(
                          forecast: runningForm.weatherForecast!,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WeatherDetailScreen(
                                  forecast: runningForm.weatherForecast!,
                                  location: runningForm.location,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${runningForm.temperatureC.round()}°C (${(runningForm.temperatureC * 9/5 + 32).round()}°F)',
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
                      value: runningForm.temperatureC,
                      min: -5,
                      max: 40,
                      divisions: 45,
                      onChanged: (value) => ref.read(runningInputControllerProvider.notifier).updateTemperature(value),
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
                      fontSize: 16.sp,
                      color: AppTheme.primary900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${runningForm.humidityPct.round()}%',
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
                      value: runningForm.humidityPct,
                      min: 20,
                      max: 95,
                      divisions: 15,
                      onChanged: (value) => ref.read(runningInputControllerProvider.notifier).updateHumidity(value),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dry (20%)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                      Text('Humid (95%)', style: AppTheme.textStyle.copyWith(fontSize: 12.sp, color: AppTheme.baseGrey)),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: 40.h),
              
              // Generate Plan Button - ONLY calls controller, no business logic
              PrimaryButton(
                text: state.generateButtonText,
                onPressed: state.isGeneratingMacros ? null : _handleGenerateButtonPress,
                width: 280.w,
                height: 56.h,
              ),
              
              SizedBox(height: 40.h),
                ],
              ),
            ),
          ),
          
          // Loading overlay - simple spinner in the middle
          if (state.isGeneratingMacros)
            const LoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker(BuildContext context) {
    final runningForm = ref.watch(runningInputControllerProvider);

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
                final picked = await showAppDatePicker(
                  context: context,
                  initialDate: runningForm.selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  ref.read(runningInputControllerProvider.notifier).updateDateTime(picked, runningForm.selectedTime);
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
                        DateFormat('MMM d, yyyy').format(runningForm.selectedDate),
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
                final picked = await showTimePicker(
                  context: context,
                  initialTime: runningForm.selectedTime,
                );
                if (picked != null) {
                  ref.read(runningInputControllerProvider.notifier).updateDateTime(runningForm.selectedDate, picked);
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
                        runningForm.selectedTime.format(context),
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

  // Helper methods for formatting
  String _formatDistance(double distance) {
    if (distance == distance.round()) {
      return '${distance.round()} miles';
    }
    return '${distance.toStringAsFixed(1)} miles';
  }

  String _formatPace(double paceMinutes) {
    final minutes = paceMinutes.floor();
    final seconds = ((paceMinutes - minutes) * 60).round();
    return '$minutes:${seconds.toString().padLeft(2, '0')} min/mile';
  }
}
