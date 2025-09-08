import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mealvana_endurance/features/feedback/presentation/providers/feedback_provider.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/feedback_data.dart';
import '../../application/feedback_service.dart';
import '../../../content/application/content_service.dart';
import '../../../../shared/database/app_database.dart';
import '../../../../shared/services/notification_service.dart';

part 'survey_controller.g.dart';

/// State for the survey flow
class SurveyState {
  const SurveyState({
    this.confidenceLevel,
    this.reuseIntent,
    this.reminderPreference,
    this.missedReason,
    this.missedOther,
    this.isSubmitting = false,
  });

  final ConfidenceLevel? confidenceLevel;
  final ReuseIntent? reuseIntent;
  final NotificationPreference? reminderPreference;
  final MissedReason? missedReason;
  final String? missedOther;
  final bool isSubmitting;

  SurveyState copyWith({
    ConfidenceLevel? confidenceLevel,
    ReuseIntent? reuseIntent,
    NotificationPreference? reminderPreference,
    MissedReason? missedReason,
    String? missedOther,
    bool? isSubmitting,
  }) {
    return SurveyState(
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      reuseIntent: reuseIntent ?? this.reuseIntent,
      reminderPreference: reminderPreference ?? this.reminderPreference,
      missedReason: missedReason ?? this.missedReason,
      missedOther: missedOther ?? this.missedOther,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  bool get isPage1Complete => confidenceLevel != null && reuseIntent != null;
  
  bool get isPage2Complete {
    if (reuseIntent == ReuseIntent.yes) {
      return reminderPreference != null;
    } else {
      return missedReason != null && 
             (missedReason != MissedReason.other || (missedOther?.trim().isNotEmpty ?? false));
    }
  }

  SurveyResponse toSurveyResponse({String? deviceId, String? planName}) {
    return SurveyResponse(
      confidenceLevel: confidenceLevel!,
      reuseIntent: reuseIntent!,
      reminderPreference: reminderPreference,
      missedReason: missedReason,
      missedOther: missedOther,
      deviceId: deviceId,
      planName: planName,
      timestamp: DateTime.now(),
    );
  }
}

@riverpod
class SurveyController extends _$SurveyController {
  FeedbackService get _feedbackService => ref.read(feedbackServiceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AppDatabase get _database => ref.read(appDatabaseProvider);

  @override
  FutureOr<SurveyState> build() {
    return const SurveyState();
  }

  /// Update confidence level (Page 1)
  void setConfidenceLevel(ConfidenceLevel level) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(confidenceLevel: level));
    }
  }

  /// Update reuse intent (Page 1)
  void setReuseIntent(ReuseIntent intent) {
    final currentState = state.value;
    if (currentState != null) {
      // Clear page 2 data when reuse intent changes
      state = AsyncValue.data(currentState.copyWith(
        reuseIntent: intent,
        reminderPreference: null,
        missedReason: null,
        missedOther: null,
      ));
    }
  }

  /// Update notification preference (Page 2 - for "yes" reuse intent)
  void setReminderPreference(NotificationPreference? preference) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(reminderPreference: preference));
    }
  }

  /// Update missed reason (Page 2 - for "maybe/no" reuse intent)
  void setMissedReason(MissedReason? reason) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(
        missedReason: reason,
        missedOther: reason == MissedReason.other ? currentState.missedOther : null,
      ));
    }
  }

  /// Update "other" reason text (Page 2 - when missed reason is "other")
  void setMissedOther(String text) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(missedOther: text));
    }
  }

  /// Submit the survey response
  Future<bool> submitSurvey({String? planName}) async {
    final currentState = state.value;
    if (currentState == null || !currentState.isPage1Complete || !currentState.isPage2Complete) {
      return false;
    }

    state = AsyncValue.data(currentState.copyWith(isSubmitting: true));

    try {
      // Get current user profile to get device ID
      final user = await _database.getCurrentUserProfile();
      final deviceId = user?.id ?? 'anonymous';
      final response = currentState.toSurveyResponse(deviceId: deviceId, planName: planName);
      
      final success = await _feedbackService.submitSurveyResponse(
        response: response,
        deviceId: deviceId,
        planName: planName,
      );

      if (success) {
        // Reset survey state after successful submission
        resetSurvey();
      } else {
        state = AsyncValue.data(currentState.copyWith(isSubmitting: false));
      }
      
      return success;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error submitting survey: $error');
        print('Stack trace: $stackTrace');
      }
      state = AsyncValue.data(currentState.copyWith(isSubmitting: false));
      return false;
    }
  }

  /// Reset survey state (for testing or if user goes back)
  void resetSurvey() {
    state = const AsyncValue.data(SurveyState());
  }

  /// Send a test notification immediately (for testing purposes)
  Future<bool> sendTestNotification() async {
    try {
      // Request permissions first
      final hasPermission = await NotificationService.requestPermissions();
      if (!hasPermission) {
        if (kDebugMode) {
          print('Test notification failed: No permissions');
        }
        return false;
      }

      // Schedule test notification for 5 seconds from now
      final testTime = DateTime.now().add(const Duration(seconds: 5));
      
      await NotificationService.scheduleReminder(
        scheduledDate: testTime,
        recurring: false,
        title: 'Test Notification 📱',
        body: 'This is a test notification from your nutrition app. Tap to open the app!',
      );

      if (kDebugMode) {
        print('Test notification scheduled for: $testTime');
      }
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('Error sending test notification: $error');
        print('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Get UI text for the current page
  Map<String, String> getPageContent(int pageNumber) {
    final content = _contentService.getActiveContent();
    final uiText = content?.content['ui_text'] as Map<String, dynamic>? ?? {};
    final surveyText = uiText['survey'] as Map<String, dynamic>? ?? {};
    
    if (pageNumber == 1) {
      return {
        'title': surveyText['page1_title'] as String? ?? 'How confident are you?',
        'subtitle': surveyText['page1_subtitle'] as String? ?? 'How confident are you that this plan will meet your needs?',
        'reuse_question': surveyText['reuse_question'] as String? ?? 'Would you use this app again?',
      };
    } else {
      final currentState = state.value;
      if (currentState?.reuseIntent == ReuseIntent.yes) {
        return {
          'title': surveyText['page2_reminder_title'] as String? ?? 'Set a reminder',
          'subtitle': surveyText['page2_reminder_subtitle'] as String? ?? 'When would you like to be reminded to try the app again?',
        };
      } else {
        return {
          'title': surveyText['page2_feedback_title'] as String? ?? 'Help us improve',
          'subtitle': surveyText['page2_feedback_subtitle'] as String? ?? 'What could we do better to meet your expectations?',
        };
      }
    }
  }
}