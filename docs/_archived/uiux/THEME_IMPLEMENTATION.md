# Mealvana Endurance Theme Implementation

## Overview
This document describes the actual theme implementation for Mealvana Endurance as of December 2024. The app uses Material Design 3 with custom fonts loaded from local assets and a light-mode-only theme configuration.

## Font Configuration

### Installed Fonts
The application uses custom fonts loaded from the `assets/fonts/` directory:

1. **Sansita** - Headlines, titles, and display text
   - Regular (400), Medium (500), Bold (700), ExtraBold (800), Black (900), Light (300)
   - Italic variants available
   
2. **Apercu** - Body text and readable content
   - Regular (400), Light (300), Medium (500), Bold (700)
   - Italic variants for all weights
   
3. **Helvetica** - Nutrition data and technical information
   - Regular (400), Black (900)
   
4. **Compadre** - Special selection and UI elements
   - Regular (400)

### Font Usage Guidelines

#### Sansita (Display Font)
- **Usage**: Headlines, titles, section headers, button text
- **Styles Available**:
  - `AppTheme.titleStyle` - Main titles (24sp, bold)
  - `AppTheme.subtitleStyle` - Subtitles (20sp, w600)
  - `AppTheme.heading1Style` - Large headers (32sp, bold)
  - `AppTheme.heading2Style` - Medium headers (28sp, bold)
  - `AppTheme.heading3Style` - Small headers (24sp, w600)
  - `AppTheme.calendarStyle` - Calendar/date text (16sp, w500)
  - `AppTheme.hintStyle` - Hint text (14sp, italic)

#### Apercu (Body Font)
- **Usage**: Body text, descriptions, notes, links
- **Styles Available**:
  - `AppTheme.textStyle` - Regular body text (16sp, w400)
  - `AppTheme.textCrossedStyle` - Crossed out text (16sp, w400, strikethrough)
  - `AppTheme.noteStyle` - Notes and captions (14sp, w400)
  - `AppTheme.linkStyle` - Hyperlinks (14sp, w400, underlined)

#### Helvetica (Nutrition Font)
- **Usage**: Nutrition facts, macro data, technical information
- **Styles Available**:
  - `AppTheme.nutritionRegularStyle` - Regular nutrition text (14sp, w400)
  - `AppTheme.nutritionRegularObliqueStyle` - Italic nutrition text (14sp, italic)
  - `AppTheme.nutritionFootnoteStyle` - Small nutrition notes (12sp, w400)
  - `AppTheme.nutritionBoldStyle` - Bold nutrition text (14sp, w900)
  - `AppTheme.nutritionTitleStyle` - Nutrition section titles (16sp, w900)
  - `AppTheme.nutritionLargeStyle` - Large nutrition values (18sp, w900)
  - `AppTheme.macroLabelStyle` - Macro nutrient labels (12sp, w400)
  - `AppTheme.macroValueStyle` - Macro nutrient values (20sp, w900)
  - `AppTheme.calorieTitleStyle` - Calorie displays (24sp, w900)
  - `AppTheme.nutritionFactStyle` - Nutrition fact labels (14sp, w400)

#### Compadre (Special Font)
- **Usage**: Special UI elements, selections
- **Styles Available**:
  - `AppTheme.selectionStyle` - Selection text (14sp, w500, letter-spacing: 1.5)

## Color Palette

### Brand Colors
```dart
// Primary Colors (Blues)
primary900: #001C71  // Dark blue
primary600: #3366FF  // Medium blue
primary100: #D6E0FF  // Light blue
primary50:  #E0E8FF  // Very light blue

// Highlight Colors (Coral/Pink)
highlight600:    #D92D20  // Coral red
highlight600Alt: #DC2597  // Pink
highlight490:    #F97066  // Light coral
highlight400:    #FF8476  // Lighter coral
highlight290:    #FDA29B  // Very light coral
highlight100:    #FEE4E2  // Pale coral
highlight50:     #FEF3F2  // Very pale coral

// Base Colors
baseBlack: #000000  // Pure black
baseCream: #F8F6EB  // Cream background
baseWhite: #FFFFFF  // Pure white
baseGrey:  #667085  // Medium grey

// Warning
warning500: #FFC629  // Yellow/amber
```

### Nutrition-Specific Colors
```dart
proteinColor:  #DC2597  // Pink
carbsColor:    #FFC629  // Yellow
fatsColor:     #3366FF  // Blue
caloriesColor: #001C71  // Dark blue
sodiumColor:   #FFC629  // Yellow
fluidsColor:   #3366FF  // Blue

// Status Colors
successColor:  #4CAF50  // Green
warningColor:  #D92D20  // Red
infoColor:     #3366FF  // Blue
```

