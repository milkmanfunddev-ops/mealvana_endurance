import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_controller.dart';
import '../../../auth/data/models/user_preferences.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final controller = ref.read(onboardingControllerProvider.notifier);
    
    final success = await controller.createUserProfile(
      gender: _selectedGender!,
      birthday: _selectedBirthday!,
      heightFeet: int.parse(_heightFeetController.text),
      heightInches: int.parse(_heightInchesController.text),
      weightPounds: double.parse(_weightController.text),
      runsWithWaterBottle: _runsWithWaterBottle,
    );

    if (success) {
      context.go('/onboarding/food-preferences');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(onboardingControllerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
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
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              
              SizedBox(height: 32.h),
              
              Text(
                'Tell us about yourself',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                'This helps us calculate accurate nutrition plans for your runs.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Gender selection
              Text(
                'Gender',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Row(
                children: Gender.values.map((gender) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: gender == Gender.values.last ? 0 : 8.w),
                      child: ChoiceChip(
                        label: Text(_genderDisplayName(gender)),
                        selected: _selectedGender == gender,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              GestureDetector(
                onTap: _selectBirthday,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: theme.colorScheme.onSurfaceVariant),
                      SizedBox(width: 12.w),
                      Text(
                        _selectedBirthday?.toString().split(' ')[0] ?? 'Select your birthday',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _selectedBirthday != null 
                              ? theme.colorScheme.onSurface 
                              : theme.colorScheme.onSurfaceVariant,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightFeetController,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              TextFormField(
                controller: _weightController,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: asyncState.isLoading ? null : _submitProfile,
                  child: asyncState.isLoading 
                      ? const CircularProgressIndicator()
                      : const Text('Continue'),
                ),
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