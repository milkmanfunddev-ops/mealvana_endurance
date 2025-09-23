# Carb Loading Feature - Simplified Rebuild

## 🎯 **Overview**

Complete rebuild of the carb loading feature to match the simplified design shown in the screenshots. This moves from a complex nutrition planning system to a simple, user-friendly food tracking interface focused exclusively on carbohydrate management.

## 📱 **New Design Goals**

Based on the screenshots and carb_load_guide.pdf:

### **UI Simplification**
- **Carbs Only**: Remove protein and fat tracking - show only carbohydrates
- **Blue Header Card**: Race info with countdown and carb target (e.g., "11.0g carbs/kg target")
- **Simple 3-Tab System**: Day -2 (Begin), Day -1 (Peak), Race Day (Fuel)
- **Quick Add Interface**: "+50g carbs each" with curated food buttons
- **Interactive Food Pills**: Blue pills showing selected foods with quantities and +/- buttons
- **Clean Calorie Display**: Total calories per meal section (e.g., "1220 cal")

### **Functionality Focus**
- **50g Increment System**: All foods provide exactly 50g carbs each
- **Curated Food List**: 18 specific foods from Featherstone Nutrition guide
- **Simple Math**: Daily target ÷ 50g = number of servings needed
- **Real-time Updates**: Add/remove foods, see carb totals update instantly

## 📊 **Updated Calculation Engine**

### **Formula (from PDF)**
- **Base Formula**: 8g carbs/kg body weight per day
- **Duration**: 2.5-3 days before marathon
- **Weight Ranges**: Pre-calculated daily targets based on user weight

### **Daily Carb Targets**
```
110-120 lbs → 400g carbs/day (8 servings of 50g)
120-130 lbs → 450g carbs/day (9 servings of 50g)
130-145 lbs → 500g carbs/day (10 servings of 50g)
145-160 lbs → 550g carbs/day (11 servings of 50g)
160-170 lbs → 600g carbs/day (12 servings of 50g)
170-180 lbs → 650g carbs/day (13 servings of 50g)
180-190 lbs → 700g carbs/day (14 servings of 50g)
200+ lbs → 750g carbs/day (15 servings of 50g)
```

## 🍎 **50g Carb Food List**

From carb_load_guide.pdf - each provides exactly 50g carbohydrates:

### **Grains & Starches**
- Bagel (1 large)
- Bread (2 slices large)
- Pasta (1 heaping cup cooked)
- Rice (1 cup cooked)
- Oats (1 cup dry)
- Cereal (1.5-2 cups dry)
- Baked potato (1 large)

### **Snacks & Treats**
- Pretzels (2 servings)
- Graham crackers (4 crackers)
- Skittles/candy (2 servings)

### **Fruits & Natural**
- Bananas (2 whole)
- Pineapple (2 cups)
- Applesauce (1 cup sweetened)
- Raisins (1/2 cup)

### **Liquids & Sweeteners**
- Sports drink (2 scoops Skratch)
- Juice/lemonade (16 oz)
- Honey (3 Tbsp)
- Maple syrup (1/4 cup)

## 🏗️ **New Architecture**

### **Simplified Data Model**

```dart
class CarbLoadingPlan {
  final String id;
  final String userId;
  final DateTime raceDate;
  final int dailyCarbTargetG;        // e.g., 500g
  final int dailyServingsTarget;     // e.g., 10 servings
  final Map<int, DayFoodSelections> daySelections; // Day -2, -1, 0
}

class DayFoodSelections {
  final Map<String, MealFoods> meals; // breakfast, lunch, snack1, etc.
}

class MealFoods {
  final Map<String, int> selectedFoods; // {"Bagel": 2, "Bananas": 1}
  int get totalCarbs => selectedFoods.values.fold(0, (sum, qty) => sum + (qty * 50));
  int get totalCalories => totalCarbs * 4; // Simple 4 cal/g carb estimate
}
```

