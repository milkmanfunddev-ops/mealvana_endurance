# Mealvana Endurance - Design System Analysis
## Figma File: Kyle's Mockups

**Source:** https://www.figma.com/design/4FvaeGejofuETyP5LUIxQK/Kyle-s-Mockups
**Analysis Date:** 2025-11-11
**Status:** Initial Analysis from Screenshot Review

---

## Executive Summary

This document analyzes the design system from Kyle's Figma mockups, identifying key design patterns, color schemes, typography, components, and implementation requirements for updating the Mealvana Endurance UI.

---

## Color Palette

### Dark Mode (Primary Theme)
Based on visual analysis of the Figma mockups:

**Primary Colors:**
- **Deep Purple Background**: `#2D1B3D` (approximate) - Main background color
- **Rich Purple**: `#3D2450` (approximate) - Card/elevated surface color
- **Darker Purple**: `#1F1229` (approximate) - Deeper sections

**Accent Colors:**
- **Primary Orange/Coral**: `#FF8C42` (approximate) - Primary CTA buttons, emphasis
- **Teal/Cyan**: `#4ECDC4` (approximate) - Icons, highlights, secondary actions
- **Bright Pink/Magenta**: `#E84393` (approximate) - Special highlights, badges

**UI Elements:**
- **White Text**: `#FFFFFF` - Primary text on dark backgrounds
- **Light Gray Text**: `#B8B8D1` (approximate) - Secondary text
- **Input Backgrounds**: `#3D2450` (approximate) - Form field backgrounds
- **Dividers**: `#4A3B5C` (approximate) - Subtle separators

### Light Mode
Based on calendar screens visible in mockups:

**Primary Colors:**
- **Light Background**: `#F5F5F0` or `#FAFAF8` (approximate) - Main background
- **White Cards**: `#FFFFFF` - Card surfaces
- **Light Gray**: `#E8E8E8` (approximate) - Borders, dividers

**Text:**
- **Dark Purple Text**: `#2D1B3D` (approximate) - Primary text on light
- **Gray Text**: `#6B6B6B` (approximate) - Secondary text

**Accent Colors (Consistent):**
- **Primary Orange**: Same as dark mode
- **Teal**: Same as dark mode
- **Pink**: Same as dark mode

---

## Typography

### Font Family
**Needs Verification from Figma Variables**
- Appears to use a modern sans-serif font (possibly Inter, SF Pro, or similar)
- Clean, readable, athletic aesthetic

### Text Styles (Approximate)
**Headings:**
- **H1**: ~28-32pt, Bold
- **H2**: ~24-28pt, Semibold
- **H3**: ~20-24pt, Semibold
- **H4**: ~18-20pt, Medium

**Body:**
- **Body Large**: ~16-18pt, Regular
- **Body Medium**: ~14-16pt, Regular
- **Body Small**: ~12-14pt, Regular

**UI Elements:**
- **Button Text**: ~14-16pt, Semibold
- **Input Labels**: ~12-14pt, Medium
- **Caption**: ~11-13pt, Regular

---

## Spacing System

### Approximate Grid
Based on visual spacing analysis:
- **Base Unit**: 4px or 8px
- **Common Spacing Values**: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64

### Padding/Margins Patterns
- **Screen Padding**: 16-20px horizontal
- **Card Padding**: 16-20px all sides
- **Button Padding**: 12-16px vertical, 20-32px horizontal
- **Element Spacing**: 8-16px between related elements

---

## Key Components

### 1. Activity Cards
**Features:**
- Large hero image (athlete in action)
- Activity type indicator
- Distance/duration display
- Dark purple background (dark mode) or white (light mode)
- Rounded corners (~12-16px radius)
- Shadow/elevation effect

**Variants Observed:**
- Running activity card
- Cycling activity card
- General activity card

### 2. Calendar Views
**Features:**
- Monthly grid layout
- Weekly list view
- Date cells with event indicators
- Color-coded event types (teal, orange, pink dots/badges)
- Clean, minimal design

**Modes:**
- Light mode calendar (cream/white background)
- Dark mode calendar (purple background)

### 3. Buttons
**Primary Button:**
- Orange/coral background
- White text
- Rounded rectangle (~8-12px radius)
- Full width or auto-width
- Height: ~48-56px

**Secondary/Toggle Buttons:**
- Outlined style or purple background
- Teal or white text
- Similar sizing to primary

**Icon Buttons:**
- Circular
- Teal, orange, or pink backgrounds
- White icons

### 4. Form Inputs
**Text Fields:**
- Purple background in dark mode
- White background in light mode
- Rounded corners (~8-12px)
- Light border or no border
- Label above or floating
- Height: ~48-56px

**Dropdown/Selectors:**
- Similar style to text fields
- Chevron icon on right
- Purple background (dark mode)

