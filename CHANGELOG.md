# Changelog

All notable changes to Mealvana Endurance will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
| 2.0.0   | Dec 2024     | Dietary preferences, allergies, enhanced sync |
| 1.0.0   | Dec 2024     | Initial App Store release |

---

*For detailed technical documentation, see [/docs/technical/README.md](/docs/technical/README.md)*
