# Coach Mode Deployment Roadmap - ASAP Timeline

**Document Updated**: 2025-12-25
**Status**: Ready for Implementation
**Target**: Launch ASAP with free beta

---

## Quick Reference

| Decision | Selection |
|----------|-----------|
| **Hosting** | Vercel |
| **Domain** | enduranceapp.mealvana.io |
| **Billing** | Free during beta |
| **Verification** | Manual only |
| **Athlete Access** | Both (start with coaches) |
| **Timeline** | ~3-5 weeks to soft launch |

---

## Prerequisites (Web Mode is 85% Complete)

The web deployment foundation is already implemented:

| Component | Status | Notes |
|-----------|--------|-------|
| Database layer (drift/wasm) | Done | Conditional imports working |
| Platform utilities | Done | kIsWeb guards in place |
| OAuth service adaptations | Done | Throws on web, uses Supabase OAuth |
| Notification service guards | Done | Skips on web |
| Device info web support | Done | Browser detection working |
| Web build artifacts | Done | sqlite3.wasm, drift_worker.js |

**Remaining web setup:**
- [ ] Create Vercel project
- [ ] Add vercel.json configuration
- [ ] Set environment variables
- [ ] Test deployment

---

## Phase 0: Web Foundation (3-5 days)

### Day 1-2: Vercel Setup

**Step 1: Create Vercel Project**
```bash
# Install Vercel CLI
npm i -g vercel

# Login
vercel login

# Link project
cd /Users/leemartin/development/mealvana_endurance
vercel link
```

**Step 2: Create vercel.json**
```json
{
  "buildCommand": "flutter build web --release --wasm --pwa-strategy=none",
  "outputDirectory": "build/web",
  "framework": null,
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" },
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" }
      ]
    }
  ],
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Step 3: Environment Variables (Vercel Dashboard)**
```
SUPABASE_URL=https://[project-ref].supabase.co
SUPABASE_ANON_KEY=[anon-key]
SENTRY_DSN=[sentry-dsn]
```

**Step 4: Custom Domain**
1. Go to Vercel Dashboard → Project → Settings → Domains
2. Add: `enduranceapp.mealvana.io`
3. Configure DNS CNAME: `enduranceapp` → `cname.vercel-dns.com`

### Day 3-5: Web Testing

```bash
# Local testing
flutter run -d chrome

# Build test
flutter build web --release --wasm --pwa-strategy=none

# Preview deployment
vercel --prod
```

**Test Checklist:**
- [ ] App loads in Chrome
- [ ] IndexedDB storage works
- [ ] Supabase connection works
- [ ] OAuth redirect flow works
- [ ] No dart:io errors

---

## Phase 1: Core Coach Infrastructure (Week 1)

### Database Migration (Day 1)

**New Tables (3):**
1. `coaches` - Coach profiles
2. `coach_athlete_relationships` - Many-to-many relationships
3. `coach_feedback` - Coach notes

**Modified Tables (4):**
- `nutrition_plans` - Add coach columns
- `activities` - Add coach columns
- `workout_notes` - Add coach visibility
- `activity_completions` - RLS only

**Migration File Location:** `/docs/features/coach_mode/schema_analysis.md` Section 11

```bash
# Apply migration
supabase db push
```

### RLS Policies (Day 1)
- 22 new policies for coach access control
- Reference: `/docs/features/coach_mode/schema_analysis.md` Section 5

### Edge Functions (Day 2-3)

**Create these functions in `/supabase/functions/`:**

1. `create-coach-profile/index.ts`
   - Creates pending coach profile
   - Returns coach_id

2. `verify-coach-manual/index.ts`
   - Admin-only verification
   - Updates is_verified, is_active
   - Sends welcome/rejection email

3. `generate-invitation-link/index.ts`
   - Creates unique token (72-hour expiry)
   - Sends invitation email

4. `accept-coach-invitation/index.ts`
   - Validates token
   - Creates coach-athlete relationship
   - Sends confirmation emails

5. `send-message/index.ts`
   - Inserts message to database
   - Sends email notification

### Flutter Feature Structure (Day 3-5)

```
lib/features/coach_mode/
├── application/
│   ├── coach_service.dart
│   ├── invitation_service.dart
│   └── messaging_service.dart
├── data/
│   ├── coach_repository.dart
│   └── supabase_coach_repository.dart
├── domain/
│   ├── coach.dart
│   ├── coach_athlete_relationship.dart
│   ├── invitation.dart
│   └── message.dart
└── presentation/
    ├── screens/
    │   ├── coach_registration_screen.dart
    │   ├── coach_dashboard_screen.dart
    │   ├── athlete_list_screen.dart
    │   ├── athlete_detail_screen.dart
    │   └── message_thread_screen.dart
    ├── widgets/
    │   ├── coach_card.dart
    │   ├── athlete_card.dart
    │   └── mode_toggle_widget.dart
    └── controllers/
        ├── coach_registration_controller.dart
        ├── coach_dashboard_controller.dart
        └── message_controller.dart
