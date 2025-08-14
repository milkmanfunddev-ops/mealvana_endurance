import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/feedback_controller.dart';
import '../../application/feedback_service.dart';

/// Screen for collecting feedback about the nutrition plan
class PlanFeedbackScreen extends ConsumerStatefulWidget {
  const PlanFeedbackScreen({super.key});

  @override
  ConsumerState<PlanFeedbackScreen> createState() => _PlanFeedbackScreenState();
}

class _PlanFeedbackScreenState extends ConsumerState<PlanFeedbackScreen> {
  PlanFeedbackType? _selectedFeedback;
  final _commentsController = TextEditingController();

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_selectedFeedback == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your feedback')),
      );
      return;
    }

    final controller = ref.read(feedbackControllerProvider.notifier);
    final success = await controller.submitPlanFeedback(
      feedbackType: _selectedFeedback!,
      additionalComments: _commentsController.text.trim().isEmpty 
          ? null 
          : _commentsController.text.trim(),
    );

    if (success && mounted) {
      // Show success and navigate to app feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      
      // Go to app feedback screen
      context.go('/feedback/app');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(feedbackControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Feedback'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator - Step 1 of 2
            LinearProgressIndicator(
              value: 0.5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            
            SizedBox(height: 24.h),
            
            // Header
            Text(
              'What do you think about this plan?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 8.h),
            
            Text(
              'Your feedback helps us improve our nutrition calculations.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            SizedBox(height: 32.h),
            
            // Feedback options
            _FeedbackOption(
              type: PlanFeedbackType.prettyClose,
              title: 'Pretty close to what I think I should use',
              description: 'The recommendations align with my expectations',
              icon: Icons.thumb_up,
              isSelected: _selectedFeedback == PlanFeedbackType.prettyClose,
              onTap: () => setState(() => _selectedFeedback = PlanFeedbackType.prettyClose),
            ),
            
            SizedBox(height: 16.h),
            
            _FeedbackOption(
              type: PlanFeedbackType.muchMore,
              title: 'Much more than what I think I should use',
              description: 'The amounts seem too high for my needs',
              icon: Icons.trending_up,
              isSelected: _selectedFeedback == PlanFeedbackType.muchMore,
              onTap: () => setState(() => _selectedFeedback = PlanFeedbackType.muchMore),
            ),
            
            SizedBox(height: 16.h),
            
            _FeedbackOption(
              type: PlanFeedbackType.muchLess,
              title: 'Much less than what I think I should use',
              description: 'The amounts seem too low for my needs',
              icon: Icons.trending_down,
              isSelected: _selectedFeedback == PlanFeedbackType.muchLess,
              onTap: () => setState(() => _selectedFeedback = PlanFeedbackType.muchLess),
            ),
            
            SizedBox(height: 32.h),
            
            // Additional comments
            Text(
              'Additional Comments (Optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            SizedBox(height: 12.h),
            
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(
                hintText: 'Tell us more about your experience with this plan...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            
            SizedBox(height: 40.h),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: asyncState.isLoading ? null : _submitFeedback,
                child: asyncState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Continue'),
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Skip button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go('/feedback/app'),
                child: const Text('Skip this feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackOption extends StatelessWidget {
  final PlanFeedbackType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedbackOption({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: isSelected 
                    ? theme.colorScheme.primary 
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                icon,
                color: isSelected 
                    ? theme.colorScheme.onPrimary 
                    : theme.colorScheme.onSurfaceVariant,
                size: 24.w,
              ),
            ),
            
            SizedBox(width: 16.w),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected 
                          ? theme.colorScheme.onPrimaryContainer 
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  
                  SizedBox(height: 4.h),
                  
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isSelected 
                          ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
                size: 24.w,
              ),
          ],
        ),
      ),
    );
  }
}