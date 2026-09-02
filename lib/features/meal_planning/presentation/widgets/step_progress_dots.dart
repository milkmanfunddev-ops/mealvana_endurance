import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// Cooking-mode progress dots: one per step, current step accented.
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        final done = i < current;
        return Container(
          width: active ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: active
                ? AppColors.orange
                : done
                ? AppColors.orange.withValues(alpha: 0.5)
                : (isDark
                      ? AppColors.cream.withValues(alpha: 0.25)
                      : AppColors.blackberry.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
