# 43: Onboarding: the 971 px overflow and VoiceOver semantics

**Status:** in-progress (wave 4, 2026-10-08)
**Labels:** fix, round:develop-2026-10, area:onboarding, area:accessibility
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 40 (runs first, alone). Not alongside 42, which also edits `post_onboarding_auth_screen.dart`.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Two things. First, find and fix the vertical `Column` that overflowed by 971 px during onboarding (dev Sentry MEALVANA-ENDURANCE-DEV-B1). Second, make Build My Plan, the three sign-in options and the consent switch named controls for VoiceOver. Labels and traits only. No onboarding body copy changes: that copy is Xuan's. The gender-required item (30-009) is not here; it goes to Xuan. Line numbers are from code at `d7650d15`.

**A. The overflow (30-002).**

1. **What the event says.** The drafter read DEV-B1 event `ba3e81d087934a2aa441845a11d44049` with the Sentry MCP. FlutterError "A RenderFlex overflowed by 971 pixels on the bottom", thrown during layout, `level: fatal`, `handled: no`, iPhone 17 Pro simulator 402×874, `text_scale: 1`, `view_names: [onboarding]`, 12:58:11Z. The debugCreator chain is `Column ← MediaQuery ← Padding ← SafeArea ← KeyedSubtree-[GlobalKey] ← _BodyBuilder ← MediaQuery ← LayoutId-[_ScaffoldSlot.body]`, which is a `Scaffold(body: SafeArea(child: Column(...)))` with nothing between SafeArea and the Column. The event names no route and no widget class.
2. **Candidates, from code.** A lib-wide search for `body: SafeArea(… child: Column(` outside `_archived/` finds four, three of them onboarding chrome:
   - `OnboardingStepScaffold` (`lib/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart:115-193`): personal info, body composition, nutrition settings, plan reveal and the daily preview all use it. Personal info ("Tell us about yourself", `personal_info_screen.dart:324`) was in front at the time.
   - `OnboardingMultiSelectStep` (`onboarding_multi_select_step.dart:74-150`): sports, goals, pitfalls.
   - `ConnectedAppsScreen._buildOnboardingLayout` (`lib/features/settings/presentation/screens/connected_apps_screen.dart:198-~300`): step 3.
   - `carb_slot_screen.dart:60` is not in onboarding.
   All three have the same shape: header, `Expanded(SingleChildScrollView(...))`, footer CTA. The content scrolls, so the outer Column can only overflow by its fixed children minus the body height. The header is about 58 px (`OnboardingStepHeader`, `onboarding_multi_select_step.dart:153-194`) and the footer about 100 px (`OnboardingSpecCta` plus `fromLTRB(24, 8, 24, ≥34)`). Even at zero body height that is roughly 160 px, not 971. **Neither the cause nor the Column is confirmed.** Either the overflowing Column is a fourth one the search misses (a body built elsewhere and passed in), or a fixed child is far taller than it looks under some state, such as keyboard up, a PageView neighbour, or the build loader.
3. **Reproduce first, then fix where it reproduces.** Write the widget test in the checklist before changing any layout. Pump `OnboardingPageViewScreen` (the real PageView, `onboarding_pageview_screen.dart:300-335`, with its keep-alive pages) at 402×874 and at iPhone SE 375×667 (`smallPhoneSize` in `test/helpers/widget_test_harness.dart:129`). Jump to page 4, focus First name, and set `tester.view.viewInsets` to a keyboard (336 px on the 402×874 device; 260 on SE). Collect overflow errors from `tester.takeException()` and `FlutterError.onError`, and record the creator chain and pixel count in this ticket. Repeat on pages 3 and 5, and on the swipe between 4 and 5.
4. **Fix at the site the test names.** If it is the shared chrome, fix it once in that widget, not per screen. The fixed children must fit at the smallest height the test reaches, with the content area still scrolling, and nothing may change visually with the keyboard down (the chrome is a spec port: `OnboardingStepScaffold`'s doc comments quote the HTML-spec values). If the only fix that holds changes how the footer behaves with the keyboard up (for example the CTA hidden behind it), stop and write that into this ticket for Lee. Do not ship a visible change on your own.
5. **If nothing reproduces.** Write what was tried and the measured heights into this ticket and close item A as "not reproduced; DEV-B1 left open". Do not guess-fix.

**B. VoiceOver (30-010).** The pattern already in the codebase is `OnboardingSpecCta` (`onboarding_multi_select_step.dart:265-296`): `Semantics(container: true, button: true, enabled:, label:)` around the `InkWell`, with the visible text in `ExcludeSemantics` so it is read once.

6. **Build My Plan is a button.** On Welcome (`lib/features/onboarding/presentation/screens/welcome_screen.dart:168-202`), the CTA is a `Material` + `InkWell` (`:183-200`) with a `Text`. VoiceOver lists it as `StaticText 'Build My Plan'` next to `Button 'I already have an account'` (a `TextButton`, `:224-236`). Wrap it the same way: `Semantics(container: true, button: true, label: 'Build My Plan')`, with the `Text` inside `ExcludeSemantics`. Keep the `welcome.get_started_button` key on the `InkWell`. `welcome_get_started_navigates_test.dart:58-60` taps `find.text('Build My Plan')`, which still finds it.
7. **The three sign-in options are buttons.** `_SpecAuthButton` (`lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart:1087-1170`) is a `Material` + `InkWell` (`:1117`) with no semantics. It draws "Continue with Apple", "Continue with Google" and "Sign up with email" / "Log in with email" (`:785-848`). Wrap the `InkWell` in `Semantics(container: true, button: true, enabled: onPressed != null, label: label)` and the child in `ExcludeSemantics`. That also names the button while `isLoading` shows only a spinner (`:1121-1131`), which today has no label at all. "Continue without an account" is a `TextButton` (`:856-875`) and is already a button.
8. **The consent switch has a name.** On "Your privacy", `_buildUsageToggle` (`lib/features/privacy/presentation/screens/privacy_consent_screen.dart:102-147`) puts the title "Share usage data" (`:108-118`) and the `KyleSwitch` (`:119-125`) side by side in a `Row`. VoiceOver reads them separately, as `StaticText` plus `CheckBox '' '0'`. Wrap that `Row` in `MergeSemantics` so the switch's toggled node takes the title as its label. Change the call site only. `KyleSwitch` (`lib/shared/widgets/kyle_design/inputs/kyle_switch.dart:10`) is a library component, and changing it would owe `/design-sync`. The disclosure line under the row (`:128-145`) stays outside the merge: it is long, and VoiceOver reads it next.

**Findings:** 30-002, 30-010.

**Decisions:**
- Lee's triage on both Findings: "fix ticket 43 (onboarding overflow + VoiceOver semantics)".
- Labels and traits only, no copy changes: onboarding body copy is Xuan's (memory: onboarding copy is Xuan's). The labels are the visible strings that already exist.
- No library component changes, so `/design-sync` is not owed. If the overflow fix (item 4) changes `OnboardingSpecCta` or `OnboardingStepHeader`, those live in the feature folder, not `lib/shared/widgets/kyle_design/`, so that still holds.
- 30-009 (Continue stays dimmed until a gender is chosen) is not in this ticket: it goes to Xuan.

**Touches:** lib/features/onboarding/presentation/screens/welcome_screen.dart, lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart, lib/features/privacy/presentation/screens/privacy_consent_screen.dart, lib/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart (only if item 3 names it), lib/features/onboarding/presentation/widgets/onboarding_multi_select_step.dart (only if item 3 names it), lib/features/settings/presentation/screens/connected_apps_screen.dart (only if item 3 names it), test/features/onboarding/onboarding_overflow_test.dart (new), test/features/onboarding/onboarding_accessibility_test.dart, test/privacy/privacy_consent_semantics_test.dart (new, beside the other privacy tests). 9 files at most, 6 if the overflow is in one chrome widget. No generated files.

**Overlaps:**
- **42** (pending signup) edits `post_onboarding_auth_screen.dart`. Sequential; whichever runs second re-reads `_SpecAuthButton`'s lines.
- **37** and **47** edit `connected_apps_screen.dart`'s settings and integration paths. Item 4 touches that file only if the overflow reproduces in `_buildOnboardingLayout`. If it does, run after 37 and 47 merge.
- **36** has `preferences_accessibility_test.dart`, a different file. 34, 35, 38, 39, 40, 41, 44, 45 and 46 share no file.

No edge-function or schema change. Nothing to deploy.

- [ ] Overflow test (`onboarding_overflow_test.dart`, written first): the real `OnboardingPageViewScreen`, using the harness and provider overrides `personal_info_screen_test.dart` uses, at 402×874 and 375×667, keyboard down and up (`tester.view.viewInsets`), on pages 3, 4 and 5 and the swipe from 4 to 5. Assert no `FlutterError` whose message contains "overflowed". Before the fix, it must fail at the site that reproduces DEV-B1 (record the creator chain here). After the fix, it passes. If nothing reproduces, the test stays as a guard and item 5 applies.
- [ ] Semantics (`onboarding_accessibility_test.dart`, extended; it already pins the back circle and the Continue pill the same way): with `tester.ensureSemantics()`, Welcome's CTA `matchesSemantics(isButton: true, hasTapAction: true, hasEnabledState: true, isEnabled: true, label: 'Build My Plan')`. On Create account, each of the three `_SpecAuthButton`s is a button with its label, enabled and disabled (`isBusy`), and the loading Google button is still named.
- [ ] Semantics (`privacy_consent_semantics_test.dart`): the usage switch's node `matchesSemantics(hasToggledState: true, isToggled: false, label: 'Share usage data', hasTapAction: true, hasEnabledState: true, isEnabled: true)`. Tapping it flips `isToggled`.
- [ ] `flutter analyze` clean on touched files; run `test/features/onboarding/` and `welcome_get_started_navigates_test.dart`.
- [ ] Retest on device: wave 5 retest ticket 48 (onboarding with the keyboard up on every text page, dev Sentry checked for a new overflow event; `idb ui describe-all` on Welcome, Create account and Your privacy).

Next: /testing-wave develop-2026-10 (fix wave 4)
