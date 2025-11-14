# Implementation Guide - Kyle's Design System
## Step-by-Step Flutter Implementation

**Last Updated:** 2025-11-12
**Target Timeline:** 4-6 weeks
**Prerequisites:** Complete design token extraction

---

## Table of Contents
1. [Getting Started](#getting-started)
2. [Phase 0: Setup](#phase-0-setup)
3. [Phase 1: Theme Foundation](#phase-1-theme-foundation)
4. [Phase 2: Core Components](#phase-2-core-components)
5. [Phase 3: Screen Migration](#phase-3-screen-migration)
6. [Testing Strategy](#testing-strategy)
7. [Deployment](#deployment)

---

## Getting Started

### Prerequisites Checklist
- [ ] All Figma assets exported
- [ ] Font files acquired (Sansita, Compadre, Apercu)
- [ ] Color values confirmed
- [ ] Icon library selected (Font Awesome or custom SVGs)
- [ ] Development environment ready

### Project Structure
```
lib/
├── theme/
│   ├── app_theme.dart              # Main theme configuration
│   ├── colors.dart                 # Color palette
│   ├── text_styles.dart            # Typography system
│   ├── spacing.dart                # Spacing & layout
│   └── theme_provider.dart         # Theme state management
├── shared/
│   └── widgets/
│       └── kyle_design/
│           ├── buttons/
│           ├── inputs/
│           ├── cards/
│           ├── navigation/
│           ├── lists/
│           ├── icons/
│           ├── data/
│           └── feedback/
└── features/
    └── [existing features...]
```

---

## Phase 0: Setup
**Duration:** 1 day
**Goal:** Prepare environment and assets

### Step 1: Install Fonts

#### 1.1 Add Font Files
Place font files in project:
```
assets/
└── fonts/
    ├── Sansita-Bold.ttf
    ├── Compadre-Wide.ttf
    ├── Apercu-Regular.ttf
    ├── Apercu-Medium.ttf
    └── Apercu-Bold.ttf
```

#### 1.2 Update pubspec.yaml
```yaml
flutter:
  fonts:
    - family: Sansita
      fonts:
        - asset: assets/fonts/Sansita-Bold.ttf
          weight: 700

    - family: Compadre
      fonts:
        - asset: assets/fonts/Compadre-Wide.ttf
          weight: 400

    - family: Apercu
      fonts:
        - asset: assets/fonts/Apercu-Regular.ttf
          weight: 400
        - asset: assets/fonts/Apercu-Medium.ttf
          weight: 500
        - asset: assets/fonts/Apercu-Bold.ttf
          weight: 700
```

#### 1.3 Font Configuration
All required fonts are already available in assets/fonts/:

```yaml
flutter:
  fonts:
    - family: Sansita
      fonts:
        - asset: assets/fonts/Sansita/Sansita-Bold.ttf
          weight: 700

    - family: Compadre
      fonts:
        - asset: assets/fonts/Compadre/Compadre-Demo-Wide.otf
          weight: 400

    - family: Apercu
      fonts:
        - asset: assets/fonts/Apercu/Apercu Pro Regular.otf
          weight: 400
        - asset: assets/fonts/Apercu/Apercu Pro Medium.otf
          weight: 500
        - asset: assets/fonts/Apercu/Apercu Pro Bold.otf
          weight: 700
        - asset: assets/fonts/Apercu/Apercu Pro Mono.otf
          weight: 400
```

**Note:** Compadre fonts are demo versions. Full commercial license may be needed for production.

### Step 2: Install Icon Library

#### Font Awesome Free (Using pub.dev)
```yaml
dependencies:
  font_awesome_flutter: ^10.6.0
```

**Note:** Using Font Awesome Free icons instead of Pro. This provides sufficient icons for the design system.

Available icon categories needed:
- Activity icons: running, cycling, swimming
- Food icons: various food types
- UI icons: heart, times, plus, minus, info, warning

### Step 3: Install Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  riverpod_annotation: ^2.3.0
  flutter_riverpod: ^2.4.0
  font_awesome_flutter: ^10.6.0  # or flutter_svg
  cached_network_image: ^3.3.0   # for images
  # ... existing dependencies

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
  flutter_lints: ^3.0.0
  # ... existing dev dependencies
```

Run:
```bash
flutter pub get
```

---

## Phase 1: Theme Foundation
**Duration:** 2-3 days
**Goal:** Set up complete theming system

### Step 1: Create Color System

Create `/lib/theme/colors.dart`:
```dart
import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // Core Colors
  static const blackberry = Color(0xFF3D1F47);
  static const blackberryLight = Color(0xFF4A2854);
  static const blackberryDark = Color(0xFF2D1535);

  static const cream = Color(0xFFF5F3ED);
  static const creamDark = Color(0xFFE8E6E0);

  static const orange = Color(0xFFFF8B3D);
  static const orangeLight = Color(0xFFFFA05A);
  static const orangeDark = Color(0xFFE67A2E);

  static const electrolyte = Color(0xFF5DE4D3);
  static const electrolyteLight = Color(0xFF7FEEE0);
  static const electrolyteDark = Color(0xFF3FD4C0);

  static const dragonfruit = Color(0xFFE84393);
  static const dragonfruitLight = Color(0xFFF060A8);
  static const dragonfruitDark = Color(0xFFD0357E);

  // Semantic Colors
  static const success = electrolyte;
  static const error = dragonfruit;
  static const warning = orange;
  static const info = electrolyte;

  // Neutral Colors
  static const inactive = Color(0xFF9B8AA3);
  static const disabled = Color(0xFF6B5C6F);
}
```

### Step 2: Create Typography System

Create `/lib/theme/text_styles.dart`:
```dart
import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();

  // Font families
  static const String sansita = 'Sansita';
  static const String compadre = 'Compadre';
  static const String apercu = 'Apercu';

  // Headings (Sansita Bold)
  static const pageTitle = TextStyle(
    fontFamily: sansita,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const sectionTitle = TextStyle(
    fontFamily: sansita,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const dateTime = TextStyle(
    fontFamily: sansita,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  // Activity & Food Titles (Compadre Wide)
  static const activityTitle = TextStyle(
    fontFamily: compadre,
    fontSize: 18,
    height: 1.3,
    letterSpacing: 0.5,
  );

  static const subtitle = TextStyle(
    fontFamily: compadre,
    fontSize: 16,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const descriptor = TextStyle(
    fontFamily: compadre,
    fontSize: 14,
    height: 1.4,
    letterSpacing: 0.5,
  );

  static const foodTitle = TextStyle(
    fontFamily: compadre,
    fontSize: 16,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Body & Data (Apercu)
  static const bodyLarge = TextStyle(
    fontFamily: apercu,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontFamily: apercu,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const dataNumber = TextStyle(
    fontFamily: apercu,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  static const dataNumberLarge = TextStyle(
    fontFamily: apercu,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const inputText = TextStyle(
    fontFamily: apercu,
    fontSize: 16,
    height: 1.4,
  );

  static const smallLabel = TextStyle(
    fontFamily: apercu,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w500,
  );

  // Buttons
  static const buttonPrimary = TextStyle(
    fontFamily: sansita,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const buttonTertiary = TextStyle(
    fontFamily: apercu,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
}
```

### Step 3: Create Spacing System

Create `/lib/theme/spacing.dart`:
```dart
import 'package:flutter/material.dart';

class AppSpacing {
  AppSpacing._();

  // Spacing scale (8pt grid)
  static const double unit = 8.0;
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // Common paddings
  static const screenPadding = EdgeInsets.all(md);
  static const screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: md);
  static const cardPadding = EdgeInsets.all(md);
  static const buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: sm,
  );
  static const listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}

class AppRadius {
  AppRadius._();

  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  static const double circular = 999.0;

  static const smallRadius = BorderRadius.all(Radius.circular(small));
  static const mediumRadius = BorderRadius.all(Radius.circular(medium));
  static const largeRadius = BorderRadius.all(Radius.circular(large));
  static const xlargeRadius = BorderRadius.all(Radius.circular(xlarge));

  // Component-specific
  static const buttonRadius = BorderRadius.all(Radius.circular(large));
  static const cardRadius = BorderRadius.all(Radius.circular(medium));
  static const inputRadius = BorderRadius.all(Radius.circular(small));
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get lightCardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get lightElevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get darkCardShadow => [];

  static List<BoxShadow> get darkElevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
}

class AppIconSizes {
  AppIconSizes._();

  static const double small = 16.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xlarge = 48.0;

  static const double tabBar = 24.0;
  static const double listItem = 24.0;
  static const double button = 20.0;
  static const double foodIcon = 28.0;
  static const double activityIcon = 32.0;
}
```

### Step 4: Create Theme Configuration

Create `/lib/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
import 'spacing.dart';

class AppTheme {
  AppTheme._();

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: AppColors.orange,
        secondary: AppColors.electrolyte,
        tertiary: AppColors.dragonfruit,
        background: AppColors.cream,
        surface: Colors.white,
        onBackground: AppColors.blackberry,
        onSurface: AppColors.blackberry,
        onPrimary: AppColors.blackberry,
        error: AppColors.dragonfruit,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.cream,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.blackberry,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.blackberry,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
        shadowColor: Colors.black.withOpacity(0.08),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.blackberry,
          textStyle: AppTextStyles.buttonPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blackberry,
          textStyle: AppTextStyles.buttonPrimary,
          side: const BorderSide(
            color: AppColors.blackberry,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dragonfruit,
          textStyle: AppTextStyles.buttonTertiary,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: AppColors.blackberry.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: AppColors.blackberry.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(
            color: AppColors.orange,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.blackberry.withOpacity(0.1),
        thickness: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.blackberry,
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: AppTextStyles.pageTitle.copyWith(
          color: AppColors.blackberry,
        ),
        displayMedium: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.blackberry,
        ),
        headlineMedium: AppTextStyles.activityTitle.copyWith(
          color: AppColors.blackberry,
        ),
        titleLarge: AppTextStyles.subtitle.copyWith(
          color: AppColors.blackberry,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.blackberry,
        ),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.blackberry.withOpacity(0.7),
        ),
        labelLarge: AppTextStyles.buttonPrimary,
        labelSmall: AppTextStyles.smallLabel.copyWith(
          color: AppColors.blackberry.withOpacity(0.6),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.electrolyte,
        tertiary: AppColors.dragonfruit,
        background: AppColors.blackberry,
        surface: AppColors.blackberryLight,
        onBackground: AppColors.cream,
        onSurface: AppColors.cream,
        onPrimary: AppColors.blackberry,
        error: AppColors.dragonfruit,
      ),

      // Scaffold
      scaffoldBackgroundColor: AppColors.blackberry,

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.cream,
        ),
        iconTheme: const IconThemeData(
          color: AppColors.cream,
        ),
      ),

      // Card
      cardTheme: CardTheme(
        color: AppColors.blackberryLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.blackberry,
          textStyle: AppTextStyles.buttonPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cream,
          textStyle: AppTextStyles.buttonPrimary,
          side: const BorderSide(
            color: AppColors.cream,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.dragonfruit,
          textStyle: AppTextStyles.buttonTertiary,
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.blackberryLight.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: AppColors.cream.withOpacity(0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: BorderSide(
            color: AppColors.cream.withOpacity(0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputRadius,
          borderSide: const BorderSide(
            color: AppColors.orange,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.cream.withOpacity(0.1),
        thickness: 1,
      ),

      // Icon theme
      iconTheme: const IconThemeData(
        color: AppColors.cream,
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: AppTextStyles.pageTitle.copyWith(
          color: AppColors.cream,
        ),
        displayMedium: AppTextStyles.sectionTitle.copyWith(
          color: AppColors.cream,
        ),
        headlineMedium: AppTextStyles.activityTitle.copyWith(
          color: AppColors.cream,
        ),
        titleLarge: AppTextStyles.subtitle.copyWith(
          color: AppColors.cream,
        ),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(
          color: AppColors.cream,
        ),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.cream.withOpacity(0.7),
        ),
        labelLarge: AppTextStyles.buttonPrimary,
        labelSmall: AppTextStyles.smallLabel.copyWith(
          color: AppColors.cream.withOpacity(0.6),
        ),
      ),
    );
  }
}
```

### Step 5: Apply Theme to App

Update `/lib/shared/widgets/root_app_widget.dart` or `/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';

class RootAppWidget extends ConsumerWidget {
  const RootAppWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Mealvana Endurance',

      // Apply new themes
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system, // or use theme provider

      // ... rest of your router config
    );
  }
}
```

### Step 6: Create Theme Provider (Optional)

If you want users to manually toggle themes:

Create `/lib/theme/theme_provider.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  ThemeMode build() {
    // Load from storage or default to system
    // You could use shared_preferences here
    return ThemeMode.system;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
    // Persist to storage
  }

  void toggleTheme() {
    if (state == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }
}
```

Run code generation:
```bash
dart run build_runner build --delete-conflicting-outputs
```

Update root app widget:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final themeMode = ref.watch(themeModeNotifierProvider);

  return MaterialApp.router(
    theme: AppTheme.lightTheme(),
    darkTheme: AppTheme.darkTheme(),
    themeMode: themeMode,
    // ... rest of config
  );
}
```

---

## Phase 2: Core Components
**Duration:** 1-2 weeks
**Goal:** Build reusable component library

### Component Implementation Order

**Week 1:**
1. Buttons (Primary, Secondary, Tertiary, Icon)
2. Text Inputs
3. Base Card
4. App Bar

**Week 2:**
5. Plus/Minus Control
6. Segmented Control
7. Activity Icon
8. Food Icon

### Example: Refactoring Primary Button

Update `/lib/shared/widgets/primary_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/colors.dart';
import 'package:mealvana_endurance/theme/text_styles.dart';
import 'package:mealvana_endurance/theme/spacing.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.blackberry,
          disabledBackgroundColor: AppColors.orange.withOpacity(0.4),
          textStyle: AppTextStyles.buttonPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.blackberry,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: AppIconSizes.button),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(text),
                ],
              ),
      ),
    );
  }
}
```

**Usage:**
```dart
PrimaryButton(
  text: 'Generate Plan',
  onPressed: () {
    // Action
  },
)
```

### Testing Each Component

Create widget tests for each component:

`/test/widgets/kyle_design/buttons/primary_button_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';

void main() {
  testWidgets('PrimaryButton displays text correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: PrimaryButton(
            text: 'Test Button',
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test Button'), findsOneWidget);
  });

  testWidgets('PrimaryButton calls onPressed when tapped', (tester) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: PrimaryButton(
            text: 'Test',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PrimaryButton));
    expect(pressed, isTrue);
  });

  testWidgets('PrimaryButton shows loading indicator', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme(),
        home: Scaffold(
          body: PrimaryButton(
            text: 'Test',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test'), findsNothing);
  });
}
```

Run tests:
```bash
flutter test test/widgets/kyle_design/buttons/primary_button_test.dart
```

---

## Phase 3: Screen Migration
**Duration:** 2-3 weeks
**Goal:** Update existing screens to use new design

### Migration Strategy

1. **One screen at a time** - Complete migration before moving to next
2. **Test thoroughly** - Both light and dark modes
3. **Maintain functionality** - No regressions
4. **Feature flags** (optional) - Gradual rollout

### Example: Migrating a Screen

**Before:**
```dart
// Old implementation
class OldActivityDetailScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Activity Details')),
      body: Container(
        child: ElevatedButton(
          child: Text('Save'),
          onPressed: () {},
        ),
      ),
    );
  }
}
```

**After:**
```dart
// New implementation with Kyle's design
import 'package:mealvana_endurance/shared/widgets/kyle_design/navigation/custom_app_bar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';

class NewActivityDetailScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Activity Details',
        showBackButton: true,
      ),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          children: [
            // ... content
            Spacer(),
            PrimaryButton(
              text: 'Save Changes',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
```

### Screen Migration Checklist

For each screen:
- [ ] Update AppBar to CustomAppBar
- [ ] Replace buttons with Kyle design buttons
- [ ] Update card components
- [ ] Update text styles
- [ ] Update spacing and padding
- [ ] Test in light mode
- [ ] Test in dark mode
- [ ] Test on iOS
- [ ] Test on Android
- [ ] Verify no regressions
- [ ] Code review
- [ ] Designer approval

---

## Testing Strategy

### Unit Tests
Test individual components in isolation

### Widget Tests
Test component interactions and state

### Integration Tests
Test full screen flows

### Visual Regression Tests
Use `golden_toolkit` for screenshot comparison

```yaml
dev_dependencies:
  golden_toolkit: ^0.15.0
```

Example golden test:
```dart
testGoldens('PrimaryButton golden test', (tester) async {
  final builder = DeviceBuilder()
    ..overrideDevicesForAllScenarios(devices: [Device.phone])
    ..addScenario(
      widget: PrimaryButton(text: 'Test Button', onPressed: () {}),
      name: 'default',
    )
    ..addScenario(
      widget: PrimaryButton(text: 'Loading', isLoading: true, onPressed: () {}),
      name: 'loading',
    );

  await tester.pumpDeviceBuilder(builder);
  await screenMatchesGolden(tester, 'primary_button');
});
```

---

## Deployment

### Pre-Release Checklist
- [ ] All screens migrated
- [ ] All tests passing
- [ ] Designer approval
- [ ] Performance profiling complete
- [ ] Accessibility audit complete
- [ ] Both themes working perfectly
- [ ] Documentation updated

### Release Strategy

**Option 1: Big Bang (All at once)**
- Ship complete redesign
- Risks: High if bugs found
- Best for: Small user base

**Option 2: Phased Rollout**
- Use Shorebird or feature flags
- Release to 10% → 25% → 50% → 100%
- Best for: Large user base

**Option 3: Feature Flag per Screen**
```dart
if (FeatureFlags.useKyleDesign) {
  return NewActivityScreen();
} else {
  return OldActivityScreen();
}
```

### Rollback Plan
- Keep old components for 1-2 versions
- Feature flag to revert if needed
- Monitor analytics for issues

---

## Troubleshooting

### Common Issues

**Issue:** Fonts not displaying
**Solution:** Verify font files exist and pubspec.yaml is correct. Run `flutter clean && flutter pub get`

**Issue:** Colors look different than Figma
**Solution:** Use color picker to get exact hex values. Check device brightness and color profile.

**Issue:** Spacing looks off
**Solution:** Verify using 8pt grid. Check padding vs margin. Use Flutter Inspector.

**Issue:** Dark mode not switching
**Solution:** Verify theme provider is wired correctly. Check system theme settings.

---

## Next Steps

1. ✅ Complete Phase 0 setup
2. ⏳ Implement Phase 1 theme foundation
3. ⏳ Build Phase 2 component library
4. ⏳ Migrate screens in Phase 3
5. ⏳ Test and deploy

**Happy coding! 🚀**

---

**Document Status:** Ready for Implementation
**Maintainer:** Development Team
**Questions?** Refer to DESIGN_TOKENS.md and COMPONENTS_CATALOG.md