## Shadow Effects
```dart
dropShadow:         // Standard drop shadow
  color: rgba(0,0,0,0.1)
  offset: (0, 2)
  blur: 4

glowShadow:         // Glow effect
  color: rgba(255,255,255,0.25)
  offset: (0, 0)
  blur: 10
  spread: 2

tabBarShadow:       // Tab bar shadow
  color: rgba(0,0,0,0.05)
  offset: (0, -1)
  blur: 4

checkboxDropShadow: // Checkbox shadow
  color: rgba(0,0,0,0.05)
  offset: (0, 1)
  blur: 2
```

## Theme Configuration

### Light Mode Only
The app is configured to use light mode exclusively:
- No dark theme support
- System dark mode preferences are ignored
- `ThemeMode.light` is forced in MaterialApp

### Material Design 3
- `useMaterial3: true` enabled
- Custom ColorScheme configured for light mode
- Modern Material 3 components and styling

## Implementation Details

### Main Theme File: `/lib/theme/app_theme.dart`
- All colors, text styles, and theme configuration in one place
- Static constants for easy access throughout the app
- No external font packages (Google Fonts removed)
- Nutrition theme extension merged into main theme

### Component Themes
Located in `/lib/theme/component_themes/`:
- `button_themes.dart` - ElevatedButton, OutlinedButton, TextButton styling
- `input_themes.dart` - TextField and form input styling
- `card_themes.dart` - Card component styling
- `app_bar_themes.dart` - AppBar navigation styling

### Usage in Code
```dart
// Import the theme
import 'package:mealvana_endurance/theme/app_theme.dart';

// Use colors
Container(
  color: AppTheme.primary600,
  ...
)

// Use text styles
Text(
  'Title',
  style: AppTheme.titleStyle,
)

// Use nutrition colors
Icon(
  Icons.local_fire_department,
  color: AppTheme.caloriesColor,
)

// Use shadows
Container(
  decoration: BoxDecoration(
    boxShadow: [AppTheme.dropShadow],
  ),
)
```

## Migration Notes

### Changes from Previous Implementation
1. **Removed Google Fonts** - Now using local font files
2. **Removed NutritionThemeExtension** - Merged into AppTheme
3. **Removed Dark Theme** - Light mode only
4. **Added Local Fonts** - Sansita, Apercu, Helvetica, Compadre
5. **Simplified Access** - All theme elements accessible via AppTheme static properties

### Breaking Changes
- `context.nutritionTheme` no longer available - use `AppTheme.nutritionColor` instead
- Dark theme removed - no theme switching functionality
- Google Fonts removed - all fonts loaded from assets

## Font Asset Configuration

### pubspec.yaml Font Configuration
```yaml
fonts:
  - family: Sansita
    fonts:
      - asset: assets/fonts/Sansita/Sansita-Regular.otf
        weight: 400
      - asset: assets/fonts/Sansita/Sansita-Medium.otf
        weight: 500
      - asset: assets/fonts/Sansita/Sansita-Bold.ttf
        weight: 700
      # ... additional weights

  - family: Apercu
    fonts:
      - asset: assets/fonts/Apercu/Apercu Regular.otf
        weight: 400
      - asset: assets/fonts/Apercu/Apercu-Light.otf
        weight: 300
      # ... additional weights

  - family: Helvetica
    fonts:
      - asset: assets/fonts/Helvetica/Helvetica.ttf
        weight: 400
      - asset: assets/fonts/Helvetica/Helvetica-BlackBlack.ttf
        weight: 900

  - family: Compadre
    fonts:
      - asset: assets/fonts/Compadre/Compadre-Demo-Regular.otf
        weight: 400
```

## Best Practices

### Text Style Usage
1. Use predefined text styles from AppTheme for consistency
2. Avoid creating custom TextStyle objects inline
3. Use `.copyWith()` for minor modifications
4. Respect the font hierarchy (Sansita for display, Apercu for body, Helvetica for data)

### Color Usage
1. Use semantic color names (primary, highlight, base)
2. Use nutrition-specific colors for macro displays
3. Apply opacity with `.withValues(alpha:)` for Flutter 3.27+
4. Use predefined shadow constants for elevation

### Responsive Design
- All font sizes defined in logical pixels (sp)
- Responsive sizing handled by flutter_screenutil
- Base design: iPhone 14 Pro (393×852)

## Maintenance

### Adding New Text Styles
Add to `/lib/theme/app_theme.dart`:
```dart
static const TextStyle newStyle = TextStyle(
  fontFamily: 'Apercu', // or 'Sansita', 'Helvetica', 'Compadre'
  fontSize: 16,
  fontWeight: FontWeight.w400,
  // additional properties
);
```

### Adding New Colors
Add to color constants section in `app_theme.dart`:
```dart
static const Color newColor = Color(0xFFHEXCODE);
```

### Updating Component Themes
Modify files in `/lib/theme/component_themes/` directory

---

*Last Updated: December 2024*
*Flutter Version: 3.8+*
*Material Design: Version 3*