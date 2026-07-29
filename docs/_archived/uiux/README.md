# Mealvana Endurance UI/UX Design System

## Overview
This document defines the complete design system for Mealvana Endurance MVP, incorporating modern Flutter theming best practices and UI patterns optimized for nutrition planning apps. This follows Material Design 3 principles with custom nutrition-specific extensions.

## Design Tokens

### Typography
Based on the reference design, we have the following text styles:

**Font Family:** Inter (with system fallbacks: iOS: SF Pro, Android: Roboto)

**Font Weights:**
- Regular (400)
- Medium (500) 
- SemiBold (600)
- Bold (700)

**Text Styles:**
- **title** - Large, bold headings for main screens
- **subtitle** - Mini variant for secondary headings
- **heading1** - Primary section headers
- **heading2** - Secondary section headers  
- **heading3** - Tertiary section headers
- **calendar** - Specialized text for date/time displays
- **text** - Regular body text with crossed-out variant
- **note** - Smaller text for supplementary information

**Font Variants:**
- `Nutrition_regular` - Standard weight
- `Nutrition_regular_oblique` - Italic variant
- `Nutrition_regular_bold` - Bold weight
- `Nutrition_title` - Title-specific styling
- `Nutrition_large` - Large text variant

### Color Palette

**Primary Colors (Blues):**
- Primary Dark: `#1E3A8A` (darkest blue)
- Primary Medium: `#3B82F6` (medium blue) 
- Primary Light: `#DBEAFE` (lightest blue)
- Primary Lightest: `#F0F9FF` (very light blue)

**Highlight Colors (Coral/Pink):**
- Highlight Dark: `#EF4444` (coral red)
- Highlight Medium: `#F87171` (light coral)
- Highlight Light: `#FCA5A5` (lighter coral)
- Highlight Accent: `#EC4899` (bright pink)
- Highlight Deep: `#BE185D` (deep pink)

**Base Colors (Neutrals):**
- Base Dark: `#000000` (pure black)
- Base Medium: `#6B7280` (medium gray)

**Warning Colors:**
- Warning: `#F59E0B` (amber/yellow)

### Shadows and Effects

**Drop Shadow:**
- Standard glow effect for elevated elements

**Tab Bar Shadow:**
- Subtle shadow for navigation elements

**Checkbox Drop Shadow:**
- Light shadow for form elements and interactive components

## Component Specifications

### Buttons
- **Primary Button:** Filled style with primary colors and rounded corners (8px border radius)
- **Secondary Button:** Outlined style with highlight colors and rounded corners
- **Text Button:** Uses base colors with minimal styling
- **All buttons:** Default to filled style with rounded corners

### Form Elements
- **Checkboxes:** Include drop shadow effect with rounded corners
- **Input Fields:** Clean, minimal styling with focus states and rounded corners (8px border radius)
- **Selection Controls:** Clear visual feedback for user choices with rounded corners
- **All form elements:** Consistent rounded corner treatment

### Cards and Containers
- **Nutrition Plan Cards:** Clean layout with clear typography hierarchy
- **Information Cards:** Use shadow effects for depth

### Navigation
- **Tab Bar:** Bottom navigation with shadow
- **Screen Headers:** Bold title typography

## Layout Principles

### Spacing
- **Base Unit:** 8px grid system
- **Component Padding:** 16px default
- **Section Margins:** 24px between major sections
- **Element Spacing:** 8px between related elements
- **Responsive Sizing:** flutter_screenutil package for consistent sizing across devices

### Screen Structure
- **Header:** Title + optional subtitle
- **Content:** Main interaction area
- **Navigation:** Bottom tab bar (when applicable)

## Accessibility

### Contrast Requirements
- All text meets WCAG AA contrast standards
- Interactive elements have clear focus indicators
- Color is not the only indicator of state changes

### Typography
- Minimum 16px font size for body text
- Clear hierarchy with appropriate size differences
- Support for dynamic type/font scaling

## Responsive Design

### flutter_screenutil Package
We use the `flutter_screenutil` package to ensure consistent sizing across different screen sizes and densities.

