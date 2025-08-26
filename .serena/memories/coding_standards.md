# Coding Standards & Conventions

## Architecture Patterns

### CRITICAL: Andrea Bizzotto AsyncNotifier Pattern
ALL controllers MUST follow this exact pattern:

```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'controller_name.g.dart';

@riverpod
class ScreenController extends _$ScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  ServiceClass get _service => ref.read(serviceProvider);

  @override
  FutureOr<StateType> build() {
    // Initialize synchronously with cached content when possible
    return initialState;
  }

  Future<void> performAction() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Business logic here
      return updatedState;
    });
  }
  
  Future<void> refresh() async {
    await _service.refreshData();
    ref.invalidateSelf();
  }
}
```

### Mandatory Requirements
1. **Use `@riverpod` annotation** - Never create manual providers
2. **Extend `AsyncNotifier<T>`** - Never use old `StateNotifier`
3. **Use `AsyncValue.guard()`** - For consistent error handling
4. **Access ContentService** - All text must come from content management system
5. **Include `part` directive** - For code generation

### Code Style Rules
- **No Static Methods**: Use dependency injection via Riverpod
- **Async by Default**: Most operations should be async
- **Error Handling**: Use `AsyncValue.guard` for consistent error handling
- **Content Fallbacks**: Always provide local defaults for offline mode
- **NO COMMENTS**: Do not add comments unless explicitly requested

### Linting
- Uses `package:flutter_lints/flutter.yaml`
- Standard Flutter lint rules apply
- No custom lint overrides currently configured

### File Naming Conventions
- Feature-oriented structure under `lib/features/`
- Snake case for file names
- Generated files have `.g.dart` extension
- Part files use `part 'filename.g.dart';` directive

### Import Organization
- Flutter imports first
- Package imports second  
- Relative imports last
- Alphabetical ordering within groups