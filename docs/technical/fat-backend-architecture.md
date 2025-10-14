# Fat Backend Architecture

## Overview

Mealvana Endurance implements a "fat backend" architecture where business logic, content, and algorithm parameters are stored in Supabase and cached locally. This enables non-technical team members to make changes through a backend interface without code deployments, while maintaining offline functionality through local caching and fallback mechanisms.

## Architecture Components

### 1. Content Management System (CMS)

The app fetches UI text and algorithm parameters from Supabase at startup, caches them locally in Drift SQLite app_content table, and falls back to bundled JSON files when offline.

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│                 │         │                  │         │                 │
│   Supabase DB   │────────►│  Content Service │────────►│ Drift SQLite    │
│  (app_content)  │  Fetch  │                  │  Store  │ (app_content)   │
│                 │         │                  │         │                 │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                            │                            │
        │                            │                            │
        │                            ▼                            │
        │                   ┌──────────────────┐                 │
        │                   │                  │                 │
        │                   │   UI Components  │◄────────────────┘
        │                   │                  │   Type-Safe Access
        │                   └──────────────────┘
        │                            ▲
        │                            │ Fallback
        │                   ┌──────────────────┐
        │                   │                  │
        └──────────────────►│ Local JSON Files │
                Offline     │    (assets)      │
                Fallback    └──────────────────┘
```

### 2. Content Structure

Content is organized into two main categories:

#### UI Text Content
All user-facing strings that can be edited by the content team:
```json
{
  "main_screen": {
    "title": "Mealvana Endurance",
    "distance_label": "Distance",
    "pace_label": "Average pace",
    // ... more UI strings
  },
  "validation": {
    "required": "This field is required",
    "invalid_number": "Please enter a valid number"
    // ... validation messages
  }
}
```

#### Algorithm Parameters
Scientific constants and thresholds that can be tweaked without code changes:
```json
{
  "algorithm": {
    "energy": {
      "net_calories_per_kg_per_km": 1.0,
      "acsm_vo2_constant_a": 0.2,
      "acsm_vo2_constant_b": 3.5
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

## Implementation Details

### Content Service

The `ContentService` provides a unified interface for accessing content:

```dart
class ContentService {
  // Get UI text
  Future<String> getValue(String key, {String? defaultValue});
  
  // Get algorithm parameters
  Future<double> getAlgorithmParameter(String key, {required double defaultValue});
  Future<int> getAlgorithmParameterInt(String key, {required int defaultValue});
  Future<bool> getAlgorithmParameterBool(String key, {required bool defaultValue});
  
  // Get complex nested parameters
  Future<Map<String, dynamic>> getAlgorithmCategory(String category);
}
```

### Content Flow

1. **App Startup**: Content service initializes and checks Supabase for latest content version
2. **Background Fetch**: Fetches latest content from Supabase `app_content` table if available
3. **Version Check**: Compares version numbers to determine if update is needed
4. **Local Cache**: Stores fetched content in Hive for offline access
5. **Fallback**: If Supabase unavailable, uses cached content or bundled defaults
6. **Immediate Updates**: New content takes effect immediately through ContentService

### Content Repository

Handles the data layer operations:

```dart
class ContentRepository {
  // Fetch from backend
  Future<AppContent?> fetchFromBackend();
  
  // Local storage operations
  Future<void> saveContent(AppContent content);
  Future<AppContent?> getActiveContent();
  
  // Get specific values with dot notation
  Future<String> getValue(String key, {String? defaultValue});
}
```

## Benefits

### For Non-Technical Team Members
- **Edit UI Copy**: Update any text in the app without code knowledge
- **Tweak Algorithm**: Adjust nutrition calculation parameters based on user feedback
- **Instant Updates**: Changes reflect immediately after app restart
- **No App Store Review**: Content updates bypass app store approval process

### For Developers
- **Clean Code**: No hardcoded strings or magic numbers
- **Testability**: Easy to mock different content configurations
- **Flexibility**: Add new content keys without modifying core logic
- **Version Control**: Content changes tracked in database

### For Business
- **A/B Testing**: Test different algorithm parameters with user groups
- **Rapid Iteration**: Quick response to user feedback
- **Reduced Deployment**: Fewer app releases needed
- **Market Adaptation**: Customize content for different regions

## Content Management Workflow

### Adding New Content

1. **Define Key**: Add to `ContentKeys` class for type safety
```dart
class ContentKeys {
  static const String newFeatureTitle = 'new_feature.title';
}
```

2. **Add Default**: Update `content_defaults.json`
```json
{
  "new_feature": {
    "title": "Default Title"
  }
}
```

3. **Use in Code**: Access via ContentService
```dart
final title = await contentService.getValue(
  ContentKeys.newFeatureTitle,
  defaultValue: 'Fallback Title'
);
```

4. **Deploy**: Include updated file in next app release

### Modifying Algorithm Parameters

1. **Identify Parameter**: Find in `assets/config/content_defaults.json`
2. **Update File**: Modify value in the JSON file
3. **Test**: Rebuild and run app with new values
4. **Deploy**: Include updated file in app release

## Security Considerations

### Content Validation
- All fetched content is validated before use
- Type checking ensures parameters are within expected ranges
- Fallback values prevent app crashes from invalid content

### Access Control
- Content files bundled with app (read-only at runtime)
- Write access through development workflow and file updates
- Changes require app rebuild and deployment

## Performance Optimization

### Loading Strategy
- Content loaded once at app startup from local files
- Cached in memory for entire session
- No network requests required
- Instant access with no loading states

### Bundle Size
- Default content included in app bundle
- Ensures app works on first launch
- Minimal overhead (~50KB JSON)

## Monitoring & Analytics

### Content Usage Tracking
```dart
final analytics = ref.read(appExternalDepsProvider).analytics;
analytics.track('content_accessed', {
  'key': contentKey,
  'source': source,
});
```

### Algorithm Performance
```dart
final analytics = ref.read(appExternalDepsProvider).analytics;
analytics.track('nutrition_calculated', {
  'gut_training_multiplier': multiplier,
  'carbs_per_hour': result,
});
```

## Future Enhancements

### Planned Features
- **Content Versioning**: Version control for content file changes
- **Multiple Environments**: Different content files for dev/staging/prod
- **Hot Reloading**: Development-time content updates
- **Content Validation**: Automated testing of content file integrity

### Technical Improvements
- **Shorebird Integration**: Over-the-air content updates
- **Build Optimization**: Automated content bundling
- **Content Compression**: Optimize JSON file size
- **Configuration Management**: Multiple content profiles

## Troubleshooting

### Common Issues

**Content Not Updating**
- Verify content file was updated in assets
- Rebuild the app to include new content
- Check for JSON syntax errors
- Verify file path is correct

**Missing Content Keys**
- Ensure key exists in content_defaults.json
- Verify JSON structure is correct
- Check for typos in key names

**Performance Issues**
- Review content file size (should be minimal)
- Optimize JSON structure
- Check memory usage during loading
- Optimize key lookup patterns

## Related Documentation

- [Content Management System](/docs/technical/content-management.md)
- [Data Storage](/docs/technical/data-storage.md)
- [Technical Overview](/docs/technical/README.md)
- [Shorebird Code Push](/docs/technical/shorebird-code-push.md)
