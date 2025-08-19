# Content Management System

## Overview

The Content Management System (CMS) allows dynamic updating of UI text and algorithm parameters without code changes. Content is stored in Supabase and cached locally in Hive, with fallback to bundled JSON files, enabling the "fat backend" architecture where business logic parameters are managed remotely while maintaining offline functionality.

## Content Structure

### Data Model

Content is stored as structured JSON in the Supabase `app_content` table and cached locally in Hive:

### Content Schema

The JSON structure follows a hierarchical key-value pattern:

```json
{
  "version": "1.0.0",
  "ui_text": {
    "main_screen": {
      "title": "Mealvana Endurance",
      "subtitle": "Personalized nutrition for athletes",
      "distance_label": "Distance (miles)",
      "pace_label": "Average pace",
      "generate_button": "Generate Plan"
    },
    "plan_screen": {
      "title": "Your Nutrition Plan",
      "before_run": "Before Run",
      "during_run": "During Run",
      "after_run": "After Run"
    },
    "validation": {
      "required": "This field is required",
      "invalid_number": "Please enter a valid number",
      "distance_range": "Distance must be between 0 and 200 miles"
    }
  },
  "algorithm": {
    "energy": {
      "net_calories_per_kg_per_km": 1.0,
      "acsm_vo2_constant_a": 0.2,
      "acsm_vo2_constant_b": 3.5,
      "met_divisor": 3.5
    },
    "pre_run": {
      "carbs": {
        "time_threshold_1h": 1.0,
        "carbs_per_kg_per_hour": 1.0,
        "max_carbs_per_kg": 4.0
      }
    },
    "during_run": {
      "carbs": {
        "gut_training_multipliers": {
          "low": 0.7,
          "moderate": 0.8,
          "high": 1.0
        },
        "absorption_limit_min_g_per_h": 30,
        "absorption_limit_max_g_per_h": 60
      }
    }
  }
}
```

## Implementation

### ContentService

The main service class provides typed access to content:

```dart
class ContentService {
  final ContentRepository _contentRepository;
  
  /// Get UI text with fallback
  Future<String> getValue(String key, {String? defaultValue}) async {
    return await _contentRepository.getValue(key, defaultValue: defaultValue);
  }
  
  /// Get numeric algorithm parameters
  Future<double> getAlgorithmParameter(String key, {required double defaultValue}) async {
    final value = await _contentRepository.getValue('algorithm.$key', 
        defaultValue: defaultValue.toString());
    return double.tryParse(value) ?? defaultValue;
  }
  
  /// Get complex nested parameters
  Future<Map<String, dynamic>> getAlgorithmCategory(String category) async {
    final content = await _contentRepository.getActiveContent();
    if (content?.content['algorithm'] is Map<String, dynamic>) {
      final algorithm = content!.content['algorithm'] as Map<String, dynamic>;
      return _extractNestedMap(algorithm, category);
    }
    return {};
  }
}
```

### ContentRepository

Handles data persistence and retrieval with Supabase integration:

```dart
class ContentRepository {
  final SupabaseClient _supabase;
  late Box<AppContent> _box;
  
  /// Check for updates from Supabase in background
  Future<void> checkForUpdates({
    String environment = 'production',
    String locale = 'en',
  }) async {
    try {
      // Get current cached version
      final currentContent = await getActiveContent(
        environment: environment,
        locale: locale,
      );
      final currentVersion = currentContent?.version ?? 0;

      // Check Supabase for latest version
      final latestContent = await fetchLatestContent(
        environment: environment,
        locale: locale,
      );

      // If we found a newer version, it's already saved
      if (latestContent != null && latestContent.version > currentVersion) {
        print('Content updated to version ${latestContent.version}');
      }
    } catch (e) {
      // Don't throw - app should continue with cached/default content
    }
  }

  /// Fetch latest content from Supabase
  Future<AppContent?> fetchLatestContent({
    String environment = 'production',
    String locale = 'en',
  }) async {
    final response = await _supabase
        .from('app_content')
        .select()
        .eq('environment', environment)
        .eq('locale', locale)
        .eq('is_active', true)
        .order('version', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response != null) {
      final content = AppContent.fromJson(response);
      await _saveContent(content);
      return content;
    }
    return null;
  }
}
```

