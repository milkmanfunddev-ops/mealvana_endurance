import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/macro_targets.dart';

/// Header widget displaying run summary information (distance, duration, pace)
/// Shows key run metrics at the top of the adjust macros screen
class RunSummaryHeader extends StatelessWidget {
  const RunSummaryHeader({
    super.key,
    required this.macroTargets,
  });

  final MacroTargets macroTargets;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metrics = macroTargets.metrics;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Run Summary',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          
          SizedBox(height: 12.h),
          
          // Main metrics row
          Row(
            children: [
              // Distance
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Distance',
                  '${metrics.distanceMi.toStringAsFixed(1)} mi',
                  Icons.straighten,
                ),
              ),
              
              // Duration
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Duration',
                  metrics.formattedDuration,
                  Icons.schedule,
                ),
              ),
              
              // Pace
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Pace',
                  '${metrics.formattedPace}/mi',
                  Icons.speed,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 16.h),
          
          // Secondary metrics row
          Row(
            children: [
              // Calories
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Calories',
                  '${metrics.caloriesNetKcal.round()} kcal',
                  Icons.local_fire_department,
                ),
              ),
              
              // Speed
              Expanded(
                child: _buildMetricColumn(
                  context,
                  'Speed',
                  '${metrics.speedMph.toStringAsFixed(1)} mph',
                  Icons.flash_on,
                ),
              ),
              
              // Empty space for alignment
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and label row
        Row(
          children: [
            Icon(
              icon,
              size: 16.sp,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 4.h),
        
        // Value
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}