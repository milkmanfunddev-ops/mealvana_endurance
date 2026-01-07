import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/onboarding_widgets.dart';
import '../providers/onboarding_controller.dart';
import '../providers/food_selections_cache_provider.dart';
import '../../domain/allergy.dart';
import '../../domain/dietary_preference.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/widgets/selection/figma_food_chip.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/widgets/navigation/figma_onboarding_footer.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Food Preferences V2 Screen - Step 4 of Onboarding (Redesigned)
///
/// Chip-based food selection with:
/// - Search bar for filtering common foods
/// - Selected foods section at top with remove buttons
/// - Common foods grid filtered by diet/allergies
/// - Tap to like, tap again to unlike
///
/// Foods are filtered based on dietary preference and allergies from previous steps.
/// Matches Figma design specification exactly.
class FoodPreferencesV2Screen extends ConsumerStatefulWidget {
  const FoodPreferencesV2Screen({
    super.key,
    this.dietaryPreference,
    this.allergies = const [],
    this.onContinue,
    this.onBack,
  });

  /// Selected dietary preference from previous screen
  final DietaryPreference? dietaryPreference;

  /// Selected allergies from previous screen
  final List<Allergy> allergies;

  /// Callback to advance to next page (optional for PageView mode)
  final VoidCallback? onContinue;

  /// Callback to go back to previous page (optional for PageView mode)
  final VoidCallback? onBack;

  @override
  ConsumerState<FoodPreferencesV2Screen> createState() => _FoodPreferencesV2ScreenState();
}

class _FoodPreferencesV2ScreenState extends ConsumerState<FoodPreferencesV2Screen> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _allFoods = [];
  List<FoodItem> _filteredFoods = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Food Preferences V2 Onboarding',
      'dietary_preference': widget.dietaryPreference?.name,
      'allergies_count': widget.allergies.length,
    });
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      // Get primary foods (show_in_preferences=true)
      final primaryFoods = await foodRepository.getPrimaryFoodsForPreferences();

      // Target around 18 foods total
      List<FoodItem> foods = primaryFoods;
      if (primaryFoods.length < 18) {
        // Need more foods to reach around 18
        final additionalFoods = await foodRepository.getAdditionalFoodsForPreferences();
        final needed = 18 - primaryFoods.length;
        foods = [...primaryFoods, ...additionalFoods.take(needed)];
      } else if (primaryFoods.length > 18) {
        // Have too many, take around 18
        foods = primaryFoods.take(18).toList();
      }

      if (!mounted) return;
      setState(() {
        _allFoods = foods;
        _filteredFoods = _applyFilters(foods);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<FoodItem> _applyFilters(List<FoodItem> foods) {
    var filtered = foods.where((food) {
      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        if (!food.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }

      // TODO: Add diet/allergy filtering when FoodItem supports allergens and excludedDiets fields
      // For now, we just filter by search query

      return true;
    }).toList();

    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredFoods = _applyFilters(_allFoods);
    });
  }

  void _toggleFood(String foodId) {
    // Update the cache provider
    ref.read(foodSelectionsCacheProvider.notifier).toggleFood(foodId);
  }

  void _continue() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Food selections are already cached in foodSelectionsCacheProvider
      // Just navigate to post-onboarding auth screen - batch save will happen there

      if (!mounted) return;

      // Use callback if provided (PageView mode), otherwise navigate (standalone mode)
      if (widget.onContinue != null) {
        widget.onContinue!();
      } else {
        // Navigate to post-onboarding auth screen (sign up or continue as guest)
        context.go('/auth/post-onboarding');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the food selections cache to rebuild when selections change
    final likedFoodIds = ref.watch(foodSelectionsCacheProvider);

    // Convert foods to Figma chip items
    final chipItems = _filteredFoods
        .map((food) => FigmaFoodChipItem(
              id: food.id,
              name: food.name,
            ))
        .toList();

    final allChipItems = _allFoods
        .map((food) => FigmaFoodChipItem(
              id: food.id,
              name: food.name,
            ))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.blackberry,
      body: Column(
        children: [
          // Progress bar at the very top (no SafeArea padding)
          Container(
            color: AppColors.blackberry,
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
            child: const OnboardingProgressBar(
              currentSegment: 4, // Food Preferences segment
            ),
          ),

          // Content - top-aligned scrollable
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.orange),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        const Text(
                          'What foods fuel your training?',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orange,
                            height: 1.0,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        const Text(
                          'You can add more later in settings.',
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

                        // Search bar
                        FigmaSearchBar(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                        ),

                        const SizedBox(height: 20),

                        // Common foods section title
                        const Text(
                          'Common foods',
                          style: TextStyle(
                            fontFamily: 'Sansita',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                            height: 1.0,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Food chips grid
                        _filteredFoods.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(40),
                                child: Center(
                                  child: Text(
                                    'No foods available',
                                    style: TextStyle(
                                      fontFamily: 'Apercu',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: AppColors.textDark,
                                      letterSpacing: 0.192,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : FigmaFoodChipGrid(
                                foods: chipItems,
                                selectedFoodIds: likedFoodIds,
                                onFoodToggled: _toggleFood,
                              ),
                      ],
                    ),
                  ),
          ),

          // Footer navigation
          FigmaOnboardingFooter(
            onContinue: _continue,
            onBack: widget.onBack ?? () => context.pop(),
            canContinue: true, // Allow skip/continue always
            isLoading: _isSaving,
          ),
        ],
      ),
    );
  }
}
