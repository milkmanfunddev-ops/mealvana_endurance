// ARCHIVED 2026-09-21 (paywall ticket 08, mp-459 / mp-417).
// From lib/features/onboarding/presentation/screens/welcome_screen.dart,
// `_getStarted`: the block that ran between the funnel mark and the
// navigation. Not compiled: this folder is excluded from analysis.

    // CRITICAL: Create a fresh start for onboarding
    // 1. Sign out any existing session to ensure we start fresh
    // 2. Create new anonymous session for this onboarding flow
    // 3. Clear any temp user ID from previous attempts
    final supabase = externalDeps.supabaseClient;

    try {
      // Sign out existing session (if any) to start completely fresh
      await supabase.auth.signOut();

      // Create new anonymous session for onboarding
      await supabase.auth.signInAnonymously();

      // Clear temp user ID from any previous onboarding attempts
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_temp_user_id');
    } catch (e) {
      // Log but continue - onboarding flow will handle auth if needed
      debugPrint('[WELCOME] Error creating fresh session: $e');
    }

    // ... (navigation, unchanged) ...
    //
    // The anonymous session created above is deliberately NOT gated on this:
    // it is how the app functions at all (contract performance), not analytics.
