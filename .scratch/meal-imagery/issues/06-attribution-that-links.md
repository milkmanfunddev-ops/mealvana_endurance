# 06: Attribution that links

**What to build:** Photographers are credited in plain text that goes nowhere. Where a picture is
shown at size, the credit should name the photographer and the platform and take a tap to the
source.

This is a licence obligation already written down as one, and it is the outstanding requirement for
stock-provider production access — which has a lead time. The Unsplash pictures in the library are
currently served under demo access.

**Blocked by:** None (can start immediately)

**Status:** done (2026-09-11)

- [x] Where a picture is shown at size, its credit names the photographer and the platform and opens
      the source when tapped.
- [x] A Mosaic credits every distinct photograph behind it, deduplicated.
- [x] Cards keep carrying the credit for screen readers, without a visible credit line crowding the
      dense list.
- [x] Providers that require a particular wording get it.
- [x] Nothing regresses in the list layout at the smallest supported width.

**Outcome.** Credits are built in `KyleImageCredit` (`meal_image_mosaic.dart`) and shown under the
detail hero by `MealImageCredits`; cards carry the same text as their screen-reader label.

**Left open:**
- The photographer's name opens the photograph's page, not the photographer's profile. The
  pipeline drops Unsplash `user.links.html` and Pexels `photographer_url`. Unsplash's guideline
  links the profile, so close this before the production-access application.
- `get_meal` sends no `provider` for a dish photo, so the platform comes from the source URL's
  host. A stock dish photo with no source URL would be credited without its platform.
- The Unsplash referral name is `mealvana`; it must match the application registered with
  Unsplash.
