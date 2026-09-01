# Mealvana Endurance - Complete Codebase Summary

## Project Overview

**Mealvana Endurance** is a sophisticated, production-ready Flutter app providing personalized nutrition planning for endurance athletes. The app generates science-based nutrition plans for runs and races based on user biometrics, environmental conditions, and food preferences, with a focus on offline-first functionality and evidence-based sports nutrition.

### Target Users
- Endurance athletes preparing for races (5K to ultra-marathons)
- Runners seeking personalized nutrition guidance for training runs
- Serious athletes wanting to optimize their fueling strategy (currently focusing on marathons)

### Key Differentiators
- **Offline-First Architecture**: Full functionality without internet connection
- **Science-Based Approach**: Uses ACSM formulas and ISSN evidence-based nutrition research
- **Device-Based Authentication**: Privacy-first approach with no user accounts required
- **AI-Enhanced Planning**: Dual algorithmic/AI system (currently using algorithmic approach)
- **Dynamic Content Management**: Backend-controlled UI text and algorithm parameters

## Technical Architecture

### Core Framework & Patterns
- **Platform**: Flutter 3.8+ (iOS & Android)
- **Architecture**: Feature-Oriented Architecture (FOA) based on Andrea Bizzotto's patterns
- **State Management**: Riverpod 2.x with `@riverpod` AsyncNotifier pattern and code generation
- **Navigation**: GoRouter with robust initialization pattern
- **Version**: 1.4.0+21 (production app with active users)

### Andrea Bizzotto FOA Compliance
Each feature follows strict four-layer architecture:
```
lib/features/{feature_name}/
├── presentation/   # UI widgets and AsyncNotifier controllers
├── application/    # Service classes and business logic
├── domain/        # Data models and entities
└── data/          # Repositories and data sources
```

**🚨 Critical Requirements:**
- All controllers must use `@riverpod` AsyncNotifier pattern
- UI screens contain ONLY UI logic (no business logic)
- Controllers handle ALL business logic, API calls, data processing
- ContentService integration required for all UI text

### App Initialization (Andrea Bizzotto Pattern)
Robust initialization flow preventing race conditions:
1. `main()` → Non-recoverable initialization (Supabase, Sentry)
2. `RootAppWidget` → MaterialApp.router with builder
3. `MaterialApp.builder` → Wraps router child with `AppStartupWidget`
4. `AppStartupWidget` → Manages startup process and navigation
5. `AppStartupService` → Initializes recoverable dependencies (Drift database, user session, analytics)

## Database Architecture

### Dual Database System (Offline-First)
**Local Storage (Drift SQLite v6):**
- 10 tables with type-safe migrations and code generation
- Complete offline functionality
- Device-based user identification
- 24-hour refresh cycles for reference data

**Cloud Storage (Supabase PostgreSQL):**
- Mirrors local schema for backup and synchronization
- Dynamic content management system
- Edge functions for nutrition plan generation
- Row Level Security for privacy protection

### Current Schema (Version 6)
**Core Tables:**
1. **user_profiles** - User biometric data, preferences, notification settings
2. **food_preferences** - Three-tier preference system (like/dislike/willing_to_try)
3. **nutrition_plans** - Generated plans with full history and versioning
4. **foods** - ~30 foods with nutritional data, suitability flags, serving info
5. **macro_targets** - Custom macro adjustments and targets
6. **feedback** - User satisfaction ratings and feedback data
7. **categories** - Food timing categories (before_run/during_run/after_run)
8. **food_categories** - Many-to-many food-category relationships
9. **brands** - Brand information for affiliate features
10. **app_content** - Dynamic UI text and algorithm parameters (replaces SharedPreferences)

### Key Schema Features
- **Device-based authentication** using device ID as primary key
- **Multi-category food system** with proper relational structure
- **Structured serving data** (no more hardcoded parsing)
- **Three-tier food preferences** (like/willing_to_try/dislike)
- **Versioning & conflict resolution** for nutrition plans
- **Content management** for dynamic UI updates

## User Interface & Navigation

### Three-Tab Bottom Navigation
1. **Plan Tab** - Core nutrition planning functionality
   - Icon: Custom plan.png / activePlan.png assets
   - Screen: `CurrentPlanScreen` (shows plan or empty state)

2. **Workout Notes Tab** - Voice memos and plan rating
   - Icon: Material Icons.notes
   - Screen: `VoiceMemoScreen`
   - Label: "Workout Notes"

3. **Settings Tab** - Profile and preferences
   - Icon: Custom settings.png / activeSettings.png assets
   - Screen: `SettingsScreen`

### Complete Screen Inventory

**Onboarding Flow:**
- `WelcomeScreen` - Initial welcome and app introduction
- `UserProfileScreen` - Biometric data collection (gender, birthday, height, weight, gut training)
- `FoodPreferencesScreen` - Three-tier food preference selection

