import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/feedback/domain/feedback_data.dart';

/// Test to verify Supabase feedback table integration
/// Run with: flutter test test/supabase/feedback_table_test.dart
void main() {
  group('Supabase Feedback Table Test', () {
    late ProviderContainer container;
    late FeedbackRepository feedbackRepository;

    setUpAll(() async {
      await Supabase.initialize(
        url: 'https://wvmvsodrvbkxfydabqed.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind2bXZzb2RydmJreGZ5ZGFicWVkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzA1MDU0NTIsImV4cCI6MjA0NjA4MTQ1Mn0.YvLQB7vBKl9TFM3sKSmFDJNHbFOo8Q7IKGFmgkBfpNw',
      );
    });

    setUp(() {
      container = ProviderContainer();
      feedbackRepository = container.read(feedbackRepositoryProvider);
    });

    tearDown(() {
      container.dispose();
    });

    test('Test Supabase connection and feedback table', () async {
      final testId = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create a test survey response
      final testResponse = SurveyResponse(
        confidenceLevel: ConfidenceLevel.very,
        reuseIntent: ReuseIntent.definitely,
        deviceId: 'test-device-$testId',
        planName: 'Test Plan',
        timestamp: DateTime.now(),
      );

      print('🧪 Starting feedback table test...');
      print('🔗 Supabase URL: ${Supabase.instance.client.supabaseUrl}');
      
      // Test if we can query the feedback table (this will tell us if it exists)
      try {
        print('🔍 Testing feedback table existence...');
        final tableTest = await Supabase.instance.client
            .from('feedback')
            .select('count(*)')
            .limit(1);
        print('✅ Feedback table exists and is accessible');
        print('📊 Current record count query result: $tableTest');
      } catch (e) {
        print('❌ Feedback table test failed: $e');
        print('💡 This might indicate the table does not exist or has permission issues');
      }

      // Test saving a survey response
      try {
        print('🧪 Testing survey response save...');
        await feedbackRepository.saveSurveyResponse(testResponse);
        print('✅ Survey response save completed (check logs above for details)');
      } catch (e) {
        print('❌ Survey response save failed: $e');
      }

      // Test querying the data back
      try {
        print('🔍 Testing feedback table query after insert...');
        final queryResult = await Supabase.instance.client
            .from('feedback')
            .select('*')
            .eq('user_name', 'test-device-$testId')
            .limit(1);
        
        if (queryResult.isNotEmpty) {
          print('✅ Found test data in feedback table!');
          print('📋 Retrieved data: ${queryResult.first}');
        } else {
          print('⚠️ No test data found in feedback table');
        }
      } catch (e) {
        print('❌ Query test failed: $e');
      }

      await Future.delayed(Duration(milliseconds: 500));
      
      print('');
      print('🏁 Feedback table test completed!');
      print('📊 Test ID: $testId');
      print('');
      print('Check the logs above for:');
      print('  - Supabase connection status');
      print('  - Table existence verification');
      print('  - Insert operation details');
      print('  - Query results');
      print('');
    });

    test('Test direct Supabase client access', () async {
      final client = Supabase.instance.client;
      
      print('🔗 Direct Supabase client test');
      print('📍 URL: ${client.supabaseUrl}');
      print('🔑 Has anon key: ${client.supabaseKey.isNotEmpty}');
      
      // Test a simple operation
      try {
        final result = await client.rpc('version').select();
        print('✅ Supabase connection successful');
        print('📊 Version info: $result');
      } catch (e) {
        print('❌ Supabase connection failed: $e');
      }
      
      // Test feedback table specifically
      try {
        final tableInfo = await client
            .from('feedback')
            .select('count(*)')
            .limit(1);
        print('✅ Feedback table is accessible');
        print('📊 Table info: $tableInfo');
      } catch (e) {
        print('❌ Feedback table access failed: $e');
        print('💡 Error details: ${e.toString()}');
      }
    });
  });
}