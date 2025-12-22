# Coach Mode Implementation Roadmap

**Document Created**: 2025-12-15
**Purpose**: Complete implementation roadmap for coach portal feature in Mealvana Endurance
**Timeline**: 12-16 weeks from design to production
**Status**: Planning Phase

---

## Executive Summary

### Vision
Enable certified coaches and dietitians to manage multiple athletes via a Flutter web portal, creating a premium coaching platform that complements the existing mobile nutrition planning app.

### Business Goals
- **Revenue Stream**: Two-tier paid subscription model ($15-25/month for <20 athletes, $40-60/month for 20+ athletes)
- **Market Position**: Premium coaching features competitive with TrainingPeaks ($22/mo) and Final Surge ($21/mo)
- **Launch Timeline**: IMMEDIATE MVP launch desired with manual billing, automated payment later
- **Multi-Sport Support**: Running, cycling, and swimming from day one

### Key Features
- **Many-to-Many Relationships**: Athletes can work with multiple coaches, coaches can manage multiple athletes
- **Full Edit Access**: Coaches have complete access to athlete data (activities, nutrition plans, progress tracking)
- **Dual Web Access**: Both coaches AND athletes can use Flutter web portal
- **Mode Toggle**: Seamless switching between coach and athlete views with visual indicators
- **Email Invitations**: Industry-standard connection workflow (TrainingPeaks/Final Surge pattern)
- **Manual Verification**: NCCA-certified coaches verified manually during beta phase

### Success Metrics
- **Beta Phase**: 10-20 coaches managing 50-100 athletes within 3 months
- **Coach Adoption**: 70%+ of invited coaches complete verification within 7 days
- **Athlete Connections**: Average 8-12 athletes per coach within 6 months
- **Retention**: 80%+ monthly subscription renewal rate
- **Revenue**: $5K-10K MRR within 6 months of launch

---

## Technical Architecture

### Flutter Web Platform
- **Renderer**: Skwasm (WebAssembly) for production performance
- **Code Reusability**: 90% shared codebase with mobile app
- **Navigation**: GoRouter for web routing with deep linking support
- **State Management**: Riverpod with AsyncNotifier patterns (Andrea Bizzotto FOA)
- **Responsive Design**: flutter_screenutil for desktop/tablet/mobile breakpoints

### Backend Infrastructure
- **Database**: Supabase PostgreSQL with Row Level Security (RLS)
- **Authentication**: Device-based auth (mobile) + Supabase Auth (web)
- **Edge Functions**: TypeScript edge functions for coach verification, invitations, billing
- **Storage**: No Drift on web - direct Supabase queries only

### Hosting Strategy
- **Platform**: Cloudflare Pages (RECOMMENDED)
  - Unlimited bandwidth (critical for coaching platform)
  - Free tier supports commercial use
  - Global CDN with edge caching
  - Automatic HTTPS with custom domain
  - GitHub Actions integration
- **Domain**: enduranceapp.mealvana.io
- **Alternative**: Netlify (100GB bandwidth, fallback option)
- **NOT Vercel**: Free tier prohibits commercial use, requires $20/month Pro plan

### Database Architecture
Reference complete schema analysis at `/docs/features/coach_mode/schema_analysis.md`:
- **3 New Tables**: coaches, coach_athlete_relationships, coach_feedback
- **4 Modified Tables**: nutrition_plans, activities, workout_notes, activity_completions
- **22 New RLS Policies**: Granular coach access control with permission levels
- **15 Indexes**: Optimized for coach dashboard queries
- **3 Helper Functions**: Permission checks, athlete/coach listings
- **5 Triggers**: Relationship lifecycle, athlete limits, timestamp updates

---

## Feature Roadmap (Phased Approach)

### MVP Phase (Weeks 1-6): Core Coach Features
**Goal**: Launch with manual billing, essential coach functionality
**Timeline**: 6 weeks to production
**Focus**: Speed to market with minimal viable features

#### Core Features
1. **Coach Registration & Verification**
   - Coach profile creation via Flutter web
   - Manual verification workflow (3-5 business days)
   - NCCA certification validation (RRCA, USAT, ACE, NASM, ACSM)
   - Professional liability insurance check ($1M+ coverage)
   - Admin approval dashboard

2. **Coach-Athlete Connection**
   - Email invitation link generation (72-hour expiration)
   - Unique token-based acceptance flow
   - Connection status tracking (pending/active/declined/archived)
   - Permission level selection (view_only/full_access)
   - Manual revocation by either party

3. **Coach Dashboard (Web)**
   - Athlete list with status indicators
   - Recent activity feed (last 7 days)
   - Upcoming events/activities calendar view
   - Quick stats: total athletes, pending invitations, compliance scores
   - Search and filter athletes

4. **Core Coach Screens**
   - Athlete detail view (profile, biometrics, preferences)
   - Activity history (planned vs completed workouts)
   - Nutrition plan viewer (read-only for view_only permission)
   - Nutrition plan editor (for full_access permission)
   - Progress tracking (completion rates, macro adherence)

5. **Basic Messaging**
   - Thread-based messaging (coach ↔ athlete)
   - Message notifications via email
   - Attachment support (images, PDFs)
   - Message history per athlete

6. **Mode Toggle**
   - Toggle switch in app bar (Coach ↔ Athlete view)
   - Visual badge indicator (coach mode active)
   - Separate navigation stacks per mode
   - Persistence across sessions

7. **Manual Billing**
   - Invoice generation via email
   - PayPal/Venmo/Zelle payment instructions
   - Manual subscription tracking spreadsheet
   - Payment confirmation workflow

#### Technical Deliverables
- [ ] Flutter web build configuration (Skwasm renderer)
- [ ] Cloudflare Pages deployment pipeline
- [ ] Coach database schema migration
- [ ] Coach registration Edge Function
- [ ] Email invitation Edge Function
- [ ] 8 new coach screens (registration, dashboard, athlete list, athlete detail, activity view, plan view, messaging, settings)
- [ ] 6 new widgets (coach card, athlete card, activity card, plan card, message thread, mode toggle)
- [ ] Manual verification admin interface
- [ ] Email templates (invitation, approval, rejection)

#### Success Criteria
- ✅ 10+ coaches complete registration and verification
- ✅ 50+ coach-athlete connections established
- ✅ 80%+ invitation acceptance rate within 48 hours
- ✅ <5% error rate on core coach flows
- ✅ Sub-2 second page load times on dashboard

---

### Beta Phase (Weeks 7-12): Enhanced Features & Automated Billing
**Goal**: Scale to 50 coaches with automated payment processing
**Timeline**: 6 weeks for feature completion
**Focus**: Automation, analytics, user experience improvements

#### Enhanced Features
1. **Stripe Integration**
   - Stripe Checkout for subscription signup
   - Customer Portal for subscription management (upgrade/downgrade/cancel)
   - Automatic tier upgrades at 20 athletes threshold
   - Failed payment retry logic (3 attempts over 7 days)
   - Webhook handlers for subscription events

2. **Advanced Coach Dashboard**
   - Compliance score calculation (workout completion %, nutrition adherence)
   - Week-over-week progress charts (volume, intensity, nutrition)
   - Custom date range filtering
   - Export athlete data (CSV/PDF reports)
   - Multi-athlete comparison view

3. **Calendar Integration**
   - Monthly/weekly calendar view of athlete activities
   - Drag-and-drop activity scheduling
   - Bulk assign workouts to multiple athletes
   - Event countdown timers (race day preparation)
   - Training plan templates

4. **Enhanced Messaging**
   - Email notifications for new messages
   - Push notifications (web push API)
   - Unread message badges
   - Message search and filtering
   - Scheduled messages (future send)

5. **Automated Coach Verification (Hybrid)**
   - Auto-approve coaches with verified NCCA credentials (50-200 coach scale)
   - Automated insurance verification via API (if available)
   - Manual review queue for edge cases
   - Rejection reason templates
   - Re-verification workflow (annual)

#### Technical Deliverables
- [ ] Stripe Checkout integration
- [ ] Subscription management Edge Functions (create, upgrade, cancel)
- [ ] Webhook handlers for Stripe events
- [ ] Calendar UI component (monthly/weekly views)
- [ ] Compliance score calculation service
- [ ] Progress analytics Edge Function
- [ ] Email notification service (SendGrid/AWS SES)
- [ ] Push notification setup (web push)
- [ ] Hybrid verification workflow
- [ ] CSV/PDF report generation

#### Success Criteria
- ✅ 50+ coaches subscribed via Stripe
- ✅ 95%+ successful payment processing rate
- ✅ <1% churn rate during beta
- ✅ 90%+ coaches use calendar feature weekly
- ✅ 50+ automated verifications completed

---

### Scale Phase (Weeks 13-16): Growth Features
**Goal**: Scale to 200+ coaches with advanced collaboration tools
**Timeline**: 4 weeks for optimization
**Focus**: Platform stability, advanced features, API integrations

#### Scale Features
1. **Real-Time Chat System**
   - Supabase Realtime for instant messaging
   - Typing indicators
   - Read receipts
   - Message reactions
   - Group messaging (coach + multiple athletes)

2. **Advanced Analytics Dashboard**
   - Athlete performance trends (3/6/12 month views)
   - Goal achievement tracking
   - Injury risk indicators (volume spikes, recovery deficits)
   - Nutrition adherence heatmaps
   - Custom metric tracking

