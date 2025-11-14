import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
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
import '../../../../shared/widgets/scanned_food_category_sheet.dart';
import '../../../../shared/database/database_provider.dart';

/// Food Preferences Screen - Kyle's Design System (Settings)
/// Settings version with search bar, barcode scanning, and 5-point slider system
class FoodPreferencesScreen extends ConsumerStatefulWidget {
  const FoodPreferencesScreen({super.key});

  @override
  ConsumerState<FoodPreferencesScreen> createState() => _FoodPreferencesScreenState();
}

class _FoodPreferencesScreenState extends ConsumerState<FoodPreferencesScreen> {
  static const _uuid = Uuid();

  // Store slider levels (0-4) locally
  final Map<String, int> _sliderLevels = {};

  List<FoodItem> _allFoodPreferences = [];
  List<FoodItem> _userFoods = []; // User-added foods (scanned/searched)
  bool _isLoading = true;
  bool _isSaving = false;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // OpenFoodFacts search state
  List<FoodSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  String? _searchErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadFoods();

    ref.read(appExternalDepsProvider).analytics.track('screen_viewed', properties: {
      'screen_name': 'Food Preferences Settings',
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final authService = ref.read(authServiceProvider);
      final database = ref.read(appDatabaseProvider);

      // Get current user's device ID for user foods
      final userProfile = await database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';

      // Load primary foods, user foods, and existing preferences in parallel
      final results = await Future.wait([
        foodRepository.getPrimaryFoodsForPreferences(),
        database.getUserFoods(deviceId),
        authService.getCurrentUser().then((user) async {
          if (user != null) {
            return await authService.getFoodPreferences(user.id);
          }
          return null;
        }),
      ]);

      final primaryFoods = results[0] as List<FoodItem>;
      final userFoodsData = results[1] as List<dynamic>;
      final existingPreferences = results[2] as Map<String, FoodPreference>?;

      // Convert user foods to FoodItems
      final userFoods = userFoodsData
          .map((userFood) => database.convertUserFoodToFoodItem(userFood))
          .cast<FoodItem>()
          .toList();

      setState(() {
        _allFoodPreferences = primaryFoods;
        _userFoods = userFoods;
        _isLoading = false;

        // Initialize slider levels based on existing preferences
        for (final food in primaryFoods) {
          if (existingPreferences != null && existingPreferences.containsKey(food.name)) {
            // Convert existing preference to slider level
            _sliderLevels[food.name] = _preferenceToLevel(existingPreferences[food.name]!);
          } else {
            // Default to neutral (level 2)
            _sliderLevels[food.name] = 2;
          }
        }

        // Initialize slider levels for user foods
        for (final food in userFoods) {
          if (existingPreferences != null && existingPreferences.containsKey(food.name)) {
            _sliderLevels[food.name] = _preferenceToLevel(existingPreferences[food.name]!);
          } else {
            // Default to neutral (level 2)
            _sliderLevels[food.name] = 2;
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      DebugLogger.error('Error loading foods: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading food preferences: $e'),
            backgroundColor: AppColors.dragonfruit,
          ),
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
    DebugLogger.info('📊 Food preferences settings - Selected preferences count: ${_sliderLevels.length}');

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
        await authService.saveFoodPreferences(currentUser.id, preferences);
      }

      final analytics = ref.read(appExternalDepsProvider).analytics;
      await analytics.track('food_preferences_saved', properties: {
        'total_foods': preferences.length,
        'preferences': preferences.map((key, value) => MapEntry(key, value.toString())),
        'slider_levels': _sliderLevels,
        'source': 'settings',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Food preferences saved!'),
            backgroundColor: AppColors.electrolyte,
          ),
        );

        // Navigate back to settings
        context.pop();
      }
    } catch (e) {
      DebugLogger.error('❌ Food preferences settings - Failed to save: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save food preferences: $e'),
            backgroundColor: AppColors.dragonfruit,
          ),
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

  Color _getIconColor(int sliderLevel, bool isLeft) {
    if (isLeft) {
      // X icon on the left (avoid)
      if (sliderLevel == 0) {
        return AppColors.dragonfruit;
      } else if (sliderLevel == 1) {
        return AppColors.dragonfruit.withOpacity(0.7);
      } else if (sliderLevel == 2) {
        return Colors.white;
      } else {
        return Colors.white.withOpacity(0.5);
      }
    } else {
      // Heart icon on the right (love)
      if (sliderLevel == 4) {
        return AppColors.dragonfruit;
      } else if (sliderLevel == 3) {
        return AppColors.dragonfruit.withOpacity(0.7);
      } else if (sliderLevel == 2) {
        return Colors.white;
      } else {
        return Colors.white.withOpacity(0.5);
      }
    }
  }

  List<FoodItem> get _filteredFoods {
    if (_searchQuery.isEmpty) {
      return _allFoodPreferences;
    }
    return _allFoodPreferences
        .where((food) => food.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<FoodItem> get _filteredUserFoods {
    if (_searchQuery.isEmpty) {
      return _userFoods;
    }
    return _userFoods
        .where((food) => food.name.toLowerCase().contains(_searchQuery.toLowerCase()))
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
          _searchErrorMessage = 'No products found for "$query". Try different keywords.';
        });
      }

      ref.read(appExternalDepsProvider).analytics.track('food_search_performed', properties: {
        'query': query,
        'results_count': results.length,
        'source': 'settings_food_preferences',
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot load details for this product'),
            backgroundColor: AppColors.dragonfruit,
          ),
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
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to load product details'),
              backgroundColor: AppColors.dragonfruit,
            ),
          );
        }
        return;
      }

      // Map to Food then convert to FoodItem
      final mappingService = ref.read(foodMappingServiceProvider);
      final food = await mappingService.mapToFood(apiProduct);
      final foodItem = _convertFoodToFoodItem(food);

      // Show category selection sheet
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ScannedFoodCategorySheet(
            scannedFood: foodItem,
            context: 'add_food',
            fluidMlPerServing: foodItem.fluidMlPerServing,
            onSave: (categoryIds, finalFluidAmount, {carbsPerServing, proteinPerServing, fatPerServing, sodiumMg}) async {
              await _saveSearchedFood(
                foodItem,
                categoryIds,
                finalFluidAmount,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                fatPerServing: fatPerServing,
                sodiumMg: sodiumMg,
              );
            },
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load product details'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
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
  }) async {
    try {
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      final supabase = ref.read(appExternalDepsProvider).supabaseClient;

      // Generate unique UUID for this food
      final foodId = _uuid.v4();

      final categoryNames = categoryIds.map((id) {
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

      // 1. Save to local Drift database first (for offline access)
      await database.saveUserFood(
        deviceId: deviceId,
        userId: deviceId,
        id: foodId,
        clientFoodId: foodItem.id,
        name: foodItem.name,
        displayName: foodItem.displayName,
        displayNamePlural: foodItem.displayNamePlural,
        description: foodItem.description,
        imageAddress: foodItem.imageAddress,
        servingAmount: foodItem.servingAmount,
        servingUnit: foodItem.servingUnit,
        caloriesPerServing: (carbsPerServing?.toInt()) ?? foodItem.caloriesPerServing,
        carbsPerServing: carbsPerServing ?? foodItem.carbsPerServing,
        proteinPerServing: proteinPerServing ?? foodItem.proteinPerServing,
        fatPerServing: fatPerServing ?? foodItem.fatPerServing,
        sodiumMg: (sodiumMg?.toInt()) ?? foodItem.sodiumMg,
        fluidMlPerServing: finalFluidAmount ?? foodItem.fluidMlPerServing,
        productTypeId: foodItem.productTypeId,
        categories: categoryNames,
      );

      // 2. Sync to Supabase via edge function (for backup and cross-device sync)
      try {
        final response = await supabase.functions.invoke('save-user-food', body: {
          'device_id': deviceId,
          'id': foodId,
          'client_food_id': foodItem.id,
          'name': foodItem.name,
          'display_name': foodItem.displayName ?? foodItem.name,
          'display_name_plural': foodItem.displayNamePlural ?? '${foodItem.name}s',
          'description': foodItem.description,
          'image_address': foodItem.imageAddress,
          'serving_amount': foodItem.servingAmount,
          'serving_unit': foodItem.servingUnit,
          'calories_per_serving': (carbsPerServing?.toInt()) ?? foodItem.caloriesPerServing,
          'carbs_per_serving': carbsPerServing ?? foodItem.carbsPerServing,
          'protein_per_serving': proteinPerServing ?? foodItem.proteinPerServing,
          'fat_per_serving': fatPerServing ?? foodItem.fatPerServing,
          'sodium_mg': (sodiumMg?.toInt()) ?? foodItem.sodiumMg,
          'fluid_ml_per_serving': finalFluidAmount ?? foodItem.fluidMlPerServing,
          'product_type_id': foodItem.productTypeId,
          'category_ids': categoryIds,
        });

        if (response.status != 200) {
          DebugLogger.warning('⚠️ Supabase sync failed, but local save succeeded: ${response.data}');
        } else {
          DebugLogger.info('✅ Food saved to both local and Supabase: ${foodItem.name}');
        }
      } catch (supabaseError) {
        DebugLogger.warning('⚠️ Supabase sync failed, but local save succeeded: $supabaseError');
      }

      // Set default preference at neutral
      setState(() {
        _sliderLevels[foodItem.name] = 2;
      });

      // Clear search and refresh list
      _clearSearch();
      await _loadFoods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${foodItem.name} added to your foods!'),
            backgroundColor: AppColors.electrolyte,
          ),
        );
      }
    } catch (e) {
      DebugLogger.error('Error saving searched food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save food. Please try again.'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
  }

  Future<void> _deleteUserFood(FoodItem food) async {
    try {
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      final supabase = ref.read(appExternalDepsProvider).supabaseClient;

      // 1. Delete from local Drift database first
      await database.deleteUserFood(food.id);

      // 2. Sync deletion to Supabase via edge function
      try {
        final response = await supabase.functions.invoke('delete-user-food', body: {
          'device_id': deviceId,
          'food_id': food.id,
        });

        if (response.status != 200) {
          DebugLogger.warning('⚠️ Supabase delete sync failed, but local delete succeeded: ${response.data}');
        } else {
          DebugLogger.info('✅ Food deleted from both local and Supabase: ${food.name}');
        }
      } catch (supabaseError) {
        DebugLogger.warning('⚠️ Supabase delete sync failed, but local delete succeeded: $supabaseError');
      }

      // Remove from local state and preference
      setState(() {
        _userFoods.removeWhere((f) => f.id == food.id);
        _sliderLevels.remove(food.name);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} removed from your foods'),
            backgroundColor: AppColors.electrolyte,
          ),
        );
      }
    } catch (e) {
      DebugLogger.error('Error deleting user food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete food. Please try again.'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
      }
    }
  }

  Future<void> _handleBarcodeScan() async {
    try {
      // Navigate to barcode scanner screen
      final result = await context.push('/barcode-scanner', extra: {
        'category': 'preferences',
      });

      // If a food was successfully scanned, handle it
      if (result != null && result is Food && mounted) {
        final foodItem = _convertFoodToFoodItem(result);

        // Show category selection sheet for the scanned food
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => ScannedFoodCategorySheet(
            scannedFood: foodItem,
            context: 'add_food',
            fluidMlPerServing: foodItem.fluidMlPerServing,
            onSave: (categoryIds, finalFluidAmount, {carbsPerServing, proteinPerServing, fatPerServing, sodiumMg}) async {
              await _saveSearchedFood(
                foodItem,
                categoryIds,
                finalFluidAmount,
                carbsPerServing: carbsPerServing,
                proteinPerServing: proteinPerServing,
                fatPerServing: fatPerServing,
                sodiumMg: sodiumMg,
              );
            },
          ),
        );
      }
    } catch (e) {
      DebugLogger.error('Error with barcode scanning: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open barcode scanner'),
            backgroundColor: AppColors.dragonfruit,
          ),
        );
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
      leading: IconButton(
        icon: Icon(
          FontAwesomeIcons.arrowLeft,
          size: AppIconSizes.md,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => context.pop(),
      ),
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

              // Search bar with barcode button and search button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search foods...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: AppIconSizes.controlIcon,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Barcode button
                            IconButton(
                              icon: Icon(
                                FontAwesomeIcons.barcode,
                                size: AppIconSizes.controlIcon,
                                color: AppColors.electrolyte,
                              ),
                              onPressed: () {
                                final analytics = ref.read(appExternalDepsProvider);
                                analytics.analytics.track('barcode_scanner_opened', properties: {
                                  'source': 'food_preferences_settings',
                                });
                                _handleBarcodeScan();
                              },
                            ),
                            // Clear button (if search query is not empty)
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: Icon(
                                  FontAwesomeIcons.xmark,
                                  size: AppIconSizes.controlIcon,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                onPressed: _clearSearch,
                              ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadius.inputRadius,
                          borderSide: const BorderSide(
                            color: AppColors.electrolyte,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Search button
                  KylePrimaryButton(
                    text: 'Search',
                    onPressed: _performSearch,
                    isFullWidth: false,
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),

        // Food preferences list
        Expanded(
          child: (_filteredFoods.isEmpty && _filteredUserFoods.isEmpty)
              ? Center(
                  child: Text(
                    'No foods found',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  padding: AppSpacing.screenPaddingHorizontal,
                  children: [
                    // Your Added Foods section (if any)
                    if (_filteredUserFoods.isNotEmpty) ...[
                      _buildUserFoodsSection(context),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Primary foods
                    ..._filteredFoods.map((food) {
                      final sliderLevel = _sliderLevels[food.name] ?? 2;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildFoodPreferenceItem(context, food, sliderLevel),
                      );
                    }).toList(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blackberry.withOpacity(0.2)
            : AppColors.electrolyte.withOpacity(0.1),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: AppColors.electrolyte.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(
                FontAwesomeIcons.circlePlus,
                size: AppIconSizes.md,
                color: AppColors.electrolyte,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your Added Foods',
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                  ),
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.electrolyte,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredUserFoods.length}',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // User foods list
          ..._filteredUserFoods.map((food) {
            final sliderLevel = _sliderLevels[food.name] ?? 2;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildUserFoodPreferenceItem(context, food, sliderLevel),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildUserFoodPreferenceItem(BuildContext context, FoodItem food, int sliderLevel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: [
          // Food info row with delete button
          Row(
            children: [
              // Food icon
              KyleFoodIcon(
                foodType: _mapFoodType(food.name),
              ),

              const SizedBox(width: AppSpacing.md),

              // Food name
              Expanded(
                child: Text(
                  food.name.toUpperCase(),
                  style: AppTextStyles.foodTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              // Delete button
              IconButton(
                icon: Icon(
                  FontAwesomeIcons.trashCan,
                  size: AppIconSizes.sm,
                  color: AppColors.dragonfruit,
                ),
                onPressed: () => _deleteUserFood(food),
                tooltip: 'Remove food',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Preference slider
          _buildPreferenceSlider(context, food, sliderLevel),
        ],
      ),
    );
  }

  Widget _buildFoodPreferenceItem(BuildContext context, FoodItem food, int sliderLevel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberry.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: [
          // Food info row
          Row(
            children: [
              // Food icon
              KyleFoodIcon(
                foodType: _mapFoodType(food.name),
              ),

              const SizedBox(width: AppSpacing.md),

              // Food name
              Expanded(
                child: Text(
                  food.name.toUpperCase(),
                  style: AppTextStyles.foodTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Preference slider
          _buildPreferenceSlider(context, food, sliderLevel),
        ],
      ),
    );
  }

  Widget _buildPreferenceSlider(BuildContext context, FoodItem food, int sliderLevel) {
    return Column(
      children: [
        // Slider track
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth - 40;
            final dotSpacing = trackWidth / 4;

            return GestureDetector(
              onHorizontalDragStart: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(0, 4);

                setState(() {
                  _sliderLevels[food.name] = newLevel;
                });

                final analytics = ref.read(appExternalDepsProvider);
                analytics.analytics.track('food_preference_changed', properties: {
                  'food_name': food.name,
                  'slider_level': newLevel,
                  'backend_preference': _levelToPreference(newLevel).toString(),
                  'source': 'settings',
                });
              },
              onHorizontalDragUpdate: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(0, 4);

                if (newLevel != sliderLevel) {
                  setState(() {
                    _sliderLevels[food.name] = newLevel;
                  });

                  final analytics = ref.read(appExternalDepsProvider);
                  analytics.analytics.track('food_preference_changed', properties: {
                    'food_name': food.name,
                    'slider_level': newLevel,
                    'backend_preference': _levelToPreference(newLevel).toString(),
                    'source': 'settings',
                  });
                }
              },
              onTapDown: (details) {
                final localX = details.localPosition.dx - 20;
                final newLevel = ((localX / trackWidth) * 4).round().clamp(0, 4);

                setState(() {
                  _sliderLevels[food.name] = newLevel;
                });

                final analytics = ref.read(appExternalDepsProvider);
                analytics.analytics.track('food_preference_changed', properties: {
                  'food_name': food.name,
                  'slider_level': newLevel,
                  'backend_preference': _levelToPreference(newLevel).toString(),
                  'source': 'settings',
                });
              },
              child: Container(
                height: 40,
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Track line
                    Positioned(
                      left: 20,
                      right: 20,
                      top: 19,
                      child: Container(
                        height: 2,
                        color: Colors.white,
                      ),
                    ),

                    // Track dots
                    ...List.generate(5, (index) {
                      final position = 20.0 + (index * dotSpacing);
                      return Positioned(
                        left: position - 4,
                        top: 15,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: index <= sliderLevel
                                ? Colors.white
                                : Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    }),

                    // Active handle
                    Positioned(
                      left: 20.0 + (sliderLevel * dotSpacing) - 10,
                      top: 11,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.sm),

        // Labels with dynamic color
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Avoid label with X icon
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.xmark,
                  size: 15,
                  color: _getIconColor(sliderLevel, true),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Avoid',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: _getIconColor(sliderLevel, true),
                  ),
                ),
              ],
            ),

            // Love label with heart icon
            Row(
              children: [
                Text(
                  'Love',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: _getIconColor(sliderLevel, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  FontAwesomeIcons.heart,
                  size: 20,
                  color: _getIconColor(sliderLevel, false),
                ),
              ],
            ),
          ],
        ),
      ],
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
              ? const Center(child: CircularProgressIndicator())
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _handleSearchResultTap(result),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.blackberry.withOpacity(0.3) : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: AppColors.electrolyte.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            // Product image (if available)
            if (result.imageUrl?.isNotEmpty == true)
              Container(
                width: 50,
                height: 50,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.cardRadius,
                  image: DecorationImage(
                    image: NetworkImage(result.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.displayName,
                    style: AppTextStyles.foodTitle.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (result.brand?.isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      result.brand!,
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Add button
            Icon(
              FontAwesomeIcons.circlePlus,
              size: AppIconSizes.lg,
              color: AppColors.electrolyte,
            ),
          ],
        ),
      ),
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
    } else if (name.contains('drink') || name.contains('water') || name.contains('fluid')) {
      return KyleFoodType.drink;
    } else if (name.contains('protein') || name.contains('meat') || name.contains('chicken')) {
      return KyleFoodType.protein;
    } else if (name.contains('vegetable') || name.contains('carrot') || name.contains('salad')) {
      return KyleFoodType.vegetable;
    } else if (name.contains('snack') || name.contains('cookie') || name.contains('cracker')) {
      return KyleFoodType.snack;
    } else if (name.contains('supplement') || name.contains('pill') || name.contains('vitamin')) {
      return KyleFoodType.supplement;
    } else {
      return KyleFoodType.other;
    }
  }
}