```

---

## Phase 2: Core Features (Week 2)

### Coach Registration Screen (Day 1-2)

**Fields:**
- Full name (required)
- Email (required, verified)
- Phone (optional)
- Specializations (multi-select)
- Bio (500 chars max)
- Certification uploads (PDF/images)
- Insurance certificate upload

**Flow:**
1. User fills form → Submit
2. Edge function creates pending coach profile
3. Admin dashboard shows pending verification
4. Admin approves/rejects manually
5. Coach receives email notification

### Coach Dashboard (Day 2-3)

**Components:**
- Athlete list (name, last activity, status)
- Quick stats (total athletes, pending invites)
- Recent activity feed (last 7 days)
- Search/filter athletes

**Empty State:**
- Welcome message
- "Invite Your First Athlete" CTA

### Invitation Flow (Day 3-4)

**Coach Side:**
1. Enter athlete email
2. Select permission level (view_only / full_access)
3. Add custom message (optional)
4. Generate link → Copy to clipboard
5. System sends email invitation

**Athlete Side:**
1. Receive email with invitation link
2. Click link → Preview screen (coach info, permissions)
3. Accept or Decline
4. If accepted → Relationship created

### Messaging (Day 4-5)

**Basic Implementation:**
- Thread-based (one thread per relationship)
- Text messages (5000 char max)
- Attachment support (images, PDFs)
- Email notifications on new message
- No real-time (refresh to see new messages)

---

## Phase 3: Mode Toggle & Polish (Week 3)

### Mode Toggle Widget

```dart
class ModeToggleWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCoachMode = ref.watch(appModeProvider) == AppMode.coach;
    final isCoach = ref.watch(isCoachProvider);

    if (!isCoach) return const SizedBox.shrink();

    return Row(
      children: [
        if (isCoachMode)
          Chip(label: Text('Coach Mode'), backgroundColor: Colors.blue),
        Switch(
          value: isCoachMode,
          onChanged: (value) {
            ref.read(appModeProvider.notifier).toggle();
            context.go(value ? '/coach/dashboard' : '/athlete/dashboard');
          },
        ),
      ],
    );
  }
}
```

### Visual Indicators
- **Coach Mode**: Blue badge, blue accent theme
- **Athlete Mode**: No badge, green accent theme

### Persistence
- SharedPreferences (mobile)
- localStorage (web)
- Sync to Supabase `user_profiles.preferred_mode`

---

## Phase 4: Testing & Launch (Week 4-5)

### Testing Checklist

**Functional Testing:**
- [ ] Coach registration end-to-end
- [ ] Admin verification workflow
- [ ] Invitation generation and acceptance
- [ ] Coach dashboard displays athletes
- [ ] Athlete detail view shows data
- [ ] Messaging sends and receives
- [ ] Mode toggle switches views

**Cross-Browser Testing:**
- [ ] Chrome (primary)
- [ ] Firefox
- [ ] Safari
- [ ] Edge

**Responsive Testing:**
- [ ] Desktop (1920x1080)
- [ ] Tablet (768x1024)
- [ ] Mobile (375x667)

**Performance Testing:**
- [ ] Page load < 3 seconds
- [ ] Bundle size < 3MB
- [ ] Lighthouse score > 80

### Soft Launch (Week 5)

1. **Invite 5-10 beta coaches**
   - Personal outreach
   - 1-on-1 onboarding calls
   - Weekly feedback sessions

2. **Monitor and iterate**
   - Sentry error tracking
   - Analytics (coach signups, invitations sent)
   - User feedback collection

3. **Public launch**
   - Once stable with beta coaches
   - Email announcement
   - Social media

---

## Key Simplifications for ASAP Launch

### What We're Skipping (For Now)

1. **Stripe Integration** - Free beta means no payment complexity
2. **Real-time Chat** - Poll-based messaging is sufficient
3. **Advanced Analytics** - Basic stats only
4. **Hybrid Verification** - Manual only for quality control
5. **Public API** - Not needed for MVP
6. **Calendar Drag-Drop** - Read-only calendar view

### What's Essential

1. **Coach Registration** - Must work end-to-end
2. **Manual Verification** - You approve each coach
3. **Invitation System** - Core connection mechanism
4. **Basic Dashboard** - View athletes, recent activity
5. **Simple Messaging** - Thread-based, email notifications
6. **Mode Toggle** - Switch between coach/athlete views

---

## Success Criteria for Launch

| Metric | Target |
|--------|--------|
| Beta coaches | 5-10 verified |
| Coach-athlete connections | 20+ active |
| Invitation acceptance rate | 70%+ |
| Error rate | <5% on core flows |
| Page load time | <3 seconds |

---

## Post-Launch Roadmap

### Phase 5: Athlete Web Access (Week 6-7)
- Athletes can log in via web
- View coach-assigned plans
- Messaging works both ways

### Phase 6: Stripe Integration (When Ready)
- Only when you have 20+ coaches
- Or when manual billing becomes burdensome

### Phase 7: Enhanced Features (Based on Feedback)
- Real-time chat
- Calendar scheduling
- Advanced analytics

---

## File References

| Document | Purpose |
|----------|---------|
| `/docs/features/coach_mode/README.md` | Complete feature documentation |
| `/docs/features/coach_mode/schema_analysis.md` | Database schema and RLS policies |
| `/docs/web_mode/SETUP.md` | Web deployment setup guide |
| `/docs/features/coach_mode/DEPLOYMENT_ROADMAP.md` | This document |

---

**Last Updated**: 2025-12-25
**Owner**: Development Team
**Next Review**: After soft launch
