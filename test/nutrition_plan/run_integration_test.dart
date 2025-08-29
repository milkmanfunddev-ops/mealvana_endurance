import 'dart:io';
import 'generate_ai_nutrition_plan_integration_test.dart' as integration_tests;

/// Simple script to run the integration test
/// 
/// Usage:
/// 1. Set environment variables:
///    export SUPABASE_URL="https://your-project.supabase.co"
///    export SUPABASE_ANON_KEY="your-anon-key"
/// 
/// 2. Run the test:
///    dart test test/nutrition_plan/run_integration_test.dart
void main() {
  // Check if required environment variables are set
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_ANON_KEY'];
  
  if (supabaseUrl == null || supabaseKey == null) {
    print('❌ Missing environment variables!');
    print('Please set the following environment variables:');
    print('  SUPABASE_URL="https://your-project.supabase.co"');
    print('  SUPABASE_ANON_KEY="your-anon-key"');
    print('');
    print('Example:');
    print('  export SUPABASE_URL="https://your-project.supabase.co"');
    print('  export SUPABASE_ANON_KEY="your-anon-key"');
    print('  dart test test/nutrition_plan/run_integration_test.dart');
    exit(1);
  }
  
  print('🚀 Running integration tests for generate-ai-nutrition-plan...');
  print('📡 Supabase URL: $supabaseUrl');
  print('🔑 Using provided anon key');
  print('');
  
  // Run the integration tests
  integration_tests.main();
}