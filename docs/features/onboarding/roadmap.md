# Onboarding Enhancement Roadmap

## Overview
This roadmap outlines the implementation plan for enhancing the onboarding screen with expanded food options, barcode scanning integration, and improved database synchronization for user-created foods.

## Current State Analysis

### Existing Implementation
- **Onboarding Screen**: Shows curated foods where `show_in_preferences = true`
- **Food Preferences**: Three-tier system (Love, Willing to Try, Avoid)
- **Barcode Scanning**: Fully functional in swap_food_screen with Open Food Facts integration
- **Database Schema**: Already has `user_foods`, `user_food_categories`, and `user_hidden_foods` tables
- **Edge Functions**: `save-food-preferences` handles preference saving but needs updates

### Key Findings
1. **show_in_preferences field**: Already exists in foods table and filters onboarding display
2. **Barcode scanning**: Complete implementation exists but not integrated into onboarding
3. **Beverage handling**: Database supports `fluid_ml_per_serving` but barcode scanner doesn't extract it
4. **User foods**: Full schema exists for custom/scanned foods with category associations
5. **Save preferences**: Edge function needs updates to handle user_foods and user_hidden_foods

## Implementation Roadmap

### Phase 1: Show More Food Options Widget

#### 1.1 Add Expandable Section to Onboarding Screen
**Location**: `lib/features/onboarding/presentation/screens/food_preferences_screen.dart`

**Tasks**:
1. Create `ExpandableMoreOptionsWidget` component with:
   - Collapsed state: "Show more food options" with chevron down icon
   - Expanded state: List of foods where `show_in_preferences = false`
   - Default all expanded foods to "Avoid" preference
2. Update `FoodRepository.getFoodsForPreferences()` to return two lists:
   - Primary foods (`show_in_preferences = true`) - default to "Willing to Try"
   - Additional foods (`show_in_preferences = false`) - default to "Avoid"
3. Track expanded/collapsed state in local UI state
4. Integrate with existing preference selection logic

#### 1.2 Database Query Updates
**Location**: `lib/features/nutrition_plan/data/food_repository.dart`

**New Methods Needed**:
```dart
Future<List<Food>> getPrimaryFoodsForPreferences() // show_in_preferences = true
Future<List<Food>> getAdditionalFoodsForPreferences() // show_in_preferences = false
```

### Phase 2: Barcode Scanning Integration

#### 2.1 Add Scan Button to Onboarding
**Location**: `lib/features/onboarding/presentation/screens/food_preferences_screen.dart`

**Tasks**:
1. Add "Scan product barcode" button below the expandable section
2. Navigate to barcode scanner with onboarding context
3. Handle scanned product return with category selection dialog

#### 2.2 Create Full-Screen Category Selection Bottom Sheet (Shared Component)
**Location**: `lib/shared/widgets/scanned_food_category_sheet.dart`

**Purpose**: Shared component used by both onboarding and swap food screens

**Features**:
1. Full-screen bottom modal sheet (not regular modal)
2. Show scanned product details (name, image, nutrition) at top
3. Add editable "Fluid Amount (ml)" field for beverages (auto-populated)
4. Phase selection with checkboxes (all checked by default):
   - ✅ Before Run (category_id: 1)
   - ✅ During Run (category_id: 2)
   - ✅ After Run (category_id: 3)
5. Require at least one category selected (validation)
6. Context-aware button text:
   - Onboarding: "Add to My Foods"
   - Swap Food: "Add to Plan"
7. Handle duplicate barcode detection with "You already scanned this product" message

#### 2.3 Update Swap Food Screen Integration
**Location**: `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart`

**Updates Needed**:
1. Replace existing barcode result handling with new category selection sheet
2. Update navigation to use shared `scanned_food_category_sheet`
3. Handle beverage fluid amount in food selection
4. Maintain existing quantity adjustment functionality

#### 2.4 Enhance Barcode Scanner Service for Beverages
**Location**: `lib/features/barcode_scanning/application/barcode_scanner_service.dart`

**Beverage Detection Strategy** (from sports_drink.txt analysis):
1. **Primary Field**: `serving_quantity` + `serving_quantity_unit`
   - Example: `"serving_quantity": 1000, "serving_quantity_unit": "ml"`
2. **Backup Field**: `product_quantity` + `product_quantity_unit`
   - Example: `"product_quantity": 330, "product_quantity_unit": "ml"`
3. **Category Detection**: Check `categories` field for "beverages" (case-insensitive)
   - Example: `"categories": "Beverages and beverages preparations,Beverages,Waters"`

**Implementation**:
```dart
// Extract fluid content for beverages
if (apiResponse.categories?.toLowerCase().contains('beverage') == true) {
  final fluidAmount = apiResponse.serving_quantity ?? apiResponse.product_quantity;
  final fluidUnit = apiResponse.serving_quantity_unit ?? apiResponse.product_quantity_unit;

  if (fluidUnit?.toLowerCase() == 'ml' && fluidAmount != null) {
    fluidMlPerServing = fluidAmount.toDouble();
  }
}
```

