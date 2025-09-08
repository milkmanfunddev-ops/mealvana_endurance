# Mealvana Endurance - Coding Standards

## Naming Conventions

### Database & Storage
- **Supabase tables and columns**: `snake_case`
- **Hive box keys and stored maps**: `snake_case`

### Dart Code
- **Class names**: `PascalCase` (e.g., `UserProfile`, `NutritionPlan`)
- **Property names**: `camelCase` (e.g., `firstName`, `bodyWeight`)
- **Method names**: `camelCase` (e.g., `calculateNutrition`, `saveUserData`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `DEFAULT_TIMEOUT`)
- **File names**: `snake_case.dart` (e.g., `user_profile.dart`)

### Entity Structure
Each database table must include standardized fields:
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
user_id UUID REFERENCES auth.users(id) NOT NULL,
updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at TIMESTAMPTZ NULL  -- For soft deletes
```

## Data Consistency Rules

### Type Safety Guidelines
- **Consistent naming**: snake_case in storage, camelCase in Dart
- **Null safety**: Enable strict null safety across the project
- **Type annotations**: Always provide explicit type annotations for public APIs
- **Immutable models**: Use immutable classes for domain entities

### Conflict Resolution
- **Newest-wins policy**: Based on `updated_at` timestamp
- **Soft deletes**: Server sets `deleted_at`, client mirrors it
- **Optimistic updates**: UI updates immediately, sync resolves conflicts later

## Code Organization

### Feature Structure
Each feature must follow the standard directory structure:
```
feature_name/
  application/        # Services and business logic coordination
  data/              # Models, repositories, data sources
    models/          # Data Transfer Objects with serialization
    repositories/    # Data access layer
  domain/            # Business entities and use cases (future)
  presentation/      # UI layer
    screens/         # Page-level widgets
    widgets/         # Reusable UI components
    providers/       # State management providers
```

### Cross-Feature Communication
- Use **application layer services** for feature coordination
- Services access other features through dependency injection
- Avoid direct widget-to-widget communication across features

## Documentation Standards

### Code Comments
- **Public APIs**: Always document with dartdoc comments
- **Complex logic**: Explain the "why", not the "what"
- **Algorithm references**: Include scientific sources for nutrition calculations

### File Headers
Include source reference in organized documentation:
```dart
/// Organized from: /original/path/to/file.md
```

### Model Documentation
Document business rules and constraints:
```dart
/// User profile with nutritional and biometric data.
/// 
/// Weight is stored in pounds for US compatibility.
/// Gut training affects carbohydrate absorption calculations.
class UserProfile {
  // ...
}
```

## Testing Standards

### Test Organization
- **Unit tests**: `/test/unit/`
- **Integration tests**: `/test/integration/`
- **Widget tests**: `/test/widget/`

### Test Naming
```dart
// Good
test('should calculate carbs per hour when body weight is 70kg', () async {
  // ...
});

// Bad
test('carbs test', () async {
  // ...
});
```

### Mock Standards
- Use consistent mock naming: `Mock<ClassName>`
- Mock at the boundary (repository level, not service level)
- Provide meaningful test data that reflects real usage

## Error Handling

### Exception Types
Define domain-specific exceptions:
```dart
class NutritionCalculationException extends Exception {
  final String message;
  final Map<String, dynamic>? context;
  
  NutritionCalculationException(this.message, [this.context]);
}
```

### Error Boundaries
- Repository layer: Handle data access errors
- Service layer: Handle business logic errors  
- UI layer: Handle presentation errors gracefully

### Logging Standards
```dart
// Include context in error logs
logger.error('Failed to calculate nutrition plan', {
  'userId': user.id,
  'distance': distance,
  'error': error.toString(),
});
```

## Performance Standards

### Database Access
- Use prepared statements for repeated queries
- Batch operations when possible
- Implement proper indexing for query optimization

### State Management
- Keep provider scope as narrow as possible
- Dispose resources in provider cleanup
- Use `autoDispose` for temporary state

### Memory Management
- Dispose controllers and streams properly
- Avoid memory leaks in long-running operations
- Use weak references for callbacks

## Security Standards

### Data Validation
- Validate all user inputs
- Sanitize data before storage
- Use type-safe parsing with fallbacks

### Authentication
- Never store sensitive data in plain text
- Use Supabase JWT for authenticated requests
- Implement proper session management

### Privacy
- Follow data minimization principles
- Implement proper data retention policies
- Provide clear user consent mechanisms

## Build and Deployment

### Version Management
- Follow semantic versioning (semver)
- Update version numbers in all relevant files
- Tag releases consistently

### Code Generation
```bash
# Run code generation for providers and models
dart run build_runner build --delete-conflicting-outputs
```

### Dependencies
- Pin major versions to avoid breaking changes
- Regular dependency audits for security vulnerabilities
- Document rationale for dependency choices

## Quality Assurance

### Code Review Checklist
- [ ] Follows naming conventions
- [ ] Includes proper error handling
- [ ] Has appropriate test coverage
- [ ] Documentation is complete and accurate
- [ ] Performance considerations addressed

### Static Analysis
- Enable strict lint rules
- Fix all warnings before merging
- Use custom lint rules for project-specific patterns

### Continuous Integration
- All tests must pass
- Code coverage thresholds met
- Static analysis passes
- Build successful on all target platforms

## Source Reference

Based on: `../../../docs/03_architecture/app_architecture.md`