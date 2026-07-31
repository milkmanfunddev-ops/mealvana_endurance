import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/app_config.dart';

/// Wrench indicator that appears when app is in development mode
/// Shows in the top-right corner of the screen
class EnvironmentIndicator extends ConsumerWidget {
  const EnvironmentIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);

    // Only show in development mode
    if (!config.devModeEnabled) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 50.h,
      right: 16.w,
      child: Container(
        padding: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(Icons.build, color: Colors.black87, size: 20.sp),
      ),
    );
  }
}

/// Stack wrapper that adds the environment indicator to a screen
class ScreenWithEnvironmentIndicator extends StatelessWidget {
  final Widget child;

  const ScreenWithEnvironmentIndicator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [child, const EnvironmentIndicator()]);
  }
}
