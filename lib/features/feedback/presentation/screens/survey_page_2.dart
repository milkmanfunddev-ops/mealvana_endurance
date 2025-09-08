import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/feedback_data.dart';
import '../providers/survey_controller.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../theme/app_theme.dart';

/// Second page of survey: Reminder setup or feedback on missed expectations
class SurveyPage2 extends ConsumerWidget {
  const SurveyPage2({
    super.key,
    required this.onSubmit,
  });

  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyState = ref.watch(surveyControllerProvider);
    final controller = ref.read(surveyControllerProvider.notifier);

    return surveyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading survey',
          style: TextStyle(color: AppTheme.warning500),
        ),
      ),
      data: (state) {
        final content = controller.getPageContent(2);
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                content['title']!,
                style: AppTheme.titleStyle,
              ),
              const SizedBox(height: 8),
              Text(
                content['subtitle']!,
                style: AppTheme.textStyle.copyWith(color: AppTheme.baseGrey),
              ),
              const SizedBox(height: 32),
              
              // Show different content based on reuse intent
              if (state.reuseIntent == ReuseIntent.yes)
                _buildReminderSection(state, controller)
              else
                _buildFeedbackSection(state, controller),
              
              const SizedBox(height: 40),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: state.isSubmitting ? 'Submitting...' : 'Submit',
                  onPressed: (state.isPage2Complete && !state.isSubmitting) ? onSubmit : null,
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderSection(SurveyState state, SurveyController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder Options',
          style: AppTheme.subtitleStyle,
        ),
        const SizedBox(height: 16),
        
        // Option 1: Next Thursday at 5 PM
        _buildReminderOption(
          state,
          controller,
          const NotificationPreference(
            dayOfWeek: 4, // Thursday
            hour: 17, // 5 PM
            minute: 0,
            isRecurring: false,
          ),
          'Next Thursday at 5:00 PM (one-time)',
        ),
        
        const SizedBox(height: 12),
        
        // Option 2: Every Thursday at 5 PM
        _buildReminderOption(
          state,
          controller,
          const NotificationPreference(
            dayOfWeek: 4, // Thursday
            hour: 17, // 5 PM
            minute: 0,
            isRecurring: true,
          ),
          'Every Thursday at 5:00 PM (recurring)',
        ),
        
        const SizedBox(height: 12),
        
        // Option 3: Next Saturday at 5 PM
        _buildReminderOption(
          state,
          controller,
          const NotificationPreference(
            dayOfWeek: 6, // Saturday
            hour: 17, // 5 PM
            minute: 0,
            isRecurring: false,
          ),
          'Next Saturday at 5:00 PM (one-time)',
        ),
        
        const SizedBox(height: 12),
        
        // Option 4: No reminder
        _buildReminderOption(
          state,
          controller,
          null,
          'No reminder needed',
        ),
      ],
    );
  }

  Widget _buildReminderOption(
    SurveyState state,
    SurveyController controller,
    NotificationPreference? preference,
    String label,
  ) {
    final isSelected = (preference == null && state.reminderPreference == null) ||
        (preference != null && 
         state.reminderPreference?.dayOfWeek == preference.dayOfWeek &&
         state.reminderPreference?.hour == preference.hour &&
         state.reminderPreference?.isRecurring == preference.isRecurring);

    return GestureDetector(
      onTap: () => controller.setReminderPreference(preference),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary100 : AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary600 : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: AppTheme.baseWhite,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTheme.textStyle.copyWith(
                  color: isSelected ? AppTheme.primary600 : AppTheme.baseBlack,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection(SurveyState state, SurveyController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What missed your expectations?',
          style: AppTheme.subtitleStyle,
        ),
        const SizedBox(height: 16),
        
        // Missed reason options
        ...MissedReason.values.map((reason) {
          final isSelected = state.missedReason == reason;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => controller.setMissedReason(reason),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary100 : AppTheme.baseWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppTheme.primary600 : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: AppTheme.baseWhite,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reason.label,
                        style: AppTheme.textStyle.copyWith(
                          color: isSelected ? AppTheme.primary600 : AppTheme.baseBlack,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        
        // Other reason text field (shown when "Other" is selected)
        if (state.missedReason == MissedReason.other) ...[
          const SizedBox(height: 16),
          TextField(
            onChanged: controller.setMissedOther,
            decoration: InputDecoration(
              labelText: 'Please specify',
              hintText: 'Tell us what could be better...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary600, width: 2),
              ),
            ),
            maxLines: 3,
            style: AppTheme.textStyle,
          ),
        ],
      ],
    );
  }
}