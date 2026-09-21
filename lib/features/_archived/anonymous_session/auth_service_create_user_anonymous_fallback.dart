// ARCHIVED 2026-09-21 (paywall ticket 08, mp-459 / mp-417).
// From lib/features/auth/application/auth_service.dart, `createUser`: the
// parameters that defaulted a new profile to anonymous and the fallback that
// opened an anonymous session when no user was signed in. `createUser` now
// requires `authProvider`, writes `isAnonymous: false`, and throws with no
// session. Not compiled: this folder is excluded from analysis.

  /// Create a new user profile during onboarding using Supabase Auth
  /// Uses anonymous auth session created during app startup
  Future<UserProfile> createUser({
    // ... other parameters unchanged ...
    String authProvider =
        'anonymous', // 'anonymous', 'email', 'google', 'apple'
    bool isAnonymous = true, // false when user signs up with email/OAuth
  }) async {
    try {
      // Get or create Supabase auth session
      // Session may not exist if user logged out and is starting fresh
      var authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        _logger.info(
          'No auth session found, creating anonymous session for new user',
          context: 'AUTH',
        );
        final response = await _supabase.auth.signInAnonymously();
        authUser = response.user;
        if (authUser == null) {
          throw Exception('Failed to create anonymous session');
        }
      }

      // ...

      final userProfile = UserProfile(
        // ...
        authProvider: authProvider, // 'anonymous', 'email', 'google', 'apple'
        isAnonymous: isAnonymous, // false when user signs up with email/OAuth
        // ...
      );
