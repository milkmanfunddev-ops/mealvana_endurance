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
import '../../../barcode_scanning/application/product_detail_service.dart';
import '../../../barcode_scanning/application/food_mapping_service.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../../shared/widgets/inputs/figma_search_bar.dart';
import '../../../../shared/database/database_provider.dart';
import '../../../../shared/services/food_management/user_food_crud_service.dart';
import '../../../../shared/services/sync/sync_coordinator.dart';
import '../../../user_foods/data/user_foods_repository.dart';
import '../../../../shared/controllers/food_search_controller.dart';
import '../../../../shared/widgets/food_search/unified_food_search_results.dart';
import '../../../../shared/widgets/content_area.dart';
import '../../../barcode_scanning/application/catalog_search_service.dart';
import '../../../nutrition_plan/presentation/widgets/swap_food/catalog_section_widget.dart';
import '../widgets/food_preferences/food_preference_item_widget.dart';
import '../widgets/food_preferences/user_food_item_widget.dart';
import '../widgets/food_preferences/additional_foods_section_widget.dart';
import '../widgets/food_preferences/user_foods_section_widget.dart';

/// Food Preferences Screen - Kyle's Design System (Settings)
/// Settings version with search bar, barcode scanning, and 5-point slider system.
///
/// Search is now handled by the shared [FoodSearchController] and
/// [UnifiedFoodSearchResults] widget for consistency with the Swap Food screen.
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() =>
      _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  static const _searchControllerKey = 'food_preferences';

  // Store slider levels (0-4) locally
  final Map<String, int> _sliderLevels = {};

  List<FoodItem> _allFoodPreferences = [];
  List<FoodItem> _additionalFoodPreferences = [];
  List<FoodItem> _userFoods = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Expandable additional foods state
  bool _isAdditionalFoodsExpanded = false;

  // Search input controller
  final TextEditingController _searchController = TextEditingController();

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
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .updateSearch(query);
  }

  void _onClearSearch() {
    _searchController.clear();
    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .clearSearch();
  }

  Future<void> _onSearchButtonPressed(String query) async {
    if (query.trim().isNotEmpty) {
      await ref
          .read(foodSearchControllerProvider(_searchControllerKey).notifier)
          .searchOpenFoodFacts(query.trim());
    }
  }

  /// Seed the shared search controller with the food pool
  void _seedSearchController() {
    // Convert FoodItems to Food domain objects for the search controller
    final allFoods = <Food>[
      ..._allFoodPreferences.map(_convertFoodItemToFood),
      ..._additionalFoodPreferences.map(_convertFoodItemToFood),
    ];
    final userFoods = _userFoods.map(_convertFoodItemToFood).toList();

    ref
        .read(foodSearchControllerProvider(_searchControllerKey).notifier)
        .updateFoodPool(
          allFoods: [...allFoods, ...userFoods],
          userFoods: userFoods,
        );
  }

  Food _convertFoodItemToFood(FoodItem item) {
    return Food(
      id: item.id,
      name: item.name,
      imageAddress: item.imageAddress,
      description: item.description,
      displayName: item.displayName,
      displayNamePlural: item.displayNamePlural,
      servingSize: item.servingSize,
      servingAmount: item.servingAmount,
      servingUnit: item.servingUnit,
      servingQualifier: item.servingQualifier,
      carbsPerServing: item.carbsPerServing,
      proteinPerServing: item.proteinPerServing,
      fatPerServing: item.fatPerServing,
      sodiumMg: item.sodiumMg,
      caloriesPerServing: item.caloriesPerServing,
      fluidMlPerServing: item.fluidMlPerServing,
      productTypeId: item.productTypeId,
      caffeineMg: item.caffeineMg,
      potassiumMg: item.potassiumMg,
      categories: item.categories.map((c) {
        switch (c) {
          case FoodCategory.beforeRun:
            return 'before_run';
          case FoodCategory.duringRun:
            return 'during_run';
          case FoodCategory.afterRun:
            return 'after_run';
        }
      }).toList(),
    );
  }

  Future<void> _loadFoods() async {
    DebugLogger.info('[FOOD_PREFS] Starting food preferences load...');

    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final database = ref.read(appDatabaseProvider);

      // Get current user's ID using Supabase auth session for correct UUID
      final supabaseClient = ref.read(appExternalDepsProvider).supabaseClient;
      final currentAuthUserId = supabaseClient.auth.currentUser?.id;
      final userProfile = await database.userDao.getCurrentUserProfile(
        currentAuthUserId: currentAuthUserId,
      );
      final deviceId = userProfile?.id ?? 'unknown';

      // Ensure user_foods are synced from remote
      try {
        final userFoodsRepo = await ref.read(
          userFoodsRepositoryProvider.future,
        );
        await ref
            .read(syncCoordinatorProvider.notifier)
            .ensureSynced('user_foods', deviceId, repository: userFoodsRepo);
      } catch (e) {
        DebugLogger.warning(
          '[FOOD_PREFS] User foods sync failed, continuing with cached data: $e',
        );
      }

      // Load all data in parallel
      final results =
          await Future.wait([
            foodRepository.getPrimaryFoodsForPreferences(),
            foodRepository.getAdditionalFoodsForPreferences(),
            database.foodsDao.getUserFoods(deviceId),
            () async {
              final user = await authService.getCurrentUser();
              if (user != null) {
                return await authService.getFoodPreferences(user.id);
              }
              return null;
            }(),
            () async {
              final user = await authService.getCurrentUser();
              if (user != null) {
                return await authService.getFoodPreferenceLevels(user.id);
              }
              return <String, int>{};
            }(),
          ]).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
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

      // Convert user foods to FoodItems
      final userFoods = userFoodsData
          .map(
            (userFood) => database.foodsDao.convertUserFoodToFoodItem(userFood),
          )
          .cast<FoodItem>()
          .toList();

      setState(() {
        _allFoodPreferences = primaryFoods;
        _additionalFoodPreferences = additionalFoods;
        _userFoods = userFoods;
        _isLoading = false;

        // Initialize slider levels based on existing preferences
        for (final food in primaryFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            _sliderLevels[food.name] = 2;
          }
        }

        for (final food in additionalFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            _sliderLevels[food.name] = 0;
          }
        }

        for (final food in userFoods) {
          if (existingPreferences != null &&
              existingPreferences.containsKey(food.name)) {
            final level =
                (sliderLevels[food.name] ??
                        _preferenceToLevel(existingPreferences[food.name]!))
                    .clamp(0, 4);
            _sliderLevels[food.name] = level.toInt();
          } else {
            _sliderLevels[food.name] = 2;
          }
        }
      });

      // Seed search controller after food data loads
      _seedSearchController();

      DebugLogger.info(
        '[FOOD_PREFS] Load completed (${primaryFoods.length} primary, ${userFoods.length} user)',
      );
    } catch (e, stackTrace) {
      DebugLogger.error(
        '[FOOD_PREFS] Failed to load foods',
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

    try {
      final authService = ref.read(authServiceProvider);

      // Convert slider levels (0-4) to backend preferences (3 states)
      final Map<String, FoodPreference> preferences = {};
      for (final entry in _sliderLevels.entries) {
        preferences[entry.key] = _levelToPreference(entry.value);
      }

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
        MealvanaSnackbar.showSuccess(context, 'Food preferences saved!');
        context.pop();
      }
    } catch (e) {
      DebugLogger.error('Food preferences settings - Failed to save: $e');
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

  int _preferenceToLevel(FoodPreference preference) {
    switch (preference) {
      case FoodPreference.dislike:
        return 1;
      case FoodPreference.willingToTry:
        return 2;
      case FoodPreference.like:
        return 3;
    }
  }

  FoodPreference _levelToPreference(int level) {
    if (level <= 1) {
      return FoodPreference.dislike;
    } else if (level >= 3) {
      return FoodPreference.like;
    } else {
      return FoodPreference.willingToTry;
    }
  }

  Future<void> _handleCatalogResultTap(CatalogSearchResult result) async {
    final preCheckedCategories = <int>[1, 2, 3];

    final detailResult = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (ctx) => FoodDetailScreen(
          foodData: FoodDetailData(
            id: '',
            name: result.displayName,
            categoryIds: preCheckedCategories,
            imageUrl: result.imageUrl,
            carbsPerServing: result.carbsG,
            proteinPerServing: result.proteinG,
            fatPerServing: result.fatG,
            sodiumMg: result.sodiumMg,
            caloriesPerServing: result.caloriesPerServing,
            servingSize: result.servingSize,
            productType: result.productTypeId,
          ),
          mode: FoodDetailMode.addFromSearch,
          screenContext: FoodDetailContext.foodPreferences,
          preSelectedCategories: preCheckedCategories,
          showCategories: true,
          showProductType: true,
        ),
      ),
    );

    if (detailResult is FoodDetailResult && mounted) {
      final foodItem = FoodItem(
        id: detailResult.foodId.isEmpty
            ? const Uuid().v4()
            : detailResult.foodId,
        name: detailResult.name,
        categories: [],
        carbsPerServing: detailResult.carbsPerServing,
        proteinPerServing: detailResult.proteinPerServing,
        fatPerServing: detailResult.fatPerServing,
        sodiumMg: detailResult.sodiumMg,
        caloriesPerServing: detailResult.caloriesPerServing,
        fluidMlPerServing: detailResult.fluidMlPerServing,
        imageAddress: result.imageUrl,
        servingSize: detailResult.servingSize,
        servingAmount: detailResult.servingAmount,
        servingUnit: detailResult.servingUnit,
        productTypeId: detailResult.productType,
      );

      await _saveSearchedFood(
        foodItem,
        detailResult.categoryIds,
        detailResult.fluidMlPerServing,
        carbsPerServing: detailResult.carbsPerServing,
        proteinPerServing: detailResult.proteinPerServing,
        fatPerServing: detailResult.fatPerServing,
        sodiumMg: detailResult.sodiumMg.toDouble(),
        productType: detailResult.productType,
      );
    }
  }

  Future<void> _handleOpenFoodFactsSelection(dynamic result) async {
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
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      }

      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

      if (mounted) Navigator.of(context).pop();

      if (apiProduct == null) {
        if (mounted) {
          MealvanaSnackbar.showError(context, 'Unable to load product details');
        }
        return;
      }

      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      final foodItem = _convertFoodToFoodItem(food);

      if (mounted) {
        final detailResult = await context.pushNamed<dynamic>(
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

        if (detailResult is FoodDetailResult && mounted) {
          await _saveSearchedFood(
            foodItem,
            detailResult.categoryIds,
            detailResult.fluidMlPerServing,
            carbsPerServing: detailResult.carbsPerServing,
            proteinPerServing: detailResult.proteinPerServing,
            fatPerServing: detailResult.fatPerServing,
            sodiumMg: detailResult.sodiumMg.toDouble(),
            productType: detailResult.productType,
          );
        }
      }
    } catch (e) {
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

      await userFoodCrudService.saveUserFood(food, categoryIds);

      setState(() {
        _sliderLevels[foodItem.name] = 2;
      });

      _onClearSearch();
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

      await database.foodsDao.deleteUserFood(food.id);

      try {
        await supabase
            .from('user_foods')
            .delete()
            .eq('device_id', deviceId)
            .eq('id', food.id);
      } catch (supabaseError) {
        DebugLogger.warning(
          'Supabase delete sync failed, but local delete succeeded: $supabaseError',
        );
      }

      setState(() {
        _userFoods.removeWhere((f) => f.id == food.id);
        _sliderLevels.remove(food.name);
      });

      // Re-seed search controller
      _seedSearchController();

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

        final userFoodCrudService = ref.read(userFoodCrudServiceProvider);
        await userFoodCrudService.saveUserFood(food, result.categoryIds);

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

        setState(() {
          _userFoods.insert(0, foodItem);
          _sliderLevels[food.name] = 2;
        });

        // Re-seed search controller
        _seedSearchController();

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
      final result = await context.push(
        '/barcode-scanner',
        extra: {'category': 'preferences'},
      );

      if (result != null && result is Food && mounted) {
        final foodItem = _convertFoodToFoodItem(result);

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
    final searchState = ref.watch(
      foodSearchControllerProvider(_searchControllerKey),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: ContentArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(context, searchState),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: const CustomAppBarBackButton(
        key: ValueKey('food_likes.back_button'),
      ),
      title: Text(
        key: const ValueKey('food_likes.title'),
        'Food Preferences',
        style: AppTextStyles.sectionTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FoodSearchState searchState) {
    return Column(
      children: [
        // Search bar and barcode scanning section
        Padding(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),

              Column(
                children: [
                  FigmaSearchBar(
                    key: const ValueKey('food_likes.search_field'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onBarcodeScan: () {
                      final analytics = ref.read(appExternalDepsProvider);
                      analytics.analytics.track(
                        'barcode_scanner_opened',
                        properties: {'source': 'food_preferences_settings'},
                      );
                      _handleBarcodeScan();
                    },
                    onSearchSubmit: _onSearchButtonPressed,
                    triggerSearchOnKeyboardSubmit: false,
                    enableAutoSearch: false,
                    hintText: 'Search foods...',
                    useDarkStyle:
                        Theme.of(context).brightness == Brightness.dark,
                  ),

                  // Clear search button
                  if (searchState.searchQuery.isNotEmpty ||
                      searchState.openFoodFactsResults.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Center(
                      child: TextButton.icon(
                        onPressed: _onClearSearch,
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
                      key: const ValueKey('food_likes.create_custom_button'),
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

        // Food search results or default preference list
        Expanded(
          child: UnifiedFoodSearchResults(
            controllerKey: _searchControllerKey,
            userFoodItemBuilder: (food) {
              final foodItem = _convertFoodToFoodItem(food);
              final sliderLevel = _sliderLevels[food.name] ?? 2;
              return UserFoodItemWidget(
                food: foodItem,
                sliderLevel: sliderLevel,
                onLevelChanged: (newLevel) {
                  setState(() {
                    _sliderLevels[food.name] = newLevel;
                  });
                  _trackPreferenceChange(food.name, newLevel);
                },
                onEditTap: () => _showUserFoodEditSheet(foodItem),
              );
            },
            templateFoodItemBuilder: (food) {
              final foodItem = _convertFoodToFoodItem(food);
              final sliderLevel = _sliderLevels[food.name] ?? 2;
              return FoodPreferenceItemWidget(
                food: foodItem,
                sliderLevel: sliderLevel,
                onLevelChanged: (newLevel) {
                  setState(() {
                    _sliderLevels[food.name] = newLevel;
                  });
                  _trackPreferenceChange(food.name, newLevel);
                },
              );
            },
            catalogItemBuilder: (result) => CatalogCard(
              result: result,
              onTap: () => _handleCatalogResultTap(result),
            ),
            onSearchOpenFoodFacts: () =>
                _onSearchButtonPressed(searchState.searchQuery),
            onOpenFoodFactsResultTap: _handleOpenFoodFactsSelection,
            emptyQueryContent: _buildDefaultPreferencesView(context),
          ),
        ),

        // Save button
        Padding(
          padding: AppSpacing.screenPaddingHorizontal,
          child: KylePrimaryButton(
            key: const ValueKey('food_likes.save_button'),
            text: _isSaving ? 'Saving...' : 'Save Changes',
            onPressed: _isSaving ? null : _savePreferences,
            isFullWidth: true,
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildDefaultPreferencesView(BuildContext context) {
    return ListView(
      padding: AppSpacing.screenPaddingHorizontal,
      children: [
        // Your Added Foods section
        if (_userFoods.isNotEmpty) ...[
          _buildUserFoodsSection(context),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Primary foods
        ..._allFoodPreferences.map((food) {
          final sliderLevel = _sliderLevels[food.name] ?? 2;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildFoodPreferenceItem(context, food, sliderLevel),
          );
        }),

        // Additional foods
        if (_additionalFoodPreferences.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _buildExpandableAdditionalFoods(context),
        ],
      ],
    );
  }

  Widget _buildUserFoodsSection(BuildContext context) {
    return UserFoodsSectionWidget(
      foodCount: _userFoods.length,
      children: _userFoods.map((food) {
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
        _trackPreferenceChange(food.name, newLevel);
      },
      onEditTap: () => _showUserFoodEditSheet(food),
    );
  }

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

    if (result is String && result.startsWith('DELETE:')) {
      await _deleteUserFood(food);
    } else if (result is FoodDetailResult) {
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
          productTypeId: result.productType,
          categoryIds: result.categoryIds,
        );

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
        _trackPreferenceChange(food.name, newLevel);
      },
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
      children: _additionalFoodPreferences.map((food) {
        final sliderLevel = _sliderLevels[food.name] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildFoodPreferenceItem(context, food, sliderLevel),
        );
      }).toList(),
    );
  }

  void _trackPreferenceChange(String foodName, int newLevel) {
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track(
      'food_preference_changed',
      properties: {
        'food_name': foodName,
        'slider_level': newLevel,
        'backend_preference': _levelToPreference(newLevel).toString(),
        'source': 'settings',
      },
    );
  }
}
