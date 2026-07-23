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
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

part 'survey_controller.g.dart';

/// State for the survey flow
class SurveyState {
  const SurveyState({
    this.confidenceLevel,
    this.reuseIntent,
    this.reminderPreference,
    this.customReminderDate,
    this.isRecurring = false,
    this.noReminderNeeded = false,
    this.missedReason,
    this.missedOther,
    this.isSubmitting = false,
  });

  final ConfidenceLevel? confidenceLevel;
  final ReuseIntent? reuseIntent;
  final NotificationPreference? reminderPreference;
  final DateTime? customReminderDate;
  final bool isRecurring;
  final bool noReminderNeeded;
  final MissedReason? missedReason;
  final String? missedOther;
  final bool isSubmitting;

  SurveyState copyWith({
    ConfidenceLevel? confidenceLevel,
    ReuseIntent? reuseIntent,
    NotificationPreference? reminderPreference,
    DateTime? customReminderDate,
    bool? isRecurring,
    bool? noReminderNeeded,
    MissedReason? missedReason,
    String? missedOther,
    bool? isSubmitting,
  }) {
    return SurveyState(
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      reuseIntent: reuseIntent ?? this.reuseIntent,
      reminderPreference: reminderPreference ?? this.reminderPreference,
      customReminderDate: customReminderDate ?? this.customReminderDate,
      isRecurring: isRecurring ?? this.isRecurring,
      noReminderNeeded: noReminderNeeded ?? this.noReminderNeeded,
      missedReason: missedReason ?? this.missedReason,
      missedOther: missedOther ?? this.missedOther,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  bool get isPage1Complete => confidenceLevel != null && reuseIntent != null;

  bool get isPage2Complete {
    if (reuseIntent == ReuseIntent.yes) {
      // Always allow completion - user can choose no reminder or set reminder
      return true;
    } else {
      return missedReason != null &&
          (missedReason != MissedReason.other ||
              (missedOther?.trim().isNotEmpty ?? false));
    }
  }

  SurveyResponse toSurveyResponse({String? deviceId, String? planName}) {
    NotificationPreference? finalReminderPreference;

    if (!noReminderNeeded && reuseIntent == ReuseIntent.yes) {
      if (customReminderDate != null) {
        finalReminderPreference = NotificationPreference.custom(
          dateTime: customReminderDate!,
          isRecurring: isRecurring,
        );
      } else {
        // Default to Thursday at 5:00 PM if no custom date is set
        finalReminderPreference = NotificationPreference.defaultThursday(
          isRecurring: isRecurring,
        );
      }
    }

    return SurveyResponse(
      confidenceLevel: confidenceLevel!,
      reuseIntent: reuseIntent!,
      reminderPreference: finalReminderPreference,
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
      state = AsyncValue.data(
        currentState.copyWith(
          reuseIntent: intent,
          reminderPreference: null,
          customReminderDate: null,
          isRecurring: false,
          noReminderNeeded: false,
          missedReason: null,
          missedOther: null,
        ),
      );
    }
  }

  /// Set reminder type (default vs custom) - DEPRECATED: No longer needed with simplified UI
  void setReminderType(ReminderType type) {
    // This method is no longer needed since we removed separate reminder type selection
    // The UI now directly sets custom reminder date or uses defaults
  }

  /// Set custom reminder date/time
  void setCustomReminderDate(DateTime dateTime) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          customReminderDate: dateTime,
          noReminderNeeded: false,
        ),
      );
    }
  }

  /// Set whether reminder is recurring
  void setIsRecurring(bool isRecurring) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          isRecurring: isRecurring,
          noReminderNeeded: false,
        ),
      );
    }
  }

  /// Set no reminder needed
  void setNoReminderNeeded(bool noReminder) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          noReminderNeeded: noReminder,
          customReminderDate: null,
          isRecurring: false,
        ),
      );
    }
  }

  /// Update notification preference (Page 2 - for "yes" reuse intent) - Legacy method for compatibility
  void setReminderPreference(NotificationPreference? preference) {
    if (preference == null) {
      setNoReminderNeeded(true);
    } else {
      final currentState = state.value;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(
            reminderPreference: preference,
            noReminderNeeded: false,
          ),
        );
      }
    }
  }

  /// Update missed reason (Page 2 - for "maybe/no" reuse intent)
  void setMissedReason(MissedReason? reason) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          missedReason: reason,
          missedOther: reason == MissedReason.other
              ? currentState.missedOther
              : null,
        ),
      );
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
    if (currentState == null ||
        !currentState.isPage1Complete ||
        !currentState.isPage2Complete) {
      return false;
    }

    state = AsyncValue.data(currentState.copyWith(isSubmitting: true));

    try {
      // Get current user profile to get device ID
      final user = await _database.userDao.getCurrentUserProfile();
      final deviceId = user?.id ?? 'anonymous';
      final response = currentState.toSurveyResponse(
        deviceId: deviceId,
        planName: planName,
      );

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
        DebugLogger.error('Error submitting survey: $error');
        DebugLogger.debug('Stack trace: $stackTrace');
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
          DebugLogger.debug('Test notification failed: No permissions');
        }
        return false;
      }

      // Schedule test notification for 5 seconds from now
      final testTime = DateTime.now().add(const Duration(seconds: 5));

      await NotificationService.scheduleReminder(
        scheduledDate: testTime,
        recurring: false,
        title: 'Test Notification 📱',
        body:
            'This is a test notification from your nutrition app. Tap to open the app!',
      );

      if (kDebugMode) {
        DebugLogger.debug('Test notification scheduled for: $testTime');
      }
      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('Error sending test notification: $error');
        DebugLogger.debug('Stack trace: $stackTrace');
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
        'title':
            surveyText['page1_title'] as String? ?? 'How confident are you?',
        'subtitle':
            surveyText['page1_subtitle'] as String? ??
            'How confident are you that this plan will meet your needs?',
        'reuse_question':
            surveyText['reuse_question'] as String? ??
            'Would you use this app again?',
      };
    } else {
      final currentState = state.value;
      if (currentState?.reuseIntent == ReuseIntent.yes) {
        return {
          'title':
              surveyText['page2_reminder_title'] as String? ?? 'Set a reminder',
          'subtitle':
              surveyText['page2_reminder_subtitle'] as String? ??
              'When would you like to be reminded to try the app again?',
        };
      } else {
        return {
          'title':
              surveyText['page2_feedback_title'] as String? ??
              'Help us improve',
          'subtitle':
              surveyText['page2_feedback_subtitle'] as String? ??
              'What could we do better to meet your expectations?',
        };
      }
    }
  }
}
