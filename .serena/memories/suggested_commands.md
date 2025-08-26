# Suggested Development Commands

## Essential Daily Commands

### Code Generation (CRITICAL - Must run after @riverpod or @DriftDatabase changes)
```bash
# Watch mode for continuous generation during development
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Migrations (After schema changes)
```bash
# Generate new migration after database table changes
dart run drift_dev make-migrations

# Export schema for version control
dart run drift_dev schema dump lib/shared/database/app_database.dart drift_schemas/
```

### Development & Testing
```bash
# Run app on connected device
flutter run

# Fast analysis - AI assistants should use this
flutter analyze

# Run tests
flutter test

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade
```

### Code Quality
```bash
# Format code
dart format .

# Check for lint issues
flutter analyze
```

### App Icons & Splash (After asset changes)
```bash
# Generate app icons
dart run flutter_launcher_icons

# Generate splash screens
dart run flutter_native_splash:create
```

### Shorebird Deployment (Production Only)
```bash
# Create release
shorebird release ios
shorebird release android

# Push over-the-air update
shorebird patch ios
shorebird patch android

# Check patch status
shorebird patches
```

### Build Commands (HUMAN ONLY - Takes 5-10+ minutes)
⚠️ **AI assistants should NEVER run these commands**
```bash
flutter build ios --release
flutter build appbundle --release
```

## System Commands (Darwin/macOS)
- `ls` - List directory contents
- `find` - Search for files (prefer Serena tools)
- `grep` - Search in files (prefer Serena tools) 
- `git` - Version control commands
- `cd` - Change directory