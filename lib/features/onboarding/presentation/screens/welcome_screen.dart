import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/secondary_button.dart';

/// Welcome screen - first screen users see
/// Simple introduction to the app with call-to-action to start onboarding
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 80.h),

              // App logo
              SizedBox(
                width: 120.w,
                height: 120.h,
                child: Image.asset(
                  'assets/images/endurance_welcome_logo_base_cream.png',
                  width: 120.w,
                  height: 120.h,
                  fit: BoxFit.contain,
                ),
              ),

              SizedBox(height: 16.h),

              // App title
              Text(
                'Endurance',
                style: AppTheme.heading1Style.copyWith(
                  color: AppTheme.primary900,
                  fontSize: 32.sp,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16.h),

              // Subtitle
              Text(
                'Personalized Nutrition Plans\nfor Long Run Days',
                style: AppTheme.subtitleStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 18.sp,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 32.h),
              
              // Features list
              _FeatureItem(
                icon: Icons.calculate,
                title: 'Smart Calculations',
                description: 'Evidence-based nutrition formulas tailored to your body and run distance',
              ),
              
              SizedBox(height: 24.h),
              
              _FeatureItem(
                icon: Icons.restaurant,
                title: 'Food Preferences',
                description: 'Plans based on foods you actually like and want to try',
              ),
              
              SizedBox(height: 24.h),
              
              _FeatureItem(
                icon: Icons.offline_bolt,
                title: 'Offline Ready',
                description: 'Works completely offline - no internet required',
              ),
              
              const Spacer(),
              
              // Get started button
              PrimaryButton(
                text: 'Get Started',
                onPressed: () => context.go('/onboarding/profile'),
                width: double.infinity,
              ),

              // SizedBox(height: 16.h),

              // // Skip for now option (for testing)
              // SecondaryButton(
              //   text: 'Skip for Now',
              //   onPressed: () => context.go('/main'),
              //   width: double.infinity,
              // ),
              
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: AppTheme.primary100,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [AppTheme.dropShadow],
          ),
          child: Icon(
            icon,
            size: 24.w,
            color: AppTheme.primary600,
          ),
        ),

        SizedBox(width: 16.w),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.heading3Style.copyWith(
                  fontSize: 16.sp,
                  color: AppTheme.primary900,
                ),
              ),

              SizedBox(height: 4.h),

              Text(
                description,
                style: AppTheme.textStyle.copyWith(
                  fontSize: 14.sp,
                  color: AppTheme.baseGrey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}