# 66: The Subscription screen names the plan, and Manage never opens a blank page

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The Subscription screen's status card names the plan bought (Monthly or Annual; mp-495 "shows the plan"). Manage subscription opens the store's page when RevenueCat has a management URL; when it has none (a Test Store subscription), it says where to manage it instead of opening an empty Safari page.

**Findings:** 08-001, 09-001 (read each in `.scratch/testing-wave/findings/` before starting; they hold the steps, the evidence and the cause where the run found it). A retest wave closes them; this ticket does not.

**Decisions:** mp-495

**Touches:** lib/features/subscription/application/subscription_screen_controller.dart, lib/features/subscription/presentation/screens/subscription_screen.dart, lib/features/subscription/data/subscription_service.dart

- [ ] A widget test: a monthly subscription shows Monthly on the status card.
- [ ] A test: a null management URL shows the message and opens nothing.
- [ ] codegen if annotations changed, `flutter analyze` and the suite green.

Next: /implement-lee testing-wave