**Usage:**
- All dimensions should use `.w` (width), `.h` (height), or `.sp` (font size) extensions
- Base design reference: iPhone 14 Pro (393×852 logical pixels)
- Automatic scaling for tablets, different phone sizes, and screen densities

```dart
// Example usage
Container(
  width: 200.w,        // Responsive width
  height: 100.h,       // Responsive height  
  padding: EdgeInsets.all(16.w),  // Responsive padding
  child: Text(
    'Hello',
    style: TextStyle(fontSize: 16.sp), // Responsive font size
  ),
)
```

## Modern Flutter Theming Implementation (2024/2025)

### Material Design 3 with ColorScheme.fromSeed()

**Primary Theme Configuration:**
```dart
// lib/theme/app_theme.dart
class AppTheme {
  // Use existing brand blue as seed color
  static const Color _seedColor = Color(0xFF3B82F6);
  
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    extensions: const [NutritionThemeExtension.light],
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    extensions: const [NutritionThemeExtension.dark],
  );
}
```

### ThemeExtension for Nutrition-Specific Design Tokens

**Custom Nutrition Colors:**
```dart
// lib/theme/nutrition_theme_extension.dart
@immutable
class NutritionThemeExtension extends ThemeExtension<NutritionThemeExtension> {
  // Macro-specific colors for nutrition data
  final Color? proteinColor;    // Pink for protein
  final Color? carbsColor;      // Orange for carbs  
  final Color? fatsColor;       // Purple for fats
  final Color? caloriesColor;   // Blue for calories
  
  // Custom text styles for nutrition labels
  final TextStyle? macroLabelStyle;
  final TextStyle? macroValueStyle;
  final TextStyle? nutritionFactStyle;
  
  // Light theme colors
  static const light = NutritionThemeExtension(
    proteinColor: Color(0xFFE91E63),
    carbsColor: Color(0xFFFF9800),
    fatsColor: Color(0xFF9C27B0),
    caloriesColor: Color(0xFF2196F3),
    macroLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    macroValueStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );
}

// Easy access extension
extension NutritionThemeContext on BuildContext {
  NutritionThemeExtension get nutritionTheme =>
      Theme.of(this).extension<NutritionThemeExtension>()!;
}
```

### Typography with Google Fonts Integration

**Modern Inter Font Setup:**
```dart
// Typography optimized for nutrition data display
static TextTheme get lightTextTheme {
  return GoogleFonts.interTextTheme().copyWith(
    // Large numbers for calories/macros
    displayLarge: GoogleFonts.inter(
      fontSize: 48,
      fontWeight: FontWeight.bold,
      height: 1.1,
    ),
    // Nutrition plan titles
    headlineMedium: GoogleFonts.inter(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      height: 1.3,
    ),
    // Food item names
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    // Nutrition labels
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.3,
    ),
  );
}
```

### Component Theming for Nutrition App

**ElevatedButton Theme:**
```dart
static ElevatedButtonThemeData elevatedButtonTheme(ColorScheme colorScheme) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  );
}
```

**InputDecoration Theme:**
```dart
static InputDecorationTheme inputDecorationTheme(ColorScheme colorScheme) {
  return InputDecorationTheme(
    filled: true,
    fillColor: colorScheme.surfaceContainerHighest,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colorScheme.primary, width: 2),
    ),
    contentPadding: EdgeInsets.all(16),
  );
}
```

## Screen-Specific UI Patterns & Widgets

### 1. Onboarding Screen Design

**Modern Onboarding Best Practices:**
- Streamlined process with minimal cognitive load
- Visual progress indicators
- Clear value proposition on each step
- Smooth micro-animations between steps

**Recommended Widgets & Packages:**
```dart
// Core widgets for onboarding flow
PageView              // Horizontal swipe navigation
AnimatedSmoothIndicator // Page indicators with animations  
Lottie               // Custom illustrations/animations
flutter_staggered_animations // Entrance animations
```

