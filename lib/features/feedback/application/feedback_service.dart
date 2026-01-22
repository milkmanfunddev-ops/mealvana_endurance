import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/feedback_data.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/services/analytics/analytics_tracker.dart';
import '../../../shared/services/notification_service.dart';
import '../data/feedback_repository.dart';
import '../../../shared/database/database_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

/// Service for submitting feedback to Google Forms and handling survey responses
class FeedbackService {
  FeedbackService(this.ref);
  final Ref ref;
  
  
  /// Get feedback repository
  FeedbackRepository get _repository => ref.read(feedbackRepositoryProvider);
  AnalyticsTracker get _analytics => ref.read(appExternalDepsProvider).analytics;
  // Google Form URL - your actual form
  static const String _formUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSfKkSEUYd_vdDKv4iMVT3jPr2v2VWTg5bVkWRxbvFN1HaAFKQ/formResponse';
  
  // Form field entry IDs - extracted from your Google Form
  static const String _satisfactionFieldId = 'entry.326851736';    // "What do you think about this plan?"
  static const String _appFeedbackFieldId = 'entry.205830727';     // "What do you think about this tiny app?"
  static const String _suggestionsFieldId = 'entry.1733379717';   // "Suggestions for improvement"
  static const String _planNameFieldId = 'entry.1956700449';      // "Plan Name"
  static const String _userNameFieldId = 'entry.536281714';       // "User Name"
  static const String _timestampFieldId = 'entry.845631390';      // "Submission Time"

  /// Submit survey response to local database and handle notifications
  Future<bool> submitSurveyResponse({
    required SurveyResponse response,
    required String deviceId,
    String? planName,
  }) async {
    try {
      // Create full response with device info
      final fullResponse = SurveyResponse(
        confidenceLevel: response.confidenceLevel,
        reuseIntent: response.reuseIntent,
        reminderPreference: response.reminderPreference,
        missedReason: response.missedReason,
        missedOther: response.missedOther,
        deviceId: deviceId,
        planName: planName,
        timestamp: DateTime.now(),
      );

      // Save to local database
      await _repository.saveSurveyResponse(fullResponse);

      // Track survey completion
      await _analytics.trackSurveyCompleted(
        confidenceLevel: response.confidenceLevel.value,
        reuseIntent: response.reuseIntent.value,
        reminderRequested: response.reminderPreference != null,
        missedReason: response.missedReason?.value,
      );

      // Handle notification scheduling if user wants reminders
      if (response.reminderPreference != null) {
        await _scheduleReminder(response.reminderPreference!);
      }

      return true;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('💥 Error submitting survey response: $error');
        DebugLogger.debug('Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Schedule notification reminder based on user preferences
  Future<void> _scheduleReminder(NotificationPreference preference) async {
    try {
      // Request notification permissions first
      final hasPermission = await NotificationService.requestPermissions();
      if (!hasPermission) {
        if (kDebugMode) {
          DebugLogger.warning('⚠️ Notification permission denied, cannot schedule reminder');
        }
        return;
      }

      // Calculate the next reminder date
      final reminderDate = preference.getNextReminderDate();

      // Get the latest plan ID for notification tracking
      // Since notifications are for "how did your plan work", we need a plan ID for analytics
      String? activityId;
      try {
        final database = ref.read(appDatabaseProvider);
        final currentUser = await database.userDao.getCurrentUserProfile();
        if (currentUser != null) {
          final latestPlanActivity =
              await database.activityDao.getLatestActivityWithNutritionPlan(currentUser.id);
          activityId = latestPlanActivity?.id;
        }
      } catch (e) {
        if (kDebugMode) {
          DebugLogger.error('⚠️ Could not get plan ID for notification: $e');
        }
      }

      // Schedule the reminder
      await NotificationService.scheduleReminder(
        scheduledDate: reminderDate,
        recurring: preference.isRecurring,
        title: 'How did your nutrition plan work?',
        body: 'Share your feedback to help us improve your fueling strategy.',
        activityId: activityId,
      );

      if (kDebugMode) {
        DebugLogger.info('✅ Reminder scheduled for $reminderDate');
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('💥 Error scheduling reminder: $error');
        DebugLogger.debug('Stack trace: $stackTrace');
      }
    }
  }

  /// Check if user should be shown the survey
  /// Returns false if they've completed it recently
  Future<bool> shouldShowSurvey(String deviceId) async {
    try {
      return !(await _repository.hasRecentSurveyResponse(deviceId));
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Error checking survey eligibility: $error');
      }
      return true; // Default to showing survey if check fails
    }
  }

  /// Get latest survey response for a device
  Future<SurveyResponse?> getLatestSurveyResponse(String deviceId) async {
    try {
      final entry = await _repository.getLatestSurveyResponse(deviceId);
      return _repository.convertToSurveyResponse(entry);
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Error getting latest survey response: $error');
      }
      return null;
    }
  }

  /// Cancel all scheduled reminders (if user changes notification preferences)
  Future<void> cancelAllReminders() async {
    try {
      await NotificationService.cancelAllReminders();
      if (kDebugMode) {
        DebugLogger.info('✅ All reminders cancelled');
      }
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Error cancelling reminders: $error');
      }
    }
  }