### **Replaced Components**

**Remove Complex Widgets:**
- ❌ `CarbLoadingMacroCard` (protein/fat tracking)
- ❌ `CarbLoadingMealList` (detailed meal breakdowns)
- ❌ `CarbLoadingDayContent` (complex day view)
- ❌ Complex plan view controller with nutrition details toggles

**New Simplified Widgets:**
- ✅ `CarbLoadingHeaderCard` (blue card with race info + countdown)
- ✅ `CarbLoadingDayTabs` (simplified 3-tab system)
- ✅ `CarbLoadingMealSection` (breakfast, lunch, etc. with calorie totals)
- ✅ `QuickAddFoodButtons` (curated 50g food list)
- ✅ `SelectedFoodPills` (blue pills with +/- quantity controls)
- ✅ `CarbProgressIndicator` (daily progress toward target)

### **Controller Simplification**

```dart
@riverpod
class CarbLoadingController extends _$CarbLoadingController {
  @override
  FutureOr<CarbLoadingState> build() async {
    // Load existing plan or create default based on user weight
    final user = await _userRepository.getCurrentUser();
    final plan = await _repository.getCurrentPlan(user.id) ??
                  _createDefaultPlan(user);

    return CarbLoadingState(
      plan: plan,
      selectedDay: -1,
      selectedMeal: 'breakfast',
    );
  }

  // Simple actions
  Future<void> selectDay(int day) async { ... }
  Future<void> selectMeal(String meal) async { ... }
  Future<void> addFood(String foodName) async { ... }
  Future<void> removeFood(String foodName) async { ... }
  Future<void> updateFoodQuantity(String foodName, int quantity) async { ... }
}
```

## 🎨 **UI Implementation Plan**

### **1. Blue Header Card**
```dart
// Matches screenshot design exactly
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(/* blue gradient */),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Column(
    children: [
      // "Marathon" + race date
      Text(plan.raceDistance.displayName),
      Text(DateFormat('MMM d, yyyy').format(plan.raceDate)),

      // Countdown
      Text('${daysUntilRace} days'),

      // Carb target
      Text('${plan.carbsPerKgTarget}g carbs/kg target'),

      // Status message
      Text('Carb loading starts in ${daysUntilStart} days'),
    ],
  ),
)
```

### **2. Simplified Day Tabs**
```dart
// Three simple tabs matching screenshot
Row(
  children: [
    _DayTab('Day -2', 'Begin', isSelected: selectedDay == -2),
    _DayTab('Day -1', 'Peak', isSelected: selectedDay == -1),
    _DayTab('Race Day', 'Fuel', isSelected: selectedDay == 0),
  ],
)
```

### **3. Meal Sections with Quick Add**
```dart
// Each meal section (Breakfast, Lunch, etc.)
Column(
  children: [
    // Header with calories
    Row(
      children: [
        Text('Breakfast'),
        Spacer(),
        Container(
          child: Text('${meal.totalCalories} cal'),
        ),
      ],
    ),

    // Large carb number
    Text('${meal.totalCarbs}g', style: largeNumberStyle),
    Text('Carbs', style: labelStyle),

    // Quick Add section
    Text('Quick Add (+50g carbs each):'),
    Wrap(
      children: availableFoods.map((food) =>
        _FoodButton(food, onTap: () => addFood(food))
      ).toList(),
    ),

    // Selected foods as blue pills
    if (meal.selectedFoods.isNotEmpty)
      _SelectedFoodPills(meal.selectedFoods),
  ],
)
```

### **4. Interactive Food Pills**
```dart
// Blue pills with quantities and +/- buttons (from screenshot)
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(icon: Icon(Icons.remove), onPressed: decrementFood),
      Text('$foodName x $quantity'),
      IconButton(icon: Icon(Icons.add), onPressed: incrementFood),
    ],
  ),
)
```

