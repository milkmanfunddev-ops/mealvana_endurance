import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Reusable section widget for a single sport's during-workout override fields.
///
/// Displays carbs (g/hr), sodium (mg/hr), and fluids (mL/hr or fl oz/hr,
/// depending on the user's unit-system preference) with optional carb field
/// disabling (e.g. swimming). The fluid controller's underlying value is
/// owned/converted by the parent screen - this widget only renders the
/// unit-aware label.
class DuringSportOverrideSection extends StatelessWidget {
  const DuringSportOverrideSection({
    super.key,
    required this.sportLabel,
    required this.sportIcon,
    required this.carbController,
    required this.sodiumController,
    required this.fluidController,
    required this.onChanged,
    required this.useMetric,
    this.carbsDisabled = false,
    this.showHighCarbRateWarning = false,
    this.highCarbRateWarningThreshold = 120,
    this.onHighCarbRateWarningInfoTap,
  });

  final String sportLabel;
  final IconData sportIcon;
  final TextEditingController carbController;
  final TextEditingController sodiumController;
  final TextEditingController fluidController;
  final VoidCallback onChanged;
  final bool useMetric;
  final bool carbsDisabled;
  final bool showHighCarbRateWarning;
  final double highCarbRateWarningThreshold;
  final VoidCallback? onHighCarbRateWarningInfoTap;

  @override
  Widget build(BuildContext context) {
    return BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(sportIcon, size: 18, color: AppColors.electrolyte),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'During $sportLabel (per hour)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (carbsDisabled)
            _buildDisabledField(context, 'Carbs (g/hr)', 'N/A')
          else
            _buildField(context, 'Carbs (g/hr)', carbController),
          if (!carbsDisabled && showHighCarbRateWarning)
            _buildHighCarbRateWarning(context),
          _buildField(context, 'Sodium (mg/hr)', sodiumController),
          _buildField(
            context,
            'Fluids (${UnitFormatter.fluidUnitLabel(useMetric: useMetric)}/hr)',
            fluidController,
          ),
        ],
      ),
    );
  }

  Widget _buildHighCarbRateWarning(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.warning,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'At or above ${highCarbRateWarningThreshold.toInt()} g/hr is an advanced carb target.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (onHighCarbRateWarningInfoTap != null)
              IconButton(
                onPressed: onHighCarbRateWarningInfoTap,
                icon: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: 'Why this warning?',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                hintText: 'Auto',
                hintStyle: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
                ),
              ),
              onChanged: (_) => onChanged(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisabledField(
    BuildContext context,
    String label,
    String placeholder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.05),
              ),
              child: Text(
                placeholder,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
