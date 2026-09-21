# 14: The paywall opens on our app

**Status:** ready-for-agent
**Blocked by:** 03 (touches lib/features/subscription/presentation/screens/paywall_screen.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A new dev athlete meets a paywall that opens on about four seconds of the real app playing silently in a phone frame (timeline, Vana, meal plan), then slides over to four headline features, an "also includes" divider and the rest, with the AI features under one Vana line. With Reduce Motion on, it shows the clip's first frame and goes straight to the features. The phone frame, the slide-over and the feature list are new `kyle_design` widgets on the glass materials, each with a component spec awaiting Xuan.

**Decisions:** mp-493, mp-497, mp-453; approved as mp-498.

**Touches:** assets/video/, pubspec.yaml, lib/shared/widgets/kyle_design/data/phone_clip_frame.dart, lib/shared/widgets/kyle_design/navigation/slide_over_pager.dart, lib/shared/widgets/kyle_design/cards/feature_list.dart, lib/shared/widgets/kyle_design/kyle_design.dart, docs/ssot/spec/design/components/phone-clip-frame.md, docs/ssot/spec/design/components/slide-over-pager.md, docs/ssot/spec/design/components/feature-list.md, lib/features/subscription/presentation/screens/paywall_screen.dart, test/shared/widgets/kyle_design/phone_clip_frame_test.dart, test/shared/widgets/kyle_design/slide_over_pager_test.dart, test/features/subscription/presentation/paywall_screen_test.dart

- [ ] A clip of about four seconds (timeline, Vana answering, meal plan) is recorded from the dev simulator and bundled with the app.
- [ ] The paywall plays it silently in the phone frame, then slides to the features; close and ⋯ placeholders appear only on the second page (screen widget test).
- [ ] Reduce Motion shows the first frame and goes straight to the features (screen widget test).
- [ ] Four headline features, the "also includes" divider, and the AI features under one Vana line, copy from the content system.
- [ ] Each new widget has a widget test and a component spec marked "PROPOSED, authored app-side, awaiting Xuan"; no colour literals outside `lib/theme/`; `/design-sync` run.
- [ ] Checked on the dev simulator.

Next: /implement-lee paywall
