import 'package:flutter/foundation.dart';
import 'lib/features/feedback/application/supabase_feedback_service.dart';
import 'lib/features/feedback/domain/feedback_data.dart';

/// Quick test script to verify Supabase connection
Future<void> main() async {
  if (kDebugMode) {
    print('🧪 Testing Supabase connection...');
  }
  
  final service = SupabaseFeedbackService();
  
  // Test connection
  final connectionTest = await service.testConnection();
  if (kDebugMode) {
    print('Connection test: ${connectionTest ? '✅ SUCCESS' : '❌ FAILED'}');
  }
  
  if (connectionTest) {
    // Test actual feedback submission
    final testFeedback = FeedbackResponse(
      satisfactionLevel: SatisfactionLevel.justRight,
      appFeedback: AppFeedbackOption.likeIt,
      suggestions: 'Test from app - Supabase integration working!',
      planName: 'Test Plan',
      userName: 'Test User',
      timestamp: DateTime.now(),
    );
    
    final submitTest = await service.submitFeedback(testFeedback);
    if (kDebugMode) {
      print('Feedback submission test: ${submitTest ? '✅ SUCCESS' : '❌ FAILED'}');
    }
    
    // Get stats
    final stats = await service.getFeedbackStats();
    if (kDebugMode) {
      print('📊 Current stats: $stats');
    }
  }
}