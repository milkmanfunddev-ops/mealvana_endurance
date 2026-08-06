import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/onboarding_analytics.dart';
import '../widgets/onboarding_navigation_footer.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/page_keep_alive_wrapper.dart';
import 'sports_selection_screen.dart';
import 'goals_screen.dart';
import 'pitfalls_screen.dart';
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
/// 0. Sports Selection   4. Personal Info (stub)      8. Daily Plan Preview (stub)
/// 1. Goals              5. Body Composition (stub)
/// 2. Pitfalls           6. Nutrition Settings (stub)
/// 3. Connect Training   7. Plan Reveal (stub)
///
/// Steps 4-8 are temporary placeholder pages until redesign phase 5 lands the
/// real screens; they keep the flow navigable end-to-end and the final stub's
/// Continue routes to /auth/post-onboarding exactly like the finished flow.
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

      // 4-8. Temporary stubs until redesign phase 5 (see class doc).
      PageKeepAliveWrapper(
        child: _StubStepScreen(
          title: 'Personal Info',
          stepIndex: 4,
          onContinue: _nextPage,
          onBack: _previousPage,
        ),
      ),
      PageKeepAliveWrapper(
        child: _StubStepScreen(
          title: 'Body Composition',
          stepIndex: 5,
          onContinue: _nextPage,
          onBack: _previousPage,
        ),
      ),
      PageKeepAliveWrapper(
        child: _StubStepScreen(
          title: 'Nutrition Settings',
          stepIndex: 6,
          onContinue: _nextPage,
          onBack: _previousPage,
        ),
      ),
      PageKeepAliveWrapper(
        child: _StubStepScreen(
          title: 'Plan Reveal',
          stepIndex: 7,
          onContinue: _nextPage,
          onBack: _previousPage,
        ),
      ),
      // Final step — its Continue routes to /auth/post-onboarding via
      // _nextPage's last-page branch.
      PageKeepAliveWrapper(
        child: _StubStepScreen(
          title: 'Daily Plan Preview',
          stepIndex: 8,
          onContinue: _nextPage,
          onBack: _previousPage,
        ),
      ),
    ];
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

/// Minimal placeholder for a not-yet-built onboarding step (redesign phase 5).
///
/// Renders the step title on the standard dark scaffold with a working
/// Continue/Back footer so the flow stays navigable end-to-end, and stamps
/// the same `screen_viewed` + `step_index` event as a real step so funnel
/// indices stay comparable before/after phase 5 lands.
class _StubStepScreen extends ConsumerStatefulWidget {
  const _StubStepScreen({
    required this.title,
    required this.stepIndex,
    required this.onContinue,
    this.onBack,
  });

  final String title;
  final int stepIndex;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  ConsumerState<_StubStepScreen> createState() => _StubStepScreenState();
}

class _StubStepScreenState extends ConsumerState<_StubStepScreen> {
  @override
  void initState() {
    super.initState();
    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {
            'screen_name': '${widget.title} Onboarding',
            'step_index': widget.stepIndex,
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: OnboardingProgressBar(
              currentSegment: widget.stepIndex + 1,
              totalSegments: kOnboardingStepNames.length,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Sansita',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orange,
                  height: 1.0,
                ),
              ),
            ),
          ),
          OnboardingNavigationFooter(
            onContinue: widget.onContinue,
            onBack: widget.onBack,
            showBack: widget.onBack != null,
          ),
        ],
      ),
    );
  }
}
