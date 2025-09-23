# Carb Loading Feature Implementation Roadmap

## Overview

This roadmap outlines the implementation of a carb loading calculator feature as a **third tab** in the Mealvana Endurance app. The feature will provide personalized carb loading targets for endurance athletes based on body weight, race distance, and training volume, following the UI design shown in the mockup.

## 📋 **Scope Definition**

### **✅ In Scope**
- Third tab in bottom navigation (between Workout Notes and Settings)
- Simple race date picker with local storage
- Carb loading calculations based on formulas from requirements
- Day-by-day macro breakdown (Day -2, Day -1, Day 0) matching mockup design
- Local storage only (Drift database)
- Single carb loading plan at a time
- ContentService integration for dynamic text
- Follow exact mockup UI design

### **❌ Out of Scope**
- Food recommendations and shopping lists
- Integration with existing nutrition plan system
- Supabase sync for carb loading data
- Notification reminders
- Training platform connections
- Complex race management
- Multiple carb loading plans
- Testing implementation

## 🏗️ **Architecture Overview**

### **Feature-Oriented Architecture (FOA) Structure**
```
lib/features/carb_loading/
├── presentation/
│   ├── controllers/
│   │   └── carb_loading_controller.dart        # AsyncNotifier with ContentService
│   ├── screens/
│   │   └── carb_loading_screen.dart           # Main tab screen
│   └── widgets/
│       ├── carb_loading_day_tabs.dart         # Day -2, -1, 0 tab selector
│       ├── loading_phase_card.dart            # Main content card
│       ├── macro_breakdown_display.dart       # Carbs/Protein/Fat/Calories
│       └── race_date_picker_widget.dart       # Race date selection
├── application/
│   └── carb_loading_service.dart              # Business logic calculations
├── domain/
│   ├── carb_loading_plan.dart                 # Data model
│   ├── race_info.dart                         # Race date/distance model
│   └── carb_loading_enums.dart               # Enums for race distances, training levels
└── data/
    └── carb_loading_repository.dart           # Local Drift storage
```

## 📊 **Database Schema Changes**

### **1. Add Carb Loading Table to Drift**

**File**: `lib/shared/database/tables/carb_loading_table.dart`

```dart
@DataClassName('CarbLoadingEntry')
class CarbLoadingTable extends Table {
  TextColumn get id => text()();                    // UUID (PK)
  TextColumn get userId => text()();                // References user_profiles.id

  // Race Information
  DateTimeColumn get raceDate => dateTime()();
  TextColumn get raceDistance => text()();          // half_marathon, marathon, 50k, etc.
  TextColumn get trainingVolume => text()();        // low, moderate, high

  // Calculated Targets (JSON format)
  TextColumn get planData => text()();              // Full plan JSON

  // Metadata
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
```

### **2. Update AppDatabase**

**File**: `lib/shared/database/app_database.dart`

```dart
@DriftDatabase(tables: [
  // Existing tables...
  CarbLoadingTable,  // Add this
])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 7; // Increment from current version 6

  // Add migration method
  Future<void> _migrateV6ToV7(Migrator m, Schema6 schema) async {
    await m.createTable(carbLoadingTable);
    logger.info('Migration V6→V7: Added carb_loading table');
  }
}
```

### **3. Update Migration Strategy**

Add to existing migration strategy in `AppDatabase`:
```dart
onUpgrade: stepByStep(
  // Existing migrations...
  from6To7: (m, schema) async {
    await _migrateV6ToV7(m, schema);
  },
),
```

## 🎨 **UI Implementation**

### **1. Update Tabs Screen**

**File**: `lib/shared/widgets/tabs_screen.dart`

```dart
List<Widget> get _screens => [
  const CurrentPlanScreen(),
  const VoiceMemoScreen(),
  const CarbLoadingScreen(),      // Add as 3rd tab
  const SettingsScreen(),
];

List<BottomNavigationBarItem> get _tabs => [
  // Existing Plan tab...
  // Existing Workout Notes tab...
  BottomNavigationBarItem(            // Add new tab
    icon: Icon(Icons.bakery_dining, size: 24, color: Colors.grey),
    activeIcon: Icon(Icons.bakery_dining, size: 24, color: AppTheme.primary900),
    label: 'Carb Loading',
  ),
  // Existing Settings tab...
];
```

