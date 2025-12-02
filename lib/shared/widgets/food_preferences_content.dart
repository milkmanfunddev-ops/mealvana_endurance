import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/domain/user_preferences.dart';
import '../../features/nutrition_plan/domain/food_item.dart';
import '../../features/nutrition_plan/domain/food.dart';
import '../../features/nutrition_plan/data/food_repository.dart';
import '../../features/onboarding/presentation/widgets/expandable_more_options_widget.dart';
import '../database/database_provider.dart';
import '../../theme/app_theme.dart';
import 'food_preference_widget.dart';
import '../../features/content/application/content_service.dart';
import '../../features/content/domain/content_keys.dart';
import '../../features/barcode_scanning/application/open_food_facts_search_service.dart';
import '../../features/barcode_scanning/application/product_detail_service.dart';
import '../../features/barcode_scanning/application/food_mapping_service.dart';
import '../screens/food_detail_screen.dart';
import '../services/app_external_deps.dart';

/// Configuration for different food preferences layouts
enum FoodPreferencesLayout {
  /// Settings version with search bar at top and no FAB
  settings,
  /// Onboarding version with scan section at bottom
  onboarding,
}

/// Shared food preferences content widget
/// Used by both onboarding and settings screens
class FoodPreferencesContent extends ConsumerStatefulWidget {
  final Map<String, FoodPreference> selectedPreferences;
  final Function(String foodName, FoodPreference preference) onPreferenceChanged;
  final VoidCallback? onSave;
  final String saveButtonText;
  final bool isSaving;
  final bool showSaveButton;
  final FoodPreferencesLayout layout;

  const FoodPreferencesContent({
    super.key,
    required this.selectedPreferences,
    required this.onPreferenceChanged,
    this.onSave,
    this.saveButtonText = 'Save',
    this.isSaving = false,
    this.showSaveButton = true,
    this.layout = FoodPreferencesLayout.settings,
  });

  @override
  ConsumerState<FoodPreferencesContent> createState() => _FoodPreferencesContentState();
}

class _FoodPreferencesContentState extends ConsumerState<FoodPreferencesContent> {
  static const _uuid = Uuid();

  List<FoodItem> _primaryFoods = [];
  List<FoodItem> _additionalFoods = [];
  List<FoodItem> _scannedFoods = [];
  bool _isLoading = true;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<FoodSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;
  String? _searchErrorMessage;

  // Filter functionality
  final Set<FoodPreference> _selectedFilters = {};
  String _searchQuery = '';
  bool _showFilters = false;

