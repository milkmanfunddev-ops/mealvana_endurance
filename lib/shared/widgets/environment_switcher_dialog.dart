import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';
import '../services/app_config.dart';

/// Secret environment switcher dialog
/// Allows switching between dev and prod environments at runtime
class EnvironmentSwitcherDialog extends StatelessWidget {
  final AppConfig config;

  const EnvironmentSwitcherDialog({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    final currentMode = config.devModeEnabled ? 'Development' : 'Production';
    final currentMixpanel = config.devModeEnabled
        ? 'Mealvana Endurance Dev'
        : 'Mealvana Endurance';
    final currentSentry = config.sentryEnvironment;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.build, size: 24),
          const SizedBox(width: 8),
          const Text('Environment Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current environment info
            Text(
              'Current Environment',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
              ),
            ),
            SizedBox(height: 8.h),
            _buildInfoRow('Mode', currentMode),
            _buildInfoRow('Mixpanel', currentMixpanel),
            _buildInfoRow('Sentry', currentSentry),
            _buildInfoRow('Supabase', _getSupabaseProject(config.supabaseUrl)),

            SizedBox(height: 16.h),
            const Divider(),
            SizedBox(height: 16.h),

            // Warning message
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppTheme.highlight600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: AppTheme.highlight600),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.highlight600,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'App restart required after changing environment',
                      style: TextStyle(
                        color: AppTheme.highlight600,
                        fontSize: 13.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (config.devModeEnabled)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary600,
            ),
            onPressed: () async {
              await AppConfig.setDevModeOverride(false);
              if (context.mounted) {
                Navigator.of(context).pop();
                _showRestartDialog(context, 'Production');
              }
            },
            child: const Text('Switch to Production'),
          )
        else
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary600,
            ),
            onPressed: () async {
              await AppConfig.setDevModeOverride(true);
              if (context.mounted) {
                Navigator.of(context).pop();
                _showRestartDialog(context, 'Development');
              }
            },
            child: const Text('Switch to Development'),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14.sp,
                color: AppTheme.baseGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                color: AppTheme.baseBlack,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSupabaseProject(String url) {
    if (url.contains('vlmtsdzpnjnavdgytcmi')) {
      return 'Dev';
    } else if (url.contains('wvmvsodrvbkxfydabqed')) {
      return 'Production';
    }
    return 'Unknown';
  }

  void _showRestartDialog(BuildContext context, String newMode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restart_alt, size: 24),
            SizedBox(width: 8),
            Text('Restart Required'),
          ],
        ),
        content: Text(
          'Environment switched to $newMode mode.\n\nPlease force-quit and restart the app for changes to take effect.',
          style: TextStyle(fontSize: 14.sp),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary600,
            ),
            onPressed: () {
              // Force exit the app
              exit(0);
            },
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }
}
