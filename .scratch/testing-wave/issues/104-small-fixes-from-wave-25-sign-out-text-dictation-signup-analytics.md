# 104: One sign-out text, dictation explains a refusal, signup analytics carries the device id

**Status:** in-progress (wave 27, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Three small rulings by Lee at wave 25 triage (2026-09-25, in the terminal).
1. **One sign-out confirm (86-004).** The paywall ⋯ → Sign out confirm uses Settings' text: "You'll need to sign in again to use Mealvana. Your data stays with your account." One content key for both, the way ticket 47 did for the two delete confirms.
2. **Dictation after Don't Allow (86-005).** When the athlete has refused Speech Recognition, the Vana chat's Dictate button stays. A tap shows a `MealvanaSnackbar` (content system) saying dictation needs Speech Recognition and Microphone access, turned on in iOS Settings → Mealvana. The button still hides where there is no speech engine at all (web, a device without one).
3. **user_registered carries the device id (86-006).** `OnboardingService` sends the same device id `app_opened` sends, not the user id (`onboarding_service.dart:55`).

**Findings:** 86-004, 86-005, 86-006. Retest ticket 107 closes them; this ticket does not.

**Decisions:** Lee's rulings above; mp-508 holds (no guest wording). No page writes.

**Touches:** lib/features/subscription/presentation/screens/paywall_screen.dart, lib/features/settings/presentation/screens/settings_screen.dart (the sign-out confirm's key), lib/features/meal_planning/presentation/widgets/vana_mic_button.dart, lib/features/onboarding/application/onboarding_service.dart, lib/shared/services/analytics/ (where the device id is read), lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Widget test: both sign-out confirms show the same body text from one key.
- [ ] Widget test: with speech permission refused the Dictate button shows, and a tap shows the settings message; with no speech engine it is hidden.
- [ ] Test: `trackUserRegistered` receives the device id, not the user id.
- [ ] `flutter analyze` clean on touched files, the touched tests green.

Next: /implement-lee testing-wave