**Nutrition Planning:**
- `DistancePaceGutEntryScreen` - Run parameters input (distance, pace, timing, environment)
- `CurrentPlanScreen` - Generated plan display with three phases
- `AdjustMacrosScreen` - Fine-tune macro targets with evidence-based validation
- `SwapFoodScreen` - Replace foods based on preferences
- `SamplePlanDemo` - Demo/preview functionality

**User Journal & Feedback:**
- `VoiceMemoScreen` - Record voice notes about workouts
- `VoiceNotesListScreen` - Browse and replay voice recordings
- `PlanHowWellScreen` - Rate plan effectiveness (1-3 scale)
- `SurveyScreen` - Multi-page feedback collection
- `SurveyPage1` / `SurveyPage2` - Individual survey pages
- `SurveyPage1Simple` / `SurveyPage2Simple` - Simplified survey variants

**Settings & Management:**
- `SettingsScreen` - Main settings hub
- `FoodPreferencesEditScreen` - Modify food preferences post-onboarding

**Additional Features:**
- `RecipesScreen` - Recipe management (in development)
- `BarcodeScannerScreen` - Barcode scanning for food lookup
- **App Startup Widgets** - Loading, error handling, initialization

### Design System & Theme

**Brand Colors:**
- **Primary (Blues)**: primary900 (#001C71), primary600 (#3366FF), primary100 (#D6E0FF)
- **Highlight (Coral/Pink)**: highlight600 (#D92D20), highlight400 (#FF8476), highlight100 (#FEE4E2)
- **Base**: baseBlack (#000000), baseCream (#F8F6EB), baseWhite (#FFFFFF), baseGrey (#667085)

**Nutrition-Specific Colors:**
- **Protein**: Pink (#DC2597)
- **Carbohydrates**: Yellow (#FFC629)
- **Fats**: Blue (#3366FF)
- **Calories**: Dark Blue (#001C71)
- **Sodium**: Yellow (#FFC629)
- **Fluids**: Blue (#3366FF)

**Typography System:**
- **Sansita**: Headers, titles, display text (400-900 weight)
- **Apercu**: Body text, labels, readable content (300-700 weight)
- **Helvetica**: Nutrition facts, macro values, scientific data
- **Compadre**: Selection/button text with letter spacing

**Material Design 3 Implementation:**
- Light theme only (no dark mode)
- Custom component themes for buttons, inputs, cards, app bars
- Consistent shadow system and visual effects
- Nutrition-specific macro visualization colors

## Current Feature Implementation Status

### ✅ Fully Implemented & Production Ready

**Core Nutrition Planning:**
- Algorithmic nutrition plan generation (moved away from AI approach)
- Three-phase planning (before/during/after run)
- Real-time macro target adjustment with evidence-based validation
- Food swapping based on user preferences
- Plan saving and history with offline access

**User Management:**
- Device-based authentication (no user accounts required)
- Complete onboarding flow with biometric collection
- Three-tier food preference system (like/willing_to_try/dislike)
- Profile editing and preference updates
- Gut training level customization

**Data & Storage:**
- Complete offline-first architecture with Drift SQLite v6
- Dual database sync with Supabase PostgreSQL
- 24-hour refresh cycles for food and content data
- Device-based sync using device ID as identifier
- Conflict resolution with timestamp-based newest-wins strategy

**Voice Journal & Feedback:**
- Voice memo recording and playback functionality
- Plan effectiveness rating system (1-3 scale)
- User feedback collection with multi-page surveys
- Voice notes list with browsing and replay
- Feedback data sync to backend

**Content Management:**
- Dynamic UI text and algorithm parameters via backend
- Fat backend architecture for instant content updates
- Fallback to local defaults for offline functionality
- A/B testing capabilities for nutrition formulas

### 🔄 Partially Implemented

**Enhanced Analytics:**
- Mixpanel integration configured
- Analytics service and wrapper implemented
- Comprehensive tracking plan defined
- North-Star metric: Successful fueling plans per WAU
- Event tracking for plan lifecycle and user behavior

**Recipe Management:**
- Basic recipe domain models and repository structure
- Recipe screen placeholder implemented
- Full recipe functionality in development

**Barcode Scanning:**
- Barcode scanner screen implemented
- Integration with OpenFoodFacts and FDA nutrition database
- Food mapping service for product lookup

### 🚧 Planned Features

**Advanced Integrations:**
- Training platform integration (Strava, TrainingPeaks, Garmin)
- Wearable device data integration
- Race calendar integration
- Coach/athlete collaboration features

**Enhanced Functionality:**
- Carb loading calculator for race preparation
- Advanced nutrition tracking and logging
- Plan comparison and effectiveness analysis
- Social features for plan sharing

## Edge Functions & Backend Services

### Current Active Edge Functions (Supabase)
1. **`run-plan`** - Primary algorithmic nutrition planning (evidence-based ACSM formulas)
2. **`save-food-preferences`** - Three-tier preference management system
3. **`create-user`** - Device-based user creation with biometric data
4. **`get-foods`** - Food database retrieval with caching and filtering
5. **`create-nutrition-plan`** - Plan creation and storage
6. **`generate-macros`** - Macro target calculation
7. **`barcode-lookup`** - Product lookup via barcode scanning

### Integration Points
- **OpenFoodFacts API** - Food database and nutritional information
- **FDA Nutrition Database** - Validated nutritional data
- **Supabase PostgreSQL** - Primary backend database
- **Mixpanel** - Analytics and user behavior tracking
- **Sentry** - Error tracking and performance monitoring
- **Shorebird** - Over-the-air code push updates

### Authentication & Privacy
- **Device-Based Authentication**: No traditional user accounts
- **Privacy-First**: No email, password, or personal identification required
- **Device ID**: iOS identifierForVendor, Android Android ID
- **Anonymous Analytics**: Until user creates profile
- **Local Data Storage**: All data stored locally first, synced using device ID

## Development Workflow & Tools

### Code Generation & Build System
- **build_runner**: Riverpod providers and Drift database generation
- **riverpod_generator**: Automatic provider generation from @riverpod annotations
- **drift_dev**: Database migration and schema generation
- **flutter_launcher_icons**: App icon generation for all platforms
- **flutter_native_splash**: Splash screen configuration

### Quality Assurance & Testing
- **Testing Strategy**: Focused, speed-optimized approach for aggressive development
- **Integration Tests**: Critical business logic paths over unit tests
- **Real Dependencies**: In-memory databases and live API calls
- **Risk-Based Coverage**: Test 5% of functionality that causes 95% of user pain
- **Performance Focus**: Fast execution with Andrea Bizzotto's AsyncNotifier patterns

### Deployment & Distribution
- **Platforms**: iOS 12.0+ / Android API 21+
- **Code Push**: Shorebird for OTA updates without App Store releases
- **Analytics**: RudderStack → Mixpanel pipeline for user behavior tracking
- **Error Tracking**: Sentry integration with Drift database monitoring
- **Environment Management**: Development, staging, and production configurations

### Key Dependencies
```yaml
# Core Framework
flutter_riverpod: ^2.5.1          # State management
drift: ^2.20.0                     # Local database
supabase_flutter: ^2.8.5          # Backend integration
go_router: ^12.1.3                # Navigation

# UI & Design
google_fonts: ^6.1.0              # Typography
flutter_screenutil: ^5.9.3        # Responsive design
flutter_animate: ^4.5.0           # Animations

# Analytics & Monitoring
mixpanel_flutter: ^2.3.1          # User analytics
sentry_flutter: ^9.6.0            # Error tracking
sentry_drift: ^9.6.0              # Database monitoring

# Additional Features
speech_to_text: ^6.6.0            # Voice memo transcription
mobile_scanner: ^7.0.1            # Barcode scanning
flutter_local_notifications: ^19.4.1  # Local notifications
```

## Nutrition Science & Algorithm Implementation

### Evidence-Based Approach
- **ACSM Formulas**: Energy expenditure calculation using metabolic equations
- **ISSN Guidelines**: International Society of Sports Nutrition recommendations
- **Phase-Specific Rules**: Pre/during/post-run nutrition based on research
- **Individual Variation**: Gut training levels and personal tolerance factors

### Macro Target Guidelines
- **Carbohydrates**: Pre-workout 1–4g/kg body weight, During 30–60g/hour
- **Sodium**: 300–600mg/hour (up to 1000mg/hour in heat conditions)
- **Fluids**: ~0.4–0.8 L/hour depending on sweat rate and environment
- **Timing**: Evidence-based timing windows for optimal nutrient delivery

### Smart Food Selection
Advanced multi-factor scoring system:
1. **User Preferences**: Like (+20 pts) > Willing-to-try (+5 pts) > Neutral (0 pts)
2. **Phase Appropriateness**: Practicality and digestibility scoring
3. **Nutritional Efficiency**: Macro density and bioavailability
4. **Individual Tolerance**: GI sensitivity and gut training adaptations
5. **Environmental Factors**: Heat, humidity, aid station availability

## Current Production Status

**Live Status**: Production app with active users
**Continuous Improvement**: Nutrition algorithms and user experience based on athlete feedback
**Data Integration**: Real-world usage data informing algorithm refinements
**Platform Support**: iOS and Android with feature parity
**Offline Reliability**: Complete functionality without internet dependency

This comprehensive summary reflects the current state of a sophisticated, production-ready nutrition planning application built with modern Flutter architecture patterns, evidence-based sports nutrition science, and a strong focus on offline-first user experience.