### **2. Main Screen Implementation**

**File**: `lib/features/carb_loading/presentation/screens/carb_loading_screen.dart`

```dart
class CarbLoadingScreen extends ConsumerWidget {
  const CarbLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(carbLoadingControllerProvider);

    // Listen for errors
    ref.listen<AsyncValue<CarbLoadingState>>(
      carbLoadingControllerProvider,
      (_, state) {
        if (!state.isLoading && state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error.toString())),
          );
        }
      },
    );

    return controllerState.when(
      data: (state) => _buildScreen(context, state, ref),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, CarbLoadingState state, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(state.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppTheme.baseGrey),
            onPressed: () {
              // Settings action if needed
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              state.subtitle,
              style: AppTheme.noteStyle.copyWith(color: AppTheme.baseGrey),
            ),
          ),
          const SizedBox(height: 16),

          // Day selector tabs
          CarbLoadingDayTabs(
            selectedDay: state.selectedDay,
            onDaySelected: (day) => ref.read(carbLoadingControllerProvider.notifier).selectDay(day),
          ),

          const SizedBox(height: 24),

          // Main content
          Expanded(
            child: state.currentPlan == null
              ? _buildEmptyState(context, state, ref)
              : _buildPlanView(context, state, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CarbLoadingState state, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(state.emptyStateMessage, style: AppTheme.textStyle),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(carbLoadingControllerProvider.notifier).createNewPlan(),
            child: Text(state.createPlanButtonText),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanView(BuildContext context, CarbLoadingState state, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Loading phase card
          LoadingPhaseCard(
            day: state.selectedDay,
            plan: state.currentPlan!,
          ),
        ],
      ),
    );
  }
}
```

### **3. Day Tabs Widget**

**File**: `lib/features/carb_loading/presentation/widgets/carb_loading_day_tabs.dart`

```dart
class CarbLoadingDayTabs extends StatelessWidget {
  const CarbLoadingDayTabs({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final int selectedDay;
  final Function(int) onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppTheme.baseGrey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          _buildTab('Day -2', -2),
          _buildTab('Day -1', -1),
          _buildTab('Day 0', 0),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int day) {
    final isSelected = selectedDay == day;
    return Expanded(
      child: GestureDetector(
        onTap: () => onDaySelected(day),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.baseWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTheme.textStyle.copyWith(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppTheme.baseBlack : AppTheme.baseGrey,
            ),
          ),
        ),
      ),
    );
  }
}
```

### **4. Loading Phase Card**

**File**: `lib/features/carb_loading/presentation/widgets/loading_phase_card.dart`

```dart
class LoadingPhaseCard extends StatelessWidget {
  const LoadingPhaseCard({
    super.key,
    required this.day,
    required this.plan,
  });

  final int day;
  final CarbLoadingPlan plan;

  @override
  Widget build(BuildContext context) {
    final dayData = plan.getDayData(day);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [AppTheme.dropShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loading Phase',
                style: AppTheme.titleMedium.copyWith(color: AppTheme.baseBlack),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                decoration: BoxDecoration(
                  color: AppTheme.primary100,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Text(
                  'Today',
                  style: AppTheme.labelMedium.copyWith(color: AppTheme.primary600),
                ),
              ),
            ],
          ),

          Text(
            _getDayLabel(day),
            style: AppTheme.labelLarge.copyWith(color: AppTheme.baseGrey),
          ),

          const SizedBox(height: 24),

          // Macro breakdown
          MacroBreakdownDisplay(dayData: dayData),

          const SizedBox(height: 16),

          // Description
          Text(
            dayData.description,
            style: AppTheme.noteStyle.copyWith(color: AppTheme.baseGrey),
          ),

          const SizedBox(height: 16),

          // Weight note
          Text(
            plan.weightNote,
            style: AppTheme.labelSmall.copyWith(color: AppTheme.baseGrey),
          ),
        ],
      ),
    );
  }

  String _getDayLabel(int day) {
    switch (day) {
      case -2: return 'Day -2';
      case -1: return 'Day -1';
      case 0: return 'Day 0';
      default: return 'Day $day';
    }
  }
}
```

