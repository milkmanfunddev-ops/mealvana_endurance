import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/survey_controller.dart';
import 'survey_page_1.dart';
import 'survey_page_2.dart';
import '../../../../theme/app_theme.dart';

/// Main survey screen that handles navigation between survey pages
class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({
    super.key,
    this.planName,
  });

  final String? planName;

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitSurvey() async {
    final controller = ref.read(surveyControllerProvider.notifier);
    
    final success = await controller.submitSurvey(planName: widget.planName);
    
    if (mounted) {
      if (success) {
        // Show success message and navigate to tabs
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Thank you for your feedback!'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to tabs screen (replace current route)
        context.go('/main');
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit survey. Please try again.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Quick Survey',
          style: AppTheme.subtitleStyle,
        ),
        backgroundColor: AppTheme.baseWhite,
        foregroundColor: AppTheme.baseBlack,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goToPreviousPage,
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  // Reset survey and go to tabs
                  ref.read(surveyControllerProvider.notifier).resetSurvey();
                  context.go('/main');
                },
              ),
        actions: [
          // Test notification button (for development/testing)
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Test Notification',
            onPressed: () async {
              final controller = ref.read(surveyControllerProvider.notifier);
              final success = await controller.sendTestNotification();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? '🔔 Test notification scheduled for 5 seconds!'
                        : '❌ Failed to schedule notification. Check permissions.',
                    ),
                    backgroundColor: success ? AppTheme.successColor : AppTheme.warningColor,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          // Skip button (only on first page)
          if (_currentPage == 0)
            TextButton(
              onPressed: () {
                ref.read(surveyControllerProvider.notifier).resetSurvey();
                context.go('/main');
              },
              child: Text(
                'Skip',
                style: AppTheme.textStyle.copyWith(color: AppTheme.baseGrey),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_currentPage + 1) / 2,
                    backgroundColor: AppTheme.baseGrey,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary600),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${_currentPage + 1} of 2',
                  style: AppTheme.noteStyle.copyWith(color: AppTheme.baseGrey),
                ),
              ],
            ),
          ),
          
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                SurveyPage1(onContinue: _goToNextPage),
                SurveyPage2(onSubmit: _submitSurvey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}