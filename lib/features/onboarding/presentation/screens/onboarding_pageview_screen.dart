import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../providers/onboarding_analytics.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/page_keep_alive_wrapper.dart';
import 'user_profile_screen.dart';
import 'sports_selection_screen.dart';
import 'dietary_preference_screen.dart';
import 'allergies_screen.dart';
import '../../../settings/presentation/screens/connected_apps_screen.dart';

/// Onboarding PageView Screen - Wrapper for all onboarding steps
///
/// Uses PageView to maintain state across all screens and enable swipe navigation.
/// Dynamically builds pages based on selected sports to show/hide sport detail screens.
///
/// Note: Welcome screen is shown separately at /welcome before navigating here.
///
/// Flow:
/// 1. Connect Training (Final Surge, TrainingPeaks, etc.)
/// 2. User Profile
/// 3. Sports Selection
/// 4-6. [Dynamic] Sport Details (Running, Cycling, Swimming based on selection)
/// 7. Dietary Preference
/// 8. Allergies (final step)
class OnboardingPageViewScreen extends ConsumerStatefulWidget {
  const OnboardingPageViewScreen({super.key});

  @override
  ConsumerState<OnboardingPageViewScreen> createState() => _OnboardingPageViewScreenState();
}

class _OnboardingPageViewScreenState extends ConsumerState<OnboardingPageViewScreen> {
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

  /// Build the list of pages dynamically based on selected sports
  ///
  /// The `stepIndex` passed to each screen must stay aligned with this list's
  /// order — it is what stamps `step_index` onto the per-screen `screen_viewed`
  /// events, and with [kOnboardingStepNames] it defines the drop-off funnel.
  List<Widget> _buildPages(Set<String> selectedSports) {
    return [
      // 1. Connect Training (Final Surge, TrainingPeaks, etc.)
      PageKeepAliveWrapper(
        child: ConnectedAppsScreen(
          onContinue: _nextPage,
          onBack: null, // First page - can't go back
          stepIndex: 0,
        ),
      ),

      // 2. User Profile
      PageKeepAliveWrapper(
        child: UserProfileScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 1,
        ),
      ),

      // 3. Sports Selection
      PageKeepAliveWrapper(
        child: SportsSelectionScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          onSportsChanged: _handleSportsChanged,
          stepIndex: 2,
        ),
      ),

      // Sport detail pages skipped for v1.16 - fields left null/unset
      // Running/Cycling/Swimming detail screens are preserved but not shown

      // 4. Dietary Preference
      PageKeepAliveWrapper(
        child: DietaryPreferenceScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 3,
        ),
      ),

      // 7. Allergies (final onboarding step — its Continue routes to post-onboarding auth)
      PageKeepAliveWrapper(
        child: AllergiesScreen(
          onContinue: _nextPage,
          onBack: _previousPage,
          stepIndex: 4,
        ),
      ),

      // Food Preferences step removed (2026-06-25): food likes/dislikes are no
      // longer collected. Allergies + dietary restrictions are kept; nutrition
      // planning is driven by formulas/pinned formulas, not food preferences.
    ];
  }

  /// Handle sports selection changes
  void _handleSportsChanged(Set<String> newSports) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final oldSports = controller.cachedSelectedSports;

    // Cache the new sports selection
    controller.cacheSelectedSports(newSports);

    // If we're currently on a sport detail page that's being removed,
    // we need to adjust the page index
    if (oldSports.length > newSports.length) {
      // A sport was removed - check if we need to adjust current page
      // Rebuild pages to get new structure
      setState(() {
        // The state rebuild will trigger a new page list build
        // We'll handle page adjustment after the rebuild
      });

      // If we're past the sports selection screen, we might need to adjust
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentPageIndex > 2) {
          // We're on or past sport details - may need to adjust
          // For simplicity, just stay on current page if valid, else go to sports selection
          final newPages = _buildPages(newSports);
          if (_currentPageIndex >= newPages.length) {
            // Current page index is now invalid, go back to sports selection (page 2)
            _goToPage(2);
          }
        }
      });
    } else {
      // Sports added or unchanged - just rebuild
      setState(() {});
    }
  }

  /// Navigate to next page or complete onboarding
  void _nextPage() {
    // Dismiss keyboard before navigation
    FocusManager.instance.primaryFocus?.unfocus();

    if (_pageController.hasClients) {
      final selectedSports = ref.read(onboardingControllerProvider.notifier).cachedSelectedSports;
      final pages = _buildPages(selectedSports);

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
      ref.read(appExternalDepsProvider).analytics.track(
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
      ref.read(appExternalDepsProvider).analytics.track(
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

  /// Jump to specific page
  void _goToPage(int pageIndex) {
    // Dismiss keyboard before navigation
    FocusManager.instance.primaryFocus?.unfocus();

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the controller to rebuild when sports selection changes
    ref.watch(onboardingControllerProvider);

    final selectedSports = ref.read(onboardingControllerProvider.notifier).cachedSelectedSports;
    final pages = _buildPages(selectedSports);

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
