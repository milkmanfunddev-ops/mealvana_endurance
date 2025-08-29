import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/hero_image.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/loading_overlay.dart';
import '../../../../shared/widgets/increment_decrement_widget.dart';
import '../providers/distance_page_gut_entry_controller.dart';
import '../widgets/pre_run_timing_selector.dart';
import '../../domain/run_parameters.dart';
import '../../../auth/domain/user_preferences.dart';

/// Main Nutrition Plan Screen - Main input screen matching Alex's design
/// Users enter run details and generate their nutrition plan
/// 
/// FOA COMPLIANT: This screen contains ONLY UI logic, no business logic
class DistancePaceGutEntryScreen extends ConsumerStatefulWidget {
  const DistancePaceGutEntryScreen({super.key});

  @override
  ConsumerState<DistancePaceGutEntryScreen> createState() => _DistancePaceGutEntryScreenState();
}

class _DistancePaceGutEntryScreenState extends ConsumerState<DistancePaceGutEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Using numeric values for increment/decrement widgets
  double _distance = 12.0; // Default 12 miles
  double _paceMinutes = 9.0; // Default 9:00 pace (stored as decimal minutes)
  int _selectedPreRunMinutes = 120; // Default 2 hours
  GutTraining _selectedGutTraining = GutTraining.high;
  SweatRateCat _selectedSweatRate = SweatRateCat.medium;
  double _temperature = 20.0; // Default 20°C (68°F)
  double _humidity = 60.0; // Default 60% humidity

  @override
  void initState() {
    super.initState();
    
    // Load user's gut training preference if available - CONTROLLER CALL ONLY
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(distancePageGutEntryControllerProvider.notifier).loadUserPreferences();
    });
  }

  Future<void> _handleGenerateButtonPress() async {
    if (!_formKey.currentState!.validate()) return;
    
    // UI-only logic: dismiss keyboard
    FocusScope.of(context).unfocus();
    
    // Convert pace back to M:SS format for controller
    final paceMinutePart = _paceMinutes.floor();
    final paceSecondPart = ((_paceMinutes - paceMinutePart) * 60).round();
    final paceText = '$paceMinutePart:${paceSecondPart.toString().padLeft(2, '0')}';
    
    // ALL business logic is in the controller
    await ref.read(distancePageGutEntryControllerProvider.notifier).generateMacros(
      distanceText: _distance.toString(),
      paceText: paceText,
      timeBeforeRunMinutes: _selectedPreRunMinutes,
      gutTraining: _selectedGutTraining,
      distanceUnit: DistanceUnit.miles, // Fixed to miles as per requirements
      paceUnit: PaceUnit.minPerMile, // Fixed to min/mile as per requirements
      sweatRateCat: _selectedSweatRate, // Add sweat rate category
      temperatureC: _temperature,
      humidityPct: _humidity,
    );
    
    // Check if generation was successful by looking at the state
    final currentState = ref.read(distancePageGutEntryControllerProvider).valueOrNull;
    
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
    final controllerState = ref.watch(distancePageGutEntryControllerProvider);
    
    return controllerState.when(
      data: (state) => _buildScreen(context, state),
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

  Widget _buildScreen(BuildContext context, DistancePageGutEntryState state) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: CustomAppBarBackButton(),
        elevation: 0,
        scrolledUnderElevation: 0,
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
              
              // SizedBox(height: 40.h),
              
              // Main instruction text
              // Text(
              //   'Enter the completed distance and average training pace.',
              //   style: AppTheme.textStyle.copyWith(
              //     fontSize: 18.sp,
              //     fontWeight: FontWeight.w600,
              //     color: AppTheme.primary900,
              //   ),
              //   textAlign: TextAlign.center,
              // ),
              
              // SizedBox(height: 20.h),
              
              // Distance Input with Increment/Decrement
              IncrementDecrementWidget(
                label: 'Distance',
                value: _distance.toString(),
                formatValue: (value) => _formatDistance(double.parse(value)),
                onIncrement: _incrementDistance,
                onDecrement: _decrementDistance,
              ),
              
              SizedBox(height: 20.h),
              
              // Pace Input with Increment/Decrement
              IncrementDecrementWidget(
                label: 'Average Pace',
                value: _paceMinutes.toString(),
                formatValue: (value) => _formatPace(double.parse(value)),
                onIncrement: _incrementPace,
                onDecrement: _decrementPace,
              ),
              
              SizedBox(height: 20.h),
              
              // Pre-run Timing Selector
              PreRunTimingSelector(
                label: state.preRunLabel,
                selectedMinutes: _selectedPreRunMinutes,
                onChanged: (int newValue) {
                  setState(() {
                    _selectedPreRunMinutes = newValue;
                  });
                },
              ),
              
              SizedBox(height: 20.h),
              
              // Gut Training Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.gutTrainingLabel,
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
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
                        value: _selectedGutTraining,
                        onChanged: (GutTraining? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedGutTraining = newValue;
                            });
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
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
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
                      value: _selectedSweatRate.index.toDouble(),
                      min: 0,
                      max: 2,
                      divisions: 2,
                      onChanged: (value) {
                        setState(() {
                          _selectedSweatRate = SweatRateCat.values[value.round()];
                        });
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: SweatRateCat.values.map((category) => Text(
                      category.displayName,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 14.sp,
                        color: _selectedSweatRate == category ? AppTheme.primary600 : AppTheme.baseGrey,
                        fontWeight: _selectedSweatRate == category ? FontWeight.w600 : FontWeight.normal,
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
                  Text(
                    'Temperature',
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${_temperature.round()}°C (${(_temperature * 9/5 + 32).round()}°F)',
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
                      value: _temperature,
                      min: -5,
                      max: 40,
                      divisions: 45,
                      onChanged: (value) {
                        setState(() {
                          _temperature = value;
                        });
                      },
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
                    style: AppTheme.textStyle.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '${_humidity.round()}%',
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
                      value: _humidity,
                      min: 20,
                      max: 95,
                      divisions: 15,
                      onChanged: (value) {
                        setState(() {
                          _humidity = value;
                        });
                      },
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
  
  // Helper methods for formatting and increment/decrement
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
  
  void _incrementDistance() {
    setState(() {
      _distance += 1.0;
    });
  }
  
  void _decrementDistance() {
    setState(() {
      if (_distance > 1.0) {
        _distance -= 1.0;
      }
    });
  }
  
  void _incrementPace() {
    setState(() {
      _paceMinutes += 0.25; // 15 second increments (0.25 minutes)
    });
  }
  
  void _decrementPace() {
    setState(() {
      if (_paceMinutes > 1.0) {
        _paceMinutes -= 0.25; // 15 second increments (0.25 minutes)
      }
    });
  }
}