// ARCHIVED 2026-09-21 (paywall ticket 08, mp-459 / mp-417).
// From lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart,
// the head of `_handleAppleSignIn` (the Google handler was identical with
// 'Google'). Sign-up mode always linked onto an anonymous session, opening
// one first when none existed. Now sign-up links only when an old install's
// anonymous user is present (`_linksOldAnonymousInstall`) and otherwise
// signs in outright. Not compiled: this folder is excluded from analysis.

  Future<void> _handleAppleSignIn() async {
    final controller = ref.read(postOnboardingAuthControllerProvider.notifier);
    final isLogin = widget.mode == 'login';
    final supabase = ref.read(appExternalDepsProvider).supabaseClient;
    final authListenerService = ref.read(authListenerServiceProvider);

    if (!isLogin) {
      // For signup mode, we LINK to the existing anonymous session to preserve onboarding data.
      // If we don't have an anonymous session (unexpected), create one to link against.
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || !currentUser.isAnonymous) {
        // Preserve cached onboarding data while resetting the auth session.
        authListenerService.markOnboardingSignOut();
        await supabase.auth.signOut();
        final response = await supabase.auth.signInAnonymously();
        if (response.user == null) {
          if (mounted) {
            _handleError(context, 'Apple');
          }
          return;
        }
      }
    }

    // Signup mode: link to anonymous user (throws AccountAlreadyExistsException if provider exists)
    // Login mode: sign in to existing account (or create if none exists)
    final bool success = isLogin
        ? await controller.signInWithApple()
        : await controller.linkAppleAccount();

    if (!mounted) return;

    if (success) {
      if (kIsWeb) return;

      // Login mode: Navigate directly (no onboarding data to save)
      // Signup mode: Save cached onboarding data before navigating
      if (isLogin) {
        await _navigateToMain();
      } else {
        await _saveOnboardingDataAndNavigate(
          authProvider: 'apple',
          isAnonymous: false,
        );
      }
    } else {
      _handleError(context, 'Apple');
    }
  }
