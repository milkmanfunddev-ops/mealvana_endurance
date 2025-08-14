import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/nutrition_plan_controller.dart';
import '../../data/models/nutrition_plan.dart';
import '../../../../theme/nutrition_theme_extension.dart';

/// Results screen showing generated nutrition plan
class PlanResultsScreen extends ConsumerWidget {
  const PlanResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nutritionColors = theme.extension<NutritionThemeExtension>();
    final planState = ref.watch(nutritionPlanControllerProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Nutrition Plan'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback),
            onPressed: () => context.push('/feedback'),
            tooltip: 'Give Feedback',
          ),
        ],
      ),
      body: planState.when(
        data: (plan) {
          if (plan == null) {
            return _EmptyState(
              onGeneratePressed: () => context.go('/home'),
            );
          }
          return _PlanContent(plan: plan, nutritionColors: nutritionColors);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error.toString(),
          onRetryPressed: () => context.go('/home'),
        ),
      ),
    );
  }
}

class _PlanContent extends ConsumerWidget {
  final NutritionPlan plan;
  final NutritionThemeExtension? nutritionColors;

  const _PlanContent({
    required this.plan,
    this.nutritionColors,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommendations = ref.watch(nutritionRecommendationsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Run summary
          _RunSummaryCard(plan: plan),
          
          SizedBox(height: 24.h),
          
          // Macro targets
          Text(
            'Nutrition Targets',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          _MacroTargetsGrid(plan: plan, nutritionColors: nutritionColors),
          
          SizedBox(height: 24.h),
          
          // Hourly breakdown
          Text(
            'Per Hour Requirements',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          
          SizedBox(height: 16.h),
          
          _HourlyBreakdownCard(plan: plan, nutritionColors: nutritionColors),
          
          SizedBox(height: 24.h),
          
          // Recommendations
          if (recommendations.isNotEmpty) ...[
            Text(
              'Recommendations',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 16.h),
            
            _RecommendationsCard(recommendations: recommendations),
            
            SizedBox(height: 24.h),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Create New Plan'),
                ),
              ),
              
              SizedBox(width: 16.w),
              
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push('/feedback'),
                  child: const Text('Give Feedback'),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}

class _RunSummaryCard extends StatelessWidget {
  final NutritionPlan plan;

  const _RunSummaryCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            Text(
              'Run Summary',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 16.h),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryItem(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${plan.distanceMiles.toStringAsFixed(1)} mi',
                ),
                _SummaryItem(
                  icon: Icons.speed,
                  label: 'Pace',
                  value: _formatPace(plan.paceMinutesPerMile),
                ),
                _SummaryItem(
                  icon: Icons.schedule,
                  label: 'Duration',
                  value: _formatDuration(plan.durationHours),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPace(double paceMinutesPerMile) {
    final minutes = paceMinutesPerMile.floor();
    final seconds = ((paceMinutesPerMile - minutes) * 60).round();
    return '${minutes}:${seconds.toString().padLeft(2, '0')}/mi';
  }

  String _formatDuration(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          icon,
          size: 24.w,
          color: theme.colorScheme.primary,
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MacroTargetsGrid extends StatelessWidget {
  final NutritionPlan plan;
  final NutritionThemeExtension? nutritionColors;

  const _MacroTargetsGrid({
    required this.plan,
    this.nutritionColors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MacroCard(
            label: 'Carbs',
            value: '${plan.totalCarbs.toStringAsFixed(0)}g',
            color: nutritionColors?.carbsColor ?? Colors.orange,
            icon: Icons.grain,
          ),
        ),
        
        SizedBox(width: 12.w),
        
        Expanded(
          child: _MacroCard(
            label: 'Sodium',
            value: '${plan.totalSodium.toStringAsFixed(0)}mg',
            color: nutritionColors?.sodiumColor ?? Colors.blue,
            icon: Icons.water_drop,
          ),
        ),
        
        SizedBox(width: 12.w),
        
        Expanded(
          child: _MacroCard(
            label: 'Fluids',
            value: '${plan.totalFluids.toStringAsFixed(0)} fl oz',
            color: nutritionColors?.fluidsColor ?? Colors.lightBlue,
            icon: Icons.local_drink,
          ),
        ),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28.w,
              color: color,
            ),
            SizedBox(height: 8.h),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyBreakdownCard extends StatelessWidget {
  final NutritionPlan plan;
  final NutritionThemeExtension? nutritionColors;

  const _HourlyBreakdownCard({
    required this.plan,
    this.nutritionColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Per Hour Intake',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 16.h),
            
            _HourlyItem(
              label: 'Carbohydrates',
              value: '${plan.carbsPerHour.toStringAsFixed(0)}g/hour',
              color: nutritionColors?.carbsColor ?? Colors.orange,
            ),
            
            SizedBox(height: 12.h),
            
            _HourlyItem(
              label: 'Sodium',
              value: '${plan.sodiumPerHour.toStringAsFixed(0)}mg/hour',
              color: nutritionColors?.sodiumColor ?? Colors.blue,
            ),
            
            SizedBox(height: 12.h),
            
            _HourlyItem(
              label: 'Fluids',
              value: '${plan.fluidsPerHour.toStringAsFixed(0)} fl oz/hour',
              color: nutritionColors?.fluidsColor ?? Colors.lightBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HourlyItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 4.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        
        SizedBox(width: 12.w),
        
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: theme.colorScheme.primary,
                  size: 20.w,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Tips for Your Plan',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 12.h),
            
            ...recommendations.map((recommendation) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4.w,
                    height: 4.h,
                    margin: EdgeInsets.only(top: 8.h, right: 12.w),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      recommendation,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onGeneratePressed;

  const _EmptyState({required this.onGeneratePressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calculate,
              size: 64.w,
              color: theme.colorScheme.primary,
            ),
            
            SizedBox(height: 24.h),
            
            Text(
              'No Plan Generated',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 8.h),
            
            Text(
              'Generate a nutrition plan to see your personalized recommendations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 32.h),
            
            ElevatedButton(
              onPressed: onGeneratePressed,
              child: const Text('Generate Plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetryPressed;

  const _ErrorState({
    required this.error,
    required this.onRetryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: theme.colorScheme.error,
            ),
            
            SizedBox(height: 24.h),
            
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 8.h),
            
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 32.h),
            
            ElevatedButton(
              onPressed: onRetryPressed,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}