### **5. Macro Breakdown Display**

**File**: `lib/features/carb_loading/presentation/widgets/macro_breakdown_display.dart`

```dart
class MacroBreakdownDisplay extends StatelessWidget {
  const MacroBreakdownDisplay({
    super.key,
    required this.dayData,
  });

  final CarbLoadingDayData dayData;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildMacroRow('Carbohydrates', '${dayData.carbs.toInt()}g', AppTheme.carbsColor),
        const SizedBox(height: 12),
        _buildMacroRow('Protein', '${dayData.protein.toInt()}g', AppTheme.proteinColor),
        const SizedBox(height: 12),
        _buildMacroRow('Fat', '${dayData.fat.toInt()}g', AppTheme.fatsColor),
        const SizedBox(height: 16),
        Divider(color: AppTheme.baseGrey.withOpacity(0.3)),
        const SizedBox(height: 16),
        _buildMacroRow('Total Calories', '${dayData.totalCalories.toInt()}', AppTheme.caloriesColor, isLarge: true),
      ],
    );
  }

  Widget _buildMacroRow(String label, String value, Color color, {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isLarge
            ? AppTheme.titleMedium.copyWith(color: AppTheme.baseBlack)
            : AppTheme.bodyMedium.copyWith(color: AppTheme.baseBlack),
        ),
        Text(
          value,
          style: isLarge
            ? AppTheme.titleLarge.copyWith(color: color, fontWeight: FontWeight.bold)
            : AppTheme.titleMedium.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
```

## 💼 **Business Logic Implementation**

### **1. Domain Models**

**File**: `lib/features/carb_loading/domain/carb_loading_plan.dart`

```dart
class CarbLoadingPlan {
  final String id;
  final String userId;
  final DateTime raceDate;
  final RaceDistance raceDistance;
  final TrainingVolume trainingVolume;
  final double userWeightKg;
  final Map<int, CarbLoadingDayData> dayData; // -2, -1, 0
  final DateTime createdAt;
  final DateTime updatedAt;

  const CarbLoadingPlan({
    required this.id,
    required this.userId,
    required this.raceDate,
    required this.raceDistance,
    required this.trainingVolume,
    required this.userWeightKg,
    required this.dayData,
    required this.createdAt,
    required this.updatedAt,
  });

  CarbLoadingDayData getDayData(int day) => dayData[day]!;

  String get weightNote => 'Targets based on ${userWeightKg.toInt()}kg athlete. Adjust according to body weight and activity level.';

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'raceDate': raceDate.toIso8601String(),
    'raceDistance': raceDistance.toString(),
    'trainingVolume': trainingVolume.toString(),
    'userWeightKg': userWeightKg,
    'dayData': dayData.map((key, value) => MapEntry(key.toString(), value.toJson())),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory CarbLoadingPlan.fromJson(Map<String, dynamic> json) => CarbLoadingPlan(
    id: json['id'],
    userId: json['userId'],
    raceDate: DateTime.parse(json['raceDate']),
    raceDistance: RaceDistance.values.firstWhere((e) => e.toString() == json['raceDistance']),
    trainingVolume: TrainingVolume.values.firstWhere((e) => e.toString() == json['trainingVolume']),
    userWeightKg: json['userWeightKg'].toDouble(),
    dayData: (json['dayData'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(int.parse(key), CarbLoadingDayData.fromJson(value)),
    ),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
  );
}

class CarbLoadingDayData {
  final double carbs;
  final double protein;
  final double fat;
  final double totalCalories;
  final String description;

  const CarbLoadingDayData({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.totalCalories,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'carbs': carbs,
    'protein': protein,
    'fat': fat,
    'totalCalories': totalCalories,
    'description': description,
  };

  factory CarbLoadingDayData.fromJson(Map<String, dynamic> json) => CarbLoadingDayData(
    carbs: json['carbs'].toDouble(),
    protein: json['protein'].toDouble(),
    fat: json['fat'].toDouble(),
    totalCalories: json['totalCalories'].toDouble(),
    description: json['description'],
  );
}
```

