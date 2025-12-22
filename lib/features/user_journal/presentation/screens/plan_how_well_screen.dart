import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/primary_button.dart';
import '../../../../theme/app_theme.dart';
import '../providers/plan_rating_controller.dart';

/// Screen for users to rate how well their nutrition plan worked
/// Shown after a run is completed (via notification or app startup)
class PlanHowWellScreen extends ConsumerStatefulWidget {
  const PlanHowWellScreen({
    super.key,
    required this.activityId,
  });

  final String activityId;

  @override
  ConsumerState<PlanHowWellScreen> createState() => _PlanHowWellScreenState();
}

class _PlanHowWellScreenState extends ConsumerState<PlanHowWellScreen> {
  int? selectedRating;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(planRatingControllerProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        // title: Text(
        //   'Plan evaluation',
        //   style: AppTheme.textStyle.copyWith(
        //     color: AppTheme.baseGrey,
        //     fontSize: 16.sp,
        //   ),
        // ),
        // leading: IconButton(
        //   icon: Icon(
        //     Icons.arrow_back,
        //     color: AppTheme.primary900,
        //   ),
        //   onPressed: () {
        //     // Try to go back, or navigate to main if no back stack
        //     if (Navigator.of(context).canPop()) {
        //       context.pop();
        //     } else {
        //       context.go('/main');
        //     }
        //   },
        // ),
        actions: [
          // Skip button
          TextButton(
            onPressed: _handleSkip,
            child: Text(
              'Skip',
              style: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 16.sp,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SizedBox(height: 32.h),
                
                // Hand illustration
                SizedBox(
                  height: 260.h,
                  child: Image.asset(
                    'assets/images/hand.png',
                    fit: BoxFit.contain,
                  ),
                ),
                
                // SizedBox(height: 24.h),
                
                // Question text
                Text(
                  'How well did this plan work for your pre-workout needs?',
                  textAlign: TextAlign.center,
                  style: AppTheme.titleStyle.copyWith(
                    fontSize: 22.sp,
                    color: AppTheme.primary900,
                    height: 1.3,
                  ),
                ),
                
                SizedBox(height: 32.h),
                
                // Rating options
                Column(
                  children: [
                    _buildRatingOption(
                      rating: 3,
                      emoji: '😍',
                      label: 'Satisfied',
                      isSelected: selectedRating == 3,
                    ),
                    SizedBox(height: 12.h),
                    _buildRatingOption(
                      rating: 2,
                      emoji: '😐',
                      label: 'Neutral',
                      isSelected: selectedRating == 2,
                    ),
                    SizedBox(height: 12.h),
                    _buildRatingOption(
                      rating: 1,
                      emoji: '😔',
                      label: 'Could be better',
                      isSelected: selectedRating == 1,
                    ),
                  ],
                ),
                
                SizedBox(height: 32.h),
              
              // Submit button
              controller.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, stack) => Column(
                  children: [
                    Text(
                      'Error: ${error.toString()}',
                      style: TextStyle(color: AppTheme.warningColor),
                    ),
                    SizedBox(height: 16.h),
                    _buildButtonRow(),
                  ],
                ),
                data: (_) => _buildButtonRow(),
              ),
              
              SizedBox(height: 24.h),
            ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildRatingOption({
    required int rating,
    required String emoji,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedRating = rating;
        });
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary100 : Colors.transparent,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isSelected ? AppTheme.primary600 : AppTheme.highlight490,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 24.sp),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: AppTheme.textStyle.copyWith(
                fontSize: 18.sp,
                color: AppTheme.primary900,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow() {
    return Column(
      children: [
        // Primary submit button (full width)
        SizedBox(
          width: double.infinity,
          child: PrimaryButton(
            text: 'Submit',
            onPressed: selectedRating != null ? _handleSubmit : null,
          ),
        ),
        
        SizedBox(height: 16.h),
        
        // Skip button
        TextButton(
          onPressed: _handleSkip,
          child: Text(
            'Skip for now',
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.baseGrey,
              fontSize: 16.sp,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (selectedRating == null) return;

    try {
      await ref.read(planRatingControllerProvider.notifier)
          .submitRating(widget.activityId, selectedRating!);

      if (!mounted) return;

      await context.pushNamed(
        'voice-memo',
        pathParameters: {'activityId': widget.activityId},
        extra: {'rating': selectedRating},
      );

      if (!mounted) return;
      context.go('/main?tab=workout-notes');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rating: $error'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }
  }
  
  Future<void> _handleSkip() async {
    try {
      // Mark plan as skipped so it won't show this screen again
      await ref.read(planRatingControllerProvider.notifier)
          .skipFeedback(widget.activityId);
      
      if (mounted) {
        // Navigate to main tabs
        context.go('/main');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to skip feedback: $error'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        // Even if skip fails, still navigate away to avoid being stuck
        context.go('/main');
      }
    }
  }
}
