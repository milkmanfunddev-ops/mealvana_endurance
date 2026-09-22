# 04: The day-five reminder

**Status:** in-progress (wave 2, 2026-09-22)
**Blocked by:** 03 (touches lib/features/subscription/application/pro_paywall_controller.dart).
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A dev athlete who starts the free week gets a local notification at 10:00 two days before the trial ends: the trial ends in two days, the price after, and they can cancel any time; tapping it opens the store's subscription page. If they cancel, the next app open removes it.

**Decisions:** mp-456; approved as mp-483.

**Touches:** lib/shared/services/notification_service.dart, lib/features/subscription/application/pro_paywall_controller.dart, lib/features/subscription/application/subscription_status_provider.dart, lib/features/content/domain/content_keys.dart, test/features/subscription/application/pro_paywall_controller_test.dart, test/shared/services

- [ ] A purchase that starts a trial schedules one notification at the right local time (controller test with a fake scheduler).
- [ ] A trial that will not renew cancels it on app open.
- [ ] A purchase with no trial schedules nothing.
- [ ] The text comes from the content system.

Next: /implement-lee paywall
