import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import '../widgets/onboarding_widgets.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/selection/figma_checkbox_card.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/adaptive/adaptive.dart';

/// Sports Selection Screen - Step 2 of Onboarding
///
/// Allows users to select which sports they participate in:
/// - Running (default selected)
/// - Cycling
/// - Swimming
///
/// Based on selection, navigates to sport-specific detail screens.
/// Matches Figma design specification exactly.
class SportsSelectionScreen extends ConsumerStatefulWidget {
  const SportsSelectionScreen({
    super.key,
    this.onContinue,
    this.onBack,
    this.onSportsChanged,
  });

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  /// Callback when sports selection changes (for PageView to rebuild pages)
  final void Function(Set<String>)? onSportsChanged;

  @override
  ConsumerState<SportsSelectionScreen> createState() =>
      _SportsSelectionScreenState();
}

class _SportsSelectionScreenState extends ConsumerState<SportsSelectionScreen> {
  // Sport selection state
  late Set<String> _selectedSports;

  @override
  void initState() {
    super.initState();

    // Initialize from controller cache (or default to running)
    final controller = ref.read(onboardingControllerProvider.notifier);
    _selectedSports = Set.from(controller.cachedSelectedSports);

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {'screen_name': 'Sports Selection Onboarding'},
        );
  }

  void _toggleSport(String sport) {
    setState(() {
      if (_selectedSports.contains(sport)) {
        // Don't allow deselecting if it's the only sport
        if (_selectedSports.length > 1) {
          _selectedSports.remove(sport);
        }
      } else {
        _selectedSports.add(sport);
      }
    });

    // Notify PageView of sports change
    if (widget.onSportsChanged != null) {
      widget.onSportsChanged!(_selectedSports);
    }
  }

  void _continue() async {
    // Validate at least one sport selected
    if (_selectedSports.isEmpty) {
      MealvanaSnackbar.showInfo(context, 'Please select at least one sport');
      return;
    }

    // Track selection
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(
      'sports_selected',
      properties: {
        'running': _selectedSports.contains('running'),
        'cycling': _selectedSports.contains('cycling'),
        'swimming': _selectedSports.contains('swimming'),
        'count': _selectedSports.length,
      },
    );

    if (!mounted) return;

    // Cache sports selection in controller
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.cacheSelectedSports(_selectedSports);

    // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      // Navigate to first sport detail screen or skip to diet if only running with no details needed
      // For now, go to running details if running selected, else cycling, else swimming
      if (_selectedSports.contains('running')) {
        context.push(
          '/onboarding/running-details',
          extra: _selectedSports.toList(),
        );
      } else if (_selectedSports.contains('cycling')) {
        context.push(
          '/onboarding/cycling-details',
          extra: _selectedSports.toList(),
        );
      } else if (_selectedSports.contains('swimming')) {
        context.push(
          '/onboarding/swimming-details',
          extra: _selectedSports.toList(),
        );
      } else {
        // Fallback to dietary preferences
        context.push('/onboarding/dietary-preference');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptivePageScaffold(
      backgroundColor: AppColors.blackberry,
      contentWidth: AdaptiveContentWidth.narrow,
      body: Column(
        children: [
          // Progress bar at the very top (no SafeArea padding)
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: const OnboardingProgressBar(
              currentSegment: 2, // Sports + Details segment
            ),
          ),

          // Content
          Expanded(
            child: AdaptiveScrollableBody(
              safeAreaTop: false,
              safeAreaBottom: false,
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      'Which sports do you train for?',
                      style: TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orange,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Subtitle
                    const Text(
                      'We\'ll customize your nutrition plans for each sport.',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textDark,
                        letterSpacing: 0.192,
                        height: 1.0,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sport selection cards
                    FigmaCheckboxCard(
                      label: 'Running',
                      isSelected: _selectedSports.contains('running'),
                      onTap: () => _toggleSport('running'),
                    ),

                    const SizedBox(height: 12),

                    FigmaCheckboxCard(
                      label: 'Cycling',
                      isSelected: _selectedSports.contains('cycling'),
                      onTap: () => _toggleSport('cycling'),
                    ),

                    const SizedBox(height: 12),

                    FigmaCheckboxCard(
                      label: 'Swimming',
                      isSelected: _selectedSports.contains('swimming'),
                      onTap: () => _toggleSport('swimming'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: _continue,
            onBack: widget.onBack ?? () => context.pop(),
            canContinue: _selectedSports.isNotEmpty,
          ),
        ],
      ),
    );
  }
}
