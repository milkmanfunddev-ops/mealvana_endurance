# 23: The launcher is an allow-list of three screens

**Status:** ready-for-agent
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** The launcher appears on the main tabs screen, the meal-planning screen and coach formulas, and nowhere else. Any page pushed over one of those hides it without naming itself. The flow-pattern list, the gate-prefix list and the three route-settings workarounds are deleted.

**Decisions:** mp-264; approved as mp-301.

**Touches:** lib/features/meal_planning/domain/vana_launcher_rule.dart, test/features/meal_planning/domain/vana_launcher_rule_test.dart, lib/shared/screens/food_detail_screen.dart, lib/features/events/presentation/screens/event_form_screen.dart

- [ ] The rule is an allow-list of the three routes; every other route, and any route pushed over one of the three, returns no launcher (rule tests).
- [ ] The flow-pattern list, the gate-prefix list and the RouteSettings workarounds are gone (the build-meal screen's workaround included; that file is otherwise untouched).
- [ ] Simulator: launcher on the Timeline, the Food tab and the formula library; none on a pushed form.

Next: /implement-lee mealplanning