### 5. Icons
**Style:**
- Outlined/line icons
- Circular background badges
- Color-coded by category:
  - Teal: Activities, events
  - Orange: Primary actions
  - Pink: Special items
  - Purple: Secondary items

**Sizes:**
- Small: ~16-20px
- Medium: ~24-28px
- Large: ~32-40px

### 6. Navigation
**Bottom Tab Bar (visible in some screens):**
- Fixed bottom position
- Icon + label
- Active state highlighting
- Dark purple background

### 7. Cards/Containers
**Standard Card:**
- Rounded corners (~12-16px)
- Purple background (dark mode) or white (light mode)
- Subtle shadow/elevation
- 16-20px padding

**List Items:**
- Horizontal layout
- Icon on left
- Title + subtitle
- Chevron or action on right
- Dividers between items

---

## Layout Patterns

### Screen Structure
**Common Layout:**
1. **Header Bar** - Title, back button, optional actions
2. **Content Area** - Scrollable main content
3. **Bottom Navigation** - Tab bar (when applicable)
4. **Floating Action Button** - Primary action (some screens)

### Grid System
- Appears to use standard mobile grid (single column mostly)
- Some screens show 2-column layouts for specific content
- Responsive spacing that adapts to screen size

---

## Light Mode vs Dark Mode Differences

### Key Distinctions

**Dark Mode (Primary):**
- Deep purple backgrounds (#2D1B3D range)
- White/light gray text
- Purple elevated surfaces
- Slightly more saturated accent colors
- Darker image overlays on cards

**Light Mode:**
- Cream/off-white backgrounds (#F5F5F0 range)
- Dark purple/gray text
- White elevated surfaces
- Same accent colors (orange, teal, pink)
- Lighter, cleaner overall aesthetic
- Calendar appears to favor this mode

**Consistent Across Both:**
- Orange primary buttons
- Teal/cyan accent color
- Pink/magenta highlights
- Icon styles and sizes
- Component shapes and spacing
- Typography hierarchy

---

## Assets & Icons Required

### Custom Icons Needed
- Activity type icons (run, bike, swim)
- Calendar event types
- Navigation icons (home, calendar, profile, settings)
- Action icons (add, edit, delete, share)
- Status indicators
- Weather icons (if applicable to nutrition planning)

### Image Assets
**Athlete Hero Images:**
- Runner (appears to be a key visual)
- Cyclist (teal jersey visible)
- Swimmer (may be present)
- High-quality, aspirational photography
- Consistent treatment/style

**Illustrations/Graphics:**
- Potentially empty states
- Onboarding graphics (if present in full file)

### Export Requirements
- SVG format for icons (scalable, small file size)
- PNG 2x, 3x for images (Retina support)
- Consider using Figma's export functionality or code generation

---

## Design Tokens (To Be Extracted from Figma Variables)

**Priority Items to Extract:**
1. **Color Variables** - Complete palette with semantic naming
2. **Typography Scale** - Font sizes, weights, line heights
3. **Spacing Scale** - Margin/padding system
4. **Border Radius Values** - Corner radius standards
5. **Shadow/Elevation Levels** - Card and component shadows
6. **Breakpoints** - Responsive design breakpoints (if any)

**Action Required:**
- Need to access Figma file directly with `get_variable_defs` tool
- User must select a frame/component in Figma Desktop
- Alternative: Manual export of design tokens from Figma

---

## Figma MCP Server Issues Encountered

### Current Status
- ✅ **Screenshot access** working successfully
- ❌ **Design context extraction** - fetch errors
- ❌ **Variable definitions** - selection required
- ❌ **Metadata access** - file too large at root level

### To Complete Full Extraction
**User Action Needed:**
1. Open the Figma file in **Figma Desktop application**
2. Select specific frames/components (one at a time):
   - A complete activity card screen
   - A calendar view screen
   - A form input screen
   - The style guide page (if exists)
3. Run these tools with selections active:
   - `get_design_context` - for React/code representation
   - `get_variable_defs` - for design tokens
   - `get_code_connect_map` - for component mapping (if applicable)

**Alternative Approach:**
- Export design tokens manually from Figma using plugins:
  - "Design Tokens" plugin
  - "Style Dictionary" plugin
  - Manual inspection in Dev Mode

---

## Next Steps

See **[UI_REDESIGN_ROADMAP.md](./UI_REDESIGN_ROADMAP.md)** for the complete implementation plan.

**Immediate Actions:**
1. ✅ Complete this initial analysis
2. ⏳ Create comprehensive roadmap
3. ⏳ Extract exact design tokens from Figma
4. ⏳ Set up theme system in Flutter
5. ⏳ Begin component implementation

---

## Notes
- This analysis is based on visual inspection of screenshots
- Exact color values, spacing, and typography need to be confirmed via Figma Dev Mode or variable extraction
- Some components may not be visible in the captured screenshot and require additional exploration
- Light mode appears less developed than dark mode in visible screens