**File**: `lib/features/carb_loading/domain/carb_loading_enums.dart`

```dart
enum RaceDistance {
  halfMarathon,
  marathon,
  ultra50k,
  ultra50m,
  ultra100k,
  ultra100m,
  custom;

  String get displayName {
    switch (this) {
      case RaceDistance.halfMarathon: return 'Half Marathon';
      case RaceDistance.marathon: return 'Marathon';
      case RaceDistance.ultra50k: return '50K Ultra';
      case RaceDistance.ultra50m: return '50 Mile Ultra';
      case RaceDistance.ultra100k: return '100K Ultra';
      case RaceDistance.ultra100m: return '100 Mile Ultra';
      case RaceDistance.custom: return 'Custom Distance';
    }
  }

  double get distanceMultiplier {
    switch (this) {
      case RaceDistance.halfMarathon: return 0.8;
      case RaceDistance.marathon: return 1.0;
      case RaceDistance.ultra50k:
      case RaceDistance.ultra100k: return 1.1;
      case RaceDistance.ultra50m:
      case RaceDistance.ultra100m: return 1.2;
      case RaceDistance.custom: return 1.0;
    }
  }
}

enum TrainingVolume {
  low,
  moderate,
  high;

  String get displayName {
    switch (this) {
      case TrainingVolume.low: return 'Low (<30 miles/week)';
      case TrainingVolume.moderate: return 'Moderate (30-50 miles/week)';
      case TrainingVolume.high: return 'High (>50 miles/week)';
    }
  }

  double get volumeMultiplier {
    switch (this) {
      case TrainingVolume.low: return 0.9;
      case TrainingVolume.moderate: return 1.0;
      case TrainingVolume.high: return 1.1;
    }
  }
}
```

### **2. Carb Loading Service**

**File**: `lib/features/carb_loading/application/carb_loading_service.dart`

```dart
class CarbLoadingService {
  CarbLoadingService(this.ref);
  final Ref ref;

  /// Calculate carb loading plan based on user data and race information
  CarbLoadingPlan calculatePlan({
    required String userId,
    required DateTime raceDate,
    required RaceDistance raceDistance,
    required TrainingVolume trainingVolume,
    required double userWeightKg,
  }) {
    final planId = const Uuid().v4();
    final now = DateTime.now();

    // Calculate daily targets using formulas from requirements
    final day2Data = _calculateDayData(-2, userWeightKg, raceDistance, trainingVolume);
    final day1Data = _calculateDayData(-1, userWeightKg, raceDistance, trainingVolume);
    final day0Data = _calculateDayData(0, userWeightKg, raceDistance, trainingVolume);

    return CarbLoadingPlan(
      id: planId,
      userId: userId,
      raceDate: raceDate,
      raceDistance: raceDistance,
      trainingVolume: trainingVolume,
      userWeightKg: userWeightKg,
      dayData: {
        -2: day2Data,
        -1: day1Data,
        0: day0Data,
      },
      createdAt: now,
      updatedAt: now,
    );
  }

  CarbLoadingDayData _calculateDayData(
    int dayOffset,
    double weightKg,
    RaceDistance raceDistance,
    TrainingVolume trainingVolume,
  ) {
    // Base carb targets (following FeatherStone methodology from requirements)
    double baseCarbsPerKg;
    switch (dayOffset) {
      case -2:
        baseCarbsPerKg = 8.0; // 8g/kg for Day -2
        break;
      case -1:
        baseCarbsPerKg = 9.0; // 9g/kg for Day -1
        break;
      case 0:
        baseCarbsPerKg = 10.0; // 10g/kg for Day 0
        break;
      default:
        baseCarbsPerKg = 8.0;
    }

    // Apply distance and training volume multipliers
    final distanceMultiplier = raceDistance.distanceMultiplier;
    final volumeMultiplier = trainingVolume.volumeMultiplier;

    final adjustedCarbsPerKg = baseCarbsPerKg * distanceMultiplier * volumeMultiplier;
    final totalCarbs = adjustedCarbsPerKg * weightKg;

    // Calculate other macros
    // Protein: ~1.5g/kg for endurance athletes
    final protein = weightKg * 1.5;

    // Fat: Fill remaining calories (targeting ~20-25% of total calories)
    final carbCalories = totalCarbs * 4;
    final proteinCalories = protein * 4;
    final targetTotalCalories = _calculateTargetCalories(weightKg, dayOffset);
    final fatCalories = targetTotalCalories - carbCalories - proteinCalories;
    final fat = fatCalories / 9; // 9 calories per gram of fat

    final description = _getDayDescription(dayOffset);

    return CarbLoadingDayData(
      carbs: totalCarbs,
      protein: protein,
      fat: fat.clamp(0, double.infinity), // Ensure non-negative
      totalCalories: targetTotalCalories,
      description: description,
    );
  }

  double _calculateTargetCalories(double weightKg, int dayOffset) {
    // Base metabolic rate estimate + activity
    // Simple estimate: ~35-40 calories per kg for active individuals
    final baseCalories = weightKg * 37;

    // Slightly higher calories on carb loading days
    final multiplier = dayOffset == 0 ? 1.15 : 1.1;

    return baseCalories * multiplier;
  }

  String _getDayDescription(int dayOffset) {
    switch (dayOffset) {
      case -2:
        return 'High carb intake, reduced protein and fat';
      case -1:
        return 'High carb intake, reduced protein and fat';
      case 0:
        return 'High carb intake, reduced protein and fat';
      default:
        return 'High carb intake, reduced protein and fat';
    }
  }
}

@riverpod
CarbLoadingService carbLoadingService(CarbLoadingServiceRef ref) {
  return CarbLoadingService(ref);
}
```