3. **Multi-Coach Coordination**
   - Shared athlete notes (visible to all athlete's coaches)
   - Coach-to-coach messaging
   - Conflict resolution (overlapping workouts/plans)
   - Primary coach designation
   - Coach permission inheritance

4. **API for Third-Party Integrations**
   - REST API for external tools
   - Webhook support for activity sync
   - OAuth 2.0 authentication
   - Rate limiting (1000 requests/hour per coach)
   - API documentation (OpenAPI spec)

5. **Advanced Verification**
   - Automated NCCA credential API verification
   - Background check integration (Checkr - $30/coach)
   - Automated insurance verification
   - Annual re-verification reminders
   - Public coach directory (verified coaches only)

#### Technical Deliverables
- [ ] Supabase Realtime integration
- [ ] Advanced analytics Edge Functions
- [ ] Multi-coach coordination logic
- [ ] REST API implementation (FastAPI/Express)
- [ ] OAuth 2.0 server setup
- [ ] Webhook infrastructure
- [ ] Background check integration (Checkr API)
- [ ] Public coach directory UI
- [ ] Performance monitoring (APM)
- [ ] Load testing (1000+ concurrent coaches)

#### Success Criteria
- ✅ 200+ active coach subscriptions
- ✅ 2000+ active coach-athlete relationships
- ✅ 95%+ uptime during peak usage (6-9am, 5-8pm)
- ✅ Sub-1 second API response times (p99)
- ✅ 10+ third-party integrations using API

---

## Database Migration Plan

### Schema Changes Overview
**Reference**: `/docs/features/coach_mode/schema_analysis.md` for complete DDL and RLS policies

#### New Tables (3)

1. **coaches** - Coach profiles and settings
   - One-to-one with users table (coach_id → user_id)
   - Verification status, certifications, specializations
   - Business info (email, phone, website)
   - Athlete limits and auto-accept settings

2. **coach_athlete_relationships** - Core relationship management
   - Many-to-many relationships (coach ↔ athlete)
   - Status tracking (pending/active/declined/archived)
   - Permission levels (view_only/full_access/custom)
   - JSONB custom permissions for granular control
   - Relationship metadata (requested_by, timestamps)

3. **coach_feedback** - Coach notes and feedback
   - Linked to specific activities or nutrition plans
   - Visibility controls (athlete-visible vs coach-only)
   - Feedback types (general/activity/nutrition/progress/goal)

#### Modified Tables (4)

1. **nutrition_plans** - Track coach involvement
   - Add: created_by_coach_id, last_modified_by_coach_id
   - Add: coach_notes, is_coach_created
   - RLS: Coach read/write policies based on permissions

2. **activities** - Track coach assignments
   - Add: created_by_coach_id, assigned_by_coach_id
   - Add: coach_notes, is_coach_assigned
   - RLS: Coach read/write policies based on permissions

3. **workout_notes** - Enable coach annotations
   - Add: created_by_coach_id, is_coach_note
   - Add: is_visible_to_athlete
   - RLS: Coach read/add policies

4. **activity_completions** - Enable coach visibility
   - No schema changes
   - RLS: Coach read policy based on permissions

### Migration Script Location
**File**: `/docs/features/coach_mode/schema_analysis.md` (Section 11)

### Migration Phases

#### Phase 1: Create Core Tables (Week 2)
```sql
-- Create enum types
CREATE TYPE relationship_status_enum AS ENUM ('pending', 'active', 'declined', 'archived');
CREATE TYPE permission_level_enum AS ENUM ('view_only', 'full_access', 'custom');

-- Create coaches table
CREATE TABLE coaches (...);

-- Create coach_athlete_relationships table
CREATE TABLE coach_athlete_relationships (...);

-- Create coach_feedback table
CREATE TABLE coach_feedback (...);
```

#### Phase 2: Modify Existing Tables (Week 2)
```sql
-- Add coach columns to nutrition_plans
ALTER TABLE nutrition_plans
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id),
  ADD COLUMN last_modified_by_coach_id UUID REFERENCES coaches(id),
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_created BOOLEAN DEFAULT false;

-- Add coach columns to activities
ALTER TABLE activities
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id),
  ADD COLUMN assigned_by_coach_id UUID REFERENCES coaches(id),
  ADD COLUMN coach_notes TEXT,
  ADD COLUMN is_coach_assigned BOOLEAN DEFAULT false;

-- Add coach columns to workout_notes
ALTER TABLE workout_notes
  ADD COLUMN created_by_coach_id UUID REFERENCES coaches(id),
  ADD COLUMN is_coach_note BOOLEAN DEFAULT false,
  ADD COLUMN is_visible_to_athlete BOOLEAN DEFAULT true;
```

#### Phase 3: Create RLS Policies (Week 2)
```sql
-- Enable RLS on new tables
ALTER TABLE coaches ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_athlete_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE coach_feedback ENABLE ROW LEVEL SECURITY;

-- Create 22 RLS policies for coach access control
-- See schema_analysis.md Section 5 for complete policy definitions
```

#### Phase 4: Create Helper Functions & Triggers (Week 3)
```sql
-- Helper function: Check coach permission
CREATE OR REPLACE FUNCTION has_coach_permission(...) RETURNS BOOLEAN;

-- Helper function: Get coach's athletes
CREATE OR REPLACE FUNCTION get_coach_athletes(...) RETURNS TABLE;

-- Helper function: Get athlete's coaches
CREATE OR REPLACE FUNCTION get_athlete_coaches(...) RETURNS TABLE;

-- Triggers: updated_at, relationship status dates, athlete limits
-- See schema_analysis.md Section 7 for complete trigger definitions
```

### Rollback Strategy
Each migration phase can be rolled back independently:

```sql
-- Rollback Phase 4
DROP TRIGGER IF EXISTS update_relationship_status_dates_trigger ON coach_athlete_relationships;
DROP FUNCTION IF EXISTS has_coach_permission(TEXT, TEXT, TEXT);

-- Rollback Phase 3
DROP POLICY IF EXISTS "Coaches can view athlete plans" ON nutrition_plans;
-- ... (drop all 22 policies)

-- Rollback Phase 2
ALTER TABLE nutrition_plans
  DROP COLUMN IF EXISTS created_by_coach_id,
  DROP COLUMN IF EXISTS coach_notes;
-- ... (drop columns from all modified tables)

-- Rollback Phase 1
DROP TABLE IF EXISTS coach_feedback CASCADE;
DROP TABLE IF EXISTS coach_athlete_relationships CASCADE;
DROP TABLE IF EXISTS coaches CASCADE;
DROP TYPE IF EXISTS permission_level_enum;
DROP TYPE IF EXISTS relationship_status_enum;
```

### Testing Strategy
1. **Local Testing**: Use Supabase CLI (`supabase db reset`, `supabase db diff`)
2. **Dev Environment**: Deploy to dev project first, run integration tests
3. **Production**: Deploy with manual approval after dev validation

---

## Flutter Web Setup Guide

### Prerequisites
- Flutter 3.24.0+ (stable channel)
- Dart 3.0+
- Web browser with WebAssembly support

### Platform Detection Pattern
```dart
// lib/shared/utils/platform_helper.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class PlatformHelper {
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isIOS || Platform.isAndroid);
  static bool get isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);
}
```

### Conditional Imports (Database Layer)
```dart
// lib/shared/database/database_provider.dart
export 'database_provider_stub.dart'
  if (dart.library.io) 'database_provider_mobile.dart'
  if (dart.library.html) 'database_provider_web.dart';

// database_provider_mobile.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor getDatabaseExecutor() {
  return driftDatabase(name: 'mealvana_db');
}

// database_provider_web.dart
import 'package:supabase_flutter/supabase_flutter.dart';

// NO Drift on web - use Supabase directly
SupabaseClient getSupabaseClient() {
  return Supabase.instance.client;
}
```

### Web-Specific Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # Shared dependencies
  riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  go_router: ^14.0.0
  supabase_flutter: ^2.0.0

  # Web-specific (conditionally imported)
  universal_html: ^2.2.4
  web: ^0.5.1

dev_dependencies:
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
```

### Build Configuration
```bash
# Development build (debug mode)
flutter build web --web-renderer canvaskit

# Production build (Skwasm with WebAssembly)
flutter build web --web-renderer skwasm --release

# Custom output directory for Cloudflare Pages
flutter build web --web-renderer skwasm --release --output web/dist
```

### Web-Specific Configuration Files

**web/index.html** (updated for Skwasm):
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mealvana Endurance - Coach Portal</title>

  <!-- Service Worker Registration -->
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('flutter-first-frame', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
  </script>

  <!-- Skwasm Loader -->
  <script src="flutter_bootstrap.js" async></script>
</head>
<body>
  <div id="loading">
    <p>Loading Mealvana Endurance...</p>
  </div>
</body>
</html>
```

### Navigation Setup (GoRouter)
```dart
// lib/shared/routing/router_config.dart
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

@riverpod
GoRouter router(RouterRef ref) {
  return GoRouter(
    initialLocation: '/coach/dashboard',
    routes: [
      // Coach routes (web + mobile)
      GoRoute(
        path: '/coach/register',
        builder: (context, state) => const CoachRegistrationScreen(),
      ),
      GoRoute(
        path: '/coach/dashboard',
        builder: (context, state) => const CoachDashboardScreen(),
      ),
      GoRoute(
        path: '/coach/athletes/:athleteId',
        builder: (context, state) {
          final athleteId = state.pathParameters['athleteId']!;
          return AthleteDetailScreen(athleteId: athleteId);
        },
      ),

      // Athlete routes (mobile only - conditionally visible)
      GoRoute(
        path: '/athlete/dashboard',
        builder: (context, state) => const AthleteDashboardScreen(),
      ),

      // Shared routes
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // Redirect logic based on authentication and mode
    redirect: (context, state) {
      final isCoachMode = ref.read(appModeProvider) == AppMode.coach;
      final isAuthenticated = ref.read(authStateProvider).hasValue;

      if (!isAuthenticated && !state.path.startsWith('/auth')) {
        return '/auth/login';
      }

      if (isCoachMode && !state.path.startsWith('/coach')) {
        return '/coach/dashboard';
      }

      return null; // No redirect
    },
  );
}
```

### Responsive Design Considerations
```dart
// lib/shared/widgets/responsive_layout.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200 && desktop != null) {
          return desktop!;
        } else if (constraints.maxWidth >= 768 && tablet != null) {
          return tablet!;
        } else {
          return mobile;
        }
      },
    );
  }
}

// Usage in coach dashboard
class CoachDashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveLayout(
      mobile: _MobileCoachDashboard(),
      tablet: _TabletCoachDashboard(),
      desktop: _DesktopCoachDashboard(),
    );
  }
}
```

### Web Performance Optimization
- **Code Splitting**: Use deferred imports for large features
- **Image Optimization**: Use WebP format, lazy loading for athlete photos
- **Asset Caching**: Configure service worker for offline asset access
- **Font Loading**: Use `FontManifest.json` with subset fonts
- **Tree Shaking**: Ensure `--release` mode removes unused code

---

## Coach Onboarding Flow

### Registration Process

#### Step 1: Initial Registration (Web Form)
**Screen**: CoachRegistrationScreen
**Duration**: 3-5 minutes

**Form Fields**:
- Full name (required)
- Email address (required, verified)
- Phone number (optional)
- Business name (optional)
- Website URL (optional)
- Specializations (multi-select: marathon, triathlon, cycling, nutrition, ultra)
- Bio (500 characters max)

**Action**: Submit → Create pending coach profile

#### Step 2: Certification Upload
**Screen**: CoachCertificationScreen
**Duration**: 5-10 minutes

**Required Uploads**:
- NCCA-accredited certification (RRCA, USAT, ACE, NASM, ACSM, etc.)
- Professional liability insurance certificate ($1M+ coverage)
- Photo ID (driver's license or passport)

**Optional Uploads**:
- Additional certifications
- Professional headshot
- References (email addresses)

**Action**: Upload documents → Trigger manual review workflow

#### Step 3: Manual Verification (Admin)
**Dashboard**: Admin Coach Verification Dashboard
**Timeline**: 3-5 business days

**Verification Checklist**:
- ☐ Certification validity check (expiration date, authenticity)
- ☐ Insurance coverage confirmation ($1M+ required)
- ☐ Photo ID verification (name match)
- ☐ Background check (optional, $30 via Checkr)
- ☐ References contacted (optional)
- ☐ Rejection reason documented (if denied)

**Admin Actions**:
- Approve → Send welcome email with setup instructions
- Reject → Send rejection email with reason and reapplication link
- Request more info → Send clarification email

#### Step 4: Welcome & Setup (Coach)
**Screen**: CoachWelcomeScreen
**Duration**: 5-10 minutes

**Setup Tasks**:
- ☐ Choose subscription tier (<20 athletes or 20+)
- ☐ Enter billing information (MVP: Manual invoice, Beta: Stripe)
- ☐ Set max athlete limit (default: 50)
- ☐ Configure auto-accept invitations (default: off)
- ☐ Complete profile (headshot, detailed bio, social links)
- ☐ Generate first athlete invitation link

**Action**: Complete setup → Redirect to coach dashboard

### Verification Workflow Implementation

#### Manual Verification (MVP & Beta Phase)
**Use Case**: <50 coaches, high quality bar

**Edge Function**: `verify-coach-manual`
```typescript
// supabase/functions/verify-coach-manual/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(...)
  const { coachId, adminUserId, approved, rejectionReason } = await req.json()

  // Validate admin permissions
  const { data: admin } = await supabase
    .from('admins')
    .select('*')
    .eq('user_id', adminUserId)
    .single()

  if (!admin) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 403 })
  }

  // Update coach status
  const { error } = await supabase
    .from('coaches')
    .update({
      is_verified: approved,
      is_active: approved,
      rejection_reason: rejectionReason,
      verified_at: approved ? new Date().toISOString() : null,
      verified_by: approved ? adminUserId : null,
    })
    .eq('id', coachId)

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  // Send notification email (SendGrid/AWS SES)
  if (approved) {
    await sendWelcomeEmail(coachEmail, coachName)
  } else {
    await sendRejectionEmail(coachEmail, coachName, rejectionReason)
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
```

#### Hybrid Automated Verification (Scale Phase)
**Use Case**: 50-200 coaches, balance quality + speed

**Edge Function**: `verify-coach-hybrid`
```typescript
// supabase/functions/verify-coach-hybrid/index.ts
serve(async (req) => {
  const { coachId } = await req.json()

  // Fetch coach data
  const { data: coach } = await supabase
    .from('coaches')
    .select('*, certification_data, insurance_data')
    .eq('id', coachId)
    .single()

  // Auto-verification checks
  const checks = {
    certificationValid: await validateNCCACertification(coach.certification_data),
    insuranceValid: await validateInsurance(coach.insurance_data, 1000000), // $1M+
    noDuplicates: await checkDuplicateCoach(coach.email),
  }

  if (checks.certificationValid && checks.insuranceValid && checks.noDuplicates) {
    // Auto-approve
    await supabase
      .from('coaches')
      .update({
        is_verified: true,
        is_active: true,
        verified_at: new Date().toISOString(),
        verification_method: 'automated',
      })
      .eq('id', coachId)

    await sendWelcomeEmail(coach.email, coach.coach_name)
    return new Response(JSON.stringify({ approved: true, method: 'automated' }), { status: 200 })
  } else {
    // Queue for manual review
    await supabase
      .from('verification_queue')
      .insert({
        coach_id: coachId,
        failed_checks: Object.entries(checks).filter(([_, v]) => !v).map(([k]) => k),
        created_at: new Date().toISOString(),
      })

    await sendManualReviewEmail(coach.email, coach.coach_name)
    return new Response(JSON.stringify({ approved: false, method: 'manual_queue' }), { status: 200 })
  }
})
```

### First-Time Coach Experience

#### Coach Dashboard (Empty State)
**Screen**: CoachDashboardScreen (first load)

**UI Elements**:
- Welcome message: "Welcome, [Coach Name]! Let's get started."
- Empty state illustration (athletes icon with "No athletes yet")
- Primary CTA: "Invite Your First Athlete" button
- Secondary CTAs:
  - "Complete Your Profile" (if incomplete)
  - "Watch Tutorial Video" (2-minute onboarding)
  - "Join Coach Community" (link to Slack/Discord)

**Analytics Tracking**:
- Event: `coach_dashboard_first_load`
- Properties: `coach_id`, `verification_date`, `profile_completion_%`

#### Invitation Link Generation
**Screen**: GenerateInvitationScreen

**UI Elements**:
- Athlete email input (required)
- Custom message textarea (optional, 200 characters)
- Permission level selector (view_only / full_access)
- Expiration period selector (24h / 72h / 7 days, default: 72h)
- Generate button → Copy link to clipboard

**Generated Link Format**:
```
https://enduranceapp.mealvana.io/coach/invite/{unique_token}
```

**Edge Function**: `generate-invitation-link`
```typescript
serve(async (req) => {
  const { coachId, athleteEmail, permissionLevel, expiresInHours, customMessage } = await req.json()

  // Generate unique token
  const token = crypto.randomUUID()

  // Create invitation record
  const expiresAt = new Date()
  expiresAt.setHours(expiresAt.getHours() + (expiresInHours || 72))

  await supabase
    .from('coach_athlete_invitations')
    .insert({
      token,
      coach_id: coachId,
      athlete_email: athleteEmail,
      permission_level: permissionLevel,
      custom_message: customMessage,
      expires_at: expiresAt.toISOString(),
      status: 'pending',
    })

  // Send invitation email
  await sendInvitationEmail(
    athleteEmail,
    `https://enduranceapp.mealvana.io/coach/invite/${token}`,
    coach.coach_name,
    customMessage
  )

  return new Response(JSON.stringify({
    token,
    link: `https://enduranceapp.mealvana.io/coach/invite/${token}`,
    expiresAt: expiresAt.toISOString(),
  }), { status: 200 })
})
```

---

## Athlete Experience

### Web Access for Athletes
**Domain**: enduranceapp.mealvana.io (same as coaches)
**Authentication**: Device-based (mobile) OR Supabase Auth (web)

#### Athlete Web Features
- **Nutrition Plan Viewer**: View coach-assigned plans (read-only)
- **Activity Calendar**: See scheduled workouts and events
- **Progress Dashboard**: Track completion rates, macro adherence
- **Messaging**: Communicate with coaches via thread-based system
- **Profile Management**: Update biometrics, food preferences, goals

#### Mobile-First, Web-Compatible
- **Primary Platform**: Flutter mobile app (iOS/Android)
- **Secondary Platform**: Flutter web for desktop access (optional)
- **Sync**: Real-time sync via Supabase Realtime (mobile ↔ web)

### Mode Toggle (Coach ↔ Athlete)

#### Toggle UI Component
**Widget**: ModeToggleWidget
**Location**: App bar (top-right corner)

```dart
// lib/shared/widgets/mode_toggle_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ModeToggleWidget extends ConsumerWidget {
  const ModeToggleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);
    final isCoach = ref.watch(isCoachProvider);

    // Only show toggle if user is a coach
    if (!isCoach) return const SizedBox.shrink();

    return Row(
      children: [
        // Badge indicator
        if (currentMode == AppMode.coach)
          const Chip(
            label: Text('Coach Mode'),
            backgroundColor: Colors.blue,
            labelStyle: TextStyle(color: Colors.white),
          ),

        const SizedBox(width: 8),

        // Toggle switch
        Switch(
          value: currentMode == AppMode.coach,
          onChanged: (isCoachMode) {
            ref.read(appModeProvider.notifier).toggleMode();

            // Analytics tracking
            ref.read(analyticsServiceProvider).logEvent(
              'mode_toggle',
              parameters: {
                'from_mode': currentMode.name,
                'to_mode': isCoachMode ? 'coach' : 'athlete',
              },
            );

            // Navigate to appropriate dashboard
            context.go(isCoachMode ? '/coach/dashboard' : '/athlete/dashboard');
          },
        ),

        const SizedBox(width: 8),

        // Mode label
        Text(
          currentMode == AppMode.coach ? 'Coach View' : 'Athlete View',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

// State provider for app mode
@riverpod
class AppMode extends _$AppMode {
  @override
  AppMode build() {
    // Load persisted mode from local storage
    final prefs = ref.read(sharedPreferencesProvider);
    final modeString = prefs.getString('app_mode') ?? 'athlete';
    return AppMode.values.firstWhere(
      (mode) => mode.name == modeString,
      orElse: () => AppMode.athlete,
    );
  }

  void toggleMode() {
    final newMode = state == AppMode.coach ? AppMode.athlete : AppMode.coach;
    state = newMode;

    // Persist mode
    ref.read(sharedPreferencesProvider).setString('app_mode', newMode.name);
  }
}

enum AppMode { coach, athlete }
```

#### Visual Indicators
- **Coach Mode Active**:
  - Blue badge in app bar: "Coach Mode"
  - Blue accent color theme
  - Navigation drawer shows coach-specific routes
  - Dashboard title: "Coach Dashboard"

- **Athlete Mode Active**:
  - No badge (default state)
  - Green accent color theme
  - Navigation drawer shows athlete-specific routes
  - Dashboard title: "My Dashboard"

#### Mode Persistence
- **Storage**: SharedPreferences (mobile), LocalStorage (web)
- **Key**: `app_mode` (values: `coach`, `athlete`)
- **Sync**: Mode preference synced across devices via Supabase (user_profiles.preferred_mode)

### Accepting Coach Invitations

#### Invitation Acceptance Flow

**Step 1: Receive Email**
- Subject: "[Coach Name] has invited you to join Mealvana Endurance"
- Body: Personalized message + CTA button "Accept Invitation"
- Link: `https://enduranceapp.mealvana.io/coach/invite/{token}`

**Step 2: Click Invitation Link**
- Redirect to web app (or deep link to mobile app)
- Parse token from URL
- Fetch invitation details via Edge Function

**Edge Function**: `get-invitation-details`
```typescript
serve(async (req) => {
  const url = new URL(req.url)
  const token = url.searchParams.get('token')

  // Validate token
  const { data: invitation, error } = await supabase
    .from('coach_athlete_invitations')
    .select('*, coach:coaches(*)')
    .eq('token', token)
    .eq('status', 'pending')
    .gt('expires_at', new Date().toISOString())
    .single()

  if (error || !invitation) {
    return new Response(JSON.stringify({ error: 'Invalid or expired invitation' }), { status: 400 })
  }

  return new Response(JSON.stringify({
    invitation: {
      coachName: invitation.coach.coach_name,
      coachBio: invitation.coach.bio,
      permissionLevel: invitation.permission_level,
      customMessage: invitation.custom_message,
      expiresAt: invitation.expires_at,
    }
  }), { status: 200 })
})
```

**Step 3: Invitation Preview Screen**
**Screen**: InvitationPreviewScreen

**UI Elements**:
- Coach profile card (name, photo, bio, specializations)
- Custom message from coach
- Permission level explanation:
  - View Only: "Coach can view your activities and nutrition plans"
  - Full Access: "Coach can view and edit your activities and nutrition plans"
- Expiration countdown: "Invitation expires in 47 hours"
- Primary CTA: "Accept Invitation" button (green)
- Secondary CTA: "Decline" button (gray)

**Step 4: Accept Invitation**
**Action**: User clicks "Accept Invitation"

**Edge Function**: `accept-coach-invitation`
```typescript
serve(async (req) => {
  const { token, athleteDeviceId } = await req.json()

  // Fetch invitation
  const { data: invitation } = await supabase
    .from('coach_athlete_invitations')
    .select('*')
    .eq('token', token)
    .single()

  if (!invitation || invitation.status !== 'pending') {
    return new Response(JSON.stringify({ error: 'Invalid invitation' }), { status: 400 })
  }

  // Get athlete user_id from device_id
  const { data: athlete } = await supabase
    .from('users')
    .select('id')
    .eq('device_id', athleteDeviceId)
    .single()

  // Create coach-athlete relationship
  await supabase
    .from('coach_athlete_relationships')
    .insert({
      coach_id: invitation.coach_id,
      athlete_user_id: athlete.id,
      athlete_device_id: athleteDeviceId,
      status: 'active',
      permission_level: invitation.permission_level,
      requested_by: 'coach',
      accepted_at: new Date().toISOString(),
    })

  // Mark invitation as accepted
  await supabase
    .from('coach_athlete_invitations')
    .update({ status: 'accepted', accepted_at: new Date().toISOString() })
    .eq('token', token)

  // Send confirmation emails
  await sendAcceptanceConfirmationEmail(invitation.athlete_email, invitation.coach.coach_name)
  await sendCoachNotificationEmail(invitation.coach.email, athlete.name)

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
```

**Step 5: Confirmation Screen**
**Screen**: InvitationAcceptedScreen

**UI Elements**:
- Success icon (green checkmark)
- Message: "You're now connected with [Coach Name]!"
- Next steps:
  - "View Your Coach" button → Navigate to coach profile
  - "Continue to Dashboard" button → Navigate to athlete dashboard
- Coach contact info (email, phone if provided)

#### Managing Coach Relationships

**Screen**: AthleteCoachesScreen
**Navigation**: Settings → My Coaches

**UI Elements**:
- List of connected coaches (cards with photo, name, specialization)
- Connection status badges (active/pending/paused)
- Permission level indicators (view only/full access)
- Primary actions per coach:
  - "View Profile" → CoachProfileScreen
  - "Message Coach" → MessagingScreen
  - "Adjust Permissions" → PermissionsScreen (athlete can downgrade permissions)
  - "Remove Coach" → Confirmation dialog with warning

**Revoke Coach Access**:
- Confirmation dialog: "Are you sure you want to remove [Coach Name]? They will no longer be able to view your data."
- Action: Update relationship status to 'archived'
- Notification: Send email to coach about relationship ending

---

## Payment Integration Strategy

### MVP Phase: Manual Invoicing
**Timeline**: Weeks 1-6
**Goal**: Launch immediately without Stripe dependency

#### Manual Billing Workflow

**Step 1: Coach Completes Registration**
- Coach selects tier during setup:
  - Tier 1: <20 athletes - $20/month (suggested price)
  - Tier 2: 20+ athletes - $50/month (suggested price)
- Coach receives welcome email with invoice details

**Step 2: Invoice Generation**
**Tool**: Manual invoice via email template

**Email Template**: WelcomeInvoiceEmail
```
Subject: Welcome to Mealvana Endurance Coach Portal - Payment Instructions

Hi [Coach Name],

Congratulations! Your coach account has been approved. Here are your payment details:

Plan: [Tier Name] - $[Amount]/month
Billing Cycle: Monthly (renews on [Day] of each month)

Payment Options:
1. PayPal: payments@mealvana.com
2. Venmo: @mealvana
3. Zelle: payments@mealvana.com

Please include your coach ID in the payment memo: COACH-[UUID]

Once payment is received, we'll activate your account within 24 hours.

Questions? Reply to this email or contact support@mealvana.com.

Best,
The Mealvana Team
```

**Step 3: Payment Tracking**
**Tool**: Google Sheets or Airtable

**Tracking Spreadsheet Columns**:
- Coach ID
- Coach Name
- Email
- Tier (1 or 2)
- Monthly Amount
- Billing Day (1-31)
- Payment Status (pending/paid/overdue)
- Last Payment Date
- Payment Method (PayPal/Venmo/Zelle)
- Transaction ID
- Notes

**Step 4: Manual Account Activation**
- Admin receives payment confirmation (PayPal/Venmo/Zelle)
- Admin updates spreadsheet (status = paid)
- Admin activates coach account in database:
  ```sql
  UPDATE coaches
  SET is_active = true,
      subscription_tier = 'tier_1',
      subscription_status = 'active',
      billing_cycle_day = 1
  WHERE id = 'coach-uuid';
  ```
- Coach receives activation confirmation email

**Step 5: Monthly Renewal Reminders**
- 7 days before billing day: Send reminder email
- On billing day: Send invoice email
- 7 days after due date: Send overdue notice
- 14 days after due date: Suspend account (downgrade to view-only)

#### Limitations & Mitigation
- **Manual Overhead**: ~1-2 hours/week for 50 coaches (sustainable for beta)
- **Payment Delays**: 24-48 hour activation time (set expectations in onboarding)
- **Churn Risk**: Manual process may cause friction (offset with personal support)
- **Scaling Limit**: Max 100-150 coaches before automation required

### Beta Phase: Stripe Integration
**Timeline**: Weeks 7-12
**Goal**: Automate billing for 50-200 coaches

#### Stripe Checkout Implementation

**Step 1: Create Stripe Products**
```bash
# Stripe CLI
stripe products create --name="Mealvana Coach - Starter" --description="Up to 20 athletes"
stripe prices create --product={PRODUCT_ID} --unit-amount=2000 --currency=usd --recurring-interval=month

stripe products create --name="Mealvana Coach - Pro" --description="20+ athletes"
stripe prices create --product={PRODUCT_ID} --unit-amount=5000 --currency=usd --recurring-interval=month
```

**Step 2: Stripe Checkout Session**
**Screen**: SubscriptionCheckoutScreen

**Edge Function**: `create-checkout-session`
```typescript
import Stripe from 'https://esm.sh/stripe@14.0.0'

serve(async (req) => {
  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
    apiVersion: '2023-10-16',
  })

  const { coachId, tier } = await req.json()

  // Fetch coach data
  const { data: coach } = await supabase
    .from('coaches')
    .select('*')
    .eq('id', coachId)
    .single()

  // Create Checkout Session
  const session = await stripe.checkout.sessions.create({
    customer_email: coach.email,
    mode: 'subscription',
    line_items: [
      {
        price: tier === 'tier_1' ? 'price_starter_id' : 'price_pro_id',
        quantity: 1,
      },
    ],
    success_url: `https://enduranceapp.mealvana.io/coach/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `https://enduranceapp.mealvana.io/coach/subscription`,
    metadata: {
      coach_id: coachId,
      tier: tier,
    },
  })

  return new Response(JSON.stringify({ sessionId: session.id, url: session.url }), { status: 200 })
})
```

**Step 3: Webhook Handler**
**Edge Function**: `stripe-webhook-handler`
```typescript
serve(async (req) => {
  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
    apiVersion: '2023-10-16',
  })

  const signature = req.headers.get('stripe-signature')!
  const body = await req.text()

  let event
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      Deno.env.get('STRIPE_WEBHOOK_SECRET')!
    )
  } catch (err) {
    return new Response(JSON.stringify({ error: 'Webhook signature verification failed' }), { status: 400 })
  }

  switch (event.type) {
    case 'checkout.session.completed':
      const session = event.data.object

      // Update coach subscription status
      await supabase
        .from('coaches')
        .update({
          subscription_status: 'active',
          subscription_tier: session.metadata.tier,
          stripe_customer_id: session.customer,
          stripe_subscription_id: session.subscription,
        })
        .eq('id', session.metadata.coach_id)

      // Send welcome email
      await sendSubscriptionConfirmationEmail(session.customer_email)
      break

    case 'invoice.payment_failed':
      const invoice = event.data.object

      // Update coach subscription status
      await supabase
        .from('coaches')
        .update({ subscription_status: 'past_due' })
        .eq('stripe_customer_id', invoice.customer)

      // Send payment failure email
      await sendPaymentFailureEmail(invoice.customer_email)
      break

    case 'customer.subscription.deleted':
      const subscription = event.data.object

      // Downgrade coach account
      await supabase
        .from('coaches')
        .update({
          subscription_status: 'canceled',
          is_active: false,
        })
        .eq('stripe_subscription_id', subscription.id)

      // Send cancellation email
      await sendSubscriptionCanceledEmail(subscription.customer)
      break
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 })
})
```

**Step 4: Customer Portal**
**Screen**: SubscriptionManagementScreen

**Edge Function**: `create-portal-session`
```typescript
serve(async (req) => {
  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
    apiVersion: '2023-10-16',
  })

  const { coachId } = await req.json()

  // Fetch coach Stripe customer ID
  const { data: coach } = await supabase
    .from('coaches')
    .select('stripe_customer_id')
    .eq('id', coachId)
    .single()

  // Create portal session
  const session = await stripe.billingPortal.sessions.create({
    customer: coach.stripe_customer_id,
    return_url: 'https://enduranceapp.mealvana.io/coach/settings',
  })

  return new Response(JSON.stringify({ url: session.url }), { status: 200 })
})
```

**Customer Portal Features**:
- View current subscription (tier, amount, next billing date)
- Update payment method (credit card)
- Upgrade tier (Starter → Pro at 20 athletes)
- Downgrade tier (Pro → Starter if <20 athletes)
- Cancel subscription (immediate or at period end)
- View invoice history

#### Automatic Tier Upgrades
**Trigger**: Coach adds 20th athlete

**Edge Function**: `check-tier-upgrade`
```typescript
// Called when coach-athlete relationship becomes active
serve(async (req) => {
  const { coachId } = await req.json()

  // Count active athletes
  const { count } = await supabase
    .from('coach_athlete_relationships')
    .select('*', { count: 'exact', head: true })
    .eq('coach_id', coachId)
    .eq('status', 'active')

  if (count === 20) {
    // Upgrade to Pro tier
    const { data: coach } = await supabase
      .from('coaches')
      .select('stripe_subscription_id')
      .eq('id', coachId)
      .single()

    // Update Stripe subscription
    const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!)
    await stripe.subscriptions.update(coach.stripe_subscription_id, {
      items: [
        {
          id: coach.stripe_subscription_item_id,
          price: 'price_pro_id',
        },
      ],
    })

    // Update database
    await supabase
      .from('coaches')
      .update({ subscription_tier: 'tier_2' })
      .eq('id', coachId)

    // Send upgrade notification email
    await sendTierUpgradeEmail(coach.email)
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})
```

#### Failed Payment Handling
**Retry Logic**: Stripe's built-in Smart Retries (3 attempts over 7 days)

**Day 0**: Payment fails → Send "Payment Failed" email
**Day 3**: Retry 1 → Send "Retry Attempted" email
**Day 5**: Retry 2 → Send "Final Retry" email
**Day 7**: Retry 3 fails → Downgrade account to view-only, send "Subscription Suspended" email

**Subscription Suspended State**:
- Coach can still log in and view athlete data
- Cannot create new nutrition plans or activities
- Cannot send new athlete invitations
- Banner message: "Your subscription is suspended due to payment failure. Please update your payment method."

### Pricing Strategy

#### Competitive Analysis
| Platform | Monthly Price | Features |
|----------|--------------|----------|
| TrainingPeaks | $22/month | Unlimited athletes, workout library, analytics |
| Final Surge | $21/month | Unlimited athletes, training plans, messaging |
| TrainHeroic | $29/month | Up to 25 athletes, programming tools, analytics |
| Mealvana Endurance | $15-25 (Starter) / $40-60 (Pro) | Nutrition-specific, multi-sport, AI-powered plans |

#### Recommended Pricing
- **Starter Tier**: $20/month (up to 20 athletes)
- **Pro Tier**: $50/month (20+ athletes, up to max_athletes limit)
- **Annual Discount**: 20% off (2 months free) - $192/year Starter, $480/year Pro

#### Value Proposition
- **Nutrition-Specific**: Only platform focused on endurance nutrition planning
- **AI-Powered**: Linear programming optimization for macro targets
- **Multi-Sport**: Running, cycling, swimming support from day one
- **Time Savings**: Automated plan generation (vs manual calculations)
- **Athlete Education**: Science-based recommendations with explanations

---

## Messaging System

### MVP Phase: Thread-Based Messaging
**Timeline**: Weeks 1-6
**Goal**: Simple, reliable coach-athlete communication

#### Implementation Details

**Database Table**: `coach_athlete_messages`
```sql
CREATE TABLE coach_athlete_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id UUID NOT NULL REFERENCES coach_athlete_relationships(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('coach', 'athlete')),
  sender_id UUID NOT NULL, -- coach.id or user.id
  message_text TEXT NOT NULL CHECK (char_length(message_text) >= 1 AND char_length(message_text) <= 5000),
  attachment_url TEXT,
  attachment_type TEXT, -- 'image', 'pdf', 'other'
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),

  CONSTRAINT message_text_length CHECK (char_length(message_text) <= 5000)
);