### Content Keys

Type-safe constants for all content keys:

```dart
class ContentKeys {
  // Main Screen
  static const String mainScreenTitle = 'main_screen.title';
  static const String mainScreenSubtitle = 'main_screen.subtitle';
  static const String mainScreenDistanceLabel = 'main_screen.distance_label';
  
  // Algorithm Parameters
  static const String algorithmEnergyNetCalories = 'algorithm.energy.net_calories_per_kg_per_km';
  static const String algorithmCarbsAbsorptionMin = 'algorithm.during_run.carbs.absorption_limit_min_g_per_h';
  
  // Validation Messages
  static const String validationRequired = 'validation.required';
  static const String validationInvalidNumber = 'validation.invalid_number';
}
```

## Usage Patterns

### In UI Components

```dart
class MainScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentService = ref.watch(contentServiceProvider);
    
    return FutureBuilder<String>(
      future: contentService.getValue(ContentKeys.mainScreenTitle, 
          defaultValue: 'Mealvana Endurance'),
      builder: (context, snapshot) {
        return Text(snapshot.data ?? 'Loading...');
      },
    );
  }
}
```

### In Controllers

```dart
class MainScreenController extends StateNotifier<AsyncValue<MainScreenState>> {
  final ContentService _contentService;
  
  Future<void> _loadContent() async {
    final title = await _contentService.getValue(ContentKeys.mainScreenTitle);
    final subtitle = await _contentService.getValue(ContentKeys.mainScreenSubtitle);
    
    state = AsyncData(MainScreenState(
      title: title,
      subtitle: subtitle,
    ));
  }
}
```

### In Algorithm Calculations

```dart
class NutritionCalculator {
  final ContentService _contentService;
  
  Future<double> calculateCarbsPerHour(double bodyWeightKg, String gutTrainingLevel) async {
    // Get configurable multipliers
    final multipliers = await _contentService.getAlgorithmCategory('during_run.carbs.gut_training_multipliers');
    final gutMultiplier = (multipliers[gutTrainingLevel] as num?)?.toDouble() ?? 1.0;
    
    // Get absorption limits
    final minLimit = await _contentService.getAlgorithmParameter(
        'during_run.carbs.absorption_limit_min_g_per_h', defaultValue: 30.0);
    final maxLimit = await _contentService.getAlgorithmParameter(
        'during_run.carbs.absorption_limit_max_g_per_h', defaultValue: 60.0);
    
    final massNormRate = gutMultiplier * bodyWeightKg;
    return massNormRate.clamp(minLimit, maxLimit);
  }
}
```

## Content Update Workflow

### 1. Supabase Content Management

Content is managed through the Supabase database using the `app_content` table:

### 2. Content Flow

The app follows this priority order: **Supabase → Hive Cache → Bundled Defaults**

1. **App Startup**: ContentService checks Supabase for latest content version
2. **Background Update**: Compares version numbers and downloads if newer available
3. **Immediate Effect**: New content takes effect immediately through ContentService
4. **Fallback**: If Supabase unavailable, uses cached content or bundled defaults

### 3. Updating Content

To update content or algorithm parameters:

#### Via Supabase Dashboard
1. **Navigate to app_content table** in Supabase dashboard
2. **Create new version**: Use the `create_content_version()` function:
   ```sql
   SELECT create_content_version('production', 'en', '{
     "algorithm": {
       "during_run": {
         "carbs": {
           "gut_training_multipliers": {
             "low": 0.75,
             "moderate": 0.85,
             "high": 1.1
           }
         }
       }
     }
   }'::jsonb);
   ```

3. **Test changes**: App will pick up changes on next startup or manual refresh
4. **Deploy**: Changes are live immediately for all app users

#### Via SQL Commands  
```sql
-- Get current content
SELECT * FROM get_latest_content('production', 'en');

-- Create new version with updated algorithm
SELECT create_content_version('production', 'en', 
  jsonb_set(
    (SELECT content FROM get_latest_content('production', 'en')),
    '{algorithm,during_run,carbs,absorption_limit_max_g_per_h}',
    '65'
  )
);
```

