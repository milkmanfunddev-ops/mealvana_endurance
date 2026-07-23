import 'package:flutter/foundation.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/feedback_data.dart';

/// Supabase-based feedback service for reliable data storage
class SupabaseFeedbackService {
  SupabaseFeedbackService(this._supabase);

  final SupabaseClient _supabase;

  /// Submit feedback to Supabase database
  Future<bool> submitFeedback(FeedbackResponse feedback) async {
    if (kDebugMode) {
      DebugLogger.info('🚀 SupabaseFeedbackService: Starting submission...');
      DebugLogger.info('📝 Feedback data: ${feedback.toString()}');
    }

    try {
      // Convert feedback to database format
      final feedbackData = {
        'satisfaction_level': feedback.satisfactionLevel.value,
        'satisfaction_emoji': feedback.satisfactionLevel.emoji,
        'satisfaction_label': feedback.satisfactionLevel.label,
        'app_feedback': feedback.appFeedback?.label,
        'suggestions': feedback.suggestions,
        'plan_name': feedback.planName,
        'user_name': feedback.userName,
        'timestamp':
            feedback.timestamp?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        DebugLogger.info('🗂️ Database data prepared:');
        feedbackData.forEach((key, value) {
          DebugLogger.debug('  $key: "$value"');
        });
      }

      // Insert into feedback table
      final result = await _supabase
          .from('feedback')
          .insert(feedbackData)
          .select();

      if (kDebugMode) {
        DebugLogger.info(
          '📡 Supabase response: ${result.length} rows inserted',
        );
        DebugLogger.info('✅ Submission successful!');
      }

      return result.isNotEmpty;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        DebugLogger.error('💥 Error submitting to Supabase:');
        DebugLogger.error('  Error: $error');
        DebugLogger.debug('  Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Get all feedback submissions (for analytics/admin)
  Future<List<Map<String, dynamic>>> getAllFeedback() async {
    try {
      final response = await _supabase
          .from('feedback')
          .select()
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Error fetching feedback: $error');
      }
      return [];
    }
  }

  /// Get feedback statistics
  Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      // Get satisfaction level distribution
      final satisfactionStats = await _supabase
          .from('feedback')
          .select('satisfaction_level');

      // Get app feedback distribution
      final appFeedbackStats = await _supabase
          .from('feedback')
          .select('app_feedback');

      // Calculate distributions
      final satisfactionCounts = <int, int>{};
      final appFeedbackCounts = <String, int>{};

      for (final row in satisfactionStats) {
        final level = row['satisfaction_level'] as int;
        satisfactionCounts[level] = (satisfactionCounts[level] ?? 0) + 1;
      }

      for (final row in appFeedbackStats) {
        final feedback = row['app_feedback'] as String?;
        if (feedback != null) {
          appFeedbackCounts[feedback] = (appFeedbackCounts[feedback] ?? 0) + 1;
        }
      }

      return {
        'total_submissions': satisfactionStats.length,
        'satisfaction_distribution': satisfactionCounts,
        'app_feedback_distribution': appFeedbackCounts,
      };
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.error('Error fetching feedback stats: $error');
      }
      return {};
    }
  }

  /// Test database connection
  Future<bool> testConnection() async {
    try {
      final testData = {
        'satisfaction_level': 2,
        'satisfaction_emoji': '🤗',
        'satisfaction_label': 'Test submission',
        'app_feedback': 'Test feedback',
        'suggestions': 'Test suggestions',
        'plan_name': 'Test Plan',
        'user_name': 'Test User',
        'timestamp': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase.from('feedback').insert(testData).select();

      if (kDebugMode) {
        DebugLogger.info(
          '🧪 Test connection: ${result.isNotEmpty ? 'SUCCESS' : 'FAILED'}',
        );
      }

      return result.isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        DebugLogger.info('🧪 Test connection failed: $error');
      }
      return false;
    }
  }
}
