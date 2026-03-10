# Changelog

All notable changes to Mealvana Endurance will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.15.0] - 2026-03-10

### Added
- **Redesigned During-Activity Nutrition**: Completely overhauled during-activity food selection with a new timeline UI and hour-by-hour nutrition view
- **Template-Based Pre-Workout Nutrition**: New template system for pre-workout food planning with beverage handling and fluid tracking
- **User-Driven Food Placement**: Replace auto-apportionment with an intuitive drag-to-hour and tap-to-place model for placing nutrition items
- **Global Sip Section**: Add a dedicated section for sip-based items (sports drinks, water) with inline quantity adjustment
- **Nutrition Target Overrides**: Users can now manually adjust their carb, protein, and hydration targets
- **Graduated Pre-Activity Fueling**: Duration-aware pre-activity fueling window with smarter recommendations for shorter vs longer activities
- **Post-Workout Carb Feedback Loop**: Track actual vs planned carb intake after workouts to improve future recommendations
- **Brick Workout V2 Support**: Full brick workout support in the V2 edge function with transition phase nutrition planning
- **V2 Nutrition Edge Function**: Unified food tables and next-generation nutrition plan generation engine
- **Schema Compatibility Window**: Graceful schema migration with configurable compatibility windows to avoid forced upgrades

### Changed
- **Rule-Based During Algorithm**: Replaced the linear programming solver with a faster, more predictable deterministic rule-based algorithm
- **Improved Brick Workout Accuracy**: Better nutrition calculations for multi-sport sessions with refined transition period handling
- UI refinements and consistency updates across nutrition plan screens

### Fixed
- Fixed 8 critical bugs in the by-hour nutrition view including layout and data display issues
- Fixed water filtering, sodium cap enforcement, and variety selection in the during-phase solver
- Fixed trailing time slots appearing in partial hours where no food can be placed
- Fixed version check incorrectly comparing pre-release suffixes
- Fixed template food preference migration deduplication and integration test parsing
- Fixed beverage handling and fluid tracking in template foods
- Various stability and performance improvements

---

## [2.0.0] - 2024-12-22

### Added
- **Dietary Preferences**: Choose from omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, or low-carb diets
- **Allergy Tracking**: Set food allergies (gluten, dairy, nuts, soy, eggs, shellfish, fish) to filter out unsafe foods
- **Enhanced Food Preference System**: New preference levels (1-5 scale) for more nuanced food recommendations
- **Improved Data Sync**: UUID-based IDs prevent conflicts when syncing across multiple devices
- **Migration Testing**: Comprehensive automated tests for database upgrades

### Fixed
- Fixed ID collision bug in activities and events tables
- Fixed food preferences sync issues with offline-first architecture
- Fixed carb loading event association bugs
- Fixed race distance and pace pre-population from events
- Resolved infinite loading on food preferences screen

### Changed
- Database schema upgraded from v1 to v2 with automatic migration
- Activities and events now use UUID identifiers instead of integers
- Improved data integrity for multi-device sync scenarios

### Security
- Removed sensitive files from git tracking
- Enhanced environment variable handling

---

## [1.0.0] - 2024-12-01

### Added
- **Personalized Nutrition Plans**: Science-based nutrition recommendations using ACSM formulas
- **Multi-Sport Support**: Running, cycling, and swimming activity tracking
- **Food Preferences**: Like/dislike foods to customize your nutrition plans
- **Activities Calendar**: Schedule and track your workouts
- **Events Management**: Add races and competitions with goal times
- **Carb Loading Planner**: 1-7 day carb loading protocols for race preparation
- **Offline-First Architecture**: Full functionality without internet connection
- **Anonymous Authentication**: Use the app without creating an account
- **OAuth Sign-In**: Optional Apple and Google sign-in for data backup
- **In-App Feedback**: Wiredash integration for bug reports and feature requests

### Technical
- Flutter 3.8+ with Dart
- Riverpod 2.x state management with code generation
- Drift SQLite database with type-safe queries
- Supabase backend for cloud sync and authentication
- Shorebird code push for over-the-air updates

---

## Version History Summary

| Version | Release Date | Highlights |
|---------|--------------|------------|
| 1.15.0  | Mar 2026     | Redesigned during-activity nutrition, template foods, user-driven placement |
| 2.0.0   | Dec 2024     | Dietary preferences, allergies, enhanced sync |
| 1.0.0   | Dec 2024     | Initial App Store release |

---

*For detailed technical documentation, see [/docs/technical/README.md](/docs/technical/README.md)*
