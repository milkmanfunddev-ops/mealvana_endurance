import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/privacy/analytics_consent.dart';
import '../providers/onboarding_analytics.dart';
import '../theme/onboarding_design_tokens.dart';

/// Welcome Screen (splash) — pixel port of the onboarding HTML spec
/// (../prototypes/onboarding/index.html). Every value below is the
/// prototype's own CSS value; do not harmonize with the app theme.
/// Controller wiring (fresh anonymous session, consent routing, funnel
/// start mark) is unchanged from the pre-redesign screen.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.onContinue});

  /// Callback to advance to next page (optional for standalone use)
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: OnbTokens.bg,
      body: Container(
        // Spec: background:radial-gradient(115% 55% at 50% 8%,#4a2143 0%,#381633 55%)
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.84), // 50% x, 8% y
            radius: 1.0,
            transform: _SpecEllipse(sx: 1.15, sy: 0.55),
            colors: [OnbTokens.cardRaised, OnbTokens.bg],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          bottom: false,
          // Spec container: padding 52px 30px 34px. 52 sits under the
          // prototype's fake status bar (real SafeArea supplies it); the
          // 34px bottom is measured to the frame edge, so the device's
          // home-indicator inset counts toward it instead of stacking.
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              30,
              0,
              30,
              (34 - MediaQuery.paddingOf(context).bottom).clamp(0, 34) +
                  MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              children: [
                Expanded(child: Center(child: _buildCenterBlock())),
                _buildFooter(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo mark, spec stroke #f8f6eb. Derived transparent asset — both
        // source logos have opaque backgrounds baked in (plum / white), so
        // tinting them paints a square; onboarding_logo_cream.png is the
        // same mark alpha-extracted and recolored to the spec cream.
        Image.asset(
          'assets/images/onboarding_logo_cream.png',
          height: 84,
          semanticLabel: 'Mealvana Endurance logo',
        ),
        const SizedBox(height: 14),
        const Text(
          'Mealvana',
          key: ValueKey('welcome.wordmark'),
          style: TextStyle(
            fontFamily: OnbTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 30,
            color: OnbTokens.cream,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'ENDURANCE',
          style: TextStyle(
            fontFamily: OnbTokens.fontBody,
            fontWeight: FontWeight.w500,
            fontSize: 13,
            // .42em of 13px, applied left too via the spec's padding-left
            letterSpacing: 13 * 0.42,
            color: OnbTokens.creamA(0.55),
          ),
        ),
        const SizedBox(height: 44),
        const Text(
          'Get more out of\nevery session.',
          key: ValueKey('welcome.title'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: OnbTokens.fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 34,
            height: 1.02,
            letterSpacing: 34 * -0.01,
            color: OnbTokens.cream,
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 290),
          child: Text.rich(
            key: const ValueKey('welcome.description'),
            TextSpan(
              style: TextStyle(
                fontFamily: OnbTokens.fontBody,
                fontSize: 15.5,
                height: 1.5,
                color: OnbTokens.creamA(0.7),
              ),
              children: const [
                TextSpan(text: 'Fueling plans built for how '),
                TextSpan(
                  text: 'you',
                  style: TextStyle(color: OnbTokens.teal),
                ),
                TextSpan(
                  text: ' train — so you stop guessing your carbs mid-race.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Spec CTA: width 100%; #f78b14; #381633 text; radius 100;
        // padding 16; Sansita 700 17; glow 0 0 40 rgba(247,139,20,.28).
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OnbTokens.rPill),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47F78B14), // rgba(247,139,20,.28)
                  blurRadius: 40,
                ),
              ],
            ),
            child: Material(
              color: OnbTokens.orange,
              borderRadius: BorderRadius.circular(OnbTokens.rPill),
              child: InkWell(
                key: const ValueKey('welcome.get_started_button'),
                borderRadius: BorderRadius.circular(OnbTokens.rPill),
                onTap: () => _getStarted(context, ref),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Build My Plan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: OnbTokens.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: OnbTokens.bg,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const ValueKey('welcome.log_in_button'),
          style: TextButton.styleFrom(padding: const EdgeInsets.all(12)),
          onPressed: () => _goToLogin(context, ref),
          child: Text(
            'I already have an account',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 14,
              color: OnbTokens.creamA(0.6),
            ),
          ),
        ),
      ],
    );
  }

  void _getStarted(BuildContext context, WidgetRef ref) async {
    // Track get started
    final externalDeps = ref.read(appExternalDepsProvider);
    externalDeps.analytics.track('welcome_get_started_tapped');

    // Start of the onboarding funnel — read back at the final step to derive
    // `duration_sec` on `onboarding_completed`.
    OnboardingAnalytics.markStarted();

    // Capture navigation info before async operations
    final shouldUseCallback = onContinue != null;
    final callback = onContinue;
    final navigator = GoRouter.of(context);

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

    // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
    if (shouldUseCallback && callback != null) {
      callback();
      return;
    }

    // Strict-regime users (EEA/UK, Washington) answer the analytics question
    // first, as the opening step of onboarding. Everyone else goes straight in
    // and never sees it — they get disclosure plus the Settings → Privacy
    // opt-out instead. `needsPrompt` already encodes that regional rule.
    //
    // The anonymous session created above is deliberately NOT gated on this:
    // it is how the app functions at all (contract performance), not analytics.
    final consent = ref.read(analyticsConsentProvider);
    navigator.push(
      consent.needsPrompt ? '/privacy-consent?next=/onboarding' : '/onboarding',
    );
  }

  void _goToLogin(BuildContext context, WidgetRef ref) {
    // Track login button tap
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('welcome_login_tapped');

    // Navigate to post-onboarding auth screen in login mode
    context.push('/auth/post-onboarding?mode=login');
  }
}

/// Scales the circular Flutter [RadialGradient] into the spec's CSS ellipse
/// (`radial-gradient(115% 55% at ...)`): x radius 115% of width, y radius
/// 55% of height, anchored at the gradient center.
class _SpecEllipse extends GradientTransform {
  const _SpecEllipse({required this.sx, required this.sy});

  final double sx;
  final double sy;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    final cy = bounds.top + bounds.height * 0.08;
    return Matrix4.identity()
      ..translateByDouble(cx, cy, 0, 1)
      ..scaleByDouble(sx, sy * (bounds.height / bounds.width), 1, 1)
      ..translateByDouble(-cx, -cy, 0, 1);
  }
}
