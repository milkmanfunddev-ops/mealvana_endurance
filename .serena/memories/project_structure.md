# Project Structure Overview

## Root Structure
```
mealvana_endurance/
├── lib/                    # Main Flutter source code
├── assets/                 # App assets and configuration
├── docs/                   # Documentation
├── test/                   # Test files
├── supabase/               # Backend functions
├── ios/android/web/        # Platform-specific code
├── pubspec.yaml            # Dependencies and app configuration
├── analysis_options.yaml   # Linting configuration
├── shorebird.yaml          # OTA update configuration
└── CLAUDE.md               # Primary AI assistant context
```

## Feature-Oriented Architecture (lib/features/)
```
lib/features/
├── auth/                   # Authentication & user management
├── content/                # Content management system
├── feedback/               # User feedback collection
├── nutrition_plan/         # Core nutrition calculations
├── onboarding/            # User onboarding flow
├── settings/              # App settings
└── app_startup/           # App initialization
```

Each feature follows the same pattern:
```
feature/
├── presentation/          # UI widgets and controllers
│   ├── providers/        # Riverpod controllers (@riverpod)
│   ├── screens/          # Full-screen widgets
│   └── widgets/          # Reusable UI components
├── application/          # Service classes and business logic
├── domain/               # Data models and entities
└── data/                 # Repositories and data sources
```

## Shared Infrastructure (lib/shared/)
```
lib/shared/
├── database/             # Drift database configuration
│   ├── tables/          # Table definitions
│   ├── app_database.dart # Main database class
│   └── database_provider.dart # Riverpod database provider
├── services/             # Cross-feature services
├── widgets/              # Reusable UI components
├── core/                 # App routing and utilities
└── utils/                # Helper functions
```

## Key Configuration Files
- `assets/config/content_defaults.json` - UI text and algorithm parameters
- `lib/main.dart` - App entry point with Sentry and Supabase initialization
- `lib/shared/widgets/root_app_widget.dart` - Root app wrapper
- `lib/shared/core/app_router.dart` - Navigation configuration

## Documentation Structure
```
docs/
├── technical/            # Architecture and implementation guides
├── business_logic/       # Algorithm documentation  
├── database/            # Database schema and migrations
├── roadmap/             # Project planning
└── privacy/             # Privacy and compliance docs
```

## Important Patterns
- All controllers use `@riverpod` annotation with code generation
- Database uses Drift with type-safe migrations
- Content management via JSON configuration
- Offline-first architecture with Supabase sync
- Feature isolation following FOA principles