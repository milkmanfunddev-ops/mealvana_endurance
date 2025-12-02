/// Test Configuration for Integration Tests
///
/// Contains test account credentials, timeouts, and configuration
/// for running integration tests against the dev Supabase instance.
library;

/// Configuration for integration tests
class TestConfig {
  /// Test account credentials for email/password login tests
  static const testEmail = 'test@test.com';
  static const testPassword = 'test';

  /// Supabase Dev Environment
  /// These match the values in .env.dev.local
  static const supabaseUrl = 'https://vlmtsdzpnjnavdgytcmi.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsbXRzZHpwbmpuYXZkZ3l0Y21pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDM0NDQ5MTAsImV4cCI6MjA1OTAyMDkxMH0.7iH2kqvRQUa4tFPYHJVSMJK3MYEYhP9RmUfX6l2YWYE';

  /// Test timeouts
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration mediumTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 2);

  /// Delays for UI interactions
  /// Keep these minimal - pumpAndSettle() handles most waiting
  static const Duration tapDelay = Duration(milliseconds: 100);
  static const Duration animationDelay = Duration(milliseconds: 200);
  static const Duration networkDelay = Duration(seconds: 1);
  static const Duration pageTransitionDelay = Duration(milliseconds: 300);

  /// Test data
  static const testUserProfile = TestUserProfile(
    gender: 'female',
    birthday: '1990-05-15',
    heightFeet: 5,
    heightInches: 6,
    weightPounds: 145.0,
    gutTrainingLevel: 'moderate',
  );

  /// Test activity data
  static const testActivity = TestActivityData(
    distanceMiles: 10.0,
    paceMinutes: 9,
    paceSeconds: 30,
  );

  /// Test event data
  static const testEvent = TestEventData(
    name: 'Test Marathon',
    location: 'Austin, TX',
    goalHours: 4,
    goalMinutes: 30,
  );
}

/// Test user profile data
class TestUserProfile {
  final String gender;
  final String birthday;
  final int heightFeet;
  final int heightInches;
  final double weightPounds;
  final String gutTrainingLevel;

  const TestUserProfile({
    required this.gender,
    required this.birthday,
    required this.heightFeet,
    required this.heightInches,
    required this.weightPounds,
    required this.gutTrainingLevel,
  });
}

/// Test activity data
class TestActivityData {
  final double distanceMiles;
  final int paceMinutes;
  final int paceSeconds;

  const TestActivityData({
    required this.distanceMiles,
    required this.paceMinutes,
    required this.paceSeconds,
  });
}

/// Test event data
class TestEventData {
  final String name;
  final String location;
  final int goalHours;
  final int goalMinutes;

  const TestEventData({
    required this.name,
    required this.location,
    required this.goalHours,
    required this.goalMinutes,
  });
}