**Screen Structure:**
```
Step 1: Welcome + Value Proposition
  └── Hero illustration (Lottie animation)
  └── App benefits in 3 bullet points
  └── "Get Started" CTA

Step 2: Basic Info Collection
  └── Form with gender, birthday, height, weight
  └── Single-column layout with floating labels
  └── Progress indicator at top

Step 3: Running Habits  
  └── "Do you run with a water bottle?" toggle
  └── Visual representation of running scenarios
  └── Continue button

Step 4: Food Preferences (The Checklist Screen)
  └── Category-organized food list
  └── Three-state selection (Like/Dislike/Open to Try)
  └── Progress completion percentage
```

### 2. Food Preferences Selection (Checklist Screen)

**UI Pattern Research Findings:**
Modern nutrition apps prioritize:
- Category-based organization (Pre-run, During-run, After-run foods)
- Clear three-state selection with visual feedback
- Progress indication to encourage completion
- Ability to skip unfamiliar foods

**Recommended Implementation:**
```dart
// Widgets for food preference selection
ListView.builder      // Efficient scrolling list
FilterChip           // Three-state food selection chips
AnimatedContainer    // Selection state animations
LinearPercentIndicator // Progress bar
Card                 // Food category grouping
shimmer              // Loading skeleton while data loads
```

**Food Selection UI Components:**
```dart
// Custom three-state selection widget
class FoodPreferenceChip extends StatefulWidget {
  final String foodName;
  final FoodPreference currentPreference;
  final VoidCallback onChanged;
  
  // Shows: Like (green check), Dislike (red X), Open to Try (orange ?)
}

// Category header with collapse/expand
class FoodCategoryHeader extends StatelessWidget {
  final String categoryName; // "Pre-run Foods", "During-run Foods", etc.
  final int totalItems;
  final int completedItems;
  final bool isExpanded;
}
```

### 3. Main Nutrition Planning Screen

**Key UI Requirements:**
- Quick distance/pace input
- "Generate Plan" CTA that feels immediate  
- Clean plan display with clear hierarchy
- Easy-to-scan macro information

**Recommended Widgets & Packages:**
```dart
// Input and display widgets
NumberPicker          // Distance and pace selection
Card                  // Plan sections (pre-run, during-run, after-run)
AnimatedNumber        // Animated macro displays
ExpansionTile         // Collapsible plan sections  
LinearProgressIndicator // Macro progress bars
flutter_staggered_animations // Plan appearance animations
```

**Plan Display Structure:**
```
Header: Generated Plan Title + Generate New Button

Macro Summary Card:
├── Calories: 1,847 / 2,200 (with progress bar)
├── Carbs: 285g (large, prominent number)
├── Sodium: 800-1200mg 
└── Fluids: 40-48 oz

Plan Sections (Expandable Cards):
├── Before Run (1-2 hours before)
├── During Run (every 30 minutes)  
└── After Run (within 30 minutes)
```

### 4. Feedback Screen

**Feedback Collection Pattern:**
- Two-step feedback process
- Visual rating systems rather than text input
- Progressive disclosure (show options based on previous answers)

**Recommended Implementation:**
```dart
// Feedback widgets
RatingBar            // Visual star/thumbs rating
ChoiceChip          // Multiple choice selection
TextField           // Optional text suggestions
AnimatedSwitcher    // Smooth transitions between questions
```

**Feedback Flow Structure:**
```
Question 1: Plan Feedback
├── "Pretty close to what I think I should use"
├── "Much more than what I think I should use"  
└── "Much less than what I think I should use"

Question 2: App Feedback (based on Q1 response)
├── "I like it! Remind me to use it"
├── "It has potential but I need it to..." → Text input
└── "Not interested" → Optional reason chips
```

## Essential Flutter Packages for Modern Nutrition App UI

