import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../nutrition_plan/data/food_repository.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../core/utils/debug_logger.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../../auth/application/auth_service.dart';
import '../../../barcode_scanning/application/open_food_facts_search_service.dart';
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../user_foods/data/user_foods_repository.dart';
import '../../../../shared/widgets/buttons/search_openfoodfacts_button.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/utils/search_strategy.dart';
import '../widgets/food_preferences/food_preference_item_widget.dart';
import '../widgets/food_preferences/user_food_item_widget.dart';
import '../widgets/food_preferences/search_result_item_widget.dart';
import '../widgets/food_preferences/additional_foods_section_widget.dart';
import '../widgets/food_preferences/user_foods_section_widget.dart';

/// Food Preferences Screen - Kyle's Design System (Settings)
/// Settings version with search bar, barcode scanning, and 5-point slider system
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() =>
      _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  // Store slider levels (0-4) locally
  final Map<String, int> _sliderLevels = {};

  List<FoodItem> _allFoodPreferences = [];
  List<FoodItem> _additionalFoodPreferences =
      []; // Additional food options (expandable)
  List<FoodItem> _userFoods = []; // User-added foods (scanned/searched)
  bool _isLoading = true;
  bool _isSaving = false;

  // Expandable additional foods state
  bool _isAdditionalFoodsExpanded = false;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // OpenFoodFacts search state
  List<FoodSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  String? _searchErrorMessage;

  // Search strategy helper for managing local vs OpenFoodFacts search
  final _searchStrategy = SearchStrategy();

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value;

      // Clear OpenFoodFacts results when search is cleared
      if (value.isEmpty) {
        _showSearchResults = false;
        _searchResults = [];
        _searchErrorMessage = null;
        _searchStrategy.cancelAutoSearch();
      }
    });

    if (value.trim().isNotEmpty) {
      // Count total local results across all lists
      final totalLocalResults =
          _filteredFoods.length +
          _filteredAdditionalFoods.length +
          _filteredUserFoods.length;

      // Use search strategy to determine if we should auto-search OpenFoodFacts
      if (_searchStrategy.shouldAutoSearch(totalLocalResults)) {
        _searchStrategy.scheduleAutoSearch(
          query: value,
          getCurrentQuery: () => _searchController.text.trim(),
          onSearch: (_) {
            if (mounted) {
              _performSearch();
            }
          },
          debounceDuration: const Duration(milliseconds: 1500),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFoods();

    ref
        .read(appExternalDepsProvider)
        .analytics
        .track(
          'screen_viewed',
          properties: {'screen_name': 'Food Preferences Settings'},
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchStrategy.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    DebugLogger.info('[FOOD_PREFS] 🔄 Starting food preferences load...');

    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final database = ref.read(appDatabaseProvider);

      // Get current user's ID using Supabase auth session for correct UUID
      DebugLogger.info('[FOOD_PREFS] 🔍 Getting current user profile...');
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final currentAuthUserId = supabaseClient.auth.currentUser?.id;
      final userProfile = await database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final deviceId = userProfile?.id ?? 'unknown';
      DebugLogger.info(
        '[FOOD_PREFS] ✅ User profile retrieved, deviceId: $deviceId',
      );

      // Ensure user_foods are synced from remote (pulls down after re-login)
      try {
        final userFoodsRepo = await ref.read(
          userFoodsRepositoryProvider.future,
        );
        await ref
            .read(syncCoordinatorProvider.notifier)
            .ensureSynced('user_foods', deviceId, repository: userFoodsRepo);
      } catch (e) {
        DebugLogger.warning(
          '[FOOD_PREFS] ⚠️ User foods sync failed, continuing with cached data: $e',
        );
      }

      // Load primary foods, additional foods, user foods, and existing preferences in parallel
      DebugLogger.info(
        '[FOOD_PREFS] 📦 Starting parallel data load (primary foods, additional foods, user foods, preferences)...',
      );

      final results =
          await Future.wait([
            () async {
              DebugLogger.info(
                '[FOOD_PREFS] 🌐 Fetching primary foods from Supabase...',
              );
              final foods = await foodRepository
                  .getPrimaryFoodsForPreferences();
              DebugLogger.info(
                '[FOOD_PREFS] ✅ Primary foods loaded: ${foods.length} items',
              );
              return foods;
            }(),
            () async {
              DebugLogger.info(
                '[FOOD_PREFS] 🌐 Fetching additional foods from Supabase...',
              );
              final foods = await foodRepository
                  .getAdditionalFoodsForPreferences();
              DebugLogger.info(
                '[FOOD_PREFS] ✅ Additional foods loaded: ${foods.length} items',
              );
              return foods;
            }(),
            () async {
              DebugLogger.info(
                '[FOOD_PREFS] 💾 Fetching user foods from local database...',
              );
              final userFoods = await database.foodsDao.getUserFoods(deviceId);
              DebugLogger.info(
                '[FOOD_PREFS] ✅ User foods loaded: ${userFoods.length} items',
              );
              return userFoods;
            }(),
            () async {
              DebugLogger.info(
                '[FOOD_PREFS] 🔐 Checking auth and loading preferences...',
              );
              final user = await authService.getCurrentUser();
              if (user != null) {
                DebugLogger.info(
                  '[FOOD_PREFS] 👤 User authenticated, fetching preferences...',
                );
                final prefs = await authService.getFoodPreferences(user.id);
                DebugLogger.info(
                  '[FOOD_PREFS] ✅ Preferences loaded: ${prefs?.length ?? 0} items',
                );
                return prefs;
              }
              DebugLogger.info(
                '[FOOD_PREFS] ⚠️ No authenticated user, skipping preferences',
              );
              return null;
            }(),
            () async {
              DebugLogger.info('[FOOD_PREFS] 📊 Loading slider levels...');
              final user = await authService.getCurrentUser();
              if (user != null) {
                final levels = await authService.getFoodPreferenceLevels(
                  user.id,
                );
                DebugLogger.info(
                  '[FOOD_PREFS] ✅ Slider levels loaded: ${levels.length}',
                );
                return levels;
              }
              return <String, int>{};
            }(),
          ]).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              DebugLogger.error(
                '[FOOD_PREFS] ❌ Future.wait timed out after 15 seconds',
              );
              throw TimeoutException(
                'Failed to load food data - operation timed out',
              );
            },
          );

      final primaryFoods = results[0] as List<FoodItem>;
      final additionalFoods = results[1] as List<FoodItem>;
      final userFoodsData = results[2] as List<dynamic>;
      final existingPreferences = results[3] as Map<String, FoodPreference>?;
      final sliderLevels = Map<String, int>.from(
        results[4] as Map<String, int>? ?? {},
      );

      DebugLogger.info('[FOOD_PREFS] 🔄 Converting user foods to FoodItems...');
      // Convert user foods to FoodItems
      final userFoods = userFoodsData
          .map(
            (userFood) => database.foodsDao.convertUserFoodToFoodItem(userFood),
          )
          .cast<FoodItem>()
          .toList();

      DebugLogger.info('[FOOD_PREFS] 🎨 Setting state with loaded data...');
      setState(() {
        _allFoodPreferences = primaryFoods;
        _additionalFoodPreferences = additionalFoods;
        _userFoods = userFoods;
        _isLoading = false;

        // Initialize slider levels based on existing preferences
        for (final food in primaryFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            // Convert existing preference to slider level
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            // Default to neutral (level 2)
            _sliderLevels[food.name] = 2;
          }
        }

        // Initialize slider levels for additional foods with avoid (level 0) by default
        for (final food in additionalFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            // Default to avoid (level 0)
            _sliderLevels[food.name] = 0;
          }
        }

        // Initialize slider levels for user foods
        for (final food in userFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            // Default to neutral (level 2)
            _sliderLevels[food.name] = 2;
          }
        }
      });

      DebugLogger.info(
        '[FOOD_PREFS] 🎉 Food preferences load completed successfully! (${primaryFoods.length} primary foods, ${userFoods.length} user foods)',
      );
    } catch (e, stackTrace) {
      DebugLogger.error(
        '[FOOD_PREFS] ❌ Failed to load foods',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Error loading food preferences: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _savePreferences() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    DebugLogger.info('🔄 Food preferences settings - Saving preferences');
    DebugLogger.info(
      '📊 Food preferences settings - Selected preferences count: ${_sliderLevels.length}',
    );

    try {
      final authService = ref.read(authServiceProvider);

      // Convert slider levels (0-4) to backend preferences (3 states)
      final Map<String, FoodPreference> preferences = {};
      for (final entry in _sliderLevels.entries) {
        preferences[entry.key] = _levelToPreference(entry.value);
      }

      // Save preferences
      final currentUser = await authService.getCurrentUser();
      if (currentUser != null) {
        await authService.saveFoodPreferences(
          currentUser.id,
          preferences,
          sliderLevels: _sliderLevels,
        );
      }

      final analytics = ref.read(appExternalDepsProvider).analytics;
      await analytics.track(
        'food_preferences_saved',
        properties: {
          'total_foods': preferences.length,
          'preferences': preferences.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
          'slider_levels': _sliderLevels,
          'source': 'settings',
        },
      );

      if (mounted) {
        MealvanaSnackbar.showSuccess(context, '✅ Food preferences saved!');

        // Navigate back to settings
        context.pop();
      }
    } catch (e) {
      DebugLogger.error('❌ Food preferences settings - Failed to save: $e');
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Failed to save food preferences: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Convert backend preference to slider level (0-4)
  int _preferenceToLevel(FoodPreference preference) {
    switch (preference) {
      case FoodPreference.dislike:
        return 1; // Moderate avoid
      case FoodPreference.willingToTry:
        return 2; // Neutral
      case FoodPreference.like:
        return 3; // Moderate love
    }
  }

  // Convert slider level (0-4) to backend preference
  FoodPreference _levelToPreference(int level) {
    if (level <= 1) {
      return FoodPreference.dislike; // Levels 0, 1 → Avoid
    } else if (level >= 3) {
      return FoodPreference.like; // Levels 3, 4 → Love
    } else {
      return FoodPreference.willingToTry; // Level 2 → Neutral
    }
  }

  List<FoodItem> get _filteredFoods {
    if (_searchQuery.isEmpty) {
      return _allFoodPreferences;
    }
    return _allFoodPreferences
        .where(
          (food) =>
              food.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<FoodItem> get _filteredAdditionalFoods {
    if (_searchQuery.isEmpty) {
      return _additionalFoodPreferences;
    }
    return _additionalFoodPreferences
        .where(
          (food) =>
              food.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  List<FoodItem> get _filteredUserFoods {
    if (_searchQuery.isEmpty) {
      return _userFoods;
    }
    return _userFoods
        .where(
          (food) =>
              food.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  // OpenFoodFacts search functionality
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _showSearchResults = false;
        _searchResults = [];
        _searchErrorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchErrorMessage = null;
      _searchResults = [];
      _showSearchResults = true;
    });

    try {
      final searchService = ref.read(openFoodFactsSearchServiceProvider);
      final results = await searchService.searchProducts(query);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

      if (results.isEmpty) {
        setState(() {
          _searchErrorMessage =
              'No products found for "$query". Try different keywords.';
        });
      }

      ref
          .read(appExternalDepsProvider)
          .analytics
          .track(
            'food_search_performed',
            properties: {
              'query': query,
              'results_count': results.length,
              'source': 'settings_food_preferences',
            },
          );
    } on SearchException catch (e) {
      setState(() {
        _searchErrorMessage = e.message;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchErrorMessage = 'Search failed. Please try again.';
        _isSearching = false;
      });
      DebugLogger.error('Error performing OpenFoodFacts search: $e');
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _showSearchResults = false;
      _searchResults = [];
      _searchErrorMessage = null;
      _searchQuery = '';
    });
  }

  Future<void> _handleSearchResultTap(FoodSearchResult result) async {
    if (!result.hasValidId) {
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Cannot load details for this product',
        );
      }
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      // Get product details
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }

      // Map to Food then convert to FoodItem
      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      final foodItem = _convertFoodToFoodItem(food);

      // Navigate to food detail screen
      if (mounted) {
        final result = await context.pushNamed<dynamic>(
          'food-detail',
          extra: {
            'foodData': FoodDetailData.fromFoodItem(foodItem),
            'mode': FoodDetailMode.addFromSearch,
            'screenContext': FoodDetailContext.foodPreferences,
            'showCategories': true,
            'showProductType': true,
            'allowDelete': false,
          },
        );

        if (result is FoodDetailResult && mounted) {
          await _saveSearchedFood(
            foodItem,
            result.categoryIds,
            result.fluidMlPerServing,
            carbsPerServing: result.carbsPerServing,
            proteinPerServing: result.proteinPerServing,
            fatPerServing: result.fatPerServing,
            sodiumMg: result.sodiumMg.toDouble(),
            productType: result.productType,
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to load product details');
      }
      DebugLogger.error('Error loading product details: $e');
    }
  }

  FoodItem _convertFoodToFoodItem(Food food) {
    return FoodItem(
      id: food.id,
      name: food.name,
      imageAddress: food.imageAddress,
      description: food.description,
      instructions: food.instructions,
      categories: [],
      servingSize: food.servingSize,
      servingAmount: food.servingAmount,
      servingUnit: food.servingUnit,
      servingUnitPlural: food.servingUnitPlural,
      servingQualifier: food.servingQualifier,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      fluidMlPerServing: food.fluidMlPerServing,
      carbsPerServing: food.carbsPerServing,
      proteinPerServing: food.proteinPerServing,
      fatPerServing: food.fatPerServing,
      sodiumMg: food.sodiumMg,
      caloriesPerServing: food.caloriesPerServing,
      productTypeId: food.productTypeId,
      beforeRunSuitable: food.beforeRunSuitable,
      duringRunSuitable: food.duringRunSuitable,
      runPortable: food.runPortable,
      requiresPreparation: food.requiresPreparation,
      aidStationAvailable: food.aidStationAvailable,
      maxServingsBefore: food.maxServingsBefore,
      maxServingsDuring: food.maxServingsDuring,
      caffeineMg: food.caffeineMg,
      potassiumMg: food.potassiumMg,
    );
  }

  Future<void> _saveSearchedFood(
    FoodItem foodItem,
    List<int> categoryIds,
    double? finalFluidAmount, {
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMg,
    String? productType,
  }) async {
    try {
      final userFoodCrudService = ref.read(userFoodCrudServiceProvider);

      // Use user-selected product type if provided, otherwise fall back to 'import'
      final finalProductType =
          productType ?? foodItem.productTypeId ?? 'import';

      final categoryStrings = categoryIds.map((id) {
        switch (id) {
          case 1:
            return 'before_run';
          case 2:
            return 'during_run';
          case 3:
            return 'after_run';
          default:
            return 'before_run';
        }
      }).toList();

      // Create a Food domain object with user-edited values
      final food = Food(
        id: foodItem.id,
        name: foodItem.name,
        displayName: foodItem.displayName,
        displayNamePlural: foodItem.displayNamePlural,
        description: foodItem.description,
        imageAddress: foodItem.imageAddress,
        servingAmount: foodItem.servingAmount,
        servingUnit: foodItem.servingUnit,
        servingSize: foodItem.servingSize,
        categories: categoryStrings,
        caloriesPerServing:
            (carbsPerServing?.toInt()) ?? foodItem.caloriesPerServing,
        carbsPerServing: carbsPerServing ?? foodItem.carbsPerServing,
        proteinPerServing: proteinPerServing ?? foodItem.proteinPerServing,
        fatPerServing: fatPerServing ?? foodItem.fatPerServing,
        sodiumMg: (sodiumMg?.toInt()) ?? foodItem.sodiumMg,
        fluidMlPerServing: finalFluidAmount ?? foodItem.fluidMlPerServing,
        productTypeId: finalProductType,
        beforeRunSuitable: categoryIds.contains(1),
        duringRunSuitable: categoryIds.contains(2),
      );

      // Save via UserFoodCrudService (handles local save + background Supabase upload)
      await userFoodCrudService.saveUserFood(food, categoryIds);

      // Set default preference at neutral
      setState(() {
        _sliderLevels[foodItem.name] = 2;
      });

      // Clear search and refresh list
      _clearSearch();
      await _loadFoods();

      if (mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          '${foodItem.name} added to your foods!',
        );
      }
    } catch (e) {
      DebugLogger.error('Error saving searched food: $e');
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Failed to save food. Please try again.',
        );
      }
    }
  }

  Future<void> _deleteUserFood(FoodItem food) async {
    try {
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.userDao.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      final supabase = ref.read(appExternalDepsProvider).supabaseClient;

      // 1. Delete from local Drift database first
      await database.foodsDao.deleteUserFood(food.id);

      // 2. Sync deletion to Supabase (direct delete)
      try {
        await supabase
            .from('user_foods')
            .delete()
            .eq('device_id', deviceId)
            .eq('id', food.id);

        DebugLogger.info(
          '✅ Food deleted from both local and Supabase: ${food.name}',
        );
      } catch (supabaseError) {
        DebugLogger.warning(
          '⚠️ Supabase delete sync failed, but local delete succeeded: $supabaseError',
        );
      }

      // Remove from local state and preference
      setState(() {
        _userFoods.removeWhere((f) => f.id == food.id);
        _sliderLevels.remove(food.name);
      });

      if (mounted) {
        MealvanaSnackbar.showSuccess(
          context,
          '${food.name} removed from your foods',
        );
      }
    } catch (e) {
      DebugLogger.error('Error deleting user food: $e');
      if (mounted) {
        MealvanaSnackbar.showError(
          context,
          'Failed to delete food. Please try again.',
        );
      }
    }
  }

  /// Open create food screen with empty form
  Future<void> _openCreateFoodScreen() async {
    final uuid = const Uuid().v4();

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (ctx) => FoodDetailScreen(
          foodData: FoodDetailData(id: uuid, name: '', categoryIds: [1, 2, 3]),
          mode: FoodDetailMode.createNew,
          screenContext: FoodDetailContext.foodPreferences,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (result != null && result is FoodDetailResult && mounted) {
      try {
        final categoryStrings = result.categoryIds.map((id) {
          switch (id) {
            case 1:
              return 'before_run';
            case 2:
              return 'during_run';
            case 3:
              return 'after_run';
            default:
              return 'before_run';
          }
        }).toList();

        final food = Food(
          id: result.foodId.isEmpty ? uuid : result.foodId,
          name: result.name,
          categories: categoryStrings,
          servingSize: result.servingSize,
          servingAmount: result.servingAmount,
          servingUnit: result.servingUnit,
          carbsPerServing: result.carbsPerServing,
          proteinPerServing: result.proteinPerServing,
          fatPerServing: result.fatPerServing,
          sodiumMg: result.sodiumMg,
          caloriesPerServing: result.caloriesPerServing,
          fluidMlPerServing: result.fluidMlPerServing,
          productTypeId: result.productType,
          beforeRunSuitable: result.categoryIds.contains(1),
          duringRunSuitable: result.categoryIds.contains(2),
        );

        // Save to user_foods
        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, result.categoryIds);

        // Convert Food to FoodItem for the list
        final foodItem = FoodItem(
          id: food.id,
          name: food.name,
          categories: categoryStrings.map((cat) {
            switch (cat) {
              case 'before_run':
                return FoodCategory.beforeRun;
              case 'during_run':
                return FoodCategory.duringRun;
              case 'after_run':
                return FoodCategory.afterRun;
              default:
                return FoodCategory.beforeRun;
            }
          }).toList(),
          carbsPerServing: food.carbsPerServing,
          proteinPerServing: food.proteinPerServing,
          fatPerServing: food.fatPerServing,
          sodiumMg: food.sodiumMg,
          caloriesPerServing: food.caloriesPerServing,
          fluidMlPerServing: food.fluidMlPerServing,
          productTypeId: food.productTypeId,
          beforeRunSuitable: food.beforeRunSuitable,
          duringRunSuitable: food.duringRunSuitable,
        );

        // Add to user foods list and set neutral preference
        setState(() {
          _userFoods.insert(0, foodItem);
          _sliderLevels[food.id] = 2; // Neutral default
        });

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, 'Custom food created!');
        }
      } catch (e) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Failed to save food: $e');
        }
      }
    }
  }

  Future<void> _handleBarcodeScan() async {
    try {
      // Navigate to barcode scanner screen
      final result = await context.push(
        '/barcode-scanner',
        extra: {'category': 'preferences'},
      );

      // If a food was successfully scanned, the FoodDetailScreen already handled category selection
      // The result from barcode-scanner is now a Food with categories already set
      if (result != null && result is Food && mounted) {
        final foodItem = _convertFoodToFoodItem(result);

        // Save the food with the categories that were set in FoodDetailScreen
        await _saveSearchedFood(
          foodItem,
          result.categories.map((cat) {
            switch (cat) {
              case 'before_run':
                return 1;
              case 'during_run':
                return 2;
              case 'after_run':
                return 3;
              default:
                return 1;
            }
          }).toList(),
          result.fluidMlPerServing,
          carbsPerServing: result.carbsPerServing,
          proteinPerServing: result.proteinPerServing,
          fatPerServing: result.fatPerServing,
          sodiumMg: result.sodiumMg?.toDouble(),
          productType: result.productTypeId,
        );
      }
    } catch (e) {
      DebugLogger.error('Error with barcode scanning: $e');
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Unable to open barcode scanner');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showSearchResults
          ? _buildSearchResultsView()
          : _buildContent(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(),
      title: Text(
        'Food Preferences',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Search bar and barcode scanning section
        Padding(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),

              // Search bar with barcode button and search icon
              Column(
                children: [
                  FigmaSearchBar(
                    controller: _searchController,
                    onChanged: _handleSearchChanged,
                    onBarcodeScan: () {
                      final analytics = ref.read(appExternalDepsProvider);
                      analytics.analytics.track(
                        'barcode_scanner_opened',
                        properties: {'source': 'food_preferences_settings'},
                      );
                      _handleBarcodeScan();
                    },
                    onSearchSubmit: (query) => _performSearch(),
                    enableAutoSearch:
                        false, // Disabled - now handled in _handleSearchChanged based on results
                    autoSearchDebounceMs: 1500,
                    hintText: 'Search foods...',
                  ),

                  // "Search OpenFoodFacts" button (when 1-3 local results)
                  if (_searchQuery.isNotEmpty &&
                      !_showSearchResults &&
                      !_isSearching)
                    Builder(
                      builder: (context) {
                        final totalLocalResults =
                            _filteredFoods.length +
                            _filteredAdditionalFoods.length +
                            _filteredUserFoods.length;

                        if (totalLocalResults > 0 && totalLocalResults < 4) {
                          return SearchOpenFoodFactsButton(
                            onPressed: _performSearch,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),

                  // Clear search button (when showing search query or results)
                  if (_searchQuery.isNotEmpty || _showSearchResults) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton.icon(
                        onPressed: _clearSearch,
                        icon: const Icon(
                          FontAwesomeIcons.xmark,
                          size: 16,
                          color: AppColors.orange,
                        ),
                        label: const Text(
                          'Clear Search',
                          style: TextStyle(
                            fontFamily: 'Apercu',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Create custom food button
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: TextButton.icon(
                      onPressed: _openCreateFoodScreen,
                      icon: const Icon(
                        FontAwesomeIcons.plus,
                        size: 14,
                        color: AppColors.orange,
                      ),
                      label: const Text(
                        'Create Custom Food',
                        style: TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),

        // Food preferences list
        Expanded(
          child:
              (_filteredFoods.isEmpty &&
                  _filteredUserFoods.isEmpty &&
                  _filteredAdditionalFoods.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FontAwesomeIcons.searchengin,
                        size: 48,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No foods found'
                            : 'No foods found for "$_searchQuery"',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Try a different search term or use the search button to find foods in our database',
                          style: AppTextStyles.smallLabel.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: AppSpacing.screenPaddingHorizontal,
                  children: [
                    // Your Added Foods section - show section when not searching, show items directly when searching
                    if (_filteredUserFoods.isNotEmpty) ...[
                      if (_searchQuery.isEmpty) ...[
                        _buildUserFoodsSection(context),
                        const SizedBox(height: AppSpacing.lg),
                      ] else ...[
                        // When searching, show user foods directly (no wrapper)
                        ..._filteredUserFoods.map((food) {
                          final sliderLevel = _sliderLevels[food.name] ?? 2;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _buildFoodPreferenceItem(
                              context,
                              food,
                              sliderLevel,
                            ),
                          );
                        }),
                      ],
                    ],

                    // Primary foods
                    ..._filteredFoods.map((food) {
                      final sliderLevel = _sliderLevels[food.name] ?? 2;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildFoodPreferenceItem(
                          context,
                          food,
                          sliderLevel,
                        ),
                      );
                    }),

                    // Additional foods - show directly when searching, in expandable section when not
                    if (_filteredAdditionalFoods.isNotEmpty) ...[
                      if (_searchQuery.isEmpty) ...[
                        // When not searching, show in expandable section
                        const SizedBox(height: AppSpacing.md),
                        _buildExpandableAdditionalFoods(context),
                      ] else ...[
                        // When searching, show additional foods directly (no expandable wrapper)
                        ..._filteredAdditionalFoods.map((food) {
                          final sliderLevel = _sliderLevels[food.name] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _buildFoodPreferenceItem(
                              context,
                              food,
                              sliderLevel,
                            ),
                          );
                        }),
                      ],
                    ],
                  ],
                ),
        ),

        // Save button
        Padding(
          padding: AppSpacing.screenPaddingHorizontal,
          child: KylePrimaryButton(
            text: _isSaving ? 'Saving...' : 'Save Changes',
            onPressed: _isSaving ? null : _savePreferences,
            isFullWidth: true,
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildUserFoodsSection(BuildContext context) {
    return UserFoodsSectionWidget(
      foodCount: _filteredUserFoods.length,
      children: _filteredUserFoods.map((food) {
        final sliderLevel = _sliderLevels[food.name] ?? 2;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildUserFoodPreferenceItem(context, food, sliderLevel),
        );
      }).toList(),
    );
  }

  Widget _buildUserFoodPreferenceItem(
    BuildContext context,
    FoodItem food,
    int sliderLevel,
  ) {
    return UserFoodItemWidget(
      food: food,
      sliderLevel: sliderLevel,
      onLevelChanged: (newLevel) {
        setState(() {
          _sliderLevels[food.name] = newLevel;
        });

        final analytics = ref.read(appExternalDepsProvider);
        analytics.analytics.track(
          'food_preference_changed',
          properties: {
            'food_name': food.name,
            'slider_level': newLevel,
            'backend_preference': _levelToPreference(newLevel).toString(),
            'source': 'settings',
          },
        );
      },
      onEditTap: () => _showUserFoodEditSheet(food),
      mapFoodType: _mapFoodType,
    );
  }

  /// Show the edit screen for a user food
  Future<void> _showUserFoodEditSheet(FoodItem food) async {
    final userFoodCrudService = ref.read(userFoodCrudServiceProvider);

    final result = await context.pushNamed<dynamic>(
      'food-detail',
      extra: {
        'foodData': FoodDetailData.fromFoodItem(food),
        'mode': FoodDetailMode.editExisting,
        'screenContext': FoodDetailContext.foodPreferences,
        'showCategories': true,
        'showProductType': true,
        'allowDelete': true,
      },
    );

    if (!mounted) return;

    // Handle delete
    if (result is String && result.startsWith('DELETE:')) {
      await _deleteUserFood(food);
    }
    // Handle update
    else if (result is FoodDetailResult) {
      try {
        await userFoodCrudService.updateUserFood(
          foodId: result.foodId,
          name: result.name,
          displayName: result.name,
          displayNamePlural: '${result.name}s',
          servingAmount: result.servingAmount,
          servingUnit: result.servingUnit,
          carbsPerServing: result.carbsPerServing,
          proteinPerServing: result.proteinPerServing,
          fatPerServing: result.fatPerServing,
          sodiumMg: result.sodiumMg,
          fluidMlPerServing: result.fluidMlPerServing,
          categoryIds: result.categoryIds,
        );

        // Reload foods to reflect changes
        await _loadFoods();

        if (mounted) {
          MealvanaSnackbar.showSuccess(context, '${result.name} updated!');
        }
      } catch (e) {
        DebugLogger.error('Error updating user food: $e');
        if (mounted) {
          MealvanaSnackbar.showError(
            context,
            'Failed to update food. Please try again.',
          );
        }
      }
    }
  }

  Widget _buildFoodPreferenceItem(
    BuildContext context,
    FoodItem food,
    int sliderLevel,
  ) {
    return FoodPreferenceItemWidget(
      food: food,
      sliderLevel: sliderLevel,
      onLevelChanged: (newLevel) {
        setState(() {
          _sliderLevels[food.name] = newLevel;
        });

        final analytics = ref.read(appExternalDepsProvider);
        analytics.analytics.track(
          'food_preference_changed',
          properties: {
            'food_name': food.name,
            'slider_level': newLevel,
            'backend_preference': _levelToPreference(newLevel).toString(),
            'source': 'settings',
          },
        );
      },
      mapFoodType: _mapFoodType,
    );
  }

  Widget _buildSearchResultsView() {
    return Column(
      children: [
        // Back to food list button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: KyleSecondaryButton(
            text: 'Back to Food List',
            onPressed: _clearSearch,
            isFullWidth: true,
          ),
        ),

        // Search results or loading/error state
        Expanded(
          child: _isSearching
              ? _buildSearchingIndicator()
              : _searchErrorMessage != null
              ? _buildSearchError()
              : _searchResults.isEmpty
              ? Center(
                  child: Text(
                    'No results found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildSearchResultItem(result),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSearchingIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Searching food database...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.triangleExclamation,
              size: 48,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _searchErrorMessage ?? 'Search failed',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(FoodSearchResult result) {
    return SearchResultItemWidget(
      result: result,
      onTap: () => _handleSearchResultTap(result),
    );
  }

  Widget _buildExpandableAdditionalFoods(BuildContext context) {
    return AdditionalFoodsSectionWidget(
      isExpanded: _isAdditionalFoodsExpanded,
      onToggle: () {
        setState(() {
          _isAdditionalFoodsExpanded = !_isAdditionalFoodsExpanded;
        });
      },
      children: _filteredAdditionalFoods.map((food) {
        final sliderLevel = _sliderLevels[food.name] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildFoodPreferenceItem(context, food, sliderLevel),
        );
      }).toList(),
    );
  }

  KyleFoodType _mapFoodType(String foodName) {
    final name = foodName.toLowerCase();

    if (name.contains('banana') || name.contains('fruit')) {
      return KyleFoodType.fruit;
    } else if (name.contains('bread') || name.contains('sandwich')) {
      return KyleFoodType.sandwich;
    } else if (name.contains('pasta')) {
      return KyleFoodType.pasta;
    } else if (name.contains('rice')) {
      return KyleFoodType.rice;
    } else if (name.contains('gel') || name.contains('gummy')) {
      return KyleFoodType.gel;
    } else if (name.contains('bar') || name.contains('energy')) {
      return KyleFoodType.energyBar;
    } else if (name.contains('drink') ||
        name.contains('water') ||
        name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') ||
        name.contains('meat') ||
        name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') ||
        name.contains('carrot') ||
        name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') ||
        name.contains('cookie') ||
        name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') ||
        name.contains('pill') ||
        name.contains('vitamin')) {
      return KyleFoodType.supplement;
    } else {
      return KyleFoodType.other;
    }
  }
}