## Content Validation

### Type Safety

All content access includes type checking:

```dart
Future<double> getAlgorithmParameter(String key, {required double defaultValue}) async {
  final value = await getValue('algorithm.$key', defaultValue: defaultValue.toString());
  final parsed = double.tryParse(value);
  
  if (parsed == null) {
    print('Warning: Invalid algorithm parameter $key: $value. Using default: $defaultValue');
    return defaultValue;
  }
  
  return parsed;
}
```

### Range Validation

Algorithm parameters include safety bounds:

```dart
Future<double> calculateCarbsPerHour(...) async {
  final minLimit = await getAlgorithmParameter('...min_g_per_h', defaultValue: 30.0);
  final maxLimit = await getAlgorithmParameter('...max_g_per_h', defaultValue: 60.0);
  
  // Ensure min < max
  final safeMin = min(minLimit, maxLimit - 1);
  final safeMax = max(maxLimit, minLimit + 1);
  
  return calculation.clamp(safeMin, safeMax);
}
```

## Performance Considerations

### Caching Strategy

- **Startup**: Load all content into memory
- **Session**: Keep content cached for entire session
- **Background**: Refresh every 24 hours
- **Manual**: Allow user to refresh via settings

### Memory Usage

- Content size typically <100KB
- Cached in memory for fast access
- Persisted to Hive for offline access
- Defaults bundled in app (~50KB)

### Network Efficiency

- Single request fetches all content
- Gzip compression reduces size
- ETags prevent unnecessary downloads
- Background refresh doesn't block UI

## Testing

### Unit Tests

```dart
void main() {
  group('ContentService', () {
    late ContentService contentService;
    late MockContentRepository mockRepository;
    
    setUp(() {
      mockRepository = MockContentRepository();
      contentService = ContentService(mockRepository);
    });
    
    test('should return backend value when available', () async {
      // Arrange
      when(mockRepository.getValue('test.key')).thenReturn('backend_value');
      
      // Act
      final result = await contentService.getValue('test.key', defaultValue: 'default');
      
      // Assert
      expect(result, equals('backend_value'));
    });
    
    test('should return default when backend unavailable', () async {
      // Arrange
      when(mockRepository.getValue('test.key')).thenThrow(Exception());
      
      // Act
      final result = await contentService.getValue('test.key', defaultValue: 'default');
      
      // Assert
      expect(result, equals('default'));
    });
  });
}
```

### Integration Tests

```dart
void main() {
  testWidgets('should display content from service', (tester) async {
    // Arrange
    final mockContentService = MockContentService();
    when(mockContentService.getValue(ContentKeys.mainScreenTitle))
        .thenAnswer((_) async => 'Test Title');
    
    // Act
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWithValue(mockContentService),
        ],
        child: MaterialApp(home: MainScreen()),
      ),
    );
    await tester.pumpAndSettle();
    
    // Assert
    expect(find.text('Test Title'), findsOneWidget);
  });
}
```

## Troubleshooting

### Common Issues

**Content not updating**
- Check Supabase connection
- Verify `is_active` flag in database
- Clear local cache: `contentBox.clear()`
- Check network connectivity

**Wrong algorithm values**
- Verify key names match exactly
- Check data types (string vs number)
- Ensure fallback values are correct
- Test with default content file

**Performance issues**
- Review content size (should be <100KB)
- Check for excessive content requests
- Optimize content structure
- Use content keys instead of dynamic lookups

### Debug Tools

Enable debug logging for content operations:

```dart
class ContentService {
  static bool debugMode = kDebugMode;
  
  Future<String> getValue(String key, {String? defaultValue}) async {
    final value = await _contentRepository.getValue(key, defaultValue: defaultValue);
    
    if (debugMode) {
      print('Content[$key] = $value (default: $defaultValue)');
    }
    
    return value;
  }
}
```

## Related Documentation

- [Fat Backend Architecture](/docs/technical/fat-backend-architecture.md)
- [Data Storage](/docs/technical/data-storage.md)
- [Technical Overview](/docs/technical/README.md)