# Mealvana Endurance - Design Tokens
## Kyle's Design System - Complete Specification

**Source:** Kyle's Figma Mockups + MCP Extraction
**Last Updated:** 2025-11-12
**Status:** ✅ EXACT VALUES (Extracted via Figma MCP)
**Extraction Method:** get_design_context tool with exact hex values from Figma variables

---

## Table of Contents
1. [Typography](#typography)
2. [Color Palette](#color-palette)
3. [Spacing & Layout](#spacing--layout)
4. [Components](#components)
5. [Iconography](#iconography)
6. [Theme Modes](#theme-modes)

---

## Typography

### Font Families

#### 1. Sansita Bold
**Usage:**
- Page Titles
- Section Titles
- Primary Buttons
- Large Format Text in headers (Date and Times in Activity Pages)

**Flutter Implementation:**
```dart
static const String sansitaBold = 'Sansita';
static const FontWeight sansitaBoldWeight = FontWeight.w700; // Bold

// Usage examples:
static const pageTitle = TextStyle(
  fontFamily: sansitaBold,
  fontWeight: sansitaBoldWeight,
  fontSize: 28,
  height: 1.2,
);

static const sectionTitle = TextStyle(
  fontFamily: sansitaBold,
  fontWeight: sansitaBoldWeight,
  fontSize: 20,
  height: 1.3,
);

static const buttonPrimary = TextStyle(
  fontFamily: sansitaBold,
  fontWeight: sansitaBoldWeight,
  fontSize: 16,
  height: 1.2,
);

static const dateTime = TextStyle(
  fontFamily: sansitaBold,
  fontWeight: sansitaBoldWeight,
  fontSize: 24,
  height: 1.2,
);
```

#### 2. Compadre Wide
**Usage:**
- Subtitles
- Descriptors
- Food Titles
- Activity Titles

**Flutter Implementation:**
```dart
static const String compadreWide = 'Compadre';

// Usage examples:
static const subtitle = TextStyle(
  fontFamily: compadreWide,
  fontSize: 16,
  height: 1.4,
  letterSpacing: 0.5, // Wide variant
);

static const descriptor = TextStyle(
  fontFamily: compadreWide,
  fontSize: 14,
  height: 1.4,
  letterSpacing: 0.5,
);

static const foodTitle = TextStyle(
  fontFamily: compadreWide,
  fontSize: 16,
  height: 1.3,
  letterSpacing: 0.5,
);

static const activityTitle = TextStyle(
  fontFamily: compadreWide,
  fontSize: 18,
  height: 1.3,
  letterSpacing: 0.5,
);
```

#### 3. Apercu
**Usage:**
- Long Form Text
- Data Numbers
- Tertiary Buttons

**Flutter Implementation:**
```dart
static const String apercu = 'Apercu';

// Usage examples:
static const longFormText = TextStyle(
  fontFamily: apercu,
  fontSize: 16,
  height: 1.5,
  fontWeight: FontWeight.w400,
);

static const dataNumber = TextStyle(
  fontFamily: apercu,
  fontSize: 32,
  height: 1.2,
  fontWeight: FontWeight.w600,
);

static const buttonTertiary = TextStyle(
  fontFamily: apercu,
  fontSize: 14,
  height: 1.2,
  fontWeight: FontWeight.w500,
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
```

### Typography Scale Summary

✅ **EXACT VALUES** extracted from Figma screens

| Name | Font Family | Size | Weight | Usage | Status |
|------|-------------|------|--------|-------|--------|
| Screen Title | Sansita Bold | 17px ✅ | Bold (700) | "Food Preferences", etc. | EXACT |
| Page Title | Sansita Bold | 20px ✅ | Bold (700) | Large screen titles | EXACT |
| Section Title | Sansita Bold | 16px ✅ | Bold (700) | Section headers | EXACT |
| Button Text | Sansita Bold | 16px ✅ | Bold (700) | "GENERATE PLAN", "Save Changes" | EXACT |
| Segmented Control | Sansita Bold | 12px ✅ | Bold (700) | Gut Training, Sweat Rate toggles | EXACT |
| Distance Label | Compadre Regular | 16px ✅ | Regular (400) | "12 miles" | EXACT |
| Food Name | Compadre Regular | 12px ✅ | Regular (400) | Food item names | EXACT |
| Food Name (Wide) | Compadre Wide | 12px ✅ | Regular (400) | Uppercase food names | EXACT |
| Table Header | Compadre Regular | 10px ✅ | Regular (400) | "Date", column headers | EXACT |
| Search Input | Apercu Mono | 14px ✅ | Regular (400) | "Search Foods" | EXACT |
| Nutritional Value | Apercu Mono | 12px ✅ | Regular (400) | Calories, macro numbers | EXACT |
| Preference Label | Apercu Mono | 10px ✅ | Regular (400) | "Avoid", "Love" | EXACT |
| Unit Label | Compadre Regular | 7px ✅ | Regular (400) | "calories", "grams" | EXACT |

---

## Color Palette

### Core Colors

#### Blackberry (Primary Dark)
**Hex:** `#381633` ✅ **EXACT** (extracted from Figma)
**Previous Estimate:** `#3D1F47` (moderate difference)
**Usage:**
- Background Color (Dark Mode)
- Text Color on Cream (Light Mode)
- Primary Button Text Color
- Selected state backgrounds
- Icon colors on light backgrounds

**Flutter:**
```dart
static const blackberry = Color(0xFF381633); // ✅ EXACT
static const blackberryLight = Color(0xFF4A2854); // Lighter variant
static const blackberryDark = Color(0xFF2D1535); // Darker variant
```

#### Cream (Primary Light)
**Hex:** `#F8F6EB` ✅ **EXACT** (extracted from Figma)
**Previous Estimate:** `#F5F3ED` (minor difference)
**Usage:**
- Text Color (Dark Mode)
- Outline Color
- Active State Background Color (Light Mode)
- Background Color (Light Mode)
- Text on Orange buttons

**Flutter:**
```dart
static const cream = Color(0xFFF8F6EB); // ✅ EXACT
static const creamDark = Color(0xFFE8E6E0); // Darker variant for outlines
```

#### Orange (Primary Accent)
**Hex:** `#F78B14` ✅ **EXACT** (extracted from Figma)
**Previous Estimate:** `#FF8B3D` (moderate difference - less red, more pure orange)
**Usage:**
- Primary Button Background
- Plus/Minus Control Borders (2px)
- Secondary Button Outline Color
- Call-to-action elements
- "Add Food" button borders

**Flutter:**
```dart
static const orange = Color(0xFFF78B14); // ✅ EXACT
static const orangeLight = Color(0xFFF9A042); // Hover state
static const orangeDark = Color(0xFFE57D0C); // Pressed state
```

#### Electrolyte (Cyan/Teal)
**Hex:** `#1CF9CF` ✅ **EXACT** (extracted from Figma)
**Previous Estimate:** `#5DE4D3` ⚠️ **MAJOR DIFFERENCE** (much brighter cyan)
**Usage:**
- Activity Icon Background Color (36px circles)
- Event Icon Background Color
- Food Icon Background Color (36px circles) - **ALL food icons use this**
- Positive Tertiary Button Text
- Accent highlights
**Critical:** This is a **significant visual change** from estimates - much more vibrant cyan!

**Flutter:**
```dart
static const electrolyte = Color(0xFF1CF9CF); // ✅ EXACT - Bright cyan
static const electrolyteLight = Color(0xFF4FFBD9); // Lighter variant
static const electrolyteDark = Color(0xFF00E7BA); // Darker variant
```

#### Dragonfruit (Pink/Magenta)
**Hex:** `#DC2597` ✅ **EXACT** (extracted from Figma)
**Previous Estimate:** `#E84393` (moderate difference - deeper magenta)
**Usage:**
- Tertiary Button Text Color
- Warning Text
- Accent highlights
- Error states

**Flutter:**
```dart
static const dragonfruit = Color(0xFFDC2597); // ✅ EXACT
static const dragonfruitLight = Color(0xFFE952AE); // Lighter variant
static const dragonfruitDark = Color(0xFFC31B7F); // Darker variant
```

#### Off Cream (Secondary Neutral)
**Hex:** `#C6C3B2` ✅ **EXACT** (newly discovered from extraction)
**Previous Estimate:** N/A (not in initial analysis)
**Usage:**
- Inactive/unselected state backgrounds
- Disabled text
- Subtle borders and dividers
- Secondary text on light backgrounds

**Flutter:**
```dart
static const offCream = Color(0xFFC6C3B2); // ✅ EXACT
static const offCreamLight = Color(0xFFD4D1C5); // Lighter variant
static const offCreamDark = Color(0xFFB3B0A0); // Darker variant
```

### Semantic Colors

```dart
// Success
static const success = electrolyte;
static const successBackground = Color(0xFF5DE4D3).withOpacity(0.1);

// Error/Warning
static const error = dragonfruit;
static const errorBackground = Color(0xFFE84393).withOpacity(0.1);

// Info
static const info = electrolyte;
static const infoBackground = Color(0xFF5DE4D3).withOpacity(0.1);

// Neutral/Inactive
static const inactive = Color(0xFF9B8AA3);
static const disabled = Color(0xFF6B5C6F);
```

### Complete Color Palette Table

| Color Name | Hex | RGB | Usage |
|------------|-----|-----|-------|
| **Blackberry** | #3D1F47 | 61, 31, 71 | Dark backgrounds, light text |
| Blackberry Light | #4A2854 | 74, 40, 84 | Elevated surfaces (dark) |
| Blackberry Dark | #2D1535 | 45, 21, 53 | Deeper sections (dark) |
| **Cream** | #F5F3ED | 245, 243, 237 | Light backgrounds, dark text |
| Cream Dark | #E8E6E0 | 232, 230, 224 | Borders, outlines |
| **Orange** | #FF8B3D | 255, 139, 61 | Primary actions |
| Orange Light | #FFA05A | 255, 160, 90 | Hover states |
| Orange Dark | #E67A2E | 230, 122, 46 | Pressed states |
| **Electrolyte** | #5DE4D3 | 93, 228, 211 | Icons, positive actions |
| Electrolyte Light | #7FEEE0 | 127, 238, 224 | Light backgrounds |
| Electrolyte Dark | #3FD4C0 | 63, 212, 192 | Emphasis |
| **Dragonfruit** | #E84393 | 232, 67, 147 | Warnings, tertiary actions |
| Dragonfruit Light | #F060A8 | 240, 96, 168 | Light backgrounds |
| Dragonfruit Dark | #D0357E | 208, 53, 126 | Emphasis |

---

## Spacing & Layout

### Spacing Scale
Based on analysis of screenshots, the design uses an **8pt grid system**.

```dart
class AppSpacing {
  // Base spacing unit: 8px
  static const double unit = 8.0;

  // Spacing scale
  static const double xxs = 4.0;   // 0.5 units
  static const double xs = 8.0;    // 1 unit
  static const double sm = 12.0;   // 1.5 units
  static const double md = 16.0;   // 2 units
  static const double lg = 20.0;   // 2.5 units
  static const double xl = 24.0;   // 3 units
  static const double xxl = 32.0;  // 4 units
  static const double xxxl = 40.0; // 5 units
  static const double huge = 48.0; // 6 units

  // Common paddings
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: sm,
  );
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}
```

### Border Radius

✅ **EXACT VALUES** extracted from Figma components

```dart
class AppRadius {
  // ✅ EXACT values from Figma
  static const double button = 100.0; // Fully rounded (extracted: 100px)
  static const double card = 15.0; // Cards and sections (extracted: 15px)
  static const double input = 15.0; // Text inputs (extracted: 15px)
  static const double activitySelector = 15.0; // Running/Cycling/Swimming (extracted: 15px)
  static const double segmentedControl = 15.0; // Toggle controls (extracted: 15px)

  // Legacy values (for backwards compatibility)
  static const double small = 8.0;
  static const double medium = 12.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  static const double circular = 100.0; // Fully circular - USE THIS for buttons

  // Common radius values
  static const BorderRadius smallRadius = BorderRadius.all(Radius.circular(small));
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card)); // ✅ 15px
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input)); // ✅ 15px
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(button)); // ✅ 100px
  static const BorderRadius circularRadius = BorderRadius.all(Radius.circular(circular)); // ✅ 100px
}
```

### Shadows & Elevation

```dart
class AppShadows {
  // Light mode shadows
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

  // Dark mode - minimal or no shadows
  static List<BoxShadow> get darkCardShadow => [];

  static List<BoxShadow> get darkElevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}
```

### Icon Sizes

✅ **EXACT VALUES** extracted from Figma components

```dart
class AppIconSizes {
  // ✅ EXACT values from Figma
  static const double foodIconCircle = 36.0; // Food icon background circle (extracted: 36px)
  static const double foodIcon = 18.0; // Icon inside circle (~50% of circle)
  static const double activityIcon = 36.0; // Activity icon circle (extracted: 36px)
  static const double plusMinusIcon = 20.0; // Plus/minus control icons (extracted: 20px)
  static const double buttonIcon = 20.0; // Icons inside buttons (extracted: 20px)

  // Font Awesome icon sizes (extracted from code)
  static const double fontAwesomeSmall = 13.0; // Small FA icons
  static const double fontAwesomeMedium = 15.0; // Navigation icons
  static const double fontAwesomeStandard = 16.0; // Standard icons
  static const double fontAwesomeLarge = 18.0; // Medium icons
  static const double fontAwesomeXLarge = 20.0; // Large icons

  // Legacy values (for backwards compatibility)
  static const double small = 16.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xlarge = 48.0;

  // Component-specific (legacy)
  static const double tabBar = 24.0;
  static const double listItem = 24.0;
}
```

---

## Components

### Button Specifications

#### Primary Button
**Visual:**
- Background: Orange (#FF8B3D)
- Text: Blackberry (#3D1F47) or Cream (#F5F3ED)
- Font: Sansita Bold, 16pt
- Border Radius: 16px
- Height: 56px
- Padding: 12px vertical, 24px horizontal

**States:**
- Default: Orange background
- Hover: Orange Light (#FFA05A)
- Pressed: Orange Dark (#E67A2E)
- Disabled: Orange with 40% opacity

**Flutter:**
```dart
class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.blackberry,
          textStyle: AppTextStyles.buttonPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          elevation: 0,
        ),
        child: Text(text),
      ),
    );
  }
}
```

#### Secondary Button
**Visual:**
- Background: Transparent
- Border: 2px solid (Cream in dark mode, Blackberry in light mode)
- Text: Cream (dark mode) or Blackberry (light mode)
- Font: Sansita Bold, 16pt
- Border Radius: 16px
- Height: 56px

**States:**
- Default: Outlined
- Hover: Slight background tint
- Pressed: More opaque background
- Active: Cream/Blackberry background (depending on mode)

**Flutter:**
```dart
class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 56,
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.cream : AppColors.blackberry,
          side: BorderSide(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            width: 2,
          ),
          textStyle: AppTextStyles.buttonPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
        ),
        child: Text(text),
      ),
    );
  }
}
```

#### Tertiary Button
**Visual:**
- Background: Transparent
- Text: Dragonfruit (#E84393)
- Font: Apercu, 14pt, Medium weight
- No border
- Icon optional

**Flutter:**
```dart
class TertiaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.dragonfruit,
        textStyle: AppTextStyles.buttonTertiary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: 4),
          ],
          Text(text),
        ],
      ),
    );
  }
}
```

#### Icon Button (Circular)
**Visual:**
- Background: Electrolyte (#5DE4D3) or other accent colors
- Icon: Blackberry (dark mode) or Cream (light mode)
- Size: 48x48px
- Fully circular (border-radius: 50%)

**Flutter:**
```dart
class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.electrolyte,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        color: isDark ? AppColors.blackberry : AppColors.cream,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}
```

### Input Fields

#### Text Input
**Visual:**
- Background: Transparent or very subtle (Light mode: white, Dark mode: slightly lighter purple)
- Border: 1px solid Cream (dark) or light gray (light)
- Text: Current theme text color
- Font: Apercu, 16pt
- Border Radius: 8px
- Height: 48px
- Padding: 12px horizontal

**Flutter:**
```dart
class CustomTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: AppTextStyles.smallLabel),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          style: AppTextStyles.inputText,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark
                ? AppColors.blackberryLight.withOpacity(0.3)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.cream.withOpacity(0.2)
                    : AppColors.blackberry.withOpacity(0.2),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
```

#### Plus/Minus Control
**Visual:**
- Two circular buttons (- and +)
- Border: 2px solid Orange
- Icon: Orange
- Background: Transparent
- Size: 40x40px
- Value display between buttons

**Flutter:**
```dart
class PlusMinusControl extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularControlButton(
          icon: Icons.remove,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '$value $unit',
            style: AppTextStyles.dataNumber,
          ),
        ),
        _CircularControlButton(
          icon: Icons.add,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _CircularControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.orange, width: 2),
      ),
      child: IconButton(
        icon: Icon(icon),
        color: AppColors.orange,
        iconSize: 20,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}
```

### Cards

#### Activity Card
**Visual:**
- Background: Cream (light mode) or Blackberry Light (dark mode)
- Border Radius: 12px
- Padding: 16px
- Shadow: Subtle in light mode, none in dark mode
- Contains: Hero image, activity type icon, title, date/time

#### Food Item Card (Expandable)
**Visual:**
- Background: Cream (light mode) or Blackberry Light (dark mode)
- Border Radius: 12px
- Icon: Circular with Electrolyte background (28px)
- Text: Food name (Compadre Wide), quantity (Apercu)
- Expandable: Shows nutritional facts when tapped
- Actions: Swap, Remove (Dragonfruit color)

#### Nutrition Display Card
**Visual:**
- Background: Transparent with subtle border
- Border: 1px solid Cream (dark) or light gray (light)
- Border Radius: 12px
- Padding: 16px
- Header: Section title (Before Run, During Run, After Run)
- Macros: Displayed at top (Carbs, Fluids, Sodium)
- List: Food items with icons

### Segmented Control / Toggle Buttons

**Visual:**
- Group of 2-3 buttons
- Unselected: Transparent with border
- Selected: Cream (light mode) or slightly lighter Blackberry (dark mode)
- Border Radius: 12px
- Height: 48px
- Font: Compadre Wide, 14pt

**Flutter:**
```dart
class SegmentedControl extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: List.generate(options.length, (index) {
        final isSelected = index == selectedIndex;
        return Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? AppColors.blackberryLight : AppColors.cream)
                  : Colors.transparent,
              border: Border.all(
                color: isDark
                    ? AppColors.cream.withOpacity(0.3)
                    : AppColors.blackberry.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.horizontal(
                left: index == 0 ? Radius.circular(12) : Radius.zero,
                right: index == options.length - 1
                    ? Radius.circular(12)
                    : Radius.zero,
              ),
            ),
            child: TextButton(
              onPressed: () => onChanged(index),
              child: Text(
                options[index],
                style: AppTextStyles.descriptor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
```

### Slider (Food Preferences)

**Visual:**
- Track: Light gray
- Active track: Electrolyte or Blackberry (depending on position)
- Thumb: Larger circle, Blackberry (light) or Cream (dark)
- Labels: "Avoid" on left, "Love" on right
- X and Heart icons on ends

---

## Iconography

### Icon Library
**Source:** Font Awesome 7 Pro (Solid/Sharp)

**License:** Pro license required
**Alternative:** Font Awesome Free or custom SVG icons

### Icon Specifications

#### Activity Icons
- **Running:** Runner icon
- **Cycling:** Bicycle icon
- **Swimming:** Swimmer icon
- Background: Electrolyte (#5DE4D3)
- Size: 32x32px
- Circular background: 48x48px

#### Food Category Icons
From screenshots, observed icons:
- Energy bar (rectangle)
- Sports drink (bottle)
- Banana (fruit)
- Salt packet (square)
- Water (cup/bottle)
- Gel (pouch)
- Electrolyte tablet (pill)
- Trail mix (bowl)

**Flutter Implementation:**
```dart
class FoodIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.electrolyte,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size ?? 28,
        color: AppColors.blackberry,
      ),
    );
  }
}
```

#### Navigation Icons
Bottom navigation bar icons:
- Calendar (grid or calendar icon)
- More/Menu (three dots)
- Add (plus sign)
- Background: Blackberry (light mode) or Cream (dark mode)
- Active state: Orange background with circular pill shape

### Icon Color Mapping

| Context | Light Mode | Dark Mode |
|---------|-----------|-----------|
| Activity Icon Background | Electrolyte | Electrolyte |
| Food Icon Background | Electrolyte | Electrolyte |
| Event Icon Background | Electrolyte | Electrolyte |
| Icon Foreground | Blackberry | Blackberry |
| Navigation Icon | Blackberry | Cream |
| Active Navigation | Orange | Orange |
| Action Icons | Orange | Orange |
| Warning Icons | Dragonfruit | Dragonfruit |

---

## Theme Modes

### Light Mode (Cream Theme)

**Color Mapping:**
```dart
static ThemeData lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
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
    scaffoldBackgroundColor: AppColors.cream,
    cardColor: Colors.white,
    dividerColor: AppColors.blackberry.withOpacity(0.1),
    // ... additional theme properties
  );
}
```

**Key Characteristics:**
- Clean, minimal aesthetic
- High contrast for outdoor visibility
- White cards on cream background
- Subtle shadows for depth
- Blackberry text on cream

### Dark Mode (Blackberry Theme)

**Color Mapping:**
```dart
static ThemeData darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
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
    scaffoldBackgroundColor: AppColors.blackberry,
    cardColor: AppColors.blackberryLight,
    dividerColor: AppColors.cream.withOpacity(0.1),
    // ... additional theme properties
  );
}
```

**Key Characteristics:**
- Rich, sophisticated aesthetic
- Better for low-light environments
- Elevated surfaces slightly lighter purple
- Minimal shadows
- Cream text on blackberry
- Same accent colors (orange, electrolyte, dragonfruit)

### Theme Comparison

| Element | Light Mode | Dark Mode |
|---------|------------|-----------|
| Background | Cream (#F5F3ED) | Blackberry (#3D1F47) |
| Surface | White (#FFFFFF) | Blackberry Light (#4A2854) |
| Primary Text | Blackberry | Cream |
| Secondary Text | Gray | Light gray |
| Primary Button | Orange | Orange |
| Primary Button Text | Blackberry | Blackberry |
| Icons (Activity) | Electrolyte BG | Electrolyte BG |
| Borders | Light gray | Cream (subtle) |
| Shadows | Visible | Minimal/None |
| Input Background | White | Blackberry Light |

---

## Implementation Notes

### Font Installation

**pubspec.yaml:**
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
    - family: Apercu
      fonts:
        - asset: assets/fonts/Apercu-Regular.ttf
          weight: 400
        - asset: assets/fonts/Apercu-Medium.ttf
          weight: 500
        - asset: assets/fonts/Apercu-Bold.ttf
          weight: 700
```

**Font Acquisition:**
- Sansita: Available on Google Fonts (open source)
- Compadre: Commercial font (verify license)
- Apercu: Commercial font by Colophon Foundry (verify license)

**Fallback Fonts (if commercial fonts unavailable):**
- Sansita → **Montserrat Bold** (Google Fonts)
- Compadre Wide → **Work Sans** (Google Fonts, expanded letter spacing)
- Apercu → **Inter** (Google Fonts, similar modern sans-serif)

### Icon Integration

**Font Awesome Pro:**
```yaml
dependencies:
  font_awesome_flutter: ^10.6.0
```

Or use custom SVG icons if Font Awesome Pro license not available.

### Color Extraction Tool

For precise color values, use a color picker on the Figma screenshots:
- macOS: Digital Color Meter
- Figma: Inspect mode in Dev Mode
- Browser: ColorZilla extension

---

## Next Steps

1. ✅ Design tokens documented
2. ⏳ Implement theme files in `/lib/theme/`
3. ⏳ Create component library in `/lib/shared/widgets/kyle_design/`
4. ⏳ Install and configure fonts
5. ⏳ Set up icon library
6. ⏳ Test themes on both iOS and Android
7. ⏳ Update screens progressively

---

**Document Owner:** Claude AI Assistant
**Reviewed By:** Kyle (Designer) - Pending
**Status:** Ready for Implementation
