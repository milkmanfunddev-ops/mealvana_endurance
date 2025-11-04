/// Test configuration for Mealvana Endurance tests
/// 
/// Contains environment-specific configuration for testing,
/// including Supabase credentials and test settings.
library;

class TestConfig {
  /// Supabase configuration for integration tests
  static const supabaseUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: 'https://your-test-project.supabase.co',
  );
  
  static const supabaseAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: 'your-test-anon-key',
  );

  /// Test timeouts
  static const defaultTestTimeout = Duration(seconds: 30);
  static const networkTestTimeout = Duration(seconds: 60);
  static const databaseTestTimeout = Duration(seconds: 15);

  /// Test database configuration
  static const testDatabaseName = 'mealvana_test.db';
  static const testDatabaseVersion = 2;

  /// Test user preferences
  static const testPreferencesKey = 'test_preferences';
  
  /// Tolerance levels for macro target validation
  static const carbToleranceGrams = 10.0;
  static const proteinToleranceGrams = 5.0;
  static const sodiumToleranceMg = 50.0;
  static const fluidToleranceMl = 100.0;

  /// Test flags
  static const enableNetworkTests = bool.fromEnvironment(
    'ENABLE_NETWORK_TESTS',
    defaultValue: false,
  );
  
  static const enableSlowTests = bool.fromEnvironment(
    'ENABLE_SLOW_TESTS',
    defaultValue: false,
  );

  /// Validation settings
  static const maxGenerationTimeSeconds = 10;
  static const minFoodItemsPerPhase = 1;
  static const maxFoodItemsPerPhase = 6;

  /// Content management test settings
  static const contentRefreshIntervalSeconds = 86400; // 24 hours
  static const contentCacheKey = 'test_app_content';

  /// Device authentication test settings  
  static const testDeviceIdPrefix = 'test-device-';
  static const deviceIdLength = 36;

  /// Schema migration test settings
  static const v1SchemaVersion = 1;
  static const v2SchemaVersion = 2;
  static const migrationTestDataSize = 100;

  /// Test environment validation
  static bool get isTestEnvironment {
    return supabaseUrl.contains('test') || 
           supabaseUrl.contains('localhost') ||
           supabaseUrl.contains('127.0.0.1');
  }

  /// Validates test configuration is properly set up
  static String? validateConfiguration() {
    if (supabaseUrl == 'https://your-test-project.supabase.co') {
      return 'TEST_SUPABASE_URL environment variable not set';
    }
    
    if (supabaseAnonKey == 'your-test-anon-key') {
      return 'TEST_SUPABASE_ANON_KEY environment variable not set';
    }

    if (!isTestEnvironment) {
      return 'Supabase URL does not appear to be a test environment';
    }

    return null; // Configuration is valid
  }
}