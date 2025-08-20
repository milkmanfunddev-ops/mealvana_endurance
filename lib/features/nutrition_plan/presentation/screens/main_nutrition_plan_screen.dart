import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/hero_image.dart';
import '../../../../shared/widgets/labeled_text_field.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../providers/main_screen_controller.dart';
import '../widgets/pre_run_timing_selector.dart';
import '../../domain/run_parameters.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/mixins/analytics_mixin.dart';

/// Main Nutrition Plan Screen - Main input screen matching Alex's design
/// Users enter run details and generate their nutrition plan
class MainNutritionPlanScreen extends ConsumerStatefulWidget {
  const MainNutritionPlanScreen({super.key});

  @override
  ConsumerState<MainNutritionPlanScreen> createState() => _MainNutritionPlanScreenState();
}

class _MainNutritionPlanScreenState extends ConsumerState<MainNutritionPlanScreen> with AnalyticsMixin {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _paceController = TextEditingController();
  
  bool _isGenerating = false;
  DistanceUnit _selectedDistanceUnit = DistanceUnit.miles;
  PaceUnit _selectedPaceUnit = PaceUnit.minPerMile;
  int _selectedPreRunMinutes = 120; // Default 2 hours
  GutTraining _selectedGutTraining = GutTraining.high;

  @override
  void initState() {
    super.initState();
    // Set default placeholder values
    _distanceController.text = '5';
    _paceController.text = '8:30';
    
    // Track screen view
    trackScreenView('Main Nutrition Plan Screen');
    
    // Load user's gut training preference if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserPreferences();
    });
  }
  
  Future<void> _loadUserPreferences() async {
    // TODO: Load user profile when auth service method is available
    // For now, use default gut training level
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _paceController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isGenerating = true);
    
    // Track generate plan button press
    await trackInteraction('Generate Plan Button Pressed', properties: {
      'Distance': _distanceController.text,
      'Pace': _paceController.text,
      'Pre Run Minutes': _selectedPreRunMinutes,
      'Gut Training': _selectedGutTraining.name,
      'Distance Unit': _selectedDistanceUnit.name,
      'Pace Unit': _selectedPaceUnit.name,
    });
    
    try {
      final distance = double.tryParse(_distanceController.text) ?? 5.0;
      final paceString = _paceController.text.trim();
      
      // Parse pace (e.g., "8:30" -> 8.5 minutes per mile)
      final paceParts = paceString.split(':');
      final paceMinutes = paceParts.length == 2
          ? (double.tryParse(paceParts[0]) ?? 8.0) + 
            ((double.tryParse(paceParts[1]) ?? 30.0) / 60.0)
          : double.tryParse(paceString) ?? 8.5;
      
      // Use the main screen controller to generate plan
      final controller = ref.read(mainScreenControllerProvider.notifier);
      await controller.generatePlan(
        distanceMiles: distance,
        paceMinutesPerMile: paceMinutes,
      );
      
      // Track successful navigation to plan screen
      await trackNavigation('Plan Screen', source: 'Main Screen Generate Button');
      
      // Navigate to plan screen
      if (mounted) {
        context.push('/plan');
      }
      
    } catch (error) {
      // Track the error
      await trackScreenError(error.toString(), 
        errorType: 'Plan Generation Error',
        additionalContext: {
          'Distance': _distanceController.text,
          'Pace': _paceController.text,
        },
      );
      
      if (mounted) {
        final currentState = ref.read(mainScreenControllerProvider).valueOrNull;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentState?.errorGeneric ?? 'Something went wrong. Please try again.'),
            backgroundColor: AppTheme.highlight600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(mainScreenControllerProvider);
    
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

  Widget _buildScreen(BuildContext context, MainScreenState state) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          state.title,
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 8.h),
              
              // Hero Image without blue background
              LargeHeroImage(),
              
              SizedBox(height: 40.h),
              
              // Input Fields
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance Input with Unit Selector
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: LabeledTextField(
                            label: state.distanceLabel,
                            hint: _selectedDistanceUnit == DistanceUnit.miles ? 'e.g. 5' : 'e.g. 8',
                            controller: _distanceController,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter distance';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              final distance = double.parse(value);
                              if (distance <= 0 || distance > 200) {
                                return 'Distance must be between 0 and 200';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit',
                                style: AppTheme.textStyle.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary900,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                width: double.infinity,
                                height: 52.h, // Match input field height
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<DistanceUnit>(
                                    value: _selectedDistanceUnit,
                                    onChanged: (DistanceUnit? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedDistanceUnit = newValue;
                                        });
                                      }
                                    },
                                    style: AppTheme.textStyle.copyWith(
                                      fontSize: 14.sp,
                                      color: AppTheme.primary900,
                                    ),
                                    items: DistanceUnit.values.map<DropdownMenuItem<DistanceUnit>>((DistanceUnit value) {
                                      return DropdownMenuItem<DistanceUnit>(
                                        value: value,
                                        child: Text(value.abbreviation),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Average Pace Input with Unit Selector
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: LabeledTextField(
                            label: 'Average pace',
                            hint: _selectedPaceUnit == PaceUnit.minPerMile ? 'e.g. 8:30' : 'e.g. 5:15',
                            controller: _paceController,
                            keyboardType: TextInputType.text,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter average pace';
                              }
                              
                              // Validate pace format (e.g., "8:30" or "8.5")
                              final paceRegex = RegExp(r'^\d{1,2}:\d{2}$|^\d{1,2}\.?\d*$');
                              if (!paceRegex.hasMatch(value.trim())) {
                                return 'Format: 8:30 or 8.5';
                              }
                              
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Unit',
                                style: AppTheme.textStyle.copyWith(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary900,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Container(
                                width: double.infinity,
                                height: 52.h, // Match input field height
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<PaceUnit>(
                                    value: _selectedPaceUnit,
                                    onChanged: (PaceUnit? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedPaceUnit = newValue;
                                        });
                                      }
                                    },
                                    style: AppTheme.textStyle.copyWith(
                                      fontSize: 12.sp,
                                      color: AppTheme.primary900,
                                    ),
                                    items: PaceUnit.values.map<DropdownMenuItem<PaceUnit>>((PaceUnit value) {
                                      return DropdownMenuItem<PaceUnit>(
                                        value: value,
                                        child: Text(
                                          value.abbreviation,
                                          style: AppTheme.textStyle.copyWith(
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Pre-run Timing Selector
                    PreRunTimingSelector(
                      label: 'Time before run',
                      selectedMinutes: _selectedPreRunMinutes,
                      onChanged: (int newValue) {
                        setState(() {
                          _selectedPreRunMinutes = newValue;
                        });
                      },
                    ),
                    
                    SizedBox(height: 24.h),
                    
                    // Gut Training Selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gut training level',
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
                        SizedBox(height: 8.h),
                        Text(
                          _getGutTrainingDescription(_selectedGutTraining),
                          style: AppTheme.textStyle.copyWith(
                            fontSize: 12.sp,
                            color: AppTheme.baseGrey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40.h),
              
              // Generate Plan Button
              PrimaryButton(
                text: 'Generate Plan',
                onPressed: _isGenerating ? null : _generatePlan,
                isLoading: _isGenerating,
                width: 280.w,
                height: 56.h,
              ),
              
              SizedBox(height: 40.h),
              
              // Tips text
              if (!_isGenerating) ...[
                Text(
                  state.tipsText,
                  style: AppTheme.noteStyle.copyWith(
                    color: AppTheme.baseGrey,
                    fontSize: 14.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getGutTrainingDescription(GutTraining gutTraining) {
    switch (gutTraining) {
      case GutTraining.low:
        return 'New to fueling during runs - start conservative';
      case GutTraining.moderate:
        return 'Some experience with sports nutrition';
      case GutTraining.high:
        return 'Experienced endurance athlete with high carb tolerance';
    }
  }
}