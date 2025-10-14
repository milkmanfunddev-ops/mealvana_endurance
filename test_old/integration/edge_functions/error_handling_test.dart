/// Error Handling and Fallback Edge Function Tests
/// 
/// These tests validate error handling, graceful degradation,
/// and fallback mechanisms in edge functions.

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_data.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Error Handling and Fallback', () {
    late SupabaseClient supabase;

    setUpAll(() {
      // Validate test environment before running
      final configError = TestConfig.validateConfiguration();
      if (configError != null) {
        fail('Test configuration invalid: $configError');
      }

      supabase = SupabaseClient(
        TestConfig.supabaseUrl,
        TestConfig.supabaseAnonKey,
      );
    });

    testWidgets('handles missing macro_targets gracefully', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Request without macro_targets (old format)
      final requestData = {
        'device_id': 'test-user-fallback',
        'age': 25,
        'gender': 'female',
        'weight_kg': 65.0,
        'height_cm': 165.0,
        'gut_training_level': 'beginner',
        'distance_miles': 10.0,
        'pace_minutes_per_mile': 9.0,
        'time_before_run_hours': 2.0,
        'liked_foods': ['banana', 'oatmeal'],
        'willing_to_try_foods': ['energy_bar'],
        'disliked_foods': [],
      };

      // Act: Call function with old format
      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Should either succeed or return graceful fallback
      if (response.status >= 400) {
        final responseData = response.data as Map<String, dynamic>?;
        expect(responseData?['fallback_to_algorithm'], equals(true),
            reason: 'Should indicate fallback when macro_targets missing');
        expect(responseData?['error'], isNotNull,
            reason: 'Should provide error explanation');
      } else {
        // If it succeeds, should have valid plan structure
        expect(response.status, lessThan(400));
        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
        expect(responseData, contains('plan'));
      }
    });

    testWidgets('validates macro_targets structure', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Invalid macro_targets structure
      final requestData = TestData.testNutritionPlanRequest.cast<String, dynamic>();
      requestData['macro_targets'] = {
        'pre_run': {
          'carbs_g': 50.0,
          // Missing required fields
        },
        // Missing during_run and post_run sections
      };

      // Act: Call function with invalid structure
      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Should return validation error
      expect(response.status, greaterThanOrEqualTo(400),
          reason: 'Should return error for invalid macro_targets structure');

      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null) {
        expect(responseData['success'], equals(false));
        expect(responseData['error'], isNotNull);
      }
    });

    testWidgets('handles network timeout gracefully', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Valid request but with very short timeout
      final requestData = TestData.testNutritionPlanRequest;

      // Act & Assert: Should handle timeout
      expect(
        () => supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(const Duration(milliseconds: 1)), // Very short timeout
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('provides meaningful error messages', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Request with invalid data types
      final invalidRequest = {
        'device_id': 123, // Should be string
        'age': 'thirty', // Should be number
        'weight_kg': 'heavy', // Should be number
        'liked_foods': 'oatmeal gels', // Should be array
      };

      // Act: Call function with invalid data
      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: invalidRequest,
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Should return meaningful error
      expect(response.status, greaterThanOrEqualTo(400));
      
      final responseData = response.data as Map<String, dynamic>?;
      if (responseData != null) {
        expect(responseData['success'], equals(false));
        expect(responseData['error'], isA<String>());
        expect(responseData['error'], isNot(isEmpty));
        
        // Should provide helpful error message
        final errorMessage = responseData['error'] as String;
        expect(errorMessage.toLowerCase(), anyOf([
          contains('invalid'),
          contains('required'),
          contains('type'),
          contains('format'),
        ]), reason: 'Error message should be descriptive');
      }
    });
  });
}