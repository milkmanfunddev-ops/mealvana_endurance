import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Cooking-mode progress: one thin bar per step spanning the full width,
/// filled up to and including the current step (prototype's step strip).
class StepProgressDots extends StatelessWidget {
  const StepProgressDots({
    super.key,
    required this.count,
    required this.current,
  });

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rest = isDark
        ? AppColors.cream.withValues(alpha: 0.15)
        : AppColors.blackberry.withValues(alpha: 0.15);

    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i <= current ? AppColors.electrolyteDark : rest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
