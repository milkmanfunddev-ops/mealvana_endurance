# Development Workflow & Patterns

## App Initialization Pattern (CRITICAL)
The app follows Andrea Bizzotto's robust initialization pattern:

1. `main()` → Only non-recoverable initialization (Supabase, Sentry)
2. `RootAppWidget` → MaterialApp.router with builder
3. `MaterialApp.builder` → Wraps router child with `AppStartupWidget`
4. `AppStartupWidget` → Manages `appStartupProvider` and navigation
5. `appStartupProvider` → Initializes recoverable dependencies (Drift database, user session)

**DO NOT modify the initialization flow without understanding this pattern!**

## Content Management System
Dynamic content system with backend control:

- All UI text comes from `ContentService`, never hardcoded
- Algorithm parameters configurable via JSON
- Fallback to local defaults in `assets/config/content_defaults.json`
- Controllers MUST access ContentService for all text

Example:
```dart
@override
FutureOr<ScreenState> build() {
  final title = _contentService.getValue(ContentKeys.screenTitle, 
      defaultValue: 'Default Title');
  return ScreenState(title: title);
}
```

## Data Architecture
**Offline-First with Drift:**
- Local SQLite database as primary data source
- Type-safe queries and migrations
- Supabase sync for backup/multi-device
- All data operations async by default

**Key Tables:**
- `user_profiles` - User biometric data and preferences
- `food_preferences` - Like/dislike food selections
- `nutrition_plans` - Generated plans with full history
- `app_content` - Cached backend content

## Code Generation Workflow
1. Write code with `@riverpod` or `@DriftDatabase` annotations
2. Run `flutter pub run build_runner watch` during development
3. Generated `.g.dart` files appear automatically
4. Never commit without running generation

## Testing Strategy
- Unit tests for algorithms and business logic
- Widget tests for UI components  
- Integration tests for critical user flows
- Manual testing on real devices for performance

## Deployment Strategy
- **Development**: Flutter run + hot reload
- **Staging**: Shorebird releases for testing
- **Production**: App Store releases + Shorebird patches for quick fixes
- **OTA Updates**: Shorebird patches for non-native code changes

## Error Handling
- **Controllers**: Use `AsyncValue.guard()` for consistent error handling
- **Services**: Throw specific exceptions with context
- **UI**: Use `AsyncValue.when()` for loading/error states
- **Monitoring**: Sentry captures all unhandled exceptions

## Performance Considerations
- **Riverpod**: Use `autoDispose` by default, `keepAlive` when needed
- **Database**: Proper indexing on commonly queried columns
- **UI**: Lazy loading for large lists, proper disposal of controllers
- **Memory**: Watch for memory leaks in streams/subscriptions