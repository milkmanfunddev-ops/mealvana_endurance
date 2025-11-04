/// Additional Edge Functions Tests
/// 
/// These tests validate supporting edge functions like
/// save-food-preferences and get-foods.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_config.dart';

void main() {
  group('Additional Edge Functions', () {
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

    testWidgets('save-food-preferences function works correctly', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Arrange: Food preferences to save
      final preferencesData = {
        'device_id': 'test-device-preferences',
        'preferences': {
          'oatmeal': 'like',
          'gels': 'like',
          'coffee': 'dislike',
          'energy_bar': 'willing_to_try',
        }
      };

      // Act: Call save preferences function
      final response = await supabase.functions.invoke(
        'save-food-preferences',
        body: preferencesData,
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Should save successfully
      expect(response.status, lessThan(400),
          reason: 'Save food preferences should succeed');

      final responseData = response.data as Map<String, dynamic>;
      expect(responseData, containsPair('success', true));
    });

    testWidgets('get-foods function returns food database', 
        (tester) async {
      if (!TestConfig.enableNetworkTests) return;

      // Act: Get foods database
      final response = await supabase.functions.invoke(
        'get-foods',
      ).timeout(TestConfig.networkTestTimeout);

      // Assert: Should return food database
      expect(response.status, lessThan(400));
      
      final responseData = response.data as Map<String, dynamic>;
      expect(responseData, containsPair('success', true));
      expect(responseData, contains('foods'));
      
      final foods = responseData['foods'] as List<dynamic>;
      expect(foods, isNotEmpty, reason: 'Should return food database');
      
      // Verify food structure
      final firstFood = foods.first as Map<String, dynamic>;
      expect(firstFood, contains('id'));
      expect(firstFood, contains('name'));
      expect(firstFood, contains('carbs_g'));
    });
  });
}