  /// Test simple submission with minimal data
  Future<bool> testSimpleSubmission() async {
    if (kDebugMode) {
      DebugLogger.info('🧪 Testing simple submission...');
    }

    try {
      // Try just the required satisfaction field
      final simpleData = {
        _satisfactionFieldId: 'Pretty close to what I think I should use',
      };

      final response = await http.post(
        Uri.parse(_formUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: simpleData,
      );

      if (kDebugMode) {
        DebugLogger.info('📡 Simple test result: ${response.statusCode}');
        if (response.statusCode != 200 && response.statusCode != 302) {
          DebugLogger.debug('Body preview: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        }
      }

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('💥 Simple test error: $error');
      }
      return false;
    }
  }

  /// Submit feedback response to Google Forms using GET method
  Future<bool> submitFeedbackGET(FeedbackResponse feedback) async {
    if (kDebugMode) {
      DebugLogger.info('🚀 FeedbackService: Starting GET submission...');
      DebugLogger.info('📝 Feedback data: ${feedback.toString()}');
    }

    try {
      // Prepare form data for GET request
      final queryParams = <String, String>{
        _satisfactionFieldId: feedback.satisfactionLevel.label,
        _appFeedbackFieldId: feedback.appFeedback?.label ?? '',
        _suggestionsFieldId: feedback.suggestions ?? '',
        _planNameFieldId: feedback.planName ?? '',
        _userNameFieldId: feedback.userName ?? '',
        _timestampFieldId: feedback.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'submit': 'Submit',
      };

      final uri = Uri.parse(_formUrl).replace(queryParameters: queryParams);
      
      if (kDebugMode) {
        DebugLogger.debug('🔗 GET URL: $uri');
      }

      final response = await http.get(uri);

      if (kDebugMode) {
        DebugLogger.info('📡 GET Response:');
        DebugLogger.debug('  Status Code: ${response.statusCode}');
        DebugLogger.debug('  Success: ${response.statusCode == 200}');
      }

      return response.statusCode == 200;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('💥 GET Error: $error');
        DebugLogger.debug('  Stack: $stackTrace');
      }
      return false;
    }
  }

  /// Submit feedback response to Google Forms using POST method
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    if (kDebugMode) {
      DebugLogger.info('🚀 FeedbackService: Starting submission...');
      DebugLogger.info('📝 Feedback data: ${feedback.toString()}');
    }

    // Track feedback submission attempt
    await _analytics.trackFeedbackSubmitted(
      activityId: null,
      confidenceLevel: _satisfactionToRating(feedback.satisfactionLevel),
      reuseIntent: 'n/a', // FeedbackResponse doesn't have reuseIntent (that's in SurveyResponse)
      reminderRequested: false, // FeedbackResponse doesn't have reminderPreference (that's in SurveyResponse)
      message: feedback.suggestions,
    );

    try {
      // Prepare form data with submit parameter
      final formData = <String, String>{
        _satisfactionFieldId: feedback.satisfactionLevel.label,
        _appFeedbackFieldId: feedback.appFeedback?.label ?? '',
        _suggestionsFieldId: feedback.suggestions ?? '',
        _planNameFieldId: feedback.planName ?? '',
        _userNameFieldId: feedback.userName ?? '',
        _timestampFieldId: feedback.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'submit': 'Submit', // Google Forms often requires this
      };

      if (kDebugMode) {
        DebugLogger.info('🗂️ Form data prepared:');
        formData.forEach((key, value) {
          DebugLogger.debug('  $key: "$value"');
        });
        DebugLogger.info('🌐 Submitting to URL: $_formUrl');
      }

      // Create properly encoded form data
      final encodedData = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      if (kDebugMode) {
        DebugLogger.debug('🔗 Encoded form data: $encodedData');
      }
      
      // Submit to Google Forms
      final response = await http.post(
        Uri.parse(_formUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'MealvanaEndurance/1.0',
        },
        body: encodedData,
      );

      if (kDebugMode) {
        DebugLogger.info('📡 Response received:');
        DebugLogger.debug('  Status Code: ${response.statusCode}');
        DebugLogger.debug('  Headers: ${response.headers}');
        DebugLogger.debug('  Body length: ${response.body.length}');
        if (response.body.length < 1000) {
          DebugLogger.debug('  Body: ${response.body}');
        } else {
          DebugLogger.debug('  Body: ${response.body.substring(0, 500)}...[truncated]');
        }
      }

      // Google Forms returns 200 even on success, but redirects to a confirmation page
      // Check if submission was successful (status code 200 or 302 for redirect)
      final success = response.statusCode == 200 || response.statusCode == 302;
      
      if (kDebugMode) {
        if (success) {
          DebugLogger.info('✅ Submission successful!');
        } else {
          DebugLogger.error('❌ Submission failed!');
        }
      }
      
      return success;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('💥 Error submitting feedback:');
        DebugLogger.error('  Error: $error');
        DebugLogger.debug('  Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Alternative method: Submit feedback as JSON to a webhook/API endpoint
  /// Use this if you prefer to process feedback through your own backend
  Future<bool> submitFeedbackToAPI(FeedbackResponse feedback, {String? apiEndpoint}) async {
    final endpoint = apiEndpoint ?? 'https://your-api.com/api/feedback';
    
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(feedback.toFormData()),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (error) {
      DebugLogger.error('Error submitting feedback to API: $error');
      return false;
    }
  }
  
  /// Convert satisfaction level to numeric rating for analytics
  int _satisfactionToRating(SatisfactionLevel level) {
    switch (level) {
      case SatisfactionLevel.tooMuch:
        return 1;
      case SatisfactionLevel.justRight:
        return 3;
      case SatisfactionLevel.tooLittle:
        return 2;
    }
  }

  /// Test method to validate form configuration
  /// Use this during development to ensure the form is properly configured
  Future<bool> testFormConnection() async {
    final testFeedback = FeedbackResponse(
      satisfactionLevel: SatisfactionLevel.justRight,
      appFeedback: AppFeedbackOption.likeIt,
      suggestions: 'Test submission from Mealvana Endurance app',
      planName: 'Test Plan',
      timestamp: DateTime.now(),
    );

    if (kDebugMode) {
      DebugLogger.info('🧪 Testing both POST and GET methods...');
    }

    // Try POST first
    final postSuccess = await submitFeedback(testFeedback);
    if (postSuccess) {
      if (kDebugMode) DebugLogger.info('✅ POST method worked!');
      return true;
    }

    // If POST fails, try GET
    if (kDebugMode) DebugLogger.warning('⚠️ POST failed, trying GET...');
    final getSuccess = await submitFeedbackGET(testFeedback);
    if (getSuccess) {
      if (kDebugMode) DebugLogger.info('✅ GET method worked!');
      return true;
    }

    if (kDebugMode) DebugLogger.error('❌ Both methods failed');
    return false;
  }
}