### Core UI & Animation Packages
```yaml
dependencies:
  # Theming & Fonts
  google_fonts: ^6.1.0          # Modern typography
  flutter_screenutil: ^5.9.0    # Responsive sizing
  
  # UI Components  
  flutter_staggered_animations: ^1.1.1  # List/grid animations
  shimmer: ^3.0.0                       # Loading skeletons
  animated_smooth_indicator: ^1.0.1     # Page indicators
  percent_indicator: ^4.2.2             # Progress displays
  
  # Form & Input
  flutter_rating_bar: ^4.0.1     # Star ratings
  choice_chip: ^2.0.0            # Multi-select chips
  number_picker: ^2.1.2          # Numeric input
  
  # Visual Elements
  lottie: ^2.7.0                 # Animations & illustrations
  cached_network_image: ^3.3.0   # Optimized images
  card_swiper: ^3.0.1           # Card animations
  
  # Navigation & State
  go_router: ^12.1.3            # Modern navigation
  provider: ^6.1.1              # State management
```

### Advanced Animation Packages (Optional)
```yaml
  # Spring animations
  sprung: ^3.0.1                # Natural spring animations
  
  # Advanced transitions  
  simple_animations: ^5.0.2     # Stateless animations
  
  # Micro-interactions
  flutter_animate: ^4.2.0       # CSS-like animations
```

## Screen Layout Patterns

### Consistent Layout Structure
```dart
// Standard screen wrapper for all app screens
class NutritionScreenLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: actions,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: body,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
```

### Card-Based Information Display
```dart
// Nutrition data card with consistent styling
class NutritionDataCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24.sp),
                SizedBox(width: 8.w),
                Text(label, style: context.nutritionTheme.macroLabelStyle),
              ],
            ),
            SizedBox(height: 8.h),
            Text(value, style: context.nutritionTheme.macroValueStyle?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
```

### Design Assets Required
- [ ] Splash screen design and implementation  
- [ ] Launcher icons for iOS and Android (all required sizes)
- [ ] App icon variations
- [ ] Food category icons (pre-run, during-run, after-run)
- [ ] Loading state indicators and shimmer placeholders
- [ ] Success/error state icons
- [ ] Onboarding illustration assets (consider Lottie animations)
- [ ] Empty state illustrations
- [ ] Food preference selection icons (thumbs up/down, question mark)

## Theme Management & Dark Mode

### System Theme Detection with Provider
```dart
// lib/core/theme/theme_provider.dart
enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  AppThemeMode _themeMode = AppThemeMode.system;
  
  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light: return ThemeMode.light;
      case AppThemeMode.dark: return ThemeMode.dark;  
      case AppThemeMode.system: return ThemeMode.system;
    }
  }
  
  Future<void> setThemeMode(AppThemeMode mode) async {
    _themeMode = mode;
    await _saveThemeMode();
    notifyListeners();
  }
}
```

### Main App Integration
```dart
// lib/main.dart
class NutritionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.currentThemeMode,
          // ... rest of app config
        );
      },
    );
  }
}
```

## Animation Guidelines

### Material Motion Principles
- **Duration**: Fast (100ms), Medium (300ms), Slow (500ms)
- **Curves**: Use Material 3 curves (easeInOutCubic for emphasis)
- **Staggered animations**: For list items and cards
- **Spring animations**: For interactive elements and feedback

### Custom Animation Components
```dart
// lib/widgets/animated_nutrition_card.dart
class AnimatedNutritionCard extends StatefulWidget {
  // Staggered entrance animation for nutrition cards
  // Scale + fade animation on appearance
  // Spring animation on tap interactions
}

class NutritionPageRoute<T> extends PageRouteBuilder<T> {
  // Custom page transitions with Material 3 motion
  // Slide transition with easeInOutCubic curve
  // 300ms duration for smooth navigation
}
```

## Accessibility & Inclusive Design

### Key Accessibility Features
- **Color Contrast**: All text meets WCAG AA standards (4.5:1 ratio)
- **Touch Targets**: Minimum 48dp touch targets for all interactive elements
- **Focus Management**: Clear focus indicators and logical tab order
- **Semantic Labels**: Screen reader support for all interactive elements
- **Dynamic Type**: Support for system font scaling
- **Color Independence**: No critical information conveyed by color alone

