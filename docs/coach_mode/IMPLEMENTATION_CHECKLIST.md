# Coach Mode Implementation Checklist

**Status**: Ready to Start
**Updated**: 2025-12-25

---

## Phase 0: Web Foundation (Days 1-5)

### Vercel Setup
- [ ] Install Vercel CLI: `npm i -g vercel`
- [ ] Login: `vercel login`
- [ ] Link project: `vercel link`
- [ ] Create `vercel.json` in project root
- [ ] Add environment variables in Vercel dashboard:
  - [ ] `SUPABASE_URL`
  - [ ] `SUPABASE_ANON_KEY`
  - [ ] `SENTRY_DSN`
- [ ] Configure custom domain: `enduranceapp.mealvana.io`
- [ ] Test preview deployment: `vercel`
- [ ] Test production deployment: `vercel --prod`

### Web Testing
- [ ] Run locally: `flutter run -d chrome`
- [ ] Build succeeds: `flutter build web --release --wasm`
- [ ] IndexedDB storage works
- [ ] Supabase connection works
- [ ] No dart:io compilation errors
- [ ] OAuth redirect flow works

---

## Phase 1: Database & Edge Functions (Week 1)

### Database Migration
- [ ] Create enum types:
  - [ ] `relationship_status_enum` (pending, active, declined, archived)
  - [ ] `permission_level_enum` (view_only, full_access, custom)
- [ ] Create `coaches` table
- [ ] Create `coach_athlete_relationships` table
- [ ] Create `coach_feedback` table
- [ ] Modify `nutrition_plans` table (add coach columns)
- [ ] Modify `activities` table (add coach columns)
- [ ] Modify `workout_notes` table (add coach columns)
- [ ] Create 22 RLS policies
- [ ] Create 15 indexes
- [ ] Create 3 helper functions
- [ ] Create 5 triggers
- [ ] Test migration in dev environment
- [ ] Deploy to production

### Edge Functions
- [ ] Create `create-coach-profile` function
- [ ] Create `verify-coach-manual` function
- [ ] Create `generate-invitation-link` function
- [ ] Create `get-invitation-details` function
- [ ] Create `accept-coach-invitation` function
- [ ] Create `send-message` function
- [ ] Deploy edge functions to Supabase
- [ ] Test each function in isolation

### Email Templates
- [ ] Welcome email (coach approved)
- [ ] Rejection email (coach rejected)
- [ ] Invitation email (coach invites athlete)
- [ ] Acceptance confirmation (athlete accepts)
- [ ] Message notification (new message)

---

## Phase 2: Flutter Feature Structure (Week 1-2)

### Domain Models
- [ ] `Coach` model
- [ ] `CoachAthleteRelationship` model
- [ ] `Invitation` model
- [ ] `Message` model

### Repositories
- [ ] `CoachRepository` (abstract interface)
- [ ] `SupabaseCoachRepository` (implementation)

### Services
- [ ] `CoachService`
- [ ] `InvitationService`
- [ ] `MessagingService`

### Controllers
- [ ] `CoachRegistrationController` (@riverpod)
- [ ] `CoachDashboardController` (@riverpod)
- [ ] `InvitationController` (@riverpod)
- [ ] `MessageController` (@riverpod)

### Run code generation
- [ ] `dart run build_runner build --delete-conflicting-outputs`

---

## Phase 3: UI Screens (Week 2-3)

### Coach Registration
- [ ] `CoachRegistrationScreen`
  - [ ] Full name field
  - [ ] Email field
  - [ ] Phone field (optional)
  - [ ] Specializations multi-select
  - [ ] Bio text area
  - [ ] Certification upload
  - [ ] Insurance upload
  - [ ] Submit button
- [ ] Form validation
- [ ] Loading states
- [ ] Success/error handling
- [ ] Pending verification message

### Coach Dashboard
- [ ] `CoachDashboardScreen`
  - [ ] Athlete list
  - [ ] Quick stats (total athletes, pending invites)
  - [ ] Recent activity feed
  - [ ] Search/filter
- [ ] Empty state UI
- [ ] "Invite Your First Athlete" CTA
- [ ] Pull-to-refresh

### Athlete Screens
- [ ] `AthleteListScreen`
  - [ ] Searchable list
  - [ ] Status indicators
  - [ ] Navigation to detail
- [ ] `AthleteDetailScreen`
  - [ ] Profile info
  - [ ] Biometrics
  - [ ] Food preferences
  - [ ] Recent activities
  - [ ] Nutrition plans

### Invitation Screens
- [ ] `GenerateInvitationScreen` (coach)
  - [ ] Email input
  - [ ] Permission level selector
  - [ ] Custom message textarea
  - [ ] Generate button
  - [ ] Copy link CTA
- [ ] `InvitationPreviewScreen` (athlete)
  - [ ] Coach profile card
  - [ ] Permission explanation
  - [ ] Expiration countdown
  - [ ] Accept/Decline buttons
- [ ] `InvitationAcceptedScreen`
  - [ ] Success message
  - [ ] Coach contact info
  - [ ] Navigate to dashboard

### Messaging Screen
- [ ] `MessageThreadScreen`
  - [ ] Message list (scrollable)
  - [ ] Message composer
  - [ ] Send button
  - [ ] Attachment upload
  - [ ] Unread badge

### Widgets
- [ ] `CoachCard`
- [ ] `AthleteCard`
- [ ] `ActivityCard`
- [ ] `PlanCard`
- [ ] `ModeToggleWidget`
- [ ] `MessageBubble`

---

## Phase 4: Mode Toggle (Week 3)

### Implementation
- [ ] Create `AppModeProvider` (@riverpod)
- [ ] Implement `ModeToggleWidget`
- [ ] Add to app bar
- [ ] Persist to SharedPreferences/localStorage
- [ ] Sync to Supabase `user_profiles.preferred_mode`

### Visual Indicators
- [ ] Coach mode badge (blue)
- [ ] Coach mode accent color
- [ ] Navigation drawer updates

### Navigation
- [ ] Update GoRouter with coach routes
- [ ] Redirect logic based on mode
- [ ] Deep link support

---

## Phase 5: Admin Verification (Week 3)

### Admin Dashboard
- [ ] Pending coaches list
- [ ] Coach detail view (certifications, insurance)
- [ ] Approve button
- [ ] Reject button (with reason)
- [ ] Verification checklist UI

### Workflow
- [ ] Email notifications on approval/rejection
- [ ] Update coach status in database
- [ ] Activity logging

---

## Phase 6: Testing (Week 4)

### Unit Tests
- [ ] Coach model serialization
- [ ] Invitation token generation
- [ ] Permission checks
- [ ] Message validation

### Widget Tests
- [ ] CoachDashboardScreen
- [ ] MessageThreadScreen
- [ ] ModeToggleWidget

### Integration Tests
- [ ] Coach registration flow
- [ ] Invitation acceptance flow
- [ ] Messaging flow

### Edge Function Tests
- [ ] All functions with valid inputs
- [ ] All functions with invalid inputs
- [ ] RLS policy enforcement

### Cross-Browser Testing
- [ ] Chrome
- [ ] Firefox
- [ ] Safari
- [ ] Edge

### Responsive Testing
- [ ] Desktop (1920x1080)
- [ ] Tablet (768x1024)
- [ ] Mobile (375x667)

### Performance Testing
- [ ] Page load < 3 seconds
- [ ] Bundle size < 3MB
- [ ] Lighthouse score > 80

---

## Phase 7: Soft Launch (Week 5)

### Beta Coaches
- [ ] Identify 5-10 beta coaches
- [ ] Send personal invitations
- [ ] Schedule 1-on-1 onboarding calls
- [ ] Create onboarding documentation

### Monitoring
- [ ] Sentry error tracking configured
- [ ] Analytics events configured
- [ ] Error rate dashboard

### Feedback Collection
- [ ] Weekly feedback calls scheduled
- [ ] Feedback form created
- [ ] Bug report process established

### Public Launch (When Ready)
- [ ] All beta feedback addressed
- [ ] Error rate < 5%
- [ ] Email announcement drafted
- [ ] Social media posts prepared

---

## Post-Launch Tasks

### Athlete Web Access
- [ ] Athletes can log in via web
- [ ] View coach-assigned plans
- [ ] Messaging works both ways

### Stripe Integration (Later)
- [ ] Only when 20+ coaches
- [ ] Or manual billing burdensome

### Enhanced Features (Based on Feedback)
- [ ] Real-time chat
- [ ] Calendar scheduling
- [ ] Advanced analytics

---

## Reference Files

| File | Purpose |
|------|---------|
| `/docs/coach_mode/DEPLOYMENT_ROADMAP.md` | Timeline and strategy |
| `/docs/features/coach_mode/schema_analysis.md` | Database schema |
| `/docs/web_mode/SETUP.md` | Web deployment guide |
| `vercel.json` | Vercel configuration |

---

**Last Updated**: 2025-12-25
