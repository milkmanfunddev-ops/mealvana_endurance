import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/enums.dart';

/// Warning banner for low energy availability
class EaWarningBanner extends StatelessWidget {
  const EaWarningBanner({super.key, required this.eaStatus, this.eaValue});

  final EaStatus eaStatus;
  final double? eaValue;

  @override
  Widget build(BuildContext context) {
    if (eaStatus == EaStatus.ok) return const SizedBox.shrink();

    final isBlock = eaStatus == EaStatus.block;
    final isHard = eaStatus == EaStatus.hardWarning;

    final backgroundColor = isBlock
        ? AppColors.dragonfruit.withValues(alpha: 0.15)
        : isHard
        ? AppColors.orange.withValues(alpha: 0.15)
        : AppColors.orange.withValues(alpha: 0.1);
    final iconColor = isBlock ? AppColors.dragonfruit : AppColors.orange;
    final textColor = isBlock ? AppColors.dragonfruit : AppColors.orange;

    final message = isBlock
        ? 'Energy availability too low. Please consult a sports dietitian.'
        : isHard
        ? 'Very low energy availability detected. Consider increasing intake.'
        : 'Energy availability is on the low side. Monitor your intake.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.triangleExclamation,
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
