import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Welcome screen - first screen users see
/// Simple introduction to the app with call-to-action to start onboarding
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              SizedBox(height: 80.h),
              
              // App logo/icon placeholder
              Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60.r),
                ),
                child: Icon(
                  Icons.run_circle,
                  size: 64.w,
                  color: theme.colorScheme.primary,
                ),
              ),
              
              SizedBox(height: 40.h),
              
              // App title
              Text(
                'Mealvana Endurance',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 16.h),
              
              // Subtitle
              Text(
                'Personalized Nutrition Plans\nfor Long Run Days',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 60.h),
              
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/onboarding/profile'),
                  child: Text('Get Started'),
                ),
              ),
              
              SizedBox(height: 16.h),
              
              // Skip for now option (for testing)
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text('Skip for Now'),
              ),
              
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
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            size: 24.w,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        
        SizedBox(width: 16.w),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 4.h),
              
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}