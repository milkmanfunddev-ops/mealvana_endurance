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
                _buildReminderSection(context, state, controller)
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

  Widget _buildReminderSection(BuildContext context, SurveyState state, SurveyController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder Options',
          style: AppTheme.subtitleStyle,
        ),
        const SizedBox(height: 16),
        
        // Option 1: No reminder needed
        _buildReminderOption(
          state,
          controller,
          () => controller.setNoReminderNeeded(true),
          'No reminder needed',
          isSelected: state.noReminderNeeded,
        ),
        
        const SizedBox(height: 12),
        
        // Option 2: Set a reminder with editable date/time
        _buildEditableReminderOption(context, state, controller),
        
        // Show recurring toggle below reminder options if reminder is enabled
        if (!state.noReminderNeeded) ...[
          const SizedBox(height: 20),
          _buildRecurringToggle(state, controller),
        ],
      ],
    );
  }

  Widget _buildReminderOption(
    SurveyState state,
    SurveyController controller,
    VoidCallback onTap,
    String label, {
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: onTap,
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

  Widget _buildEditableReminderOption(BuildContext context, SurveyState state, SurveyController controller) {
    final isSelected = !state.noReminderNeeded;
    final reminderDate = state.customReminderDate ?? 
        DateTime.now().copyWith(hour: 17, minute: 0).add(
          Duration(days: (DateTime.thursday - DateTime.now().weekday) % 7)
        );

    final weekday = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][reminderDate.weekday];
    final hour12 = reminderDate.hour > 12 ? reminderDate.hour - 12 : (reminderDate.hour == 0 ? 12 : reminderDate.hour);
    final amPm = reminderDate.hour >= 12 ? 'PM' : 'AM';
    final minute = reminderDate.minute.toString().padLeft(2, '0');
    final dateStr = '${reminderDate.month}/${reminderDate.day}';
    
    return GestureDetector(
      onTap: () => controller.setNoReminderNeeded(false),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    'Set a reminder',
                    style: AppTheme.textStyle.copyWith(
                      color: isSelected ? AppTheme.primary600 : AppTheme.baseBlack,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            
            // Show date/time pickers if reminder is selected
            if (isSelected) ...[
              const SizedBox(height: 16),
              Text(
                'When should we remind you?',
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseGrey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showDatePicker(context, reminderDate, controller),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.baseWhite,
                          border: Border.all(color: AppTheme.baseGrey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: AppTheme.baseGrey),
                            const SizedBox(width: 8),
                            Text(
                              '$weekday, $dateStr',
                              style: AppTheme.textStyle.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showTimePicker(context, reminderDate, controller),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.baseWhite,
                          border: Border.all(color: AppTheme.baseGrey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 20, color: AppTheme.baseGrey),
                            const SizedBox(width: 8),
                            Text(
                              '$hour12:$minute $amPm',
                              style: AppTheme.textStyle.copyWith(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringToggle(SurveyState state, SurveyController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.baseGrey),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Repeat this reminder',
              style: AppTheme.textStyle,
            ),
          ),
          Switch(
            value: state.isRecurring,
            onChanged: controller.setIsRecurring,
            activeColor: AppTheme.primary600,
          ),
        ],
      ),
    );
  }


  void _showDatePicker(BuildContext context, DateTime selectedDate, SurveyController controller) {
    showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((pickedDate) {
      if (pickedDate != null) {
        final newDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          selectedDate.hour,
          selectedDate.minute,
        );
        controller.setCustomReminderDate(newDateTime);
      }
    });
  }

  void _showTimePicker(BuildContext context, DateTime selectedDate, SurveyController controller) {
    showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDate),
    ).then((pickedTime) {
      if (pickedTime != null) {
        final newDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        controller.setCustomReminderDate(newDateTime);
      }
    });
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