CREATE INDEX idx_messages_relationship_created ON coach_athlete_messages(relationship_id, created_at DESC);
CREATE INDEX idx_messages_unread ON coach_athlete_messages(relationship_id, is_read) WHERE is_read = false;
```

**Edge Function**: `send-message`
```typescript
serve(async (req) => {
  const { relationshipId, senderType, senderId, messageText, attachmentUrl, attachmentType } = await req.json()

  // Validate relationship
  const { data: relationship } = await supabase
    .from('coach_athlete_relationships')
    .select('*, coach:coaches(*), athlete:users(*)')
    .eq('id', relationshipId)
    .eq('status', 'active')
    .single()

  if (!relationship) {
    return new Response(JSON.stringify({ error: 'Invalid or inactive relationship' }), { status: 400 })
  }

  // Insert message
  const { data: message, error } = await supabase
    .from('coach_athlete_messages')
    .insert({
      relationship_id: relationshipId,
      sender_type: senderType,
      sender_id: senderId,
      message_text: messageText,
      attachment_url: attachmentUrl,
      attachment_type: attachmentType,
    })
    .select()
    .single()

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  // Send email notification to recipient
  if (senderType === 'coach') {
    await sendMessageNotificationEmail(
      relationship.athlete.email,
      relationship.coach.coach_name,
      messageText
    )
  } else {
    await sendMessageNotificationEmail(
      relationship.coach.email,
      relationship.athlete.name,
      messageText
    )
  }

  return new Response(JSON.stringify({ message }), { status: 200 })
})
```

**Screen**: MessageThreadScreen

**UI Components**:
- Message list (scrollable, infinite scroll for history)
- Message composer (textarea with character counter, max 5000)
- Attachment upload button (images, PDFs up to 5MB)
- Send button (disabled if empty or >5000 characters)
- Unread badge (count of unread messages)

**Message Display**:
```dart
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
  });

  final Message message;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.messageText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (message.attachmentUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AttachmentWidget(
                  url: message.attachmentUrl!,
                  type: message.attachmentType!,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.createdAt),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }
}
```

#### Email Notifications
**Template**: MessageNotificationEmail
```
Subject: New message from [Sender Name] on Mealvana Endurance

