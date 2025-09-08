# Mealvana Endurance Documentation Overview

## Document Structure

This directory contains all markdown documents organized and translated from the `mealvana_endurance/` subproject, categorized according to the following classification:

### 01_brainstorm (Brainstorming and Planning)
- `project_roadmap.md` / `project_roadmap_zh.md` - Project development roadmap and phase planning

### 02_requirements (Product Requirements)
- `project_requirements.md` / `project_requirements_zh.md` - Project requirements and design specifications
- `nutrition_guidelines.md` / `nutrition_guidelines_zh.md` - Endurance athlete nutrition planning guidelines
- `app_overview.md` / `app_overview_zh.md` - Application overview and core features

### 03_architecture (Architecture Design)
- `app_architecture.md` / `app_architecture_zh.md` - Application architecture design and system overview

### 04_technical (Technical Design)
- `technical_design.md` / `technical_design_zh.md` - Technical design guide and development patterns
- `fat_backend_design.md` / `fat_backend_design_zh.md` - Fat backend architecture design
- `content_management_design.md` / `content_management_design_zh.md` - Content management system design

### 05_uiux (User Interface and User Experience)
- `design_system.md` / `design_system_zh.md` - UI/UX design system and component specifications

## Document Index

### Primary Source Documents
The following are the main source documents analyzed and organized from the `mealvana_endurance/` directory:

#### Core Project Documents
- `../README.md` → `02_requirements/app_overview.md`
- `../requirements/README.md` → `02_requirements/project_requirements.md`
- `../requirements/nutrition_plan_guidelines.md` → `02_requirements/nutrition_guidelines.md`

#### Architecture Design
- `../architecture/README.md` → `03_architecture/app_architecture.md`

#### Technical Design
- `../technical/README.md` → `04_technical/technical_design.md`
- `../technical/fat-backend-architecture.md` → `04_technical/fat_backend_design.md`
- `../technical/content-management.md` → `04_technical/content_management_design.md`

#### Design System
- `../uiux/README.md` → `05_uiux/design_system.md`

#### Planning Documents
- `../roadmap/README.md` → `01_brainstorm/project_roadmap.md`

### Additional Important Source Documents (Accessible via Reference)

The following documents remain accessible in their original locations and are indirectly referenced through this organized documentation:

#### Business Logic and Algorithms
- `../business_logic/README.md` - Business logic and Edge Functions overview
- `../business_logic/nutrition_algorithms.md` - Detailed nutrition calculation algorithm documentation
- `../business_logic/edge-functions-readme.md` - Edge Functions deployment and usage guide
- `../business_logic/food-preferences-system-overview.md` - Food preferences system documentation

#### Detailed Technical Documents
- `../technical/drift-implementation.md` - Drift database implementation
- `../technical/drift-migration-guide.md` - Drift migration guide
- `../technical/shorebird-code-push.md` - Shorebird code push
- `../technical/supabase-integration-guide.md` - Supabase integration guide
- `../technical/sentry-integration.md` - Sentry integration
- `../technical/foa-architecture.md` - FOA architecture detailed explanation

#### Database and Storage
- `../database/README.md` - Database overview
- `../database/DRIFT.md` - Drift implementation documentation
- `../database/schema-overview.md` - Database schema overview
- `../database/DEPLOYMENT-GUIDE.md` - Deployment guide

#### Feature Documentation
- `../features/eat_my_ride_screen/adjust_macros_screen_README.md` - Macro adjustment screen
- `../features/eat_my_ride_screen/implementation_timeline.md` - Implementation timeline

#### Privacy and Compliance
- `../privacy/app_store_privacy_details.md` - App Store privacy details
- `../privacy/privacy_manifest_explanation.md` - Privacy manifest explanation

#### Project Management
- `../roadmap/daily_progress.md` - Daily progress tracking
- `../HIVE_TO_DRIFT_MIGRATION_ROADMAP.md` - Hive to Drift migration roadmap
- `../INTEGRATION_TEST_SUMMARY.md` - Integration test summary

#### Testing Documentation
- `../test/nutrition_plan/README.md` - Nutrition plan testing
- `../test/nutrition_plan/algorithm_report.md` - Algorithm report
- `mealvana_endurance/test/sentry/README.md` - Sentry testing

#### Configuration and Deployment
- `mealvana_endurance/ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` - iOS launch image assets
- `mealvana_endurance/lib/features/nutrition_plan/data/nutrition_guidance_content.md` - Nutrition guidance content

## Documentation Organization Principles

1. **Translation Focus** - Core emphasis on accurate translation of original content, not content creation
2. **Categorical Organization** - Classification by functional type (requirements, architecture, technical, design)
3. **Bilingual Support** - Core documents provide both English and Chinese versions, distinguished by `_zh` suffix
4. **Source Attribution** - Each document annotated with original file path at the end
5. **Content Integrity** - Strictly maintain completeness and accuracy of original document content

## Usage Guidelines

- **English Version** - Use original filenames directly
- **Chinese Version** - Filenames with `_zh` suffix
- **Quick Access** - Locate relevant documents through categorical directories
- **Cross Reference** - Documents reference each other using relative paths
- **Source Documents** - Refer to original source document paths for detailed information when needed

This organization ensures all important documents from the mealvana_endurance project are properly organized and translated, facilitating subsequent content analysis work.