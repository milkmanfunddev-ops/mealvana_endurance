import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Reusable section widget for a single sport's during-workout override fields.
///
/// Displays carbs (g/hr), sodium (mg/hr), and fluids (ml/hr) with
/// sport-specific carb ceiling and optional carb field disabling (e.g. swimming).
class DuringSportOverrideSection extends StatelessWidget {
  const DuringSportOverrideSection({
    super.key,
    required this.sportLabel,
    required this.sportIcon,
    required this.carbController,
    required this.sodiumController,
    required this.fluidController,
    required this.maxCarbRate,
    required this.onChanged,
    this.carbsDisabled = false,
  });

  final String sportLabel;
  final IconData sportIcon;
  final TextEditingController carbController;
  final TextEditingController sodiumController;
  final TextEditingController fluidController;
  final double maxCarbRate;
  final VoidCallback onChanged;
  final bool carbsDisabled;

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
              Text(
                'During $sportLabel (per hour)',
                style: AppTextStyles.subtitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (carbsDisabled)
            _buildDisabledField(context, 'Carbs (g/hr)', 'N/A')
          else
            _buildField(context, 'Carbs (g/hr)', carbController, 0, maxCarbRate),
          _buildField(context, 'Sodium (mg/hr)', sodiumController, 0, 2000),
          _buildField(context, 'Fluids (ml/hr)', fluidController, 200, 3000),
        ],
      ),
    );
  }

  Widget _buildField(
    BuildContext context,
    String label,
    TextEditingController controller,
    double min,
    double max,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.2),
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                final parsed = double.tryParse(value.trim());
                if (parsed == null) return 'Invalid';
                if (parsed < min || parsed > max) {
                  return '${min.toInt()}-${max.toInt()}';
                }
                return null;
              },
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.1),
                ),
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.05),
              ),
              child: Text(
                placeholder,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
