# Barcode Scanning Feature Roadmap

## Overview
This document outlines the implementation roadmap for adding barcode scanning functionality to the Mealvana Endurance app, specifically targeting sports nutrition products like Maurten gels, Gu gels, and other packaged endurance foods.

## Current System Analysis

### Existing Swap Food Architecture
The app currently has a comprehensive food swapping system built on Feature-Oriented Architecture (FOA):

**Key Components:**
- **Screen**: `SwapFoodScreen` (`lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart`)
- **Controller**: `SwapFoodController` (`lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart`)
- **Domain Model**: `Food` class (`lib/features/nutrition_plan/domain/food.dart`)
- **Navigation**: Integrated with `app_router.dart` using GoRouter

**Current Food Model Structure:**
```dart
class Food {
  final String id;
  final String name;
  final String? imageAddress;           // S3 bucket path for images
  final String? description;
  final String? instructions;
  final double? servingAmount;
  final String? servingUnit;
  final String? servingUnitPlural;
  final String? servingQualifier;
  final String? servingSize;

  // Nutritional data
  final double? carbsPerServing;
  final int? sodiumMg;
  final double? fluidMlPerServing;
  final int? caloriesPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final int? caffeineMg;
  final int? potassiumMg;

  // Suitability flags for endurance sports
  final bool beforeRunSuitable;
  final bool duringRunSuitable;
  final bool runPortable;
  final bool requiresPreparation;
  final bool aidStationAvailable;
  final int? maxServingsBefore;
  final int? maxServingsDuring;
}
```

### Current Database Structure (Drift SQLite v8)
The app uses a sophisticated dual-database architecture with local Drift SQLite and cloud Supabase:

**Foods Table** (`FoodsTable`):
- Comprehensive nutritional information storage
- Suitability flags for endurance sports timing
- Brand and affiliate marketing support
- Image address linking to S3 bucket
- JSON nutritional info field for extensibility

**Key Database Features:**
- Offline-first architecture with 24-hour sync cycles
- Migration system supporting schema versioning
- Local caching with cloud backup synchronization
- Support for custom foods and user preferences

## Proposed Barcode Scanning Implementation

### 1. Technology Stack Selection

**Flutter Package: `mobile_scanner` (v6.0.0+)**
- **Rationale**: Most actively maintained and comprehensive barcode scanning solution for 2024
- **Platform Support**: iOS, Android, macOS, Web using native ML Kit
- **Bundle Size Impact**: 3-10MB (bundled) or 600KB (unbundled via Google Play Services)
- **Key Features**: Real-time scanning, lifecycle management, customizable UI

**Supabase Edge Function Architecture:**
- **Primary API Integration**: Supabase Edge Function handles all external API calls
- **Sequential API Approach**: Edge function tries Open Food Facts → USDA → manual entry fallback
- **Client Simplicity**: Flutter app only communicates with single Supabase endpoint
- **Server-Side Benefits**: Centralized API key management, rate limiting, and caching

**External APIs (Server-Side Only):**
1. **Primary**: Open Food Facts API (Free)
   - Community-driven database with good sports nutrition coverage
   - No rate limits for reasonable usage
   - Strong coverage of packaged foods including sports nutrition

2. **Fallback**: USDA FoodData Central API (Free)
   - Government database with comprehensive nutritional data
   - 1,000 requests/hour rate limit
   - Excellent for nutritional accuracy

3. **Future Enhancement**: Edamam Food Database API (Paid - $49/month)
   - Professional-grade database with advanced features
   - Natural language processing capabilities
   - Superior brand coverage for sports nutrition

### 2. Feature-Oriented Architecture Implementation

Following the established FOA pattern, the barcode scanning feature will be implemented as:

```
lib/features/barcode_scanning/
├── presentation/
│   ├── screens/
│   │   └── barcode_scanner_screen.dart      # Full-screen scanner interface
│   ├── widgets/
│   │   ├── scanner_overlay_widget.dart      # Camera overlay with guidelines
│   │   ├── product_confirmation_widget.dart # Product preview and confirmation
│   │   └── manual_entry_dialog.dart         # Fallback for missing products
│   └── providers/
│       └── barcode_scanner_controller.dart  # AsyncNotifier controller
├── application/
│   ├── barcode_scanner_service.dart         # Core scanning orchestration
│   ├── supabase_barcode_service.dart      # Supabase Edge Function integration
│   └── barcode_validation_service.dart     # Barcode format validation
├── domain/
│   ├── barcode_result.dart                 # Scanned barcode domain model
│   ├── api_food_product.dart              # API response domain model
│   └── food_api_provider.dart             # API provider enum
└── data/
    ├── repositories/
    │   └── barcode_food_repository.dart    # Data layer for barcode foods
    └── data_sources/
        ├── supabase_edge_function_data_source.dart  # Single Edge Function interface
        └── local_barcode_cache_data_source.dart     # Local caching layer
```

