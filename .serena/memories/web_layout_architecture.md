# Web Layout, Centering, and Coach Portal Architecture

## 1. ROOT WIDGET SETUP

### File: `/lib/shared/widgets/root_app_widget.dart`
- **Entry Point Pattern**: Follows Andrea Bizzotto's initialization pattern with MaterialApp.router
- **Deep Link Support**: MaterialApp.builder wraps router child with AppStartupWidget for deep link handling
- **Platform-Aware Wrapper**: ResponsiveContentWrapper applied at root level in builder
- **Key Line 85**: `ResponsiveContentWrapper(child: child!)` - applies to all screens without individual modifications

### Structure:
```
RootAppWidget (ScreenUtilInit)
  → ProviderScope (Riverpod)
    → MaterialApp.router
      → Wiredash (feedback)
        → builder context
          → AppStartupWidget
            → ResponsiveContentWrapper
              → child (all screens)
```

## 2. RESPONSIVE CONTENT WRAPPER (Web/iPad Centering)

### File: `/lib/shared/widgets/responsive_content_wrapper.dart`

**Key Behavior:**
- **Web**: Returns child as-is (no constraints, full width allowed)
- **Native/iPad**: Applies max-width constraint when screen > 750px

**Code Logic (lines 42-74):**
```dart
if (kIsWeb) {
  return child;  // No constraints on web
}

// On native, apply constraints for large screens
return LayoutBuilder(
  builder: (context, constraints) {
    if (!isLargeScreen) {
      return child;
    }
    // Large screens: Center + ConstrainedBox
    return ColoredBox(
      color: bgColor,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      ),
    );
  },
);
```

**Default Breakpoints:**
- `maxContentWidth: 750px` (optimal for mobile-designed content)
- `breakpoint: 750px` (Material 3 compact/medium)
- Large screens > 750px get centered + constrained
- Mobile-sized screens return child as-is

**Extensions Available:**
- `context.isLargeScreen` → width > 750px
- `context.isExtraLargeScreen` → width > 840px
- `context.isWebPlatform` → kIsWeb check

## 3. ROUTER CONFIGURATION

### File: `/lib/shared/core/app_router.dart`

**Coach Portal Routes (Web-Only):**
```dart
// Coach Portal - Full-screen dashboard (WEB ONLY)
GoRoute(
  path: '/coach',
  name: 'coach-dashboard',
  redirect: (context, state) => kIsWeb ? null : '/settings',
  builder: (context, state) => const CoachPortalScreen(),
),

// Coach Apply (WEB ONLY)
GoRoute(
  path: '/coach/apply',
  name: 'coach-apply',
  redirect: (context, state) => kIsWeb ? null : '/settings',
  builder: (context, state) => const CoachRegistrationScreen(),
),

// My Coaches (MOBILE ONLY)
GoRoute(
  path: '/my-coaches',
  name: 'my-coaches',
  redirect: (context, state) => kIsWeb ? '/settings' : null,
  builder: (context, state) => const MyCoachesScreen(),
),

// Coach Chat (BOTH PLATFORMS)
GoRoute(
  path: '/chat/:relationshipId',
  name: 'coach-chat',
  builder: (context, state) => CoachChatScreen(relationshipId: relationshipId),
),
```

**Note**: All coach portal routes check `kIsWeb` and redirect appropriately (line 673, 688, 696, 704, 712)

## 4. COACH PORTAL LAYOUT (Web-Only Full-Screen)

### File: `/lib/features/coach_mode/presentation/screens/coach_portal_screen.dart`

**Structure: Split-Panel Row Layout**
```dart
Scaffold(
  backgroundColor: AppColors.blackberryDark,
  body: Row(
    children: [
      // Left sidebar: PortalSidebar (fixed width 280px)
      const PortalSidebar(),
      
      // Divider
      const VerticalDivider(width: 1),
      
      // Right panel: Expanded with Column
      Expanded(
        child: Column(
          children: [
            // Top bar (48px height)
            _buildTopBar(context, ref),
            
            // Content area: Athlete detail, reports, or messages
            Expanded(
              child: _buildRightPanel(portalState),
            ),
          ],
        ),
      ),
    ],
  ),
);
```

**Sidebar Details (PortalSidebar):**
- **Fixed Width**: 280px (line 19 in portal_sidebar.dart)
- **Background**: AppColors.blackberry
- **Contents**:
  - Header: "Coach Portal" with icon (56px height)
  - Nav section: Athletes, Reports, Messages (fixed buttons)
  - Athletes list: Expanded scrollable list (shows when Athletes section active)

**Top Bar Details:**
- **Height**: 48px (line 71)
- **Background**: AppColors.blackberry
- **Contents**: Refresh button, Back to App button (right-aligned)

**Right Panel Sections:**
1. Athletes: PortalAthleteDetailPanel (athlete info + activity table)
2. Reports: PortalReportsPlaceholder (empty state)
3. Messages: PortalMessagesPanel (coach-athlete chat)

### Portal Controller State (coach_portal_controller.dart):
```dart
class CoachPortalState {
  final PortalSection activeSection;      // Athletes, Reports, Messages
  final String? selectedRelationshipId;   // Selected athlete
  final CoachPortalView activeView;       // Detail, Chat, etc.
}

enum PortalSection { athletes, reports, messages }
```

## 5. BOTTOM NAVIGATION & COACH TAB VISIBILITY

### File: `/lib/shared/widgets/tabs_screen.dart`

**Dynamic Tab Generation (lines 45-66):**
```dart
// Check if user is a coach (from settings controller)
final settingsAsync = ref.watch(settingsControllerProvider);
final isCoach = settingsAsync.asData?.value.isCoach ?? false;

// Check if user has active coaches (as an athlete)
final myCoachesState = ref.watch(myCoachesControllerProvider);
final hasCoaches = myCoachesState.value?.hasCoaches ?? false;

// Show coach tab if user is a coach OR has coaches (web only for coaches)
final showCoachTab = kIsWeb ? (isCoach || hasCoaches) : hasCoaches;

// Build screens dynamically
final screens = [
  const ActivitiesListScreen(),    // 0: Calendar
  if (showCoachTab)
    isCoach
      ? const CoachDashboardScreen()  // Coach sees dashboard
      : const MyCoachesScreen(),       // Athlete sees their coaches
  const EventsListScreen(),           // 1 or 2: Events
  const SettingsScreen(),             // 2 or 3: Settings
];
```

**Key Logic:**
- **Web**: Coach tab visible if user is coach OR has coaches
- **Mobile**: Coach tab visible ONLY if user has coaches (not if user is coach)
- **Web Coach**: Taps coach tab → navigates to `/coach` (full-screen portal)
- **Mobile**: Coach tab → shows CoachDashboardScreen or MyCoachesScreen within tabs

### File: `/lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart`

**Floating Action Bar Design:**
- **Position**: Bottom center (Positioned widget)
- **Main Container**: Pill-shaped border with buttons
- **Buttons**: Calendar, Coach (optional), Events, Menu
- **Plus Button**: Orange circular button (50x50) to right of pill
- **Dynamic Indices**: Adjusts active button index based on showCoachTab flag

**Tab Index Mapping (lines 95-127):**
- Without coach tab: 0=Calendar, 1=Events, 2=Settings
- With coach tab: 0=Calendar, 1=Coach, 2=Events, 3=Settings

## 6. SETTINGS SCREEN - COACH MODE LINK

### File: `/lib/features/settings/presentation/screens/settings_screen.dart`

**Web vs Mobile Coach Links (lines 606-648):**

**Web Platform:**
```dart
if (isCoach) {
  // User is a coach - show Coach Dashboard link
  _buildQuickLink(
    title: 'Coach Dashboard',
    subtitle: 'Manage your athletes',
    onTap: () => context.push('/coach'),  // Full-screen portal
  );
} else {
  // User is not a coach - show Apply to Coach option
  _buildQuickLink(
    title: 'Apply to Coach',
    subtitle: 'Register as a coach',
    onTap: () => context.push('/coach/apply'),
  );
}
```

**Mobile Platform:**
```dart
// Athletes can view their coaches
_buildQuickLink(
  title: 'My Coaches',
  subtitle: 'View and chat with your coaches',
  onTap: () => context.push('/my-coaches'),
);
```

## 7. LOGIN/AUTH SCREEN LAYOUT

### File: `/lib/features/auth/presentation/screens/email_login_screen.dart`

**Layout Pattern (lines 82-285):**
```dart
Scaffold(
  appBar: AppBar(...),
  body: Stack(
    children: [
      // Main content (responsive)
      SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPaddingHorizontal,
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title, subtitle, inputs, buttons...
              ],
            ),
          ),
        ),
      ),
      
      // Loading overlay (if isLoading)
      if (asyncState.isLoading)
        Container(
          color: scaffoldBackground.withOpacity(0.9),
          child: Center(...),
        ),
    ],
  ),
);
```

**Note**: This screen is not wrapped with responsive constraints - it will be full-width on web.

### File: `/lib/features/onboarding/presentation/screens/welcome_screen.dart`

**Layout Pattern (lines 27-85):**
```dart
Scaffold(
  backgroundColor: AppColors.blackberry,
  body: SafeArea(
    child: Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero image, title, welcome message
          // Spacer for vertical centering
          const Spacer(),
          
          // Get Started and Login buttons
          // Skip link
        ],
      ),
    ),
  ),
);
```

**Note**: Also not wrapped with responsive constraints - will be full-width on web.

## 8. KISDEBUG AND PLATFORM-SPECIFIC CODE

**Usage Pattern Throughout Codebase:**
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Web-specific route redirects
if (kIsWeb) return null;  // Allow web navigation
if (kIsWeb) return '/settings';  // Redirect mobile to settings

// OAuth service differences
final redirectUri = kIsWeb ? '...' : '...';

// Post-onboarding auth (no biometrics on web)
if (kIsWeb) return;  // Skip biometric setup
```

**Key Files Using kIsWeb:**
1. `app_router.dart` - Coach portal redirects
2. `tabs_screen.dart` - Coach tab visibility
3. `settings_screen.dart` - Coach mode links
4. `floating_action_buttons_bar.dart` - Tab indexing
5. `responsive_content_wrapper.dart` - Max-width constraints
6. `oauth_service.dart` - OAuth redirects
7. `post_onboarding_auth_screen.dart` - Biometric skipping
8. `force_upgrade_screen.dart` - Update UX differences

## 9. KEY ARCHITECTURAL DECISIONS

### Web Layout Philosophy:
- **Full Width on Web**: ResponsiveContentWrapper skips constraints on web (kIsWeb check)
- **iPad Centering**: 750px max-width when screen > 750px
- **Coach Portal Web-Only**: Split-panel layout only available on web via `/coach` route
- **Mobile Coach Features**: Coaches see dashboard in tab bar; athletes see "My Coaches"
- **Responsive Navigation**: Floating action bar adjusts indices based on coach tab visibility

### No Existing Centered Layout:
- Login/welcome screens NOT wrapped with responsive constraints
- They use full width on web (just SafeArea + Padding)
- ResponsiveContentWrapper applied at root for OVERALL app centering
- Individual screens don't explicitly center (they're already wrapped at root)

## 10. SUMMARY OF WEB LAYOUT

**Current Web Experience:**
1. All screens use ResponsiveContentWrapper at root → No additional constraints
2. Screens are full-width on web (child returned as-is)
3. Login/welcome screens are full-width
4. Coach portal is full-width split-panel layout (280px sidebar + expanded right panel)
5. Main app tabs are full-width with bottom floating action bar
6. Settings screen is full-width with full-width coach links

**ResponsiveContentWrapper Location:**
- Applied in `RootAppWidget.build()` via `builder: (context, child) => ResponsiveContentWrapper(child: child!)`
- Affects ALL screens without individual modifications
- On web: returns child as-is (no centering)
- On iPad: centers + constrains to 750px

**If Web Centering Needed:**
- Modify ResponsiveContentWrapper to NOT skip web (remove kIsWeb early return)
- OR: Create separate web-specific max-width (e.g., 1200px for desktop)
- OR: Apply in specific screens instead of root level
