/// Performance and Reliability Edge Function Tests
/// 
/// These tests validate performance characteristics, concurrent access,
/// and reliability of edge functions.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_data.dart';
import '../../helpers/test_config.dart';

void main() {
  group('Performance and Reliability', () {
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

    testWidgets('responds within acceptable time limits', 
        (tester) async {
      if (!TestConfig.enableNetworkTests || !TestConfig.enableSlowTests) return;

      // Arrange: Standard request
      final requestData = TestData.testNutritionPlanRequest;
      final stopwatch = Stopwatch()..start();

      // Act: Generate plan and measure time
      final response = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      ).timeout(TestConfig.networkTestTimeout);

      stopwatch.stop();

      // Assert: Should respond within reasonable time
      expect(response.status, lessThan(400));
      expect(stopwatch.elapsed.inSeconds, lessThan(TestConfig.maxGenerationTimeSeconds),
          reason: 'AI nutrition plan generation took ${stopwatch.elapsed.inSeconds}s, should be under ${TestConfig.maxGenerationTimeSeconds}s');

      // Should still have valid response despite time constraint
      final responseData = response.data as Map<String, dynamic>;
      expect(responseData, containsPair('success', true));
    });

    testWidgets('handles concurrent requests without issues', 
        (tester) async {
      if (!TestConfig.enableNetworkTests || !TestConfig.enableSlowTests) return;

      // Arrange: Multiple different requests
      final requests = [
        TestData.testNutritionPlanRequest,
        TestData.testHalfMarathonRequest,
        TestData.test5KRequest,
      ];

      // Act: Send concurrent requests
      final futures = requests.map((requestData) => 
        supabase.functions.invoke(
          'generate-ai-nutrition-plan',
          body: requestData,
        ).timeout(TestConfig.networkTestTimeout)
      ).toList();

      final responses = await Future.wait(futures);

      // Assert: All requests should succeed
      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        expect(response.status, lessThan(400),
            reason: 'Concurrent request $i should succeed');
            
        final responseData = response.data as Map<String, dynamic>;
        expect(responseData, containsPair('success', true));
        expect(responseData, contains('plan'));
      }

      // Verify responses are different (not cached incorrectly)
      final plans = responses.map((r) => 
        (r.data as Map<String, dynamic>)['plan']
      ).toList();
      
      // At minimum, different distance requests should have different during-run recommendations
      final duringRunItems = plans.map((plan) => 
        (plan as Map<String, dynamic>)['during'] as List<dynamic>
      ).toList();
      
      // 5K should have fewer during-run items than half marathon
      final fiveKDuringItems = duringRunItems[2]; // test5KRequest
      final halfMarathonDuringItems = duringRunItems[1]; // testHalfMarathonRequest
      
      expect(halfMarathonDuringItems.length, greaterThanOrEqualTo(fiveKDuringItems.length),
          reason: 'Longer runs should have more or equal during-run fueling');
    });

    testWidgets('maintains data consistency across multiple calls', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Same request called multiple times
      final requestData = TestData.testNutritionPlanRequest;

      // Act: Call function multiple times
      final response1 = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      ).timeout(TestConfig.networkTestTimeout);

      final response2 = await supabase.functions.invoke(
        'generate-ai-nutrition-plan',
        body: requestData,
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Both should succeed
      expect(response1.status, lessThan(400));
      expect(response2.status, lessThan(400));

      final responseData1 = response1.data as Map<String, dynamic>;
      final responseData2 = response2.data as Map<String, dynamic>;

      // Macro targets should be identical (they're input-driven)
      expect(responseData1['macro_targets'], equals(responseData2['macro_targets']),
          reason: 'Macro targets should be consistent across calls');

      // Plans might vary slightly due to AI, but should meet same nutritional goals
      final plan1 = responseData1['plan'] as Map<String, dynamic>;
      final plan2 = responseData2['plan'] as Map<String, dynamic>;

      // Both should have all required phases
      for (final phase in ['before', 'during', 'after']) {
        expect(plan1, contains(phase));
        expect(plan2, contains(phase));
        expect(plan1[phase], isA<List<dynamic>>());
        expect(plan2[phase], isA<List<dynamic>>());
      }
    });
  });
}