  // Collapsible section state
  bool _isAddedFoodsSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFoods() async {
    try {
      final foodRepository = ref.read(foodRepositoryProvider);
      final database = ref.read(appDatabaseProvider);

      // Get current user's ID
      final userProfile = await database.getCurrentUserProfile();
      final userId = userProfile?.id ?? 'unknown';

      // Load primary foods, additional foods, and scanned foods in parallel
      final results = await Future.wait([
        foodRepository.getPrimaryFoodsForPreferences(),
        foodRepository.getAdditionalFoodsForPreferences(),
        database.getUserFoods(userId),
      ]);

      final primaryFoods = results[0] as List<FoodItem>;
      final additionalFoods = results[1] as List<FoodItem>;
      final scannedFoodsData = results[2] as List<dynamic>;

      // Convert scanned foods to FoodItems
      final scannedFoods = scannedFoodsData
          .map((userFood) => database.convertUserFoodToFoodItem(userFood))
          .cast<FoodItem>()
          .toList();

      setState(() {
        _primaryFoods = primaryFoods;
        _additionalFoods = additionalFoods;
        _scannedFoods = scannedFoods;
        _isLoading = false;

        // Initialize preferences if not already set
        for (final food in primaryFoods) {
          if (!widget.selectedPreferences.containsKey(food.name)) {
            widget.onPreferenceChanged(food.name, FoodPreference.willingToTry);
          }
        }

        for (final food in additionalFoods) {
          if (!widget.selectedPreferences.containsKey(food.name)) {
            widget.onPreferenceChanged(food.name, FoodPreference.dislike);
          }
        }

        for (final food in scannedFoods) {
          if (!widget.selectedPreferences.containsKey(food.name)) {
            widget.onPreferenceChanged(food.name, FoodPreference.willingToTry);
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading foods: $e');
    }
  }


  Future<void> _deleteScannedFood(FoodItem food) async {
    try {
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.getCurrentUserProfile();
      final userId = userProfile?.id ?? 'unknown';
      final deviceId = userProfile?.deviceId ?? userId; // For backwards compatibility
      final supabase = ref.read(appExternalDepsProvider).supabaseClient;

      // 1. Delete from local Drift database first
      await database.deleteUserFood(food.id);

      // 2. Sync deletion to Supabase (direct delete, replacing edge function)
      try {
        await supabase
            .from('user_foods')
            .delete()
            .eq('device_id', deviceId)
            .eq('id', food.id);

        debugPrint('✅ Food deleted from both local and Supabase: ${food.name}');
      } catch (supabaseError) {
        debugPrint('⚠️ Supabase delete sync failed, but local delete succeeded: $supabaseError');
        // Don't throw - local delete worked, just log the sync failure
      }

      // Remove from local state
      setState(() {
        _scannedFoods.removeWhere((f) => f.id == food.id);
      });

      // Remove preference
      widget.selectedPreferences.remove(food.name);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} removed from your foods'),
            backgroundColor: AppTheme.primary600,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting scanned food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete food. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Search functionality
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

  void _toggleFilter(FoodPreference preference) {
    setState(() {
      if (_selectedFilters.contains(preference)) {
        _selectedFilters.remove(preference);
      } else {
        _selectedFilters.add(preference);
      }
    });
  }

  Future<void> _handleSearchResultTap(FoodSearchResult result) async {
    if (!result.hasValidId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot load details for this product'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

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
              backgroundColor: Colors.red,
            ),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load product details'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      final database = ref.read(appDatabaseProvider);
      final userProfile = await database.getCurrentUserProfile();
      final userId = userProfile?.id ?? 'unknown';
      final deviceId = userProfile?.deviceId ?? userId; // For backwards compatibility
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

      // Use user-selected product type if provided, otherwise fall back to 'import'
      final finalProductType = productType ?? foodItem.productTypeId ?? 'import';

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
        productTypeId: finalProductType,
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
          'product_type_id': finalProductType,
          'category_ids': categoryIds,
        });

        if (response.status != 200) {
          debugPrint('⚠️ Supabase sync failed, but local save succeeded: ${response.data}');
          // Don't throw - local save worked, just log the sync failure
        } else {
          debugPrint('✅ Food saved to both local and Supabase: ${foodItem.name}');
        }
      } catch (supabaseError) {
        debugPrint('⚠️ Supabase sync failed, but local save succeeded: $supabaseError');
        // Don't throw - local save worked, just log the sync failure
      }

      // Set default preference
      widget.onPreferenceChanged(foodItem.name, FoodPreference.willingToTry);

      // Clear search and refresh list
      _clearSearch();
      await _loadFoods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${foodItem.name} added to your foods!'),
            backgroundColor: AppTheme.primary600,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving searched food: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save food. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter foods based on search query and preference filters
  List<FoodItem> _getFilteredFoods(List<FoodItem> foods) {
    List<FoodItem> filtered = foods;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((food) =>
        food.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply preference filters
    if (_selectedFilters.isNotEmpty) {
      filtered = filtered.where((food) {
        final preference = widget.selectedPreferences[food.name];
        return preference != null && _selectedFilters.contains(preference);
      }).toList();
    }

    return filtered;
  }


  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // If showing search results, display only search UI
    if (_showSearchResults) {
      return _buildSearchResultsView(content);
    }

    // Otherwise show the main content with layout-specific differences
    switch (widget.layout) {
      case FoodPreferencesLayout.settings:
        return _buildSettingsLayout(content);
      case FoodPreferencesLayout.onboarding:
        return _buildOnboardingLayout(content);
    }
  }

  Widget _buildSearchResultsView(ContentService content) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: Column(
        children: [
          _buildSearchBar(content),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchErrorMessage != null
                    ? _buildSearchError()
                    : _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsLayout(ContentService content) {
    final likeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionLike,
      defaultValue: 'Love',
    );
    final willingLabel = content.getValue(
      ContentKeys.foodPreferencesOptionWillingToTry,
      defaultValue: 'Willing to Try',
    );
    final dislikeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionDislike,
      defaultValue: 'Avoid',
    );

    // Apply filters to all food lists
    final filteredScannedFoods = _getFilteredFoods(_scannedFoods);
    final filteredPrimaryFoods = _getFilteredFoods(_primaryFoods);
    final filteredAdditionalFoods = _getFilteredFoods(_additionalFoods);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: Column(
        children: [
          // Search bar at the top (sticky)
          _buildSearchBar(content),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Your Added Foods section (if not filtered out)
                  if (filteredScannedFoods.isNotEmpty || (_selectedFilters.isEmpty && _searchQuery.isEmpty && _scannedFoods.isNotEmpty)) ...[
                    _buildAddedFoodsSection(filteredScannedFoods, likeLabel, willingLabel, dislikeLabel),
                  ],

                  // Primary foods list
                  _buildFoodsList(filteredPrimaryFoods, likeLabel, willingLabel, dislikeLabel),

                  // Additional foods list (no expandable widget in settings)
                  if (filteredAdditionalFoods.isNotEmpty)
                    _buildFoodsList(filteredAdditionalFoods, likeLabel, willingLabel, dislikeLabel),

                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),

          // Save button (if enabled)
          if (widget.showSaveButton)
            _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildOnboardingLayout(ContentService content) {
    final likeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionLike,
      defaultValue: 'Love',
    );
    final willingLabel = content.getValue(
      ContentKeys.foodPreferencesOptionWillingToTry,
      defaultValue: 'Willing to Try',
    );
    final dislikeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionDislike,
      defaultValue: 'Avoid',
    );

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Primary foods list
                  _buildFoodsList(_primaryFoods, likeLabel, willingLabel, dislikeLabel),

                  // Expandable more options widget
                  ExpandableMoreOptionsWidget(
                    additionalFoods: _additionalFoods,
                    selectedPreferences: widget.selectedPreferences,
                    onPreferenceChanged: widget.onPreferenceChanged,
                  ),

                  // Your Scanned Foods section (at bottom for onboarding)
                  if (_scannedFoods.isNotEmpty) ...[
                    SizedBox(height: 16.h),
                    Divider(
                      color: AppTheme.baseGrey.withValues(alpha: 0.3),
                      thickness: 1,
                      indent: 16.w,
                      endIndent: 16.w,
                    ),
                    SizedBox(height: 8.h),
                    _buildAddedFoodsSection(_scannedFoods, likeLabel, willingLabel, dislikeLabel, showTitle: true),
                  ],

                  // Scan product barcode section
                  _buildScanSection(),

                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),

          // Save button (if enabled)
          if (widget.showSaveButton)
            _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ContentService content) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      color: AppTheme.baseCream,
      child: Column(
        children: [
          // Search input field
          Container(
            height: 48.h,
            decoration: BoxDecoration(
              color: AppTheme.baseWhite,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: AppTheme.primary100),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      hintText: 'Search foods...',
                      contentPadding: EdgeInsets.fromLTRB(16.w, 12.h, 8.w, 12.h),
                    ),
                    onSubmitted: (_) => _performSearch(),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                // Barcode button
                GestureDetector(
                  onTap: _handleBarcodeScan,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(6.w, 12.h, 6.w, 12.h),
                    child: Icon(Icons.qr_code_scanner, color: AppTheme.primary600, size: 20.sp),
                  ),
                ),
                // Search button with white circular background
                GestureDetector(
                  onTap: _performSearch,
                  child: Container(
                    width: 36.w,
                    height: 36.h,
                    margin: EdgeInsets.only(right: 6.w),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.search,
                      color: AppTheme.primary600,
                      size: 18.sp,
                    ),
                  ),
                ),
                // Filter button
                GestureDetector(
                  onTap: _toggleFilterPills,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(6.w, 12.h, 12.w, 12.h),
                    child: Icon(
                      Icons.filter_list,
                      color: _selectedFilters.isNotEmpty ? AppTheme.primary600 : AppTheme.primary100,
                      size: 20.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Clear search button (when showing results)
          if (_showSearchResults) ...[
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppTheme.primary100,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.clear, size: 16.sp, color: AppTheme.primary600),
                    SizedBox(width: 4.w),
                    Text(
                      'Clear Search',
                      style: TextStyle(
                        color: AppTheme.primary600,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Filter pills (when filters are shown)
          if (_showFilters) ...[
            SizedBox(height: 12.h),
            _buildFilterPills(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildSearchResultItem(FoodSearchResult result) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product image (if available)
              if (result.imageUrl?.isNotEmpty == true)
                Container(
                  width: 50.w,
                  height: 50.w,
                  margin: EdgeInsets.only(right: 12.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.r),
                    image: DecorationImage(
                      image: NetworkImage(result.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                    if (result.brand?.isNotEmpty == true) ...[
                      SizedBox(height: 4.h),
                      Text(
                        result.brand!,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.primary100,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Add Food button
              GestureDetector(
                onTap: () => _handleSearchResultTap(result),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppTheme.primary600,
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    'Add Food',
                    style: TextStyle(
                      color: AppTheme.baseWhite,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48.sp,
              color: AppTheme.primary100,
            ),
            SizedBox(height: 16.h),
            Text(
              _searchErrorMessage ?? 'Search failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                color: AppTheme.primary600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddedFoodsSection(List<FoodItem> foods, String likeLabel, String willingLabel, String dislikeLabel, {bool showTitle = false}) {
    if (foods.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.primary50, // Different background to distinguish added foods
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary100, width: 1),
      ),
      child: Column(
        children: [
          // Collapsible header
          GestureDetector(
            onTap: () {
              setState(() {
                _isAddedFoodsSectionExpanded = !_isAddedFoodsSectionExpanded;
              });
            },
            child: Container(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: AppTheme.primary600,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Your Added Foods',
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary600,
                      ),
                    ),
                  ),
                  // Count badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primary600,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${foods.length}',
                      style: TextStyle(
                        color: AppTheme.baseWhite,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Expand/collapse icon
                  AnimatedRotation(
                    turns: _isAddedFoodsSectionExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      color: AppTheme.primary600,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Collapsible content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: foods.length,
                separatorBuilder: (context, index) => SizedBox(height: 8.h),
                itemBuilder: (context, index) {
                  final food = foods[index];
                  final selected = widget.selectedPreferences[food.name] ?? FoodPreference.willingToTry;
                  return FoodPreferenceChipItem(
                    food: food,
                    selected: selected,
                    likeLabel: likeLabel,
                    willingLabel: willingLabel,
                    dislikeLabel: dislikeLabel,
                    showDeleteButton: true,
                    onChanged: (value) {
                      widget.onPreferenceChanged(food.name, value);
                    },
                    onDelete: () => _deleteScannedFood(food),
                  );
                },
              ),
            ),
            crossFadeState: _isAddedFoodsSectionExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodsList(List<FoodItem> foods, String likeLabel, String willingLabel, String dislikeLabel) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: foods.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final food = foods[index];
        final selected = widget.selectedPreferences[food.name] ?? FoodPreference.willingToTry;
        return FoodPreferenceChipItem(
          food: food,
          selected: selected,
          likeLabel: likeLabel,
          willingLabel: willingLabel,
          dislikeLabel: dislikeLabel,
          onChanged: (value) {
            widget.onPreferenceChanged(food.name, value);
          },
        );
      },
    );
  }

  Widget _buildScanSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: GestureDetector(
        onTap: _handleBarcodeScan,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppTheme.primary50,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppTheme.primary100, width: 2),
          ),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 32.sp,
                color: AppTheme.primary600,
              ),
              SizedBox(height: 8.h),
              Text(
                'Scan Product Barcode',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary600,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Add foods by scanning barcodes',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.primary100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return widget.isSaving
        ? const CircularProgressIndicator()
        : Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 34.h),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: widget.isSaving ? null : widget.onSave,
                // style: ElevatedButton.styleFrom(
                //   backgroundColor: AppTheme.primary600,
                //   foregroundColor: AppTheme.baseWhite,
                //   padding: EdgeInsets.symmetric(vertical: 16.h),
                //   shape: RoundedRectangleBorder(
                //     borderRadius: BorderRadius.circular(12.r),
                //   ),
                // ),
                text: widget.saveButtonText,
              ),
            ),
          );
  }

  void _toggleFilterPills() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  Widget _buildFilterPills() {
    final content = ref.read(contentServiceProvider);
    final likeLabel = content.getValue(ContentKeys.foodPreferencesOptionLike, defaultValue: 'Love');
    final willingLabel = content.getValue(ContentKeys.foodPreferencesOptionWillingToTry, defaultValue: 'Willing to Try');
    final dislikeLabel = content.getValue(ContentKeys.foodPreferencesOptionDislike, defaultValue: 'Avoid');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          _buildFilterPill(
            label: 'All',
            isSelected: _selectedFilters.isEmpty,
            color: AppTheme.primary600,
            onTap: () {
              setState(() {
                _selectedFilters.clear();
              });
            },
          ),
          SizedBox(width: 8.w),
          _buildFilterPill(
            label: likeLabel,
            isSelected: _selectedFilters.contains(FoodPreference.like),
            color: Colors.green,
            onTap: () => _toggleFilter(FoodPreference.like),
          ),
          SizedBox(width: 8.w),
          _buildFilterPill(
            label: willingLabel,
            isSelected: _selectedFilters.contains(FoodPreference.willingToTry),
            color: Colors.orange,
            onTap: () => _toggleFilter(FoodPreference.willingToTry),
          ),
          SizedBox(width: 8.w),
          _buildFilterPill(
            label: dislikeLabel,
            isSelected: _selectedFilters.contains(FoodPreference.dislike),
            color: Colors.red,
            onTap: () => _toggleFilter(FoodPreference.dislike),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.baseWhite,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? color : AppTheme.primary100,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : AppTheme.primary600,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13.sp,
          ),
        ),
      ),
    );
  }

  void _handleBarcodeScan() async {
    try {
      // Navigate to barcode scanner screen
      final result = await context.push('/barcode-scanner', extra: {
        'category': 'preferences', // Indicate this is for food preferences
      });

      // If a food was successfully scanned, the FoodDetailScreen already handled category selection
      // The result from barcode-scanner is now a Food with categories already set
      if (result != null && result is Food && mounted) {
        final foodItem = _convertFoodToFoodItem(result);

        // Save the food with the categories that were set in FoodDetailScreen
        await _saveSearchedFood(
          foodItem,
          result.categories.map((cat) {
            switch (cat) {
              case 'before_run': return 1;
              case 'during_run': return 2;
              case 'after_run': return 3;
              default: return 1;
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
      debugPrint('Error with barcode scanning: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open barcode scanner'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