## 📋 **Implementation Phases**

### **Phase 1: Data Model & Repository (1-2 days)**
1. ✅ Create simplified `CarbLoadingPlan` model (carbs only)
2. ✅ Update database schema to store food selections per meal/day
3. ✅ Implement new repository methods for simple CRUD operations
4. ✅ Create curated food list as static data (18 items from PDF)

### **Phase 2: Core Controller Logic (1-2 days)**
1. ✅ Build simplified `CarbLoadingController` with carb-only tracking
2. ✅ Implement calculation engine using PDF formulas (8g/kg)
3. ✅ Add food selection/quantity management methods
4. ✅ Integrate with ContentService for all UI text

### **Phase 3: UI Rebuild (2-3 days)**
1. ✅ Create blue header card matching screenshot design exactly
2. ✅ Build simplified day tabs (Day -2/Begin, Day -1/Peak, Race Day/Fuel)
3. ✅ Implement meal sections with calorie headers and large carb numbers
4. ✅ Add "Quick Add" food buttons using curated 50g list
5. ✅ Create interactive blue food pills with +/- quantity controls

### **Phase 4: Integration & Polish (1-2 days)**
1. ✅ Replace existing carb loading screen completely
2. ✅ Update navigation to use new simplified screen
3. ✅ Add ContentService keys for all dynamic text
4. ✅ Test complete user flow and edge cases
5. ✅ Polish animations and visual details to match screenshots

## 🎯 **Success Criteria**

### **Functional Requirements**
- ✅ User can select race date and get appropriate daily carb targets
- ✅ Quick Add interface allows selecting from 18 curated 50g foods
- ✅ Interactive food pills show quantities with +/- controls
- ✅ Real-time carb totals update as foods are added/removed
- ✅ Clean design matches screenshots exactly (blue header, simple tabs)
- ✅ All UI text managed via ContentService for dynamic updates

### **Technical Requirements**
- ✅ Maintains existing FOA architecture patterns
- ✅ Uses AsyncNotifier controllers with proper error handling
- ✅ Carb calculations use Featherstone guide formulas (8g/kg)
- ✅ Simple data model focused on carb tracking only
- ✅ No protein/fat tracking or complex nutrition displays

### **User Experience**
- ✅ Dramatically simplified from complex nutrition planning to simple food tracking
- ✅ Focuses exclusively on carbohydrate management for race preparation
- ✅ Intuitive 50g increment system makes portions easy to understand
- ✅ Visual design matches provided screenshots with blue theme and clean layout

## 📝 **Content Management Integration**

### **New ContentService Keys**
```json
{
  "carb_loading": {
    "header_title": "Marathon",
    "carb_target_label": "carbs/kg target",
    "countdown_days": "days",
    "loading_starts": "Carb loading starts in {days} days",
    "loading_active": "Carb loading in progress",
    "day_begin": "Begin",
    "day_peak": "Peak",
    "day_fuel": "Fuel",
    "quick_add_title": "Quick Add (+50g carbs each):",
    "added_carbs": "Added: +{amount}g carbs",
    "meal_breakfast": "Breakfast",
    "meal_lunch": "Lunch",
    "meal_snack": "Snack",
    "meal_dinner": "Dinner"
  }
}
```

## 🔄 **Migration Strategy**

### **No Data Migration Required**
- User explicitly stated not to worry about migrations
- Existing complex carb loading data will be ignored
- New simplified system starts fresh for all users
- Old database tables can remain but won't be used

### **Feature Flag Approach**
- Replace carb loading screen entirely in single deployment
- No gradual rollout needed - complete replacement
- Remove old complex widgets and controllers
- Keep calculation service but simplify to carbs-only logic

---

**This rebuild transforms carb loading from a complex nutrition planning tool into a simple, user-friendly carbohydrate tracking interface that exactly matches the provided screenshots while leveraging the proven Featherstone Nutrition methodology.**