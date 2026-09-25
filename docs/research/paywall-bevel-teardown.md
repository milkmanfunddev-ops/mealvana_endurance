# Bevel paywall teardown

**Date:** 2026-09-21 · **Branch:** `mealplanning` · **Source:** `docs/BEVEL.MP4`
**Context:** store submission ~25 Sep, paywall opens 1 Oct.

Xuan liked Bevel's paywall sheet and its code redemption and asked for something similar. This is
what the recording shows, where it lands against the paywall work already specced, and the call on
codes.

## How the video was read

`docs/BEVEL.MP4` is a 22.9-second iPhone screen recording — 1284×2778, HEVC, 60fps, with audio.
Probed with `ffprobe`, cut to one frame per second with `ffmpeg`, all 23 frames read. The file is
untracked at 20 MB; keep it out of git and keep this teardown instead.

## The flow, in order

1. **A subscription hub that states what you don't have.** One card headed "Bevel Free", then a
   single list mixing green ticks for what you have with red crosses for what you don't — and the
   four locked AI features nested one level under "Access to Bevel Intelligence", so the reason
   they are locked reads as one thing, not four. Below it an "Upgrade to Bevel Pro" row and a link
   out to membership and pricing.

2. **The sheet opens on a picture, not a price list.** "Start your health journey today with Bevel
   Pro" over a device shot of their own Recovery screen — 98% recovered, HRV and resting-HR tiles,
   an AI paragraph, "Ask Bevel anything". One black Continue pinned at the bottom. It sells the
   product by showing the product.

3. **Scroll reveals the features; the price never leaves the screen.** Four headline items with
   icons, then a divider reading *also includes* and the secondary list. The plan cards stay docked
   above Continue the whole scroll: Yearly $99.99 selected with a "Save 44%" badge and an $8.33/mo
   equivalent, Monthly $14.99 beside it.

4. **Everything else hides behind ⋯.** Redeem promo code and Restore purchase, and nothing else. No
   stack of text buttons competing with the thing they want you to tap.

5. **Redeem hands off to Apple.** A second of blank sheet, then the App Store's own "Redeem Offer"
   sheet with the Bevel icon and a Code field. Bevel built no code UI at all. The recording ends
   there, no code entered.

Frames of interest at 1 fps: 0:00 (hub), 0:06 (features + plans), 0:10 (⋯ menu), 0:17 (Apple sheet).

## Where the paywall work actually stands

- **Tickets are already cut.** `/to-tickets-lee paywall` has run: thirteen ticket cards sit in
  `.scratch/mealplanning/decisions.md` as **mp-480–mp-492**, proposed and awaiting a verdict on the
  decisions page. No issue files exist yet, so amending them is still cheap — but the fold-in has to
  change those proposals, not follow them.
- **The redeem sheet is free.** `Purchases.presentCodeRedemptionSheet()` already ships in
  `purchases_flutter` 10.3.0, the version we are on. Bevel's whole redeem flow is one line. iOS only.
- **The hub is a new surface.** No subscription settings screen exists anywhere in
  `lib/features/settings/`. It is the natural home for the "Have a code?" Settings row that ticket 10
  (mp-489) already promises.
- **Our paywall is a route, not a sheet**, with Restore / Manage / Sign out / Delete as a stack of
  text buttons (`paywall_screen.dart:324`). mp-280 ratified that shape, so moving Restore and Manage
  into a ⋯ menu is a change to a ruling, not a tidy-up.
- **mp-453 is additive, not contradictory.** It already says *what* the paywall shows — Current
  Offering, founding price beside the struck-through normal one, trial terms, links. It says nothing
  about its shape.

## Store codes: how much setup is it really?

Our own codes (mp-458, ticket 07) cost nothing at either store: a table, a function, a text field,
identical on both platforms, working the day the build lands. Store-side codes are two different
systems.

| | Apple offer codes | Google Play promo codes |
|---|---|---|
| Before you can use them | Products must exist and the app must be **Ready for Sale**. Nothing is redeemable until the 25 Sep build is approved and live. | Created per subscription product in Play Console. Separate console, campaign and codes. |
| Who can redeem | New, active and expired subscribers — you choose. One code per offer per customer. | **Custom codes only work for people who have never subscribed.** That alone kills coach comps and any free year for a lapsed athlete. |
| Volume | 1M redemptions per app per quarter, 10 active offers per SKU, custom-code cap 25,000, codes expire within six months. | One-time codes 10,000/quarter per product; custom codes 2,000–99,999. Unused codes do not carry over. |
| In-app redemption | Native sheet via StoreKit — what Bevel uses. | None. You send people out to Play. |
| Carries coach pairing or founding status | No. | No. |

### The call

Our codes stay the code system; **mp-458 is unchanged**. With four products across two apps, store
codes would mean running two consoles that behave differently, and neither can carry the coach
pairing or founding attribution the spec needs — and Apple's cannot be redeemed at all until the app
is live.

What we take from Bevel is the *placement*: "Redeem code" in the ⋯ menu instead of a link buried on
the paywall. Also wire `presentCodeRedemptionSheet()` as a second, iOS-only entry — one line, no
store setup, and the only way an App Store offer code Xuan creates later could ever be redeemed
in-app. It keeps the door open without building a code programme before launch.

## Recommendations

- **Amend mp-482** (ticket 03, the paywall): gains the sheet shape — hero, feature list split into
  headline and *also includes*, plan cards docked above one Continue with the saving badge.
- **Amend mp-489** (ticket 10, code entry): gains the ⋯ placement and the iOS App Store sheet as a
  second entry.
- **New card for the paywall's shape**, which **amends mp-280** — Restore and Manage move into ⋯,
  Sign out and Delete stay visible for a lapsed account.
- **New card for the Subscription hub**: the tick/cross list of what Pro adds, the upgrade row, the
  pricing link — plus a ticket card to build it.

Two details of Bevel's worth copying exactly: nesting the locked AI features under one parent line,
so a person reads one reason rather than four refusals; and keeping the price on screen through the
entire scroll, so the feature list never has to be scrolled back.

## Next steps

1. This file, so the cards cite something that lives in the repo. *(done)*
2. Amend mp-482 and mp-489 in `.scratch/mealplanning/decisions.md` before they are ruled.
3. Add the new proposal cards (mp-493 onward) for the sheet shape, the ⋯ menu and the Subscription hub.
4. Reseed the decisions page, get Xuan's and Lee's verdicts, run `sync.mjs apply`.
5. `/to-spec-lee paywall` to fold the rulings into the spec, then the ticket issue files.

## The one thing that can slip the 25th

Lee asked for all of it in the store build, and every part of this is code an agent can write —
except the hero. Bevel's is a device shot of their own Recovery screen. Ours needs a picture of our
app that Xuan and Kyle approve, and our own rule says a design-bearing widget gets a component spec
in `docs/ssot/spec/design/components/` before it is built, not a placeholder. That is the only piece
with a dependency outside this repo, and it wants Xuan today rather than on the 24th.

## Sources

- [Apple — Set up subscription offer codes](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-subscription-offer-codes/)
- [Android — Promo codes (Play Billing)](https://developer.android.com/google/play/billing/promo)
- [Play Console Help — Create promotions](https://support.google.com/googleplay/android-developer/answer/6321495)

Published as an artifact with the frames embedded: https://claude.ai/code/artifact/54b80c5e-f047-442a-82b8-aea7ac68ffad
