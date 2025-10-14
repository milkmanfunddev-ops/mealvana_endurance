import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/scanned_food_category_sheet.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../nutrition_plan/domain/food.dart';
import '../../application/open_food_facts_search_service.dart';
import '../../application/product_detail_service.dart';
import '../../application/food_mapping_service.dart';
import '../../../../shared/database/database_provider.dart';
import 'package:mealvana_endurance/core/utils/debug_logger.dart';

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
    } on ProductDetailException catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
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
      final database = await ref.read(databaseProvider.future);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${foodItem.name} is already in your foods'),
              backgroundColor: AppTheme.primary600,
            ),
          );
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

      await database.saveUserFood(
        deviceId: deviceId,
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
        productTypeId: foodItem.productTypeId,
        categoryIds: categoryIds,
      );

      DebugLogger.info('✅ _saveSearchedFood - Successfully saved to database');

      if (mounted) {
        DebugLogger.info('✅ _saveSearchedFood - Showing success message and closing screen');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${foodItem.name} added to your foods'),
            backgroundColor: AppTheme.primary600,
          ),
        );

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save food: ${e.toString()}. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
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

    // Handle scanned result
    if (result != null && mounted) {
      final scannedFood = result as FoodItem;

      // Show category selection sheet
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ScannedFoodCategorySheet(
          scannedFood: scannedFood,
          context: 'add_food',
          fluidMlPerServing: scannedFood.fluidMlPerServing,
          onSave: (categoryIds, finalFluidAmount, {carbsPerServing, proteinPerServing, fatPerServing, sodiumMg}) async {
            await _saveSearchedFood(
              scannedFood,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      appBar: AppBar(
        leading: CustomAppBarBackButton(),
        backgroundColor: AppTheme.baseCream,
        elevation: 0,
        title: Text(
          'Add Food',
          style: AppTheme.textStyle.copyWith(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: AppTheme.baseBlack,
          ),
        ),
        centerTitle: true,
        // leading: IconButton(
        //   onPressed: () => Navigator.of(context).pop(),
        //   icon: Icon(
        //     Icons.arrow_back_ios,
        //     color: AppTheme.baseBlack,
        //     size: 20.sp,
        //   ),
        // ),
      ),
      body: Column(
        children: [

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search section
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search for food...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: AppTheme.baseGrey,
                              size: 20.sp,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(
                                color: AppTheme.baseGrey.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppTheme.primary600),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                          ),
                          style: AppTheme.textStyle.copyWith(
                            fontSize: 16.sp,
                            color: AppTheme.baseBlack,
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      ElevatedButton(
                        onPressed: _isSearching ? null : _performSearch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary600,
                          foregroundColor: AppTheme.baseWhite,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: _isSearching
                            ? SizedBox(
                                width: 20.w,
                                height: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.baseWhite,
                                ),
                              )
                            : Text('Search'),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // Barcode scan button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppTheme.baseWhite.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppTheme.primary600.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      onTap: _handleBarcodeScan,
                      borderRadius: BorderRadius.circular(12.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        child: Row(
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              color: AppTheme.primary600,
                              size: 20.sp,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scan product barcode',
                                    style: AppTheme.textStyle.copyWith(
                                      color: AppTheme.primary600,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Scan any food product to add brand-specific preferences',
                                    style: AppTheme.textStyle.copyWith(
                                      color: AppTheme.primary600.withValues(alpha: 0.7),
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: AppTheme.primary600,
                              size: 16.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTheme.textStyle.copyWith(
                          color: Colors.red,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // Search results
                  if (_searchResults.isNotEmpty) ...[
                    Text(
                      'Search Results',
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.baseBlack,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return _buildSearchResultItem(result);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(FoodSearchResult result) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.baseGrey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleSearchResultTap(result),
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Row(
            children: [
              // Product image or placeholder
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: AppTheme.baseGrey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: result.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.r),
                        child: Image.network(
                          result.imageUrl!,
                          width: 48.w,
                          height: 48.w,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.food_bank,
                            color: AppTheme.baseGrey,
                            size: 24.sp,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.food_bank,
                        color: AppTheme.baseGrey,
                        size: 24.sp,
                      ),
              ),

              SizedBox(width: 12.w),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName,
                      style: AppTheme.textStyle.copyWith(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.baseBlack,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.categories?.isNotEmpty == true) ...[
                      SizedBox(height: 4.h),
                      Text(
                        result.categories!,
                        style: AppTheme.textStyle.copyWith(
                          fontSize: 14.sp,
                          color: AppTheme.baseGrey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios,
                color: AppTheme.baseGrey,
                size: 16.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