### 3. User Experience Flow

**Current Swap Food Flow Enhancement:**
1. **Entry Point**: Add "Scan Barcode" button/icon on `SwapFoodScreen` next to search field
2. **Scanner Screen**: Navigate to dedicated `BarcodeScannerScreen` with full-screen camera interface
3. **Product Detection**: Real-time barcode scanning with visual feedback
4. **Edge Function Lookup**: Single call to Supabase Edge Function (handles Open Food Facts → USDA → manual entry internally)
5. **Product Confirmation**: Preview screen showing:
   - Product name and image (if available)
   - Nutritional information (carbs, sodium, fluids for endurance focus)
   - Serving size adjustment controls
   - "Add to Plan" confirmation button
6. **Integration**: Seamless addition to existing nutrition plan with same swap/add/delete functionality

**Error Handling Strategy:**
- **Barcode Not Found**: Show "Product not found" dialog with manual entry option
- **Edge Function Failures**: Graceful handling of server-side API sequence failures
- **Network Issues**: Cache common sports nutrition barcodes for offline scanning
- **Invalid Barcodes**: Format validation with user feedback
- **Server Timeouts**: Fallback to manual entry with clear messaging

### 4. Database Integration Strategy

**Extending Current Architecture:**
- **No Schema Changes Required**: Leverage existing `FoodsTable` structure
- **Special Barcode Flag**: Use existing `productType` field to mark barcode-scanned foods
- **API Source Tracking**: Use `affiliateSource` field to track which API provided the data
- **Image Handling**: Download and cache product images to S3 bucket following existing pattern

**Data Mapping Strategy:**
```dart
// Edge Function Response → Food Domain Model (simplified)
Food mapEdgeFunctionResponseToFood(Map<String, dynamic> response) {
  return Food(
    id: 'barcode_${response['barcode']}',
    name: response['product_name'] ?? 'Unknown Product',
    imageAddress: response['image_address'], // Already processed by Edge Function
    carbsPerServing: response['carbohydrates_per_serving']?.toDouble(),
    sodiumMg: response['sodium_mg'],
    caloriesPerServing: response['calories_per_serving'],
    proteinPerServing: response['protein_per_serving']?.toDouble(),
    fatPerServing: response['fat_per_serving']?.toDouble(),
    // Use default values for endurance suitability flags
    beforeRunSuitable: false,  // Default: user can manually enable
    duringRunSuitable: false,  // Default: user can manually enable
    runPortable: false,        // Default: user can manually enable
    requiresPreparation: false,
    aidStationAvailable: false,
  );
}
```

### 5. Implementation Phases

**Phase 1: Core Scanning Infrastructure (Week 1-2)**
- [ ] Add `mobile_scanner` dependency
- [ ] Create `BarcodeScannerScreen` with basic camera functionality
- [ ] Implement navigation from `SwapFoodScreen` to scanner
- [ ] Add barcode format validation
- [ ] Create basic UI with scanner overlay and controls

**Phase 2: Edge Function Integration (Week 2-3)**
- [ ] Create Supabase Edge Function for barcode lookup (`barcode-lookup`)
- [ ] Implement Open Food Facts API integration server-side
- [ ] Add USDA FoodData Central fallback server-side
- [ ] Create `SupabaseBarcodeService` for Edge Function communication
- [ ] Implement Edge Function response mapping to `Food` domain model
- [ ] Add comprehensive error handling and retry logic

**Phase 3: User Experience & Integration (Week 3-4)**
- [ ] Create product confirmation screen with nutritional preview
- [ ] Implement serving size adjustment controls
- [ ] Add manual entry dialog for missing products
- [ ] Integrate with existing food swap/add functionality
- [ ] Add loading states and user feedback


### 6. Technical Considerations

**Platform-Specific Requirements:**
- **Android**: Minimum SDK 21, camera permissions in manifest
- **iOS**: Camera usage description in Info.plist, iOS 12+ support
- **Permissions**: Runtime camera permission handling with graceful fallbacks

**Performance Optimizations:**
- **Camera Lifecycle**: Proper start/stop management to preserve battery
- **Edge Function Optimization**: Server-side caching and request deduplication
- **Image Processing**: Server-side image downloads and S3 bucket caching
- **Memory Management**: Dispose camera resources properly in controller
- **API Rate Limiting**: Server-side management within Edge Function

**Offline Support:**
- Cache frequently scanned sports nutrition products locally
- Store barcode → food ID mappings for offline lookup
- Graceful degradation when Edge Function is unavailable
- Server-side caching reduces dependency on external APIs

### 7. Sports Nutrition Focus Areas

**Target Product Categories:**
- Energy gels (Maurten, Gu, Clif, etc.)
- Sports drinks and electrolyte supplements
- Energy bars and chews
- Recovery products and protein supplements
- Endurance-specific nutrition brands

**Endurance-Specific Data Enhancement:**
- Use default values for `beforeRunSuitable`, `duringRunSuitable` (users can manually adjust)
- Set conservative defaults for `maxServingsBefore` and `maxServingsDuring`
- Use default `runPortable = false` (users can enable as needed)
- Focus on accurate nutritional data extraction (carbs, sodium, fluids)
- Server-side product categorization for better data quality

### 8. Future Enhancement Opportunities

**Advanced Features (Post-MVP):**
- **Batch Scanning**: Scan multiple products for meal prep planning
- **Nutrition Label OCR**: Extract nutrition facts from product images when barcodes fail
- **Smart Recommendations**: Suggest similar products based on scanning history
- **Inventory Management**: Track personal sports nutrition inventory
- **Price Comparison**: Integrate with affiliate marketing for product purchasing

**Edge Function Enhancements:**
- Add Edamam API integration for premium sports nutrition database access
- Integrate with Spoonacular for recipe and meal planning enhancement
- Connect with brand-specific APIs (e.g., Maurten, Gu) for official product data
- Implement AI-powered nutritional data validation and correction
- Add server-side machine learning for product categorization

## Success Metrics

**Technical Metrics:**
- Barcode scanning success rate > 85%
- Edge Function response time < 3 seconds for product lookup
- Server-side API success rate > 90% (Open Food Facts + USDA combined)
- Product image processing and S3 caching success rate > 90%
- Zero critical crashes related to camera functionality
- Edge Function uptime > 99.5%

**User Experience Metrics:**
- Time from barcode scan to food addition < 10 seconds
- User adoption rate of barcode scanning vs manual search
- Product confirmation rate (users proceeding after scanning)
- Reduction in manual food entry errors

**Business Metrics:**
- Increased engagement with sports nutrition products
- Enhanced user retention through improved UX
- Foundation for affiliate marketing integration
- Competitive differentiation in endurance nutrition space

## Risk Mitigation

**Technical Risks:**
- **Camera Permission Denial**: Graceful fallback to manual search with clear messaging
- **Poor Scanning Conditions**: Provide user guidance for optimal scanning (lighting, distance)
- **Edge Function Failures**: Comprehensive error handling and fallback to manual entry
- **Network Connectivity**: Offline barcode caching for common products
- **API Rate Limiting**: Server-side management prevents client-side impact
- **External API Downtime**: Sequential fallback strategy within Edge Function

**Business Risks:**
- **Incomplete Product Database**: Manual entry option preserves user workflow
- **API Cost Escalation**: Start with free APIs, server-side optimization reduces costs
- **User Adoption**: Prominent placement and clear value proposition
- **Maintenance Overhead**: Comprehensive error logging and monitoring
- **Edge Function Costs**: Monitor and optimize based on usage patterns

## Conclusion

This roadmap provides a comprehensive plan for implementing barcode scanning functionality that aligns with Mealvana Endurance's focus on sports nutrition and the existing Feature-Oriented Architecture. The phased approach ensures stable, incremental delivery while maintaining the app's high-quality user experience and technical standards.

The implementation leverages proven technologies (`mobile_scanner`), reliable free APIs (Open Food Facts, USDA) managed through Supabase Edge Functions, and integrates seamlessly with the existing food management system. The server-side architecture provides better performance, security, and maintainability while supporting both immediate user value and future enhancement opportunities in the competitive endurance nutrition market.

## Additional Technical Notes

### Supabase Edge Function Structure

The barcode lookup Edge Function (`/supabase/functions/barcode-lookup/index.ts`) will handle:

1. **Input Validation**: Validate barcode format and sanitize input
2. **API Sequencing**: Try Open Food Facts → USDA → return structured error
3. **Data Normalization**: Convert different API responses to consistent format
4. **Image Processing**: Download product images and upload to S3 bucket
5. **Caching**: Server-side Redis caching for frequently requested barcodes
6. **Error Handling**: Comprehensive logging and graceful degradation
7. **Response Formatting**: Return standardized food data matching Flutter expectations

### Flutter Integration Points

- **Single Service**: `SupabaseBarcodeService` handles all Edge Function communication
- **Simple Interface**: `lookupBarcode(String barcode) -> Food?`
- **Default Values**: All endurance suitability flags set to conservative defaults
- **Error Handling**: Clear user feedback for all failure scenarios
- **Offline Support**: Local cache of successful lookups for offline access