### **3. Repository Implementation**

**File**: `lib/features/carb_loading/data/carb_loading_repository.dart`

```dart
class CarbLoadingRepository {
  CarbLoadingRepository(this._database);
  final AppDatabase _database;

  /// Get current carb loading plan for user
  Future<CarbLoadingPlan?> getCurrentPlan(String userId) async {
    final entry = await (_database.select(_database.carbLoadingTable)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .getSingleOrNull();

    if (entry == null) return null;

    return CarbLoadingPlan.fromJson(jsonDecode(entry.planData));
  }

  /// Save carb loading plan
  Future<void> savePlan(CarbLoadingPlan plan) async {
    final entry = CarbLoadingTableCompanion.insert(
      id: plan.id,
      userId: plan.userId,
      raceDate: plan.raceDate,
      raceDistance: plan.raceDistance.name,
      trainingVolume: plan.trainingVolume.name,
      planData: jsonEncode(plan.toJson()),
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    );

    await _database.into(_database.carbLoadingTable).insertOnConflictUpdate(entry);
  }

  /// Delete current plan (set inactive)
  Future<void> deleteCurrentPlan(String userId) async {
    await (_database.update(_database.carbLoadingTable)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true)))
        .write(const CarbLoadingTableCompanion(
          isActive: Value(false),
          updatedAt: Value.ofFunction(currentDateAndTime),
        ));
  }

  /// Check if user has an active plan
  Future<bool> hasActivePlan(String userId) async {
    final count = await (_database.selectOnly(_database.carbLoadingTable)
          ..addColumns([_database.carbLoadingTable.id.count()])
          ..where(_database.carbLoadingTable.userId.equals(userId) &
                  _database.carbLoadingTable.isActive.equals(true)))
        .getSingle();

    return count.read(_database.carbLoadingTable.id.count()) ?? 0 > 0;
  }

  /// Watch for changes to current plan
  Stream<CarbLoadingPlan?> watchCurrentPlan(String userId) {
    return (_database.select(_database.carbLoadingTable)
          ..where((t) => t.userId.equals(userId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(1))
        .watchSingleOrNull()
        .map((entry) => entry == null
          ? null
          : CarbLoadingPlan.fromJson(jsonDecode(entry.planData)));
  }
}

@riverpod
CarbLoadingRepository carbLoadingRepository(CarbLoadingRepositoryRef ref) {
  final database = ref.watch(databaseProvider);
  return CarbLoadingRepository(database);
}
```

