import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/nutrition_plan_controller.dart';

/// Main screen for inputting run details and generating nutrition plan
class PlanInputScreen extends ConsumerStatefulWidget {
  const PlanInputScreen({super.key});

  @override
  ConsumerState<PlanInputScreen> createState() => _PlanInputScreenState();
}

class _PlanInputScreenState extends ConsumerState<PlanInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _paceMinutesController = TextEditingController();
  final _paceSecondsController = TextEditingController();

  @override
  void dispose() {
    _distanceController.dispose();
    _paceMinutesController.dispose();
    _paceSecondsController.dispose();
    super.dispose();
  }

  Future<void> _generatePlan() async {
    if (!_formKey.currentState!.validate()) return;

    final distance = double.parse(_distanceController.text);
    final paceMinutes = int.parse(_paceMinutesController.text);
    final paceSeconds = int.parse(_paceSecondsController.text);
    final paceDecimal = paceMinutes + (paceSeconds / 60.0);

    final controller = ref.read(nutritionPlanControllerProvider.notifier);
    final plan = await controller.generatePlan(
      distanceMiles: distance,
      paceMinutesPerMile: paceDecimal,
    );

    if (plan != null && mounted) {
      context.go('/plan-results');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(nutritionPlanControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Nutrition'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Tell us about your run',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 8.h),
              
              Text(
                'We\'ll calculate personalized nutrition requirements based on your run details and profile.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Distance input
              Text(
                'Distance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              TextFormField(
                controller: _distanceController,
                decoration: const InputDecoration(
                  labelText: 'How far are you running?',
                  suffixText: 'miles',
                  helperText: 'Enter your planned distance',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Distance is required';
                  final distance = double.tryParse(value!);
                  if (distance == null || distance <= 0) {
                    return 'Enter a valid distance';
                  }
                  if (distance > 200) {
                    return 'Distance seems too high (max 200 miles)';
                  }
                  return null;
                },
              ),
              
              SizedBox(height: 24.h),
              
              // Pace input
              Text(
                'Average Pace',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Text(
                'What pace do you plan to maintain?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paceMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        suffixText: 'min',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final minutes = int.tryParse(value!);
                        if (minutes == null || minutes < 4 || minutes > 20) {
                          return '4-20 min';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  SizedBox(width: 16.w),
                  
                  Expanded(
                    child: TextFormField(
                      controller: _paceSecondsController,
                      decoration: const InputDecoration(
                        labelText: 'Seconds',
                        suffixText: 'sec',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        final seconds = int.tryParse(value!);
                        if (seconds == null || seconds < 0 || seconds >= 60) {
                          return '0-59 sec';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 24.h),
              
              // Pace examples
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20.w,
                          color: theme.colorScheme.primary,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Common Paces',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '• Easy/Recovery: 8:30 - 10:00 per mile\n'
                      '• Moderate: 7:30 - 8:30 per mile\n'
                      '• Marathon: 6:50 - 8:00 per mile\n'
                      '• Half Marathon: 6:20 - 7:30 per mile',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40.h),
              
              // Generate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: asyncState.isLoading ? null : _generatePlan,
                  child: asyncState.isLoading
                      ? const CircularProgressIndicator()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.calculate),
                            SizedBox(width: 8.w),
                            const Text('Generate Nutrition Plan'),
                          ],
                        ),
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // Error display
              if (asyncState.hasError)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                        size: 20.w,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          asyncState.error.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}