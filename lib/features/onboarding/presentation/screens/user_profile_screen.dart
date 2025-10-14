import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../auth/application/auth_service.dart';
import '../../../auth/data/user_repository.dart';
import '../../../../shared/services/app_external_deps.dart';

/// User profile creation screen
/// Collects basic user information during onboarding
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  Gender? _selectedGender;
  DateTime? _selectedBirthday;
  final _heightFeetController = TextEditingController();
  final _heightInchesController = TextEditingController();
  final _weightController = TextEditingController();
  bool _runsWithWaterBottle = false;

  @override
  void initState() {
    super.initState();
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'User Profile Onboarding',
    });
  }

  @override
  void dispose() {
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _selectBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  void _submitProfile() async {
    if (!_formKey.currentState!.validate() || 
        _selectedGender == null || 
        _selectedBirthday == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
      }
      return;
    }

    // Track form submission attempt
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track('user_profile_submit_attempt', properties: {
      'gender': _selectedGender!.name,
      'runs_with_water_bottle': _runsWithWaterBottle,
      'height_feet': _heightFeetController.text,
      'height_inches': _heightInchesController.text,
      'weight': _weightController.text,
    });

    final controller = ref.read(onboardingControllerProvider.notifier);
    
    final success = await controller.createUserProfile(
      gender: _selectedGender!,
      birthday: _selectedBirthday!,
      heightFeet: int.parse(_heightFeetController.text),
      heightInches: int.parse(_heightInchesController.text),
      weightPounds: double.parse(_weightController.text),
      runsWithWaterBottle: _runsWithWaterBottle,
    );

    if (success && mounted) {
      // Track successful navigation
      await analytics.track('navigation', properties: {
        'destination': 'Food Preferences Onboarding',
        'source': 'User Profile Submit',
      });
      
      // Invalidate providers to refresh user state
      ref.invalidate(currentUserProvider);
      ref.invalidate(userRepositoryProvider);
      
      if (mounted) {
        context.push('/onboarding/food-preferences');
      }
    } else if (mounted) {
      // Show error if user creation failed
      final state = ref.read(onboardingControllerProvider);
      final errorMessage = state.asError?.error.toString() ?? 'Failed to create profile';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(onboardingControllerProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          'Your Profile',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 20.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              LinearProgressIndicator(
                value: 0.5, // 50% through onboarding
                backgroundColor: AppTheme.baseGrey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary600),
              ),
              
              SizedBox(height: 32.h),
              
              Text(
                'Tell us about yourself',
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                'This helps us calculate accurate nutrition plans for your runs.',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  color: AppTheme.baseGrey,
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Gender selection
              Text(
                'Gender',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Row(
                children: Gender.values.map((gender) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: gender == Gender.values.last ? 0 : 8.w),
                      child: ChoiceChip(
                        label: Text(
                          _genderDisplayName(gender),
                          style: TextStyle(
                            color: _selectedGender == gender 
                                ? AppTheme.baseWhite 
                                : AppTheme.primary900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        selected: _selectedGender == gender,
                        selectedColor: AppTheme.primary900,
                        backgroundColor: AppTheme.baseWhite,
                        side: BorderSide(
                          color: AppTheme.primary900,
                          width: 1.5,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedGender = selected ? gender : null;
                          });
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              SizedBox(height: 24.h),
              
              // Birthday selection
              Text(
                'Birthday',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              GestureDetector(
                onTap: _selectBirthday,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.baseGrey),
                      SizedBox(width: 12.w),
                      Text(
                        _selectedBirthday?.toString().split(' ')[0] ?? 'Select your birthday',
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 16.sp,
                          color: _selectedBirthday != null 
                              ? AppTheme.primary900 
                              : AppTheme.baseGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 24.h),
              
              // Height input
              Text(
                'Height',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightFeetController,
                      style: TextStyle(
                        color: AppTheme.primary900,
                        fontSize: 16.sp,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Feet',
                        suffixText: 'ft',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final feet = int.tryParse(value!);
                        if (feet == null || feet < 3 || feet > 8) {
                          return 'Enter valid feet (3-8)';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  SizedBox(width: 16.w),
                  
                  Expanded(
                    child: TextFormField(
                      controller: _heightInchesController,
                      style: TextStyle(
                        color: AppTheme.primary900,
                        fontSize: 16.sp,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Inches',
                        suffixText: 'in',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final inches = int.tryParse(value!);
                        if (inches == null || inches < 0 || inches >= 12) {
                          return 'Enter valid inches (0-11)';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24.h),
              
              // Weight input
              Text(
                'Weight',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              TextFormField(
                controller: _weightController,
                style: TextStyle(
                  color: AppTheme.primary900,
                  fontSize: 16.sp,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'lbs',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  final weight = double.tryParse(value!);
                  if (weight == null || weight < 80 || weight > 500) {
                    return 'Enter valid weight (80-500 lbs)';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24.h),
              
              // Water bottle question
              Text(
                'Running Habits',
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              SwitchListTile(
                title: const Text('Do you run with a water bottle?'),
                subtitle: const Text('This helps us estimate your hydration needs'),
                value: _runsWithWaterBottle,
                onChanged: (value) {
                  setState(() {
                    _runsWithWaterBottle = value;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              SizedBox(height: 40.h),
              
              // Continue button
              PrimaryButton(
                text: 'Continue',
                onPressed: asyncState.isLoading ? null : _submitProfile,
                isLoading: asyncState.isLoading,
                width: double.infinity,
              ),
              
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  String _genderDisplayName(Gender gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}