### Phase 3: Database Integration & Scanned Foods Display

#### 3.1 Save Scanned Foods with Immediate Sync
**Location**: `lib/features/onboarding/application/onboarding_service.dart`

**New Method**:
```dart
Future<void> saveScannedFood({
  required String deviceId,
  required Food scannedFood,
  required List<int> categoryIds,
  required double? fluidMlPerServing,
}) async {
  // 1. Check for duplicate barcode first
  // 2. Save to local Drift database
  // 3. Sync to Supabase immediately
  // 4. Show error with retry option if sync fails
}
```

**Database Operations**:
1. **Duplicate Check**: Query existing `user_foods` by barcode
2. **Local Save**: Insert into Drift `user_foods` table:
   - Auto-generated UUID
   - Device ID from current user
   - Nutritional data + fluid amount from scanned product
   - `client_food_id` for offline sync
3. **Category Links**: Insert into `user_food_categories` for selected phases
4. **Immediate Sync**: Call Supabase edge function to sync data
5. **Error Handling**: Show user-friendly error with retry option

#### 3.2 Display Scanned Foods in Onboarding List
**Location**: `lib/features/onboarding/presentation/screens/food_preferences_screen.dart`

**UI Updates**:
1. **Scanned Foods Section**: Show at top of main list, visually distinguished
2. **Default Preference**: Set to "Willing to Try" automatically
3. **Trash Icon**: Add delete button for scanned foods only
4. **Complete Deletion**: Remove from both Drift and Supabase (not soft delete)
5. **Visual Design**: Different background/border to distinguish from generic foods

#### 3.3 Handle Avoided Foods (Simplified)
**Location**: `lib/features/onboarding/application/onboarding_service.dart`

**Logic**:
1. Foods marked as "Avoid" in expanded section → simply save as "Avoid" preference
2. No need to use `user_hidden_foods` table - just regular preference handling
3. Nutrition plan generation already respects "Avoid" preferences

### Phase 4: Edge Functions Updates

#### 4.1 Create New save-user-food Function
**Location**: `supabase/functions/save-user-food/index.ts`

**Purpose**: Handle immediate sync of individual scanned foods

**Request Interface**:
```typescript
interface SaveUserFoodRequest {
  device_id: string;
  user_food: {
    id: string;
    client_food_id: string;
    barcode?: string;
    name: string;
    display_name?: string;
    nutritional_data: NutritionalData;
    fluid_ml_per_serving?: number;
  };
  category_ids: number[]; // Selected phases
}
```

**Operations**:
1. Validate device_id exists in users table
2. Check for duplicate barcode in user_foods
3. Insert into user_foods table
4. Insert category associations into user_food_categories
5. Return success with saved food data

#### 4.2 Create delete-user-food Function
**Location**: `supabase/functions/delete-user-food/index.ts`

**Purpose**: Complete deletion of scanned foods during onboarding

**Request Interface**:
```typescript
interface DeleteUserFoodRequest {
  device_id: string;
  user_food_id: string;
}
```

**Operations**:
1. Validate ownership (device_id matches)
2. Delete from user_food_categories table
3. Delete from user_foods table completely
4. Return success confirmation

#### 4.3 save-food-preferences Function (No Changes Needed)
**Location**: `supabase/functions/save-food-preferences/index.ts`

**Status**: ✅ **No modifications required**
- Current function already handles all preference types including "Avoid"
- "Avoid" foods are processed as regular preferences (no hidden_foods table needed)
- Existing logic is sufficient for expanded options functionality

### Phase 4: Final Integration & Polish

#### 4.4 Swap Food Screen Updates
**Location**: `lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart`

**Updates Needed**:
1. Handle scanned foods with category data in controller logic
2. Process beverage fluid amounts in food selection
3. Update food display to include fluid information when available
4. Maintain existing quantity adjustment functionality

#### 4.5 UI/UX Polish
1. Smooth animations for expandable section in onboarding
2. Loading states for barcode scanning in both screens
3. Success feedback for saved preferences and scanned foods
4. Error handling with user-friendly messages and retry options

## Decisions Made

### User Requirements Clarified

1. **Food Preference Defaults**:
   - ✅ Main foods (show_in_preferences=true): Default to "Willing to Try"
   - ✅ Expanded foods (show_in_preferences=false): Default to "Avoid"

2. **Scanned Foods Display**:
   - ✅ Mixed in main list but visually distinguished at the top
   - ✅ Default to "Willing to Try" preference
   - ✅ Show in special "scanned items" section

3. **Category Selection UI**:
   - ✅ Full-screen bottom modal sheet (not regular modal)
   - ✅ Allow multiple category selection
   - ✅ Default to all three categories checked
   - ✅ Require at least one category selected