### Implementation Examples
```dart
// Accessible button with semantic labels
ElevatedButton(
  onPressed: _generatePlan,
  child: Text('Generate Nutrition Plan'),
  // Automatic semantic labeling with Material 3
)

// Progress indicator with semantic value
LinearProgressIndicator(
  value: completionPercentage,
  semanticsLabel: 'Food preferences completion',
  semanticsValue: '${(completionPercentage * 100).round()}% complete',
)
```

## Performance Optimizations

### Widget Optimization Strategies
- **const constructors**: Use for static widgets
- **ListView.builder**: For dynamic lists (food preferences)
- **Cached images**: Use cached_network_image for food images
- **Shimmer loading**: Reduce perceived loading time
- **Hero animations**: Smooth navigation between screens

### Memory Management
```dart
// Efficient list rendering
ListView.builder(
  itemCount: foods.length,
  itemBuilder: (context, index) {
    return const FoodPreferenceCard(
      key: ValueKey(foods[index].id),
      food: foods[index],
    );
  },
)

// Image caching for food icons
CachedNetworkImage(
  imageUrl: food.imageUrl,
  placeholder: (context, url) => ShimmerCard(),
  errorWidget: (context, url, error) => DefaultFoodIcon(),
)
```

## Development Best Practices

### Code Organization
```
lib/
├── theme/
│   ├── app_theme.dart              # Main theme configuration
│   ├── nutrition_theme_extension.dart  # Custom theme extension
│   └── component_themes/           # Individual component themes
├── widgets/
│   ├── common/                     # Reusable widgets
│   ├── nutrition/                  # Nutrition-specific widgets
│   └── animated/                   # Animation wrappers
├── screens/
│   ├── onboarding/                 # Onboarding flow screens
│   ├── nutrition_planning/         # Main app screens  
│   └── feedback/                   # Feedback collection
└── core/
    ├── theme/                      # Theme management
    └── constants/                  # Design constants
```

### Component Naming Conventions
- **Screen widgets**: `OnboardingScreen`, `NutritionPlanningScreen`
- **Common widgets**: `NutritionCard`, `FoodPreferenceChip`
- **Animated widgets**: `AnimatedNutritionCard`, `FadeInListTile`
- **Layout widgets**: `NutritionScreenLayout`, `CardGrid`

## Testing Strategy for UI Components

### Widget Testing Approach
```dart
// Test theme application
testWidgets('applies nutrition theme correctly', (tester) async {
  await tester.pumpWidget(ThemedTestApp(
    child: NutritionDataCard(label: 'Protein', value: '25g'),
  ));
  
  final card = find.byType(NutritionDataCard);
  expect(card, findsOneWidget);
  
  // Verify theme colors are applied
  final container = tester.widget<Container>(find.byType(Container));
  expect(container.decoration, isA<BoxDecoration>());
});

// Test animations
testWidgets('card animates on appearance', (tester) async {
  await tester.pumpWidget(AnimatedNutritionCard());
  await tester.pump(Duration(milliseconds: 150));
  
  // Verify animation states
  expect(find.byType(ScaleTransition), findsOneWidget);
});
```

## Phase 2 Branding Integration

### Future Enhancements
- **Custom Font Family:** Replace system fonts with brand typeface
- **Brand Colors:** Update color palette to match final brand guidelines
- **Logo Integration:** Add brand logo and wordmarks
- **Illustration Style:** Develop consistent illustration approach
- **Animation Guidelines:** Define micro-interactions and transitions

### Brand Asset Requirements (Phase 2)
- Logo files (SVG, PNG in multiple sizes)
- Brand color specifications (hex, RGB, HSL)
- Typography specifications (font files, weights, spacing)
- Iconography style guide
- Brand guidelines document

## Usage Guidelines

### Do's
- Use consistent spacing throughout the app
- Maintain color palette for all UI elements
- Follow typography hierarchy strictly
- Ensure proper contrast ratios

### Don'ts  
- Mix custom colors outside the defined palette
- Use inconsistent spacing or sizing
- Override font weights without design approval
- Ignore accessibility considerations

---

**Note:** This design system will evolve in Phase 2 with complete brand integration. Current specifications serve as MVP foundation for consistent user experience.