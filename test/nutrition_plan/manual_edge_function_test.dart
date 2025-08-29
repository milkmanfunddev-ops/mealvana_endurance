import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Manual test script to directly test the generate-ai-nutrition-plan edge function
/// This bypasses the Flutter app and tests the edge function directly
void main() async {
  // Get environment variables
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'];
  
  if (supabaseUrl == null || supabaseKey == null) {
    print('❌ Missing environment variables!');
    print('Please set SUPABASE_URL and SUPABASE_ANON_KEY');
    exit(1);
  }

  final edgeFunction = '$supabaseUrl/functions/v1/generate-ai-nutrition-plan';
  
  // Test data with adjusted macro targets  
  final testData = {
    'device_id': 'manual-test-${DateTime.now().millisecondsSinceEpoch}',
    'age': 30,
    'gender': 'male',
    'weight_kg': 75.0,
    'height_cm': 180.0,
    'gut_training_level': 'moderate',
    'liked_foods': ['banana', 'oatmeal', 'sports_drink', 'energy_bar'],
    'willing_to_try_foods': ['dates', 'gels'],
    'disliked_foods': ['protein_powder'],
    'macro_targets': {
      'pre_run': {
        'carbs_g': 75.0,      // ← ADJUSTED VALUE (was 65.0)
        'protein_g': 25.0,    // ← ADJUSTED VALUE (was 20.0)
        'fat_g': 15.0,
        'water_ml': 600.0,    // ← ADJUSTED VALUE (was 500.0)
        'sodium_mg': 400.0,   // ← ADJUSTED VALUE (was 300.0)
      },
      'during_run': {
        'carbs_total_g': 45.0,     // ← ADJUSTED VALUE (was 35.0)
        'sodium_total_mg': 800.0,  // ← ADJUSTED VALUE (was 650.0)  
        'water_total_ml': 750.0,   // ← ADJUSTED VALUE (was 600.0)
      },
      'post_run': {
        'carbs_g': 80.0,      // ← ADJUSTED VALUE (was 70.0)
        'protein_g': 30.0,    // ← ADJUSTED VALUE (was 25.0)
        'fat_g': 12.0,
        'water_ml': 700.0,    // ← ADJUSTED VALUE (was 600.0)
        'sodium_mg': 500.0,   // ← ADJUSTED VALUE (was 450.0)
      },
    },
  };

  print('🧪 Manual Edge Function Test');
  print('📡 Endpoint: $edgeFunction');
  print('📊 Testing adjusted macro values:');
  final macroTargets = testData['macro_targets'] as Map<String, dynamic>;
  final preRun = macroTargets['pre_run'] as Map<String, dynamic>;
  final duringRun = macroTargets['during_run'] as Map<String, dynamic>; 
  final postRun = macroTargets['post_run'] as Map<String, dynamic>;
  print('   Pre-run carbs: ${preRun['carbs_g']}g (should be 75.0)');
  print('   During-run carbs: ${duringRun['carbs_total_g']}g (should be 45.0)');
  print('   Post-run carbs: ${postRun['carbs_g']}g (should be 80.0)');
  print('');

  try {
    print('🚀 Sending request...');
    
    final response = await http.post(
      Uri.parse(edgeFunction),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseKey',
        'apikey': supabaseKey,
      },
      body: jsonEncode(testData),
    );

    print('📥 Response Status: ${response.statusCode}');
    print('📄 Response Headers: ${response.headers}');
    
    if (response.statusCode < 400) {
      print('✅ SUCCESS! Edge function responded successfully');
      
      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Check if response has the expected structure
      if (responseData.containsKey('macro_targets')) {
        final returnedMacros = responseData['macro_targets'] as Map<String, dynamic>;
        
        print('');
        print('🔍 Returned Macro Targets Analysis:');
        
        final preRun = returnedMacros['pre_run'] as Map<String, dynamic>;
        final duringRun = returnedMacros['during_run'] as Map<String, dynamic>;
        final postRun = returnedMacros['post_run'] as Map<String, dynamic>;
        
        // Test critical values
        final preRunCarbs = preRun['carbs_g'];
        final duringRunCarbs = duringRun['carbs_total_g']; 
        final postRunCarbs = postRun['carbs_g'];
        
        print('   Pre-run carbs: ${preRunCarbs}g (expected: 75.0g) ${preRunCarbs == 75.0 ? '✅' : '❌'}');
        print('   During-run carbs: ${duringRunCarbs}g (expected: 45.0g) ${duringRunCarbs == 45.0 ? '✅' : '❌'}');
        print('   Post-run carbs: ${postRunCarbs}g (expected: 80.0g) ${postRunCarbs == 80.0 ? '✅' : '❌'}');
        
        // Check other adjusted values
        final preRunWater = preRun['water_ml'];
        final duringRunSodium = duringRun['sodium_total_mg'];
        final postRunProtein = postRun['protein_g'];
        
        print('   Pre-run water: ${preRunWater}ml (expected: 600ml) ${preRunWater == 600.0 ? '✅' : '❌'}');
        print('   During-run sodium: ${duringRunSodium}mg (expected: 800mg) ${duringRunSodium == 800.0 ? '✅' : '❌'}');
        print('   Post-run protein: ${postRunProtein}g (expected: 30g) ${postRunProtein == 30.0 ? '✅' : '❌'}');
        
        // Overall test result
        final allMatch = preRunCarbs == 75.0 && 
                        duringRunCarbs == 45.0 && 
                        postRunCarbs == 80.0 &&
                        preRunWater == 600.0 &&
                        duringRunSodium == 800.0 &&
                        postRunProtein == 30.0;
        
        print('');
        if (allMatch) {
          print('🎉 PERFECT! All adjusted macro values are correctly preserved!');
          print('   The edge function is receiving and returning the adjusted values.');
        } else {
          print('⚠️  ISSUE DETECTED! Some adjusted values are not preserved.');
          print('   This indicates the edge function is not properly handling adjusted macros.');
        }
        
      } else {
        print('❌ Response missing macro_targets field');
        print('Response body: ${response.body}');
      }
      
      // Check if nutrition plan was generated
      if (responseData.containsKey('plan')) {
        final plan = responseData['plan'] as Map<String, dynamic>;
        print('');
        print('🍎 Nutrition Plan Generated:');
        print('   Before items: ${(plan['before'] as List).length}');
        print('   During items: ${(plan['during'] as List).length}'); 
        print('   After items: ${(plan['after'] as List).length}');
      }
      
    } else {
      print('❌ FAILED! Edge function returned error');
      print('Response body: ${response.body}');
      
      // Check if it's a specific error we can interpret
      try {
        final errorData = jsonDecode(response.body) as Map<String, dynamic>;
        if (errorData.containsKey('fallback_to_algorithm')) {
          print('');
          print('ℹ️  Edge function indicated fallback to algorithm needed');
        }
      } catch (e) {
        // Response body not JSON
        print('Raw response: ${response.body}');
      }
    }
    
  } catch (e, stackTrace) {
    print('💥 ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}