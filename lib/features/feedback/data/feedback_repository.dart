import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import '../../../shared/database/app_database.dart';
import '../../../shared/services/logging_service.dart';
import '../domain/feedback_data.dart';

/// Provider for feedback repository
final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final database = ref.read(appDatabaseProvider);
  return FeedbackRepository(database);
});

/// Repository for handling feedback data persistence
/// Manages survey responses and notification preferences in local database and Supabase
class FeedbackRepository {
  FeedbackRepository(this._database);
  
  final AppDatabase _database;
  final SupabaseClient _supabase = Supabase.instance.client;
  LoggingService get _logger => AppLogger.instance;

  /// Save survey response to both local database and Supabase
  Future<void> saveSurveyResponse(SurveyResponse response) async {
    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Save to local database first (for offline access)
    await _database.saveSurveyResponse(
      id: localId,
      confidenceLevel: response.confidenceLevel.value,
      confidenceLabel: response.confidenceLevel.label,
      reuseIntent: response.reuseIntent.value,
      reminderRequested: response.reminderPreference != null,
      missedReasons: response.missedReason != null ? [response.missedReason!.value] : null,
      missedOther: response.missedOther,
      reminderDayOfWeek: response.reminderPreference?.dayOfWeek,
      reminderHour: response.reminderPreference?.hour,
      reminderMinute: response.reminderPreference?.minute,
      reminderRecurring: response.reminderPreference?.isRecurring,
      deviceId: response.deviceId,
      planName: response.planName,
    );
    
    // Also save to Supabase for analytics and backup
    try {
      await _saveToSupabase(response);
    } catch (error, stackTrace) {
      _logger.error('Failed to save survey response to Supabase',
        context: 'FEEDBACK',
        error: error,
        stackTrace: stackTrace
      );
      // Don't throw error - local save already succeeded
      // The survey was saved locally, so this is not a critical failure
    }
  }
  
  /// Save survey response to Supabase feedback table
  Future<void> _saveToSupabase(SurveyResponse response) async {
    
    final feedbackId = const Uuid().v4();
    final feedbackData = {
      'id': feedbackId,
      'satisfaction_level': response.confidenceLevel.value,
      'satisfaction_emoji': _getConfidenceEmoji(response.confidenceLevel),
      'satisfaction_label': response.confidenceLevel.label,
      'confidence_level': response.confidenceLevel.value,
      'confidence_label': response.confidenceLevel.label,
      'reuse_intent': response.reuseIntent.value,
      'reminder_requested': response.reminderPreference != null,
      'missed_reasons': response.missedReason?.value,
      'missed_other': response.missedOther,
      'reminder_day_of_week': response.reminderPreference?.dayOfWeek,
      'reminder_hour': response.reminderPreference?.hour ?? 17,
      'reminder_minute': response.reminderPreference?.minute ?? 0,
      'reminder_recurring': response.reminderPreference?.isRecurring ?? false,
      'plan_name': response.planName,
      'user_name': response.deviceId, // Using deviceId as user identifier
      'timestamp': response.timestamp?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
    
    try {
      await _supabase.from('feedback').insert(feedbackData).select();
    } catch (e) {
      _logger.error('Supabase insert failed for survey feedback',
        context: 'FEEDBACK',
        error: e
      );
      rethrow; // Let the caller handle the error
    }
  }
  
  /// Get emoji for confidence level (since ConfidenceLevel doesn't have emoji property)
  String _getConfidenceEmoji(ConfidenceLevel level) {
    switch (level) {
      case ConfidenceLevel.notAtAll:
        return '😞';
      case ConfidenceLevel.aLittle:
        return '😐';
      case ConfidenceLevel.somewhat:
        return '🤔';
      case ConfidenceLevel.very:
        return '😊';
      case ConfidenceLevel.extremely:
        return '🤗';
    }
  }

  /// Get latest survey response for device
  Future<FeedbackEntry?> getLatestSurveyResponse(String deviceId) async {
    return await _database.getLatestSurveyResponse(deviceId);
  }

  /// Update user notification preferences
  Future<void> updateUserNotificationPreferences({
    required String userId,
    required NotificationPreference preference,
  }) async {
    await _database.updateUserNotificationPreferences(
      userId: userId,
      notificationsEnabled: true, // User explicitly requested notifications
      defaultReminderDay: preference.dayOfWeek ?? 4, // Default to Thursday if null
      defaultReminderHour: preference.hour,
      defaultReminderMinute: preference.minute,
      defaultReminderRecurring: preference.isRecurring,
    );
  }

  /// Check if user has submitted survey recently (DISABLED for development)
  /// Always returns false to allow unlimited survey submissions
  /// TODO: Re-enable time restrictions for production
  Future<bool> hasRecentSurveyResponse(String deviceId) async {
    return false; // Always allow survey submissions during development
  }

  /// Convert database entry to domain model for UI consumption
  SurveyResponse? convertToSurveyResponse(FeedbackEntry? entry) {
    if (entry == null) return null;
    
    final confidenceLevel = entry.confidenceLevel != null 
        ? ConfidenceLevel.fromValue(entry.confidenceLevel!)
        : ConfidenceLevel.somewhat;
        
    final reuseIntent = entry.reuseIntent != null
        ? ReuseIntent.fromValue(entry.reuseIntent!)
        : ReuseIntent.maybe;
    
    NotificationPreference? reminderPreference;
    if (entry.reminderRequested && entry.reminderDayOfWeek != null) {
      reminderPreference = NotificationPreference(
        dayOfWeek: entry.reminderDayOfWeek!,
        hour: entry.reminderHour,
        minute: entry.reminderMinute,
        isRecurring: entry.reminderRecurring,
      );
    }
    
    MissedReason? missedReason;
    if (entry.missedReasons != null && entry.missedReasons!.isNotEmpty) {
      // Parse comma-separated reasons, take first one
      final reasons = entry.missedReasons!.split(',');
      if (reasons.isNotEmpty) {
        missedReason = MissedReason.fromValue(reasons.first.trim());
      }
    }
    
    return SurveyResponse(
      confidenceLevel: confidenceLevel,
      reuseIntent: reuseIntent,
      reminderPreference: reminderPreference,
      missedReason: missedReason,
      missedOther: entry.missedOther,
      deviceId: entry.deviceId,
      planName: entry.planName,
      timestamp: entry.createdAt,
    );
  }
}