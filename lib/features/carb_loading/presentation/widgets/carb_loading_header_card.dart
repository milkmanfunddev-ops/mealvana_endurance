import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/carb_loading_plan_simple.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';

/// Blue header card widget matching screenshot design exactly
/// Shows race info, countdown, and carb loading status
class CarbLoadingHeaderCard extends StatelessWidget {
  final CarbLoadingPlan plan;
  final String contentPrefix;

  const CarbLoadingHeaderCard({
    super.key,
    required this.plan,
    this.contentPrefix = 'carb_loading',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primary900,
            AppTheme.primary900.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Race type and countdown row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Race type
                Text(
                  plan.raceDistance.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Days countdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.daysUntilRace}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'days',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Race date
            Text(
              DateFormat('MMM d, yyyy').format(plan.raceDate),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),

            const SizedBox(height: 16),

            // Carb target with green checkmark icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(plan.carbsPerKgTarget * 0.453592).toStringAsFixed(1)}g carbs/lb target',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Status message
            Text(
              _getStatusMessage(plan),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get status message based on carb loading timing
  String _getStatusMessage(CarbLoadingPlan plan) {
    final daysUntilStart = plan.daysUntilCarbLoadingStarts;

    if (daysUntilStart > 0) {
      return 'Carb loading starts in $daysUntilStart days';
    } else if (plan.isCarbLoadingActive) {
      return 'Carb loading in progress';
    } else if (plan.daysUntilRace == 0) {
      return 'Race day - time to fuel!';
    } else {
      return 'Race preparation complete';
    }
  }
}
