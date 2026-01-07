import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../shared/widgets/kyle_design/buttons/primary_button.dart';
import '../../../../shared/widgets/kyle_design/cards/base_card.dart';
import '../../../../shared/widgets/kyle_design/inputs/text_field.dart';
import '../../../../shared/screens/food_detail_screen.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../application/open_food_facts_search_service.dart';
import '../../application/product_detail_service.dart';
import '../../application/food_mapping_service.dart';
import '../../../../shared/database/database_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';
import '../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Full-screen modal for adding foods via search or barcode scan
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({super.key});

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<FoodSearchResult> _searchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _searchResults = [];
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
          _errorMessage = 'No products found for "$query". Try different keywords.';
        });
      }
    } on SearchException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search failed. Please try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _handleSearchResultTap(FoodSearchResult result) async {
    DebugLogger.info('🔄 Add Food Screen - Selected: ${result.displayName}');
    DebugLogger.info('🎯 Add Food Screen - Search result ID: ${result.id}');
    DebugLogger.info('🎯 Add Food Screen - Has valid ID: ${result.hasValidId}');

    if (!result.hasValidId) {
      MealvanaSnackbar.showError(context, 'Cannot load details for this product');
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

      DebugLogger.info('🚀 Add Food Screen - About to call ProductDetailService with Open Food Facts ID: ${result.id}');

      // Get product details using the unified service
      final productDetailService = ref.read(productDetailServiceProvider);
      final apiProduct = await productDetailService.getProductDetails(
        openFoodFactsId: result.id,
      );

      DebugLogger.info('✅ Add Food Screen - ProductDetailService returned: ${apiProduct != null ? 'SUCCESS' : 'NULL'}');

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
            'screenContext': FoodDetailContext.addFood,
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
    } on ProductDetailException catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        MealvanaSnackbar.showError(context, e.message);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to load product details');
      }
    }
  }

  /// Convert Food domain model to FoodItem for compatibility with existing UI components
  FoodItem _convertFoodToFoodItem(Food food) {
    return FoodItem(
      id: food.id,
      name: food.name,
      imageAddress: food.imageAddress,
      description: food.description,
      instructions: food.instructions,
      categories: [], // Will be set during category selection
      servingSize: food.servingSize,
      servingAmount: food.servingAmount,
      servingUnit: food.servingUnit,
      servingUnitPlural: food.servingUnitPlural,
      servingQualifier: food.servingQualifier,
      displayName: food.displayName,
      displayNamePlural: food.displayNamePlural,
      beforeRunSuitable: food.beforeRunSuitable,
      duringRunSuitable: food.duringRunSuitable,
      runPortable: food.runPortable,
      requiresPreparation: food.requiresPreparation,
      aidStationAvailable: food.aidStationAvailable,
      maxServingsBefore: food.maxServingsBefore,
      maxServingsDuring: food.maxServingsDuring,
      carbsPerServing: food.carbsPerServing,
      proteinPerServing: food.proteinPerServing,
      fatPerServing: food.fatPerServing,
      caloriesPerServing: food.caloriesPerServing,
      fluidMlPerServing: food.fluidMlPerServing,
      sodiumMg: food.sodiumMg,
      caffeineMg: food.caffeineMg,
      potassiumMg: food.potassiumMg,
      productTypeId: null, // Not available from Food model
      nutrition: null, // Legacy field
      tags: [], // Not available from Food model
      toExcludeFromSolver: false, // Default value
    );
  }

  Future<void> _saveSearchedFood(
    FoodItem foodItem,
    List<int> categoryIds,
    double? fluidMlPerServing, {
    double? carbsPerServing,
    double? proteinPerServing,
    double? fatPerServing,
    double? sodiumMg,
    String? productType,
  }) async {
    DebugLogger.info('🔄 _saveSearchedFood - Starting save process');
    DebugLogger.info('📊 _saveSearchedFood - Food: ${foodItem.name}');
    DebugLogger.info('📊 _saveSearchedFood - Category IDs: $categoryIds');
    DebugLogger.info('📊 _saveSearchedFood - Edited nutrition values:');
    DebugLogger.debug('   - Carbs: $carbsPerServing (original: ${foodItem.carbsPerServing})');
    DebugLogger.debug('   - Protein: $proteinPerServing (original: ${foodItem.proteinPerServing})');
    DebugLogger.debug('   - Fat: $fatPerServing (original: ${foodItem.fatPerServing})');
    DebugLogger.debug('   - Sodium: $sodiumMg (original: ${foodItem.sodiumMg})');
    DebugLogger.debug('   - Fluid: $fluidMlPerServing (original: ${foodItem.fluidMlPerServing})');

    try {
      DebugLogger.info('🔄 _saveSearchedFood - Getting database connection...');
      final database = ref.read(appDatabaseProvider);
      DebugLogger.info('✅ _saveSearchedFood - Database connection obtained');

      DebugLogger.info('🔄 _saveSearchedFood - Getting user profile...');
      final userProfile = await database.getCurrentUserProfile();
      final deviceId = userProfile?.id ?? 'unknown';
      DebugLogger.info('✅ _saveSearchedFood - Device ID: $deviceId');

      // Check for duplicates
      DebugLogger.info('🔄 _saveSearchedFood - Checking for duplicates...');
      final barcode = foodItem.description?.replaceAll('Scanned from barcode ', '') ?? '';
      DebugLogger.info('📊 _saveSearchedFood - Extracted barcode: "$barcode"');
      final hasDuplicate = await database.hasUserFoodWithBarcode(deviceId, barcode);
      DebugLogger.info('📊 _saveSearchedFood - Has duplicate: $hasDuplicate');

      if (hasDuplicate) {
        DebugLogger.warning('⚠️ _saveSearchedFood - Food already exists, showing duplicate message');
        if (mounted) {
          MealvanaSnackbar.showWarning(context, '${foodItem.name} is already in your foods');
        }
        return;
      }

      // Save to database
      DebugLogger.info('🔄 _saveSearchedFood - Saving to database with parameters:');
      DebugLogger.debug('   - deviceId: $deviceId');
      DebugLogger.debug('   - id: ${foodItem.id}');
      DebugLogger.debug('   - clientFoodId: ${foodItem.id}');
      DebugLogger.debug('   - barcode: $barcode');
      DebugLogger.debug('   - name: ${foodItem.name}');
      DebugLogger.debug('   - carbsPerServing: ${carbsPerServing ?? foodItem.carbsPerServing}');
      DebugLogger.debug('   - proteinPerServing: ${proteinPerServing ?? foodItem.proteinPerServing}');
      DebugLogger.debug('   - fatPerServing: ${fatPerServing ?? foodItem.fatPerServing}');
      DebugLogger.debug('   - sodiumMg: ${sodiumMg?.toInt() ?? foodItem.sodiumMg}');
      DebugLogger.debug('   - categoryIds: $categoryIds');

      // Convert category IDs to category names (array-based categories)
      final categoryNames = categoryIds.map((id) {
        switch (id) {
          case 1: return 'before_run';
          case 2: return 'during_run';
          case 3: return 'after_run';
          default: return 'before_run'; // Default fallback
        }
      }).toList();

      // Use user-selected product type if provided, otherwise fall back to 'import'
      final finalProductType = productType ?? foodItem.productTypeId ?? 'import';

      await database.saveUserFood(
        deviceId: deviceId,
        userId: deviceId,
        id: foodItem.id,
        clientFoodId: foodItem.id,
        barcode: barcode,
        name: foodItem.name,
        displayName: foodItem.displayName,
        displayNamePlural: foodItem.displayNamePlural,
        description: foodItem.description,
        imageAddress: foodItem.imageAddress,
        servingAmount: foodItem.servingAmount,
        servingUnit: foodItem.servingUnit,
        caloriesPerServing: foodItem.caloriesPerServing,
        carbsPerServing: carbsPerServing ?? foodItem.carbsPerServing,
        proteinPerServing: proteinPerServing ?? foodItem.proteinPerServing,
        fatPerServing: fatPerServing ?? foodItem.fatPerServing,
        sodiumMg: sodiumMg?.toInt() ?? foodItem.sodiumMg,
        fluidMlPerServing: fluidMlPerServing ?? foodItem.fluidMlPerServing,
        productTypeId: finalProductType,
        categories: categoryNames,  // Now using string array instead of int IDs
      );

      DebugLogger.info('✅ _saveSearchedFood - Successfully saved to database');

      if (mounted) {
        DebugLogger.info('✅ _saveSearchedFood - Showing success message and closing screen');
        MealvanaSnackbar.showSuccess(context, '${foodItem.name} added to your foods');

        // Close the screen
        Navigator.of(context).pop();
      } else {
        DebugLogger.warning('⚠️ _saveSearchedFood - Widget not mounted, skipping UI updates');
      }
    } catch (e, stackTrace) {
      DebugLogger.error('❌ _saveSearchedFood - ERROR occurred:');
      DebugLogger.error('   Error: $e');
      DebugLogger.debug('   Type: ${e.runtimeType}');
      DebugLogger.debug('   Stack trace: $stackTrace');

      if (mounted) {
        MealvanaSnackbar.showError(context, 'Failed to save food: ${e.toString()}. Please try again.');
      } else {
        DebugLogger.warning('⚠️ _saveSearchedFood - Widget not mounted, cannot show error message');
      }
    }
  }

  Future<void> _handleBarcodeScan() async {
    DebugLogger.info('🔄 Add Food Screen - Barcode scan button pressed');

    // Navigate to barcode scanner
    final result = await context.pushNamed(
      'barcode-scanner',
      extra: {
        'category': 'add_food',
        'context': 'add_food',
      },
    );

    // Handle scanned result - FoodDetailScreen already handled category selection
    // The result from barcode-scanner is now a Food with categories already set
    if (result != null && mounted) {
      final scannedFood = result as Food;
      final foodItem = _convertFoodToFoodItem(scannedFood);

      // Save the food with the categories that were set in FoodDetailScreen
      await _saveSearchedFood(
        foodItem,
        scannedFood.categories.map((cat) {
          switch (cat) {
            case 'before_run': return 1;
            case 'during_run': return 2;
            case 'after_run': return 3;
            default: return 1;
          }
        }).toList(),
        scannedFood.fluidMlPerServing,
        carbsPerServing: scannedFood.carbsPerServing,
        proteinPerServing: scannedFood.proteinPerServing,
        fatPerServing: scannedFood.fatPerServing,
        sodiumMg: scannedFood.sodiumMg?.toDouble(),
        productType: scannedFood.productTypeId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Add Food',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search section with search button
              Row(
                children: [
                  Expanded(
                    child: KyleSearchField(
                      controller: _searchController,
                      hint: 'Search for food...',
                      onChanged: (value) {
                        // Real-time search feedback could go here
                      },
                      onSubmitted: (_) => _performSearch(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: AppSizes.inputHeight,
                    child: KylePrimaryButton(
                      text: 'SEARCH',
                      onPressed: _isSearching ? null : _performSearch,
                      isFullWidth: false,
                      isLoading: _isSearching,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Barcode scan button
              BaseCard(
                child: InkWell(
                  onTap: _handleBarcodeScan,
                  borderRadius: AppRadius.cardRadius,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Icon(
                          FontAwesomeIcons.barcode,
                          color: AppColors.orange,
                          size: AppIconSizes.controlIcon,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scan product barcode',
                                style: AppTextStyles.subtitle.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Scan any food product to add brand-specific preferences',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          FontAwesomeIcons.chevronRight,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: AppIconSizes.chevron,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.dragonfruit.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smRadius,
                    border: Border.all(
                      color: AppColors.dragonfruit.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        FontAwesomeIcons.triangleExclamation,
                        color: AppColors.dragonfruit,
                        size: AppIconSizes.controlIcon,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.dragonfruit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Search results
              if (_searchResults.isNotEmpty) ...[
                Text(
                  'Search Results',
                  style: AppTextStyles.subtitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: ListView.separated(
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return _buildSearchResultItem(result);
                    },
                  ),
                ),
              ] else if (!_isSearching && _searchController.text.isEmpty) ...[
                // Empty state when no search has been performed
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Search for foods or scan a barcode',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(FoodSearchResult result) {
    return BaseCard(
      child: InkWell(
        onTap: () => _handleSearchResultTap(result),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Product image or placeholder with Electrolyte background
              Container(
                width: AppIconSizes.foodIcon,
                height: AppIconSizes.foodIcon,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte.withValues(alpha: 0.2),
                  borderRadius: AppRadius.smRadius,
                ),
                child: result.imageUrl != null
                    ? ClipRRect(
                        borderRadius: AppRadius.smRadius,
                        child: Image.network(
                          result.imageUrl!,
                          width: AppIconSizes.foodIcon,
                          height: AppIconSizes.foodIcon,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            FontAwesomeIcons.utensils,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: AppIconSizes.controlIcon,
                          ),
                        ),
                      )
                    : Icon(
                        FontAwesomeIcons.utensils,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: AppIconSizes.controlIcon,
                      ),
              ),

              const SizedBox(width: AppSpacing.md),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName,
                      style: AppTextStyles.foodTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.categories?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        result.categories!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                FontAwesomeIcons.chevronRight,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppIconSizes.chevron,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
