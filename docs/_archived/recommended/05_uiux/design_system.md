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

## Source Reference

Based on: `../../uiux/README.md`