## 🎛️ **Controller Implementation**

### **File**: `lib/features/carb_loading/presentation/controllers/carb_loading_controller.dart`

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';
import '../../application/carb_loading_service.dart';
import '../../data/carb_loading_repository.dart';
import '../../domain/carb_loading_plan.dart';
import '../../domain/carb_loading_enums.dart';
import '../../../auth/data/user_repository.dart';

part 'carb_loading_controller.g.dart';

class CarbLoadingState {
  final String title;
  final String subtitle;
  final int selectedDay;
  final CarbLoadingPlan? currentPlan;
  final bool isLoading;
  final String? errorMessage;
  final String emptyStateMessage;
  final String createPlanButtonText;

  const CarbLoadingState({
    required this.title,
    required this.subtitle,
    this.selectedDay = -1,
    this.currentPlan,
    this.isLoading = false,
    this.errorMessage,
    required this.emptyStateMessage,
    required this.createPlanButtonText,
  });

  CarbLoadingState copyWith({
    String? title,
    String? subtitle,
    int? selectedDay,
    CarbLoadingPlan? currentPlan,
    bool? isLoading,
    String? errorMessage,
    String? emptyStateMessage,
    String? createPlanButtonText,
  }) {
    return CarbLoadingState(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      selectedDay: selectedDay ?? this.selectedDay,
      currentPlan: currentPlan ?? this.currentPlan,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      emptyStateMessage: emptyStateMessage ?? this.emptyStateMessage,
      createPlanButtonText: createPlanButtonText ?? this.createPlanButtonText,
    );
  }
}

@riverpod
class CarbLoadingController extends _$CarbLoadingController {
  CarbLoadingService get _service => ref.read(carbLoadingServiceProvider);
  CarbLoadingRepository get _repository => ref.read(carbLoadingRepositoryProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  UserRepository get _userRepository => ref.read(userRepositoryProvider);

  @override
  FutureOr<CarbLoadingState> build() async {
    // Load content from ContentService
    final title = _contentService.getValue(ContentKeys.carbLoadingTitle,
        defaultValue: 'Carb Loading');
    final subtitle = _contentService.getValue(ContentKeys.carbLoadingSubtitle,
        defaultValue: 'Strategic nutrition plan for optimal glycogen storage');
    final emptyStateMessage = _contentService.getValue(ContentKeys.carbLoadingEmptyState,
        defaultValue: 'Set up your carb loading plan for your next race');
    final createPlanButtonText = _contentService.getValue(ContentKeys.carbLoadingCreateButton,
        defaultValue: 'Create Plan');

    // Get current user
    final currentUser = await _userRepository.getCurrentUser();
    if (currentUser == null) {
      return CarbLoadingState(
        title: title,
        subtitle: subtitle,
        emptyStateMessage: 'Please complete onboarding first',
        createPlanButtonText: createPlanButtonText,
      );
    }

    // Load current plan
    final currentPlan = await _repository.getCurrentPlan(currentUser.id);

    return CarbLoadingState(
      title: title,
      subtitle: subtitle,
      currentPlan: currentPlan,
      emptyStateMessage: emptyStateMessage,
      createPlanButtonText: createPlanButtonText,
    );
  }

  Future<void> selectDay(int day) async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(selectedDay: day));
  }

  Future<void> createNewPlan() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // For now, use default values - in the future this could open a setup dialog
      final raceDate = DateTime.now().add(const Duration(days: 7)); // Default to next week
      const raceDistance = RaceDistance.marathon;
      const trainingVolume = TrainingVolume.moderate;
      final userWeightKg = currentUser.weightPounds * 0.453592; // Convert to kg

      final newPlan = _service.calculatePlan(
        userId: currentUser.id,
        raceDate: raceDate,
        raceDistance: raceDistance,
        trainingVolume: trainingVolume,
        userWeightKg: userWeightKg,
      );

      await _repository.savePlan(newPlan);

      final currentState = state.valueOrNull;
      return currentState?.copyWith(
        currentPlan: newPlan,
        selectedDay: -1, // Default to Day -1
      ) ?? CarbLoadingState(
        title: _contentService.getValue(ContentKeys.carbLoadingTitle, defaultValue: 'Carb Loading'),
        subtitle: _contentService.getValue(ContentKeys.carbLoadingSubtitle, defaultValue: 'Strategic nutrition plan for optimal glycogen storage'),
        currentPlan: newPlan,
        selectedDay: -1,
        emptyStateMessage: '',
        createPlanButtonText: '',
      );
    });
  }

  Future<void> deletePlan() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      final currentUser = await _userRepository.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not found');
      }

      await _repository.deleteCurrentPlan(currentUser.id);

      final currentState = state.valueOrNull;
      return currentState?.copyWith(
        currentPlan: null,
        selectedDay: -1,
      ) ?? CarbLoadingState(
        title: _contentService.getValue(ContentKeys.carbLoadingTitle, defaultValue: 'Carb Loading'),
        subtitle: _contentService.getValue(ContentKeys.carbLoadingSubtitle, defaultValue: 'Strategic nutrition plan for optimal glycogen storage'),
        emptyStateMessage: _contentService.getValue(ContentKeys.carbLoadingEmptyState, defaultValue: 'Set up your carb loading plan for your next race'),
        createPlanButtonText: _contentService.getValue(ContentKeys.carbLoadingCreateButton, defaultValue: 'Create Plan'),
      );
    });
  }

  Future<void> refresh() async {
    await _contentService.refreshFromBackend();
    ref.invalidateSelf();
  }

  String getErrorMessage(String? error) {
    return _contentService.getValue(ContentKeys.errorGeneric,
        defaultValue: error ?? 'Something went wrong. Please try again.');
  }
}
```

## 🎨 **Content Management Integration**

### **File**: `lib/features/content/domain/content_keys.dart` (Add to existing file)

```dart
class ContentKeys {
  // Existing keys...