4. **Scanned Food Management**:
   - ✅ Trash icon on scanned foods only
   - ✅ Delete completely from both Drift and Supabase (not soft delete)
   - ✅ Hide immediately when deleted

5. **Duplicate Barcode Handling**:
   - ✅ Check for existing barcodes in user_foods
   - ✅ Show "You already scanned this product" message
   - ✅ Prevent duplicate saves

6. **Beverage Fluid Amount**:
   - ✅ Add editable "Fluid Amount (ml)" field to verification dialog
   - ✅ Auto-populate from API using straightforward extraction
   - ✅ Allow user editing if needed

7. **Sync Strategy**:
   - ✅ Immediate sync after each scanned food
   - ✅ Show user errors with retry option
   - ✅ Don't batch - sync individually for better reliability

8. **UI Layout**:
   - ✅ "Show more food options" starts collapsed
   - ✅ ~8 additional foods in expanded section
   - ✅ All remaining foods (show_in_preferences=false)

9. **Database Tables**:
   - ✅ Use `users` table (not user_profiles) for foreign keys
   - ✅ No existing users to migrate

## Implementation Timeline

### Phase 1: Show More Food Options (Week 1)
- Update `FoodRepository` with dual food queries
- Create `ExpandableMoreOptionsWidget`
- Integrate with existing preference logic
- **Estimate**: 2-3 days

### Phase 2: Shared Barcode Scanning Enhancement (Week 1-2)
- Create shared full-screen category selection bottom sheet
- Add scan button to onboarding screen
- Update swap food screen to use new category sheet
- Enhance barcode service for beverage detection
- **Estimate**: 4-5 days

### Phase 3: Database Integration (Week 2)
- Implement scanned food display with trash icons in onboarding
- Add immediate sync functionality
- Handle duplicate detection and deletion
- Update swap food controller for beverage handling
- **Estimate**: 3-4 days

### Phase 4: Edge Functions & Polish (Week 2)
- Create `save-user-food` edge function
- Create `delete-user-food` edge function
- UI/UX polish and error handling
- **Estimate**: 2-3 days

**Total Estimated Timeline**: 2 weeks

## Risk Assessment

### Technical Risks
- **Database Migration**: Need careful testing of schema changes
- **Edge Function Updates**: Must maintain backwards compatibility
- **Offline Sync**: Complex edge cases with user_foods synchronization

### UX Risks
- **Overwhelming Options**: Too many foods might confuse users
- **Barcode Scanner Friction**: Additional step might reduce completion rates
- **Default Preferences**: Wrong defaults could lead to poor recommendations

### Mitigation Strategies
- Implement feature flags for gradual rollout
- A/B test the expanded options UI
- Add analytics to track onboarding completion rates
- Provide clear user education about scanning benefits

## Success Metrics

1. **Onboarding Completion Rate**: Should maintain or improve current rate
2. **Foods Per User**: Average number of preferences set per user
3. **Scanned Foods Adoption**: Percentage of users who scan at least one product
4. **Preference Quality**: Reduction in food swaps after plan generation
5. **User Satisfaction**: Feedback on food variety and personalization

## Key Implementation Notes

### Beverage Detection Strategy
- **Primary**: Use `serving_quantity` + `serving_quantity_unit` from Open Food Facts API
- **Fallback**: Use `product_quantity` + `product_quantity_unit` if serving data unavailable
- **Detection**: Check `categories` field for "beverage" (case-insensitive)
- **UI**: Add editable "Fluid Amount (ml)" field in verification dialog

### Database Schema Requirements
All required tables already exist (no migration needed):
- ✅ `user_foods` - stores scanned food data
- ✅ `user_food_categories` - links foods to phases (1=before, 2=during, 3=after)
- ✅ `foods` - existing foods table with `show_in_preferences` field
- ✅ `food_preferences` - existing table for user preferences (handles "Avoid")

### New Edge Functions Required
1. **save-user-food**: Individual scanned food sync with immediate response
2. **delete-user-food**: Complete deletion (not soft delete) of scanned foods
3. **save-food-preferences**: ✅ No changes needed (already handles "Avoid" preferences)

### UI Flow Summary
#### Onboarding Flow:
1. **Onboarding Screen**: Shows main foods + collapsed "Show more options"
2. **Scan Button**: Navigate to barcode scanner
3. **Category Selection**: Shared full-screen bottom sheet with all phases checked
4. **Scanned Foods**: Appear at top of onboarding list with trash icons
5. **Immediate Feedback**: Sync happens right after scanning with error retry

#### Swap Food Flow:
1. **Swap Food Screen**: Existing scan button functionality
2. **Enhanced Scanner**: Same beverage detection + fluid extraction
3. **Category Selection**: Same shared full-screen bottom sheet
4. **Food Selection**: Enhanced to handle fluid amounts and category data
5. **Plan Integration**: Maintains existing quantity adjustment logic

---

*Last Updated: 2025-09-24 - All user requirements clarified and implementation plan finalized*