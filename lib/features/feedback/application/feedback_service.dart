import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/feedback_data.dart';
import '../../../shared/services/analytics_service.dart';

/// Service for submitting feedback to Google Forms
class FeedbackService {
  FeedbackService(this.ref);
  final Ref ref;
  
  /// Get analytics service
  AnalyticsService get _analytics => ref.read(analyticsServiceProvider);
  // Google Form URL - your actual form
  static const String _formUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSfKkSEUYd_vdDKv4iMVT3jPr2v2VWTg5bVkWRxbvFN1HaAFKQ/formResponse';
  
  // Form field entry IDs - extracted from your Google Form
  static const String _satisfactionFieldId = 'entry.326851736';    // "What do you think about this plan?"
  static const String _appFeedbackFieldId = 'entry.205830727';     // "What do you think about this tiny app?"
  static const String _suggestionsFieldId = 'entry.1733379717';   // "Suggestions for improvement"
  static const String _planNameFieldId = 'entry.1956700449';      // "Plan Name"
  static const String _userNameFieldId = 'entry.536281714';       // "User Name"
  static const String _timestampFieldId = 'entry.845631390';      // "Submission Time"

  /// Test simple submission with minimal data
  Future<bool> testSimpleSubmission() async {
    if (kDebugMode) {
      print('🧪 Testing simple submission...');
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
        print('📡 Simple test result: ${response.statusCode}');
        if (response.statusCode != 200 && response.statusCode != 302) {
          print('Body preview: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}');
        }
      }

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (error) {
      if (kDebugMode) {
        print('💥 Simple test error: $error');
      }
      return false;
    }
  }

  /// Submit feedback response to Google Forms using GET method
  Future<bool> submitFeedbackGET(FeedbackResponse feedback) async {
    if (kDebugMode) {
      print('🚀 FeedbackService: Starting GET submission...');
      print('📝 Feedback data: ${feedback.toString()}');
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
        print('🔗 GET URL: $uri');
      }

      final response = await http.get(uri);

      if (kDebugMode) {
        print('📡 GET Response:');
        print('  Status Code: ${response.statusCode}');
        print('  Success: ${response.statusCode == 200}');
      }

      return response.statusCode == 200;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('💥 GET Error: $error');
        print('  Stack: $stackTrace');
      }
      return false;
    }
  }

  /// Submit feedback response to Google Forms using POST method
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    if (kDebugMode) {
      print('🚀 FeedbackService: Starting submission...');
      print('📝 Feedback data: ${feedback.toString()}');
    }

    // Track feedback submission attempt
    await _analytics.trackFeedbackSubmitted(
      type: 'Plan Feedback',
      message: feedback.suggestions ?? '',
      rating: _satisfactionToRating(feedback.satisfactionLevel),
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
        print('🗂️ Form data prepared:');
        formData.forEach((key, value) {
          print('  $key: "$value"');
        });
        print('🌐 Submitting to URL: $_formUrl');
      }

      // Create properly encoded form data
      final encodedData = formData.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      
      if (kDebugMode) {
        print('🔗 Encoded form data: $encodedData');
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
        print('📡 Response received:');
        print('  Status Code: ${response.statusCode}');
        print('  Headers: ${response.headers}');
        print('  Body length: ${response.body.length}');
        if (response.body.length < 1000) {
          print('  Body: ${response.body}');
        } else {
          print('  Body: ${response.body.substring(0, 500)}...[truncated]');
        }
      }

      // Google Forms returns 200 even on success, but redirects to a confirmation page
      // Check if submission was successful (status code 200 or 302 for redirect)
      final success = response.statusCode == 200 || response.statusCode == 302;
      
      if (kDebugMode) {
        print(success ? '✅ Submission successful!' : '❌ Submission failed!');
      }
      
      return success;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('💥 Error submitting feedback:');
        print('  Error: $error');
        print('  Stack trace: $stackTrace');
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
      print('Error submitting feedback to API: $error');
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
      print('🧪 Testing both POST and GET methods...');
    }

    // Try POST first
    final postSuccess = await submitFeedback(testFeedback);
    if (postSuccess) {
      if (kDebugMode) print('✅ POST method worked!');
      return true;
    }

    // If POST fails, try GET
    if (kDebugMode) print('⚠️ POST failed, trying GET...');
    final getSuccess = await submitFeedbackGET(testFeedback);
    if (getSuccess) {
      if (kDebugMode) print('✅ GET method worked!');
      return true;
    }

    if (kDebugMode) print('❌ Both methods failed');
    return false;
  }
}