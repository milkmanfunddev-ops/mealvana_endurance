import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/onboarding_analytics.dart';
import '../widgets/page_keep_alive_wrapper.dart';
import 'sports_selection_screen.dart';
import 'goals_screen.dart';
import 'pitfalls_screen.dart';
import 'personal_info_screen.dart';
import 'body_composition_screen.dart';
import 'nutrition_settings_screen.dart';
import 'plan_reveal_screen.dart';
import 'daily_plan_preview_screen.dart';
import '../../../settings/presentation/screens/connected_apps_screen.dart';

/// Onboarding PageView Screen - Wrapper for all onboarding steps
///
/// Uses PageView to maintain state across all screens and enable swipe
/// navigation. The page list is static (no more sports-dependent dynamic
/// pages) and index-aligned with [kOnboardingStepNames] — that alignment IS
/// the Mixpanel funnel contract.
///
/// Note: the splash (welcome screen) is shown separately at /welcome before
/// navigating here.
///
/// Flow (2026-08 redesign):
/// 0. Sports Selection   4. Personal Info         8. Daily Plan Preview
/// 1. Goals              5. Body Composition
/// 2. Pitfalls           6. Nutrition Settings
/// 3. Connect Training   7. Plan Reveal
///
/// The final step's "Save My Plan" routes to /auth/post-onboarding via
/// _nextPage's last-page branch. The plan-reveal/daily-preview connect
/// nudges pop back to the connect step (page 3) via [_goToConnectStep].
class OnboardingPageViewScreen extends ConsumerStatefulWidget {
  const OnboardingPageViewScreen({super.key});

  @override
  ConsumerState<OnboardingPageViewScreen> createState() =>
      _OnboardingPageViewScreenState();
}

class _OnboardingPageViewScreenState
    extends ConsumerState<OnboardingPageViewScreen> {
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Build the list of pages.
  ///
  /// The `stepIndex` passed to each screen must stay aligned with this list's
  /// order — it is what stamps `step_index` onto the per-screen `screen_viewed`
  /// events, and with [kOnboardingStepNames] it defines the drop-off funnel.
  /// Change one, change both.
  List<Widget> _buildPages() {
    return [
      // 0. Sports Selection (first page — can't go back)
      PageKeepAliveWrapper(
        child: SportsSelectionScreen(
          onContinue: _nextPage,
          onBack: null,
          stepIndex: 0,
        ),
      ),

      // 1. Goals
      PageKeepAliveWrapper(
        child: GoalsScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 1,
        ),
      ),

      // 2. Pitfalls
      PageKeepAliveWrapper(
        child: PitfallsScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 2,
        ),
      ),

      // 3. Connect Training (Garmin, Final Surge, TrainingPeaks, etc.) —
      // existing screen, wiring unchanged from the pre-redesign flow, just
      // repositioned. Restyle lands in redesign phase 5.
      PageKeepAliveWrapper(
        child: ConnectedAppsScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 3,
        ),
      ),

      // 4. Personal Info (names/email optional; gender + birth year gate)
      PageKeepAliveWrapper(
        child: PersonalInfoScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 4,
        ),
      ),

      // 5. Body Composition (unit toggle, height/weight wheels)
      PageKeepAliveWrapper(
        child: BodyCompositionScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 5,
        ),
      ),

      // 6. Nutrition Settings (gut training + sweat rate dials)
      PageKeepAliveWrapper(
        child: NutritionSettingsScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 6,
        ),
      ),

      // 7. Plan Reveal (loader → editable fueling targets)
      PageKeepAliveWrapper(
        child: PlanRevealScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 7,
          onConnectTap: _goToConnectStep,
        ),
      ),

      // 8. Daily Plan Preview (final step — its "Save My Plan" routes to
      // /auth/post-onboarding via _nextPage's last-page branch).
      PageKeepAliveWrapper(
        child: DailyPlanPreviewScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 8,
          onConnectTap: _goToConnectStep,
        ),
      ),
    ];
  }

  /// Pop back to the connect step (page 3) — used by the "Connect now"
  /// nudge on the plan-reveal and daily-preview screens.
  void _goToConnectStep() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Navigate to next page or complete onboarding
  void _nextPage() {
    // Dismiss keyboard before navigation
    FocusManager.instance.primaryFocus?.unfocus();

    if (_pageController.hasClients) {
      final pages = _buildPages();

      // Every step's Continue routes through here, so this is the one place
      // that sees the whole funnel. Fires only on an explicit Continue tap —
      // a swipe advances via `onPageChanged` and is deliberately not counted
      // as completing a step, since the user may not have filled it in.
      _trackStepCompleted(_currentPageIndex);

      if (_currentPageIndex < pages.length - 1) {
        _pageController.animateToPage(
          _currentPageIndex + 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Last page - navigate to post-onboarding auth
        _trackOnboardingCompleted(pages.length);
        if (mounted) {
          context.go('/auth/post-onboarding');
        }
      }
    }
  }

  void _trackStepCompleted(int stepIndex) {
    try {
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'onboarding_step_completed',
            properties: {
              'step_name': onboardingStepName(stepIndex),
              'step_index': stepIndex,
            },
          );
    } catch (_) {
      // Analytics must never block onboarding navigation.
    }
  }

  void _trackOnboardingCompleted(int stepCount) {
    try {
      final durationSec = OnboardingAnalytics.durationSec();
      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'onboarding_completed',
            properties: {
              'step_count': stepCount,
              // Omitted rather than zeroed when onboarding wasn't entered through
              // the welcome screen — a bogus 0 would drag the median down.
              if (durationSec != null) 'duration_sec': durationSec,
            },
          );
    } catch (_) {
      // Analytics must never block onboarding navigation.
    }
  }

  /// Navigate to previous page
  void _previousPage() {
    // Dismiss keyboard before navigation
    FocusManager.instance.primaryFocus?.unfocus();

    if (_pageController.hasClients && _currentPageIndex > 0) {
      _pageController.animateToPage(
        _currentPageIndex - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    // Each screen has its own Scaffold and progress bar, so we just use PageView
    // Note: ContentArea.narrow is applied within each individual screen's Scaffold
    return PageView(
      controller: _pageController,
      physics: const ClampingScrollPhysics(), // Enable swipe navigation
      onPageChanged: (index) {
        // Dismiss keyboard when page changes (e.g., swipe)
        FocusManager.instance.primaryFocus?.unfocus();

        setState(() {
          _currentPageIndex = index;
        });
      },
      children: pages,
    );
  }
}
