import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../providers/feedback_controller.dart';
import '../../application/feedback_service.dart';

/// Screen for collecting general app feedback
class AppFeedbackScreen extends ConsumerStatefulWidget {
  const AppFeedbackScreen({super.key});

  @override
  ConsumerState<AppFeedbackScreen> createState() => _AppFeedbackScreenState();
}

class _AppFeedbackScreenState extends ConsumerState<AppFeedbackScreen> {
  AppFeedbackType? _selectedFeedback;
  final _suggestionsController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _suggestionsController.dispose();
    _reasonController.dispose();
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
    final success = await controller.submitAppFeedback(
      feedbackType: _selectedFeedback!,
      suggestions: _selectedFeedback == AppFeedbackType.hasPotential
          ? _suggestionsController.text.trim().isEmpty ? null : _suggestionsController.text.trim()
          : null,
      reason: _selectedFeedback == AppFeedbackType.notInterested
          ? _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim()
          : null,
    );

    if (success && mounted) {
      // Show success and navigate back to home
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asyncState = ref.watch(feedbackControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Feedback'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator - Step 2 of 2
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            
            SizedBox(height: 24.h),
            
            // Header
            Text(
              'What do you think about this tiny app?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            
            SizedBox(height: 8.h),
            
            Text(
              'Your feedback helps us understand how to improve the app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            SizedBox(height: 32.h),
            
            // Feedback options
            _AppFeedbackOption(
              type: AppFeedbackType.likeIt,
              title: 'I like it! Remind me to use it',
              description: 'The app is useful and I want to keep using it',
              icon: Icons.favorite,
              isSelected: _selectedFeedback == AppFeedbackType.likeIt,
              onTap: () => setState(() => _selectedFeedback = AppFeedbackType.likeIt),
            ),
            
            SizedBox(height: 16.h),
            
            _AppFeedbackOption(
              type: AppFeedbackType.hasPotential,
              title: 'It has potential but I need it to...',
              description: 'There are improvements that would make it better',
              icon: Icons.lightbulb_outline,
              isSelected: _selectedFeedback == AppFeedbackType.hasPotential,
              onTap: () => setState(() => _selectedFeedback = AppFeedbackType.hasPotential),
            ),
            
            SizedBox(height: 16.h),
            
            _AppFeedbackOption(
              type: AppFeedbackType.notInterested,
              title: 'Not interested',
              description: 'The app doesn\'t meet my needs',
              icon: Icons.thumb_down,
              isSelected: _selectedFeedback == AppFeedbackType.notInterested,
              onTap: () => setState(() => _selectedFeedback = AppFeedbackType.notInterested),
            ),
            
            SizedBox(height: 32.h),
            
            // Conditional input fields
            if (_selectedFeedback == AppFeedbackType.hasPotential) ...[
              Text(
                'What would make it better?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              TextField(
                controller: _suggestionsController,
                decoration: const InputDecoration(
                  hintText: 'Tell us what features or improvements you\'d like to see...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              
              SizedBox(height: 24.h),
            ],
            
            if (_selectedFeedback == AppFeedbackType.notInterested) ...[
              Text(
                'Why isn\'t this for you? (Optional)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              SizedBox(height: 12.h),
              
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Help us understand what we\'re missing...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              
              SizedBox(height: 24.h),
            ],
            
            SizedBox(height: 16.h),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: asyncState.isLoading ? null : _submitFeedback,
                child: asyncState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Submit Feedback'),
              ),
            ),
            
            SizedBox(height: 16.h),
            
            // Skip button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go('/home'),
                child: const Text('Skip feedback'),
              ),
            ),
            
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }
}

class _AppFeedbackOption extends StatelessWidget {
  final AppFeedbackType type;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppFeedbackOption({
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