Hi [Recipient Name],

You have a new message from [Sender Name]:

"[First 100 characters of message]..."

View and reply: https://enduranceapp.mealvana.io/messages/[relationship_id]

To disable email notifications, visit your settings.

Best,
The Mealvana Team
```

#### Limitations & Future Enhancements
- **No Real-Time**: Messages appear on page refresh (acceptable for MVP)
- **No Typing Indicators**: Will add in Scale phase
- **No Read Receipts**: Will add in Beta phase
- **No Message Editing**: Messages are immutable (prevents disputes)

### Beta Phase: Enhanced Messaging
**Timeline**: Weeks 7-12
**Goal**: Improved user experience with notifications

#### Enhancements
1. **Email Notifications**: Immediate notification on new message
2. **Push Notifications**: Web push for active sessions (via Web Push API)
3. **Read Receipts**: Timestamp when message is read
4. **Unread Badges**: Count of unread messages per relationship
5. **Message Search**: Full-text search across message history
6. **Attachments**: Support for images (via Supabase Storage)

### Scale Phase: Real-Time Chat
**Timeline**: Weeks 13-16
**Goal**: Instant messaging experience

#### Supabase Realtime Integration
```dart
// lib/features/messaging/application/message_realtime_service.dart
@riverpod
class MessageRealtimeService extends _$MessageRealtimeService {
  RealtimeChannel? _channel;

  @override
  Stream<List<Message>> build(String relationshipId) async* {
    final supabase = ref.read(supabaseClientProvider);

    // Fetch initial messages
    final initialMessages = await supabase
        .from('coach_athlete_messages')
        .select()
        .eq('relationship_id', relationshipId)
        .order('created_at', ascending: false)
        .limit(50);

    yield initialMessages.map((json) => Message.fromJson(json)).toList();

    // Subscribe to real-time updates
    _channel = supabase
        .channel('messages:$relationshipId')
        .on(
          RealtimeListenTypes.postgresChanges,
          ChannelFilter(
            event: '*',
            schema: 'public',
            table: 'coach_athlete_messages',
            filter: 'relationship_id=eq.$relationshipId',
          ),
          (payload, [ref]) {
            final newMessage = Message.fromJson(payload['new'] as Map<String, dynamic>);
            state = AsyncValue.data([newMessage, ...state.value!]);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
```

#### Real-Time Features
- **Instant Delivery**: Messages appear immediately (no refresh)
- **Typing Indicators**: "Coach is typing..." indicator
- **Online Status**: Green dot for active sessions
- **Message Reactions**: Emoji reactions (👍, ❤️, 🎉)
- **Group Messaging**: Coach + multiple athletes in one thread

---

## Deployment Strategy

### GitHub Actions CI/CD Pipeline

#### Workflow Files

**File**: `.github/workflows/deploy-web.yml`
```yaml
name: Deploy Flutter Web to Cloudflare Pages

on:
  push:
    branches:
      - main
      - develop
  pull_request:
    branches:
      - main
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.24.0'
          channel: 'stable'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test

      - name: Build Flutter Web (Skwasm)
        run: flutter build web --web-renderer skwasm --release --output web/dist

      - name: Deploy to Cloudflare Pages
        uses: cloudflare/pages-action@v1
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          projectName: 'mealvana-endurance-web'
          directory: 'web/dist'
          gitHubToken: ${{ secrets.GITHUB_TOKEN }}
          branch: ${{ github.ref_name }}
```

**File**: `.github/workflows/deploy-edge-functions.yml`
```yaml
name: Deploy Edge Functions to Supabase

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/functions/**'
  workflow_dispatch:

jobs:
  deploy-edge-functions:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Deploy to Supabase (Production)
        run: |
          supabase functions deploy --project-ref ${{ secrets.SUPABASE_PROJECT_ID }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

#### Environment Management

**Development Environment**:
- Branch: `develop`
- URL: `https://dev.enduranceapp.mealvana.io`
- Supabase Project: Dev project (separate from production)
- Deployment: Automatic on push to `develop`

**Production Environment**:
- Branch: `main`
- URL: `https://enduranceapp.mealvana.io`
- Supabase Project: Production project
- Deployment: Automatic on push to `main`

#### Cloudflare Pages Configuration

**Domain Setup**:
1. Add custom domain in Cloudflare Pages dashboard
2. Configure CNAME record: `enduranceapp.mealvana.io` → `mealvana-endurance-web.pages.dev`
3. Enable automatic HTTPS

**Build Settings**:
- Build command: `flutter build web --web-renderer skwasm --release`
- Build output directory: `build/web`
- Root directory: `/`

**Environment Variables** (Cloudflare Pages):
```
SUPABASE_URL=https://[project-ref].supabase.co
SUPABASE_ANON_KEY=[anon-key]
SENTRY_DSN=[sentry-dsn]
MIXPANEL_TOKEN=[mixpanel-token]
```

#### SSL/TLS Configuration
- Automatic SSL certificate provisioning via Let's Encrypt
- HTTPS enforced (HTTP redirects to HTTPS)
- TLS 1.2+ required
- HSTS enabled (max-age=31536000)

#### Rollback Strategy
```bash
# Cloudflare Pages deployments are immutable
# Rollback via Cloudflare dashboard:
# 1. Navigate to Deployments tab
# 2. Select previous successful deployment
# 3. Click "Rollback to this deployment"

# Alternatively, via Git:
git revert HEAD
git push origin main
# GitHub Actions will automatically deploy previous version
```

---

## Timeline & Milestones

### MVP Phase (Weeks 1-6): Speed to Market

#### Week 1: Foundation & Setup
**Focus**: Environment setup, database migration

- [ ] Flutter web project configuration (Skwasm renderer)
- [ ] Cloudflare Pages account setup and custom domain
- [ ] Database schema migration (3 new tables, 4 table modifications)
- [ ] RLS policies implementation (22 policies)
- [ ] GitHub Actions workflows (deploy-web.yml, deploy-edge-functions.yml)
- [ ] Development environment testing (dev.enduranceapp.mealvana.io)

**Deliverables**: Working dev environment, database schema v2 deployed

#### Week 2: Coach Registration & Verification
**Focus**: Coach onboarding flow

- [ ] CoachRegistrationScreen (web UI)
- [ ] CoachCertificationScreen (document uploads)
- [ ] Admin verification dashboard
- [ ] Edge Functions: create-coach-profile, verify-coach-manual
- [ ] Email templates (welcome, approval, rejection)
- [ ] Manual verification workflow documentation

**Deliverables**: End-to-end coach registration working, first coach verified

#### Week 3: Coach-Athlete Connection
**Focus**: Invitation system

- [ ] GenerateInvitationScreen (coach web UI)
- [ ] InvitationPreviewScreen (athlete web/mobile)
- [ ] Edge Functions: generate-invitation-link, get-invitation-details, accept-coach-invitation
- [ ] Email templates (invitation, acceptance confirmation)
- [ ] Invitation expiration logic (72-hour tokens)
- [ ] Connection status tracking UI

**Deliverables**: Coach can invite athletes, athletes can accept invitations

#### Week 4: Coach Dashboard & Core Screens
**Focus**: Primary coach interface

- [ ] CoachDashboardScreen (athlete list, recent activity, stats)
- [ ] AthleteListScreen (search, filter, sort)
- [ ] AthleteDetailScreen (profile, biometrics, preferences)
- [ ] ActivityHistoryScreen (planned vs completed workouts)
- [ ] NutritionPlanViewerScreen (read-only plan display)

**Deliverables**: Coach can view athlete data, navigate between screens

#### Week 5: Messaging & Mode Toggle
**Focus**: Communication + dual view

- [ ] MessageThreadScreen (thread-based messaging)
- [ ] ModeToggleWidget (coach ↔ athlete switch)
- [ ] Edge Function: send-message
- [ ] Email notifications for new messages
- [ ] Mode persistence (SharedPreferences/LocalStorage)
- [ ] Visual indicators (badge, theme changes)

**Deliverables**: Coach-athlete messaging working, mode toggle functional

#### Week 6: Polish, Testing & Launch
**Focus**: Quality assurance, documentation

- [ ] Responsive design testing (desktop/tablet/mobile)
- [ ] Cross-browser testing (Chrome, Firefox, Safari, Edge)
- [ ] Manual billing workflow documentation
- [ ] Coach onboarding tutorial video (2 minutes)
- [ ] User acceptance testing with 3-5 beta coaches
- [ ] Production deployment to enduranceapp.mealvana.io
- [ ] Launch announcement (email, social media)

**Deliverables**: Public MVP launch, first 10 coaches onboarded

---

### Beta Phase (Weeks 7-12): Automation & Scale

#### Week 7-8: Stripe Integration
**Focus**: Automated billing

- [ ] Stripe account setup (products, prices)
- [ ] SubscriptionCheckoutScreen (Stripe Checkout)
- [ ] Edge Functions: create-checkout-session, create-portal-session, stripe-webhook-handler
- [ ] Subscription status tracking (active/past_due/canceled)
- [ ] Automatic tier upgrades (20 athlete threshold)
- [ ] Failed payment handling (retry logic, suspension)
- [ ] Customer Portal integration (manage subscription)

**Deliverables**: Automated billing live, first Stripe payment processed

#### Week 9-10: Enhanced Features
**Focus**: User experience improvements

- [ ] Calendar view (monthly/weekly) with drag-and-drop
- [ ] Compliance score calculation
- [ ] Progress analytics (charts, trends)
- [ ] Email notifications (message, activity, plan updates)
- [ ] Push notifications (web push API)
- [ ] CSV/PDF report exports

**Deliverables**: Enhanced coach dashboard, analytics operational

#### Week 11-12: Hybrid Verification & Scaling
**Focus**: Growth infrastructure

- [ ] Hybrid verification workflow (auto-approve + manual queue)
- [ ] NCCA credential API integration (if available)
- [ ] Automated insurance verification
- [ ] Public coach directory
- [ ] Performance optimization (load testing, APM)
- [ ] Documentation updates (runbooks, API docs)

**Deliverables**: Verified 50+ coaches, 500+ coach-athlete relationships

---

### Scale Phase (Weeks 13-16): Advanced Features

#### Week 13-14: Real-Time Chat
**Focus**: Instant messaging

- [ ] Supabase Realtime integration
- [ ] Typing indicators
- [ ] Read receipts
- [ ] Message reactions
- [ ] Group messaging (coach + athletes)
- [ ] Online status indicators

**Deliverables**: Real-time chat operational

#### Week 15-16: API & Integrations
**Focus**: Platform extensibility

- [ ] REST API implementation (FastAPI/Express)
- [ ] OAuth 2.0 authentication
- [ ] Webhook infrastructure
- [ ] API documentation (OpenAPI spec)
- [ ] Rate limiting (1000 req/hr per coach)
- [ ] Background check integration (Checkr)

**Deliverables**: Public API launched, 5+ third-party integrations

---

### Parallel Work Streams

#### Database Team
- Week 1: Schema migration (3 new tables, 4 modifications, 22 RLS policies)
- Week 2-3: Edge Functions (coach profile, invitations, messaging)
- Week 7-8: Stripe integration (checkout, webhooks)
- Week 11-12: Hybrid verification logic
- Week 15-16: API implementation

#### Flutter Web Team
- Week 1: Platform setup, routing, responsive design
- Week 2: Coach registration screens
- Week 3: Invitation flows (coach + athlete)
- Week 4: Coach dashboard, athlete screens
- Week 5: Messaging UI, mode toggle
- Week 6: Polish, testing, launch prep
- Week 9-10: Calendar, analytics, reports
- Week 13-14: Real-time chat UI

#### Design Team
- Week 1-2: Coach dashboard wireframes, mockups
- Week 3-4: Athlete screens, responsive layouts
- Week 5: Messaging UI, mode toggle designs
- Week 9-10: Calendar views, analytics dashboards
- Ongoing: Email templates, marketing materials

#### QA Team
- Week 4-6: Manual testing (registration, invitations, messaging)
- Week 7-8: Stripe integration testing (checkout, webhooks, failures)
- Week 9-10: Enhanced features testing (calendar, analytics)
- Week 11-12: Load testing (100+ concurrent coaches)
- Week 13-16: Real-time chat, API testing

---

### Key Decision Points

#### Week 2: Manual vs Automated Verification
**Decision**: Start with manual verification for MVP (<50 coaches)
**Rationale**: High quality bar, personal touch for beta coaches
**Future**: Hybrid approach at 50-200 coaches, fully automated at 200+

#### Week 6: MVP Launch Readiness
**Go/No-Go Criteria**:
- ✅ 5+ coaches registered and verified
- ✅ 20+ coach-athlete connections active
- ✅ Zero critical bugs in core flows
- ✅ <2 second page load times
- ✅ Cross-browser compatibility (Chrome, Firefox, Safari)

**Decision**: Launch if all criteria met, delay 1 week if not

#### Week 8: Stripe vs Manual Billing Continuation
**Go/No-Go Criteria**:
- ✅ 20+ coaches actively using platform
- ✅ Manual billing overhead manageable (<2 hrs/week)
- ✅ Stripe integration tested and working

**Decision**: Migrate to Stripe if >20 coaches OR manual overhead >2 hrs/week

#### Week 12: Scale Phase Investment
**Go/No-Go Criteria**:
- ✅ 50+ active coaches subscribed
- ✅ <5% churn rate
- ✅ $3K+ MRR
- ✅ 90%+ user satisfaction (NPS >50)

**Decision**: Invest in Scale phase (real-time chat, API) if criteria met

---

## Development Workflow

### FOA (Feature-Oriented Architecture) Extension

#### Coach Mode Feature Structure
```
lib/features/coach_mode/
├── application/
│   ├── coach_service.dart             # Coach business logic
│   ├── coach_verification_service.dart # Manual + hybrid verification
│   ├── invitation_service.dart         # Invitation generation/acceptance
│   └── messaging_service.dart          # Thread-based messaging
├── data/
│   ├── coach_repository.dart           # Abstract interface
│   └── supabase_coach_repository.dart  # Supabase implementation (web)
├── domain/
│   ├── coach.dart                      # Coach model
│   ├── coach_athlete_relationship.dart # Relationship model
│   ├── invitation.dart                 # Invitation model
│   └── message.dart                    # Message model
└── presentation/
    ├── screens/
    │   ├── coach_registration_screen.dart
    │   ├── coach_dashboard_screen.dart
    │   ├── athlete_list_screen.dart
    │   ├── athlete_detail_screen.dart
    │   ├── message_thread_screen.dart
    │   └── subscription_checkout_screen.dart
    ├── widgets/
    │   ├── coach_card.dart
    │   ├── athlete_card.dart
    │   ├── activity_card.dart
    │   ├── mode_toggle_widget.dart
    │   └── message_bubble.dart
    └── controllers/
        ├── coach_registration_controller.dart
        ├── coach_dashboard_controller.dart
        ├── invitation_controller.dart
        └── message_controller.dart
```

#### Shared Code Reusability
- **90% reusable** from mobile app (models, services, repositories)
- **Platform-specific**: Database layer (Drift → Supabase on web)
- **Conditional imports**: Use `if (dart.library.html)` pattern

#### New Widgets Needed (6 total)
1. **CoachCard**: Coach profile display in athlete's coach list
2. **AthleteCard**: Athlete summary in coach dashboard
3. **ActivityCard**: Activity summary with completion status
4. **PlanCard**: Nutrition plan summary with macro targets
5. **ModeToggleWidget**: Toggle switch + badge for coach/athlete mode
6. **MessageBubble**: Individual message display in thread

#### New Screens Needed (8 total)
1. **CoachRegistrationScreen**: Multi-step registration form
2. **CoachDashboardScreen**: Primary coach interface (athlete list, stats, recent activity)
3. **AthleteListScreen**: Searchable, filterable list of athletes
4. **AthleteDetailScreen**: Comprehensive athlete profile view
5. **ActivityViewScreen**: Activity history with completion tracking
6. **NutritionPlanViewScreen**: Nutrition plan display (read-only or editable)
7. **MessageThreadScreen**: Thread-based messaging interface
8. **SubscriptionCheckoutScreen**: Stripe Checkout integration

### Code Generation Workflow
```bash
# Watch mode for continuous generation during development
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation (before commits)
flutter pub run build_runner build --delete-conflicting-outputs

# Generate Drift schema snapshot (after database changes)
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v2/
```

### Testing Strategy (Coach Mode)

#### Unit Tests
- **Coach Models**: Serialization, validation
- **Invitation Logic**: Token generation, expiration
- **Permission Checks**: RLS policy simulation
- **Subscription Tier**: Upgrade/downgrade logic

#### Widget Tests
- **CoachDashboardScreen**: Athlete list rendering
- **MessageThreadScreen**: Message bubble display
- **ModeToggleWidget**: Toggle state persistence

#### Integration Tests
- **Coach Registration Flow**: End-to-end registration
- **Invitation Acceptance**: Coach creates invitation → Athlete accepts
- **Messaging Flow**: Coach sends message → Athlete receives notification
- **Subscription Flow**: Coach selects tier → Stripe Checkout → Webhook activation

#### Edge Function Tests
- **create-coach-profile**: Valid/invalid inputs
- **generate-invitation-link**: Token uniqueness, expiration
- **accept-coach-invitation**: Relationship creation, email notifications
- **send-message**: Message insertion, recipient notification
- **stripe-webhook-handler**: Checkout success, payment failure, subscription cancellation

---

## Risk Analysis & Mitigation

### Technical Risks

#### Risk 1: Flutter Web Performance
**Probability**: Medium
**Impact**: High
**Description**: Flutter web may have performance issues on low-end devices or slow networks

**Mitigation**:
- Use Skwasm renderer with WebAssembly for optimal performance
- Implement code splitting with deferred imports
- Optimize images with WebP format and lazy loading
- Add loading indicators for async operations
- Test on low-end devices (3G network simulation)
- Fallback to server-side rendering for critical paths

#### Risk 2: Drift Incompatibility (Web)
**Probability**: High (known issue)
**Impact**: Medium
**Description**: Drift doesn't work on web, requires Supabase direct queries

**Mitigation**:
- Conditional imports for database layer (`if (dart.library.html)`)
- Create `SupabaseClientProvider` for web, `DriftDatabaseProvider` for mobile
- Repository pattern abstracts database layer
- Share business logic between platforms
- Document platform-specific database patterns

#### Risk 3: Multi-Coach Data Conflicts
**Probability**: Low
**Impact**: Medium
**Description**: Multiple coaches editing same athlete's data simultaneously causes conflicts

**Mitigation**:
- Optimistic locking with `updated_at` timestamp checks
- Last-write-wins conflict resolution
- Show warning when data modified by another coach
- Activity log of all coach modifications
- Option to review changes before overwriting

### Business Risks

#### Risk 4: Coach Verification Quality
**Probability**: Medium
**Impact**: High
**Description**: Manual verification may miss fraudulent coaches or delay legitimate ones

**Mitigation**:
- Strict verification checklist (NCCA certs, insurance, ID)
- 3-5 business day SLA for verification
- Automated NCCA credential API validation (when available)
- Background checks via Checkr ($30/coach) for suspicious cases
- User reporting mechanism for bad actors
- Annual re-verification requirement

#### Risk 5: Payment Disputes
**Probability**: Low
**Impact**: Medium
**Description**: Coaches dispute charges, request refunds, or experience failed payments

**Mitigation**:
- Clear pricing and refund policy (no refunds after 7 days)
- Stripe's built-in dispute handling
- Failed payment retry logic (3 attempts over 7 days)
- Downgrade to view-only after payment failure (vs full suspension)
- Manual support for legitimate payment issues
- Transparent billing dashboard (next charge date, history)

#### Risk 6: Low Coach Adoption
**Probability**: Medium
**Impact**: High
**Description**: Coaches don't see value in platform, churn after trial

**Mitigation**:
- Free 30-day trial for early adopters
- Personalized onboarding (1-on-1 video calls for first 50 coaches)
- Weekly coach community calls (share best practices)
- Feature voting (coaches prioritize roadmap)
- Success stories and case studies
- Referral program (1 month free for each referral)

### Security Risks

#### Risk 7: Coach Access to Athlete Data (GDPR)
**Probability**: Low
**Impact**: High
**Description**: Coaches access athlete data without proper consent, GDPR violation

**Mitigation**:
- Explicit opt-in via invitation acceptance
- Permission levels (view_only vs full_access)
- Athletes can revoke access anytime
- Audit log of all coach data access
- GDPR compliance documentation (data processing agreement)
- Right to erasure (athletes can delete data)
- Annual consent reconfirmation

#### Risk 8: Unauthorized Coach Verification
**Probability**: Low
**Impact**: High
**Description**: Non-coach user gains coach access, views athlete data

**Mitigation**:
- Manual verification for MVP (high scrutiny)
- NCCA certification validation (expiration dates, authenticity)
- Professional liability insurance requirement ($1M+ coverage)
- Photo ID verification (name match with certifications)
- Admin-only verification dashboard
- Periodic re-verification (annual)

#### Risk 9: Data Leakage via RLS Bypass
**Probability**: Low
**Impact**: Critical
**Description**: Bug in RLS policies allows coaches to access non-athlete data

**Mitigation**:
- Comprehensive RLS policy testing (22 policies)
- Integration tests for permission checks
- Automated schema drift detection (daily)
- Security audit before production launch
- Supabase's built-in RLS enforcement
- Database activity monitoring (alerts for suspicious queries)

---

## Success Metrics

### MVP Phase (Weeks 1-6)

#### Coach Acquisition
- **Target**: 10-20 coaches registered
- **Metric**: Weekly coach signups
- **Goal**: 2-4 signups/week by Week 6

#### Coach Approval Rate
- **Target**: 80%+ approval rate
- **Metric**: Approved coaches / Total applications
- **Goal**: High quality bar maintained

#### Coach-Athlete Connections
- **Target**: 50-100 active relationships
- **Metric**: Total active coach-athlete connections
- **Goal**: Average 5-8 athletes per coach by Week 6

#### Invitation Acceptance Rate
- **Target**: 80%+ acceptance within 48 hours
- **Metric**: Accepted invitations / Total invitations sent
- **Goal**: Email invitation flow working well

#### Platform Stability
- **Target**: <5% error rate on core flows
- **Metric**: Sentry error rate
- **Goal**: Stable platform for beta coaches

### Beta Phase (Weeks 7-12)

#### Coach Subscriptions
- **Target**: 50+ active subscriptions
- **Metric**: Total Stripe subscriptions (active status)
- **Goal**: $1K-2.5K MRR by Week 12

#### Payment Success Rate
- **Target**: 95%+ successful payments
- **Metric**: Successful payments / Total payment attempts
- **Goal**: Reliable billing system

#### Coach Retention
- **Target**: >90% monthly retention
- **Metric**: Active coaches Month N / Active coaches Month N-1
- **Goal**: <10% churn rate during beta

#### Feature Adoption
- **Target**: 90%+ coaches use calendar weekly
- **Metric**: Coaches using calendar feature / Total active coaches
- **Goal**: Calendar is killer feature

#### Athlete Growth
- **Target**: 500+ total coach-athlete relationships
- **Metric**: Total active relationships
- **Goal**: Average 10-12 athletes per coach by Week 12

### Scale Phase (Weeks 13-16)

#### Coach Scale
- **Target**: 200+ active coach subscriptions
- **Metric**: Total Stripe subscriptions (active status)
- **Goal**: $5K-10K MRR by Week 16

#### Athlete Scale
- **Target**: 2000+ active coach-athlete relationships
- **Metric**: Total active relationships
- **Goal**: Platform at meaningful scale

#### Platform Uptime
- **Target**: 95%+ uptime during peak usage
- **Metric**: Uptime monitoring (6-9am, 5-8pm)
- **Goal**: Reliable platform for daily usage

#### API Adoption
- **Target**: 10+ third-party integrations
- **Metric**: Unique API keys issued
- **Goal**: Platform extensibility via API

#### User Satisfaction
- **Target**: NPS >50 (world-class)
- **Metric**: Net Promoter Score survey
- **Goal**: Coaches love the platform

### Revenue Targets

#### MVP Phase
- **Target**: $0 revenue (manual billing, delayed payments)
- **Focus**: Product validation, user feedback

#### Beta Phase
- **Target**: $1K-2.5K MRR by Week 12
- **Calculation**: 50 coaches × $20-50/month (mix of tiers)

#### Scale Phase
- **Target**: $5K-10K MRR by Week 16
- **Calculation**: 200 coaches × $25-50/month (mix of tiers)

#### 6-Month Projection
- **Target**: $10K-15K MRR by Month 6
- **Calculation**: 300 coaches × $30-50/month (70% Starter, 30% Pro)

---

## Future Enhancements (Post-Launch)

### Phase 4: Mobile Coach App
**Timeline**: Months 7-9
**Goal**: Native coach experience on iOS/Android

**Features**:
- Native mobile UI (iOS/Android)
- Push notifications (activity completion, messages)
- Offline mode (view athlete data without internet)
- Camera integration (photo/video feedback)
- Voice messages (audio feedback)

**Why**: Coaches want mobile-first experience, not just web

### Phase 5: Advanced Analytics
**Timeline**: Months 10-12
**Goal**: Data-driven coaching insights

**Features**:
- Injury risk prediction (volume spikes, recovery deficits)
- Performance forecasting (race day readiness)
- Athlete benchmarking (vs peer group)
- Custom metric tracking (user-defined KPIs)
- Automated reporting (weekly/monthly summaries)

**Why**: Data insights differentiate platform from competitors

### Phase 6: Team/Group Coaching
**Timeline**: Months 13-15
**Goal**: Manage team training

**Features**:
- Team creation (e.g., "Marathon Training Group")
- Bulk workout assignments (one workout → all team members)
- Team leaderboards (completion rates, volume)
- Team messaging (coach → group)
- Sub-teams (e.g., "Advanced" vs "Beginner" groups)

**Why**: Many coaches manage teams, not just individuals

### Phase 7: Integration Platform
**Timeline**: Months 16-18
**Goal**: Connect to athlete ecosystems

**Features**:
- Strava integration (auto-import activities)
- TrainingPeaks integration (sync training plans)
- Garmin Connect integration (device sync)
- Apple Health / Google Fit integration (biometrics)
- Webhook marketplace (third-party tools)

**Why**: Reduce manual data entry, increase platform stickiness

### Phase 8: Marketplace
**Timeline**: Months 19-24
**Goal**: Coach discovery and monetization

**Features**:
- Public coach directory (search by sport, location, price)
- Coach ratings and reviews
- Booking system (schedule consultations)
- Payment processing (coach gets 80%, platform 20%)
- Coach promotion tools (featured listings, ads)

**Why**: Two-sided marketplace creates network effects

---

## Summary & Next Steps

### Implementation Path

#### Immediate (Week 1-2)
1. ✅ **Read This Document**: Complete understanding of coach mode roadmap
2. ✅ **Review Schema Analysis**: `/docs/features/coach_mode/schema_analysis.md`
3. ✅ **Setup Cloudflare Pages**: Account, custom domain, deployment pipeline
4. ✅ **Database Migration**: Deploy schema changes to dev environment

#### Short-Term (Week 3-6)
1. **Build MVP**: Core coach features (registration, invitations, dashboard, messaging)
2. **Manual Verification**: Onboard first 10 coaches with high-touch support
3. **Launch Beta**: Public MVP at enduranceapp.mealvana.io
4. **Gather Feedback**: Weekly calls with beta coaches

#### Medium-Term (Week 7-12)
1. **Stripe Integration**: Automate billing for scaling to 50+ coaches
2. **Enhanced Features**: Calendar, analytics, enhanced messaging
3. **Hybrid Verification**: Semi-automated verification for growth
4. **Scale to 50 Coaches**: $1K-2.5K MRR

#### Long-Term (Week 13-16)
1. **Real-Time Chat**: Supabase Realtime for instant messaging
2. **API Platform**: Open API for third-party integrations
3. **Scale to 200 Coaches**: $5K-10K MRR
4. **Platform Stability**: Load testing, monitoring, optimization

### Key Decisions Made

1. **Hosting**: Cloudflare Pages (unlimited bandwidth, free, commercial use)
2. **Billing**: Manual invoicing for MVP → Stripe for Beta
3. **Verification**: Manual for MVP (<50 coaches) → Hybrid for Beta (50-200 coaches)
4. **Messaging**: Thread-based for MVP → Real-time chat for Scale phase
5. **Connection**: Email invitations (72-hour expiration, token-based)
6. **Pricing**: $20/month Starter (<20 athletes), $50/month Pro (20+ athletes)

### Resources

- **Schema Analysis**: `/docs/features/coach_mode/schema_analysis.md`
- **FOA Architecture**: `/docs/technical/foa-architecture.md`
- **Flutter Web Guide**: [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- **Supabase RLS**: [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- **Stripe Integration**: [Stripe Checkout Docs](https://stripe.com/docs/payments/checkout)
- **Cloudflare Pages**: [Cloudflare Pages Docs](https://developers.cloudflare.com/pages/)

---

**Last Updated**: 2025-12-15
**Status**: Planning Phase
**Next Review**: After Week 6 (MVP Launch)