  // Carb Loading Content Keys
  static const String carbLoadingTitle = 'carb_loading.title';
  static const String carbLoadingSubtitle = 'carb_loading.subtitle';
  static const String carbLoadingEmptyState = 'carb_loading.empty_state';
  static const String carbLoadingCreateButton = 'carb_loading.create_button';
  static const String carbLoadingDay2Tab = 'carb_loading.day_2_tab';
  static const String carbLoadingDay1Tab = 'carb_loading.day_1_tab';
  static const String carbLoadingDay0Tab = 'carb_loading.day_0_tab';
  static const String carbLoadingLoadingPhase = 'carb_loading.loading_phase';
  static const String carbLoadingCarbsLabel = 'carb_loading.carbs_label';
  static const String carbLoadingProteinLabel = 'carb_loading.protein_label';
  static const String carbLoadingFatLabel = 'carb_loading.fat_label';
  static const String carbLoadingCaloriesLabel = 'carb_loading.calories_label';
  static const String carbLoadingTodayBadge = 'carb_loading.today_badge';
  static const String carbLoadingWeightNote = 'carb_loading.weight_note';
}
```

### **Default Content for Supabase** (Manual entry in app_content table)

```json
{
  "carb_loading": {
    "title": "Carb Loading",
    "subtitle": "Strategic nutrition plan for optimal glycogen storage",
    "empty_state": "Set up your carb loading plan for your next race",
    "create_button": "Create Plan",
    "day_2_tab": "Day -2",
    "day_1_tab": "Day -1",
    "day_0_tab": "Day 0",
    "loading_phase": "Loading Phase",
    "carbs_label": "Carbohydrates",
    "protein_label": "Protein",
    "fat_label": "Fat",
    "calories_label": "Total Calories",
    "today_badge": "Today",
    "weight_note": "Targets based on {weight}kg athlete. Adjust according to body weight and activity level."
  }
}
```

## 📋 **Implementation Phases**

### **Phase 1: Database & Core Structure** (1-2 days)
1. ✅ Add carb_loading table to Drift schema
2. ✅ Update AppDatabase with migration V6→V7
3. ✅ Create domain models (CarbLoadingPlan, enums)
4. ✅ Implement CarbLoadingRepository
5. ✅ Run code generation and test database changes

### **Phase 2: Business Logic** (1-2 days)
1. ✅ Implement CarbLoadingService with calculation formulas
2. ✅ Create CarbLoadingController with ContentService integration
3. ✅ Add ContentKeys for all UI text
4. ✅ Test calculation logic with sample data

### **Phase 3: UI Implementation** (2-3 days)
1. ✅ Update tabs_screen.dart to add 3rd tab
2. ✅ Create CarbLoadingScreen main screen
3. ✅ Implement CarbLoadingDayTabs widget
4. ✅ Create LoadingPhaseCard widget
5. ✅ Implement MacroBreakdownDisplay widget
6. ✅ Apply AppTheme consistently throughout

### **Phase 4: Integration & Polish** (1-2 days)
1. ✅ Test complete user flow
2. ✅ Verify ContentService integration
3. ✅ Add error handling and edge cases
4. ✅ Polish UI to match mockup exactly
5. ✅ Update content in Supabase app_content table

### **Phase 5: Future Enhancements** (Out of scope for now)
- Race date picker dialog
- Custom race distance/training volume selection
- Plan sharing and export features
- Integration with existing nutrition plans
- Supabase sync for carb loading data

## 🎯 **Success Criteria**

### **Functional Requirements**
- ✅ Carb loading appears as 3rd tab in bottom navigation
- ✅ User can create a carb loading plan with default settings
- ✅ Plan displays Day -2, Day -1, Day 0 tabs matching mockup design
- ✅ Each day shows correct macro breakdown based on calculations
- ✅ Plan data is stored locally in Drift database
- ✅ All UI text comes from ContentService for dynamic management

### **Technical Requirements**
- ✅ Follows Andrea Bizzotto FOA architecture patterns
- ✅ Uses AsyncNotifier controllers with ContentService integration
- ✅ Implements proper Drift schema migration V6→V7
- ✅ Uses AppTheme for consistent styling
- ✅ No hardcoded strings in UI components
- ✅ Proper error handling with AsyncValue.guard

### **UI/UX Requirements**
- ✅ Matches mockup design exactly
- ✅ Uses existing AppTheme fonts and colors
- ✅ Consistent with current app navigation patterns
- ✅ Responsive layout for different screen sizes
- ✅ Smooth animations and transitions

## 🔄 **Risk Mitigation**

### **Database Migration Risks**
- **Risk**: Schema migration V6→V7 fails or corrupts data
- **Mitigation**: Test migration thoroughly on development database, implement rollback procedures

### **Calculation Logic Risks**
- **Risk**: Carb loading formulas produce incorrect results
- **Mitigation**: Validate calculations against requirements document, test with multiple user scenarios

### **UI Consistency Risks**
- **Risk**: Carb loading tab doesn't match existing app design patterns
- **Mitigation**: Reuse existing widgets where possible, follow AppTheme strictly

### **ContentService Integration Risks**
- **Risk**: Missing content keys cause UI to show fallback text
- **Mitigation**: Define all ContentKeys upfront, provide sensible fallbacks

This roadmap provides a comprehensive implementation plan for the carb loading feature that integrates seamlessly with your existing architecture while following all FOA patterns and design requirements!

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"content": "Research carb loading requirements and mockup", "status": "completed", "activeForm": "Researched carb loading requirements and mockup"}, {"content": "Examine current tabs_screen.dart architecture", "status": "completed", "activeForm": "Examined current tabs_screen.dart architecture"}, {"content": "Analyze FOA architecture and database schema", "status": "completed", "activeForm": "Analyzed FOA architecture and database schema"}, {"content": "Review app theme and UI patterns", "status": "completed", "activeForm": "Reviewed app theme and UI patterns"}, {"content": "Ask clarifying questions about scope and requirements", "status": "completed", "activeForm": "Asked clarifying questions about scope and requirements"}, {"content": "Create comprehensive carb loading roadmap document", "status": "completed", "activeForm": "Created comprehensive carb loading roadmap document"}]