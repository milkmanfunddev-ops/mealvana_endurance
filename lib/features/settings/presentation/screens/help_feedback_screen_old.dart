import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../../theme/app_theme.dart';

/// Help & Feedback Screen - Support and bug reporting
class HelpFeedbackScreen extends ConsumerWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Help & Feedback',
          style: AppTheme.titleStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We\'re here to help',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 14.sp,
              ),
            ),
            SizedBox(height: 20.h),

            // Report Bug
            _buildReportBugButton(context),
            SizedBox(height: 16.h),

            // Contact Support (placeholder for future)
            _buildContactSupportButton(context),
            SizedBox(height: 16.h),

            // FAQ (placeholder for future)
            _buildFaqButton(context),
            SizedBox(height: 16.h),

            // About section
            _buildAboutSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReportBugButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Capture a screenshot automatically
        final screenshot = await SentryFlutter.captureScreenshot();

        if (!context.mounted) return;

        // Show the SentryFeedbackWidget
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SentryFeedbackWidget(
              screenshot: screenshot,
            ),
            fullscreenDialog: true,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bug_report_outlined,
              size: 24.sp,
              color: AppTheme.primary600,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report a Bug',
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Help us improve by reporting issues',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: AppTheme.primary600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSupportButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement contact support (email, chat, etc.)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Contact support coming soon!'),
            backgroundColor: AppTheme.primary600,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.support_agent_outlined,
              size: 24.sp,
              color: AppTheme.primary600,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Support',
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Get help from our team',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: AppTheme.primary600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement FAQ screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('FAQ coming soon!'),
            backgroundColor: AppTheme.primary600,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppTheme.baseWhite,
          border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.help_outline,
              size: 24.sp,
              color: AppTheme.primary600,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FAQ',
                    style: AppTheme.textStyle.copyWith(
                      color: AppTheme.baseBlack,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Common questions and answers',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: AppTheme.primary600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 24.sp,
                color: AppTheme.primary600,
              ),
              SizedBox(width: 12.w),
              Text(
                'About',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'Mealvana Endurance',
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Version 1.7.0',
            style: AppTheme.noteStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Personalized nutrition planning for endurance athletes',
            style: AppTheme.noteStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }
}
