import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/feedback_data.dart';
import '../providers/survey_controller.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../theme/app_theme.dart';

/// First page of survey: Confidence level and reuse intent (Simple version)
class SurveyPage1Simple extends ConsumerWidget {
  const SurveyPage1Simple({
    super.key,
    required this.onContinue,
  });

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surveyState = ref.watch(surveyControllerProvider);
    final controller = ref.read(surveyControllerProvider.notifier);
    final content = controller.getPageContent(1);

    return surveyState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading survey',
          style: TextStyle(color: AppTheme.warning500),
        ),
      ),
      data: (state) => SingleChildScrollView(
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
            
            // Confidence Level Selector
            Text(
              'Confidence Level',
              style: AppTheme.subtitleStyle,
            ),
            const SizedBox(height: 16),
            
            // Confidence scale 1-5
            Row(
              children: [
                Text(
                  'Not at all',
                  style: AppTheme.noteStyle.copyWith(color: AppTheme.baseGrey),
                ),
                const Spacer(),
                Text(
                  'Extremely',
                  style: AppTheme.noteStyle.copyWith(color: AppTheme.baseGrey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ConfidenceLevel.values.map((level) {
                final isSelected = state.confidenceLevel == level;
                return GestureDetector(
                  onTap: () => controller.setConfidenceLevel(level),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.primary600 : AppTheme.baseWhite,
                      border: Border.all(
                        color: isSelected ? AppTheme.primary600 : AppTheme.baseGrey,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        level.value.toString(),
                        style: AppTheme.subtitleStyle.copyWith(
                          color: isSelected ? AppTheme.baseWhite : AppTheme.baseBlack,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 8),
            if (state.confidenceLevel != null)
              Text(
                state.confidenceLevel!.label,
                style: AppTheme.textStyle.copyWith(color: AppTheme.primary600),
                textAlign: TextAlign.center,
              ),
            
            const SizedBox(height: 40),
            
            // Reuse Intent Question
            Text(
              content['reuse_question']!,
              style: AppTheme.subtitleStyle,
            ),
            const SizedBox(height: 16),
            
            // Reuse Intent Options
            ...ReuseIntent.values.map((intent) {
              final isSelected = state.reuseIntent == intent;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => controller.setReuseIntent(intent),
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
                            intent.label,
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
            
            const SizedBox(height: 40),
            
            // Continue Button
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                text: 'Continue',
                onPressed: state.isPage1Complete ? onContinue : null,
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}