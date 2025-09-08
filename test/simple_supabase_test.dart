import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/feedback/domain/feedback_data.dart';

/// Simple test to check Supabase connection and feedback insertion
/// Run with: flutter test test/simple_supabase_test.dart
void main() {
  group('Simple Supabase Test', () {
    late ProviderContainer container;
    late FeedbackRepository feedbackRepository;

    setUpAll(() async {
      await Supabase.initialize(
        url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUyOTMxMDcsImV4cCI6MjA3MDg2OTEwN30.pG2IYdEIIFS8_zPxzr6pZplzWQqvD13dvslrpFMAPCk',
      );
    });

    setUp(() {
      container = ProviderContainer();
      feedbackRepository = container.read(feedbackRepositoryProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('Test direct Supabase feedback table insert', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();
      final client = Supabase.instance.client;
      
      print('🧪 Testing direct Supabase insert to feedback table');
      
      // Test with simple data structure
      final testData = {
        'id': 'test-$testId',
        'satisfaction_level': 4,
        'satisfaction_emoji': '😊',
        'satisfaction_label': 'Very Confident',
        'confidence_level': 4,
        'confidence_label': 'Very Confident',
        'reuse_intent': 1,
        'reminder_requested': false,
        'user_name': 'test-device-$testId',
        'created_at': DateTime.now().toIso8601String(),
      };

      try {
        print('🚀 Inserting test data...');
        final result = await client.from('feedback').insert(testData).select();
        print('✅ Insert successful!');
        print('📋 Result: $result');
      } catch (e) {
        print('❌ Insert failed: $e');
        print('📊 Attempted data: $testData');
      }

      // Test if we can read it back
      try {
        print('🔍 Querying for test data...');
        final queryResult = await client
            .from('feedback')
            .select('*')
            .eq('user_name', 'test-device-$testId')
            .limit(1);
        
        if (queryResult.isNotEmpty) {
          print('✅ Found inserted data!');
          print('📋 Retrieved: ${queryResult.first}');
        } else {
          print('⚠️ No data found in query');
        }
      } catch (e) {
        print('❌ Query failed: $e');
      }
      
      print('🏁 Direct insert test completed');
    });

    test('Test feedback repository save', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();
      
      print('🧪 Testing feedback repository save method');
      
      // Create a test survey response with correct enum values
      final testResponse = SurveyResponse(
        confidenceLevel: ConfidenceLevel.very,
        reuseIntent: ReuseIntent.yes,
        deviceId: 'repo-test-$testId',
        planName: 'Test Plan via Repository',
        timestamp: DateTime.now(),
      );

      try {
        print('🚀 Calling repository saveSurveyResponse...');
        await feedbackRepository.saveSurveyResponse(testResponse);
        print('✅ Repository save completed (check logs above for details)');
      } catch (e) {
        print('❌ Repository save failed: $e');
      }

      print('🏁 Repository test completed');
    });
  });
}