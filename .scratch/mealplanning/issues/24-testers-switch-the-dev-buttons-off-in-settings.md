# 24: Testers switch the dev buttons off in Settings

**Status:** done (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** In a dev build, Settings shows a switch that turns the accessibility and wrench buttons off and on for that tester on that device. It defaults to on, is remembered across launches, and is absent from release builds. No build-time flag.

**Decisions:** mp-271; approved as mp-302.

**Touches:** lib/features/settings/presentation/screens/settings_screen.dart, lib/shared/widgets/root_app_widget.dart, lib/shared/widgets/environment_indicator.dart, test/features/settings

- [x] A dev-only switch in Settings, default on, persisted per device (controller test through the real notifier).
- [x] Off hides the accessibility tools and the wrench; on restores them without a restart.
- [x] Release builds show no switch and no buttons, as today.

Next: /implement-lee mealplanning
