# Technology Stack

## Core Framework
- **Flutter**: 3.8+ with Dart SDK ^3.8.1
- **State Management**: Riverpod 2.x with code generation (@riverpod annotation)
- **Navigation**: go_router 12.1.3

## Database & Storage
- **Local Database**: Drift (SQLite with type-safe migrations and code generation)
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Data Architecture**: Offline-first with sync capabilities

## Key Dependencies
- **UI Components**: flutter_staggered_animations, shimmer, smooth_page_indicator, percent_indicator
- **Forms**: flutter_rating_bar, numberpicker
- **Theming**: google_fonts, flutter_screenutil
- **Analytics**: mixpanel_flutter (via RudderStack pipeline)
- **Error Tracking**: sentry_flutter with sentry_drift integration
- **Code Push**: Shorebird for OTA updates
- **Utilities**: uuid, intl, http, device_info_plus, package_info_plus

## Development Tools
- **Code Generation**: build_runner, riverpod_generator, drift_dev
- **Testing**: flutter_test, flutter_lints
- **Assets**: flutter_launcher_icons, flutter_native_splash
- **Linting**: flutter_lints with package:flutter_lints/flutter.yaml

## Platform Support
- **iOS**: 12.0+
- **Android**: API 21+
- **Web**: Supported
- **Platform**: Darwin (macOS development environment)