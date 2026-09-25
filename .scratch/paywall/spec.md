# The 1 October paywall, built to Xuan's RevenueCat spec

**Status:** ready-for-agent

Written by `/to-spec-lee paywall` on 2026-09-21 from Xuan's `docs/revenuecat-spec-for-lee.md` (revised
09-16), Lee's approval of mp-429 on 2026-09-21 and the record cleanup that followed it. Revised the same day to
fold in Bevel's paywall (`docs/research/paywall-bevel-teardown.md`, mp-493 to mp-497). The decisions
live in the mealplanning record (`mp-` ids), as the ai-cost spec's do. This spec cites them.

## Problem Statement

The paywall opens on 1 October at Xuan's prices, with a Founding Month to 30 November, and the store
submission has to go in around 25 September to leave room for one rejection. What is built today is
the 09-15 version: a seven-day trial on the old monthly and annual products, a gate that blocks every
screen, no grace for people who already use the app, no coach path and no trial reminder. An athlete
who meets it today sees the wrong prices. A person who has used the app for months is locked out on
the first launch of the new build. A coach has to pay to see what their athletes see. Nobody warns a
trialist before the first charge. And anyone given free access by hand is still refused by the server,
because the server never hears about granted access. The paywall itself is a price list with a stack
of text buttons under it; it shows nothing of the app it is selling, and Settings has nowhere to see
or manage a plan.

## Solution

An athlete finishes onboarding with an account and meets a paywall laid out like Bevel's, in our own
branding: a few seconds of our real app playing in a phone frame, then the features with the plans
pinned above one Continue button, and everything secondary behind a ⋯ menu. They pick a plan there. During October and
November the plan shows the founding price beside the normal one struck through. The first seven days
are free. On day five their phone reminds them what happens on day eight and where to cancel. Someone
who used the app before 1 October gets 30 days free and founding-member status without doing anything.
An old install that never made an account gets the same 30 days when it registers. A coach enters their
own code and never sees the paywall. When a subscription lapses, the athlete can still see their data,
read-only, with the paywall over it, and every AI feature refuses on the server as well as in the app.
A Subscription screen in Settings shows the plan, what Pro includes and how to manage it.
Xuan switches Founding Month on and off in the RevenueCat dashboard, with no app release.

## User Stories

1. As a new athlete, I want to pick monthly or annual at the end of onboarding, so that I know what I will pay before I start.
2. As a new athlete in October, I want to see the founding price beside the normal price struck through, so that I know I am getting a deal and until when.
3. As a new athlete, I want the first seven days free, so that I can try the whole app before I pay.
4. As a new athlete, I want to see from the store's own prices what I will pay after the trial, so that nothing on the screen is out of date.
5. As a trialist, I want a notification on day five saying the trial ends in two days, the price after, and where to cancel, so that I am never charged by surprise.
6. As a trialist who cancelled, I want that reminder not to arrive, so that I am not nagged about something I already did.
7. As a trialist, I want tapping the reminder to take me to the store's subscription page, so that cancelling is one tap away.
8. As an athlete who used the app before 1 October, I want 30 days of full access without paying, so that the paywall does not take my plans away overnight.
9. As an athlete who used the app before 1 October, I want founding-member status, so that I get the founding price when I subscribe.
10. As an athlete in the grace month who subscribes early, I want my free days to still count, so that subscribing never costs me days I was given.
11. As a person with an old install that never made an account, I want to register and keep my data, so that I am not starting over.
12. As that person, I want the same 30 days the others got once I register, so that I am not punished for never signing up.
13. As a new athlete, I want the app to ask me for an account before it saves anything, so that my data is never tied to a session I can lose.
14. As a new athlete, I want my onboarding answers kept while I make the account, so that I do not answer them twice.
15. As a coach, I want to enter my own code and be let in for 30 days at once, so that I can see the app my athletes use without paying.
16. As an athlete, I want to enter my coach's code, so that I am paired with them and they can see my plan.
17. As a giveaway winner, I want to enter a code and get a year free, so that the prize works without anyone doing it by hand.
18. As an athlete, I want a wrong or expired code to say so plainly, so that I know to ask for a new one.
19. As an athlete whose subscription lapsed, I want to still see my plans, meals and history, so that my data does not feel held hostage.
20. As an athlete whose subscription lapsed, I want every screen to tell me why I cannot change anything and how to fix it, so that I am never confused about what is locked.
21. As an athlete whose subscription lapsed, I want any edit or AI action to open the paywall, so that the way back is where I tried to go.
22. As an athlete who never subscribed, I want the paywall and nothing behind it, so that the app does not pretend to have data for me.
23. As an athlete, I want Restore in the paywall's ⋯ menu, so that a subscription bought on another phone opens this one.
24. As an athlete, I want Manage subscription, Sign out and Delete account in the same ⋯ menu, so that I can leave cleanly without them crowding the plans.
25. As an athlete, I want the app to open at once from the phone's saved answer, online or not, so that a slow network never locks me out.
26. As the business, I want every AI function to check the subscription on the server, so that a lapsed account with bought budget cannot keep calling describe-meal, meal photo, coach insight or the old chat.
27. As the business, I want granted access (grace, coach comps, giveaways) to reach the server's subscription record, so that the server lets in who RevenueCat lets in.
28. As the business, I want a grant and a subscription never to shorten each other, so that no one loses days when both apply.
29. As Xuan, I want to switch Founding Month on at the start of 1 October and off after 30 November in the RevenueCat dashboard, so that no release is tied to a date.
30. As Xuan, I want the founding products taken off sale on 30 November, so that nobody switches to a founding price from Apple's own subscription screen afterwards.
31. As Lee, I want the grace grant run once on flip day with a dry run first, so that I can see exactly who gets it before anyone does.
32. As Lee, I want the grace run to skip anyone already granted, so that running it twice is harmless.
33. As Lee, I want the team's admin accounts to keep opening the app without paying, so that we can test and support on real accounts.
34. As a tester, I want to subscribe on TestFlight for free, so that I get in without a tester list.
35. As a coach's athlete, I want the coach attribution recorded when I enter the code, so that the coach's rev share can be counted later.
36. As a reviewer at Apple or Google, I want the trial terms, price after, and links to terms and privacy on the paywall, so that the submission passes.
37. As an athlete on the web build, I want the same gate answer as on my phone, read from the server, so that the web app agrees with the phone.
38. As a new athlete, I want the paywall to open on a few seconds of the real app, so that I see what I am paying for before I see a price.
39. As a new athlete, I want the plans and the Continue button to stay on screen while I scroll the features, so that I never scroll back to buy.
40. As a new athlete, I want the annual plan to show what it saves and what it costs a month, so that I can compare the two plans at a glance.
41. As a lapsed athlete, I want the AI features listed under one Vana line, so that I read one reason things are locked, not four.
42. As a lapsed athlete, I want the paywall as a sheet I can close, so that I can go back to reading my data.
43. As an athlete who turned on Reduce Motion, I want the paywall to skip the clip, so that nothing moves that I did not ask to move.
44. As an athlete, I want a Subscription screen in Settings with my plan status and renewal or end date, so that I can check my plan without the App Store.
45. As an athlete, I want Redeem code and Manage subscription on that screen, so that I know where to go for either.
46. As Xuan or Kyle, I want the paywall's clip and look built from our shared widget library in our branding, so that it matches the rest of the app and the clip can be swapped without code.

## Implementation Decisions

- **Scope.** The build follows mp-429: new products and prices, Founding Month switched by hand in the dashboard, coaches in through their own code, 30 days of grace for existing accounts, read-only data for a lapsed account, the day-five reminder, our own codes, and the server check on every AI function. Coach-discount products, the coach cron and the webhook-to-Mixpanel pipeline are out of this spec (Out of Scope), and so is the monthly Vana budget, which the ai-cost spec builds. (mp-429, mp-430)

- **The trial and the gate.** The store runs the seven-day trial as an introductory offer on every new product. The athlete subscribes at the end of onboarding with a payment method on file, and RevenueCat's `pro` entitlement is the gate from day one, with no trial clock anywhere in the app or the server. (mp-279)

- **How the client reads the gate.** On a phone the gate reads RevenueCat's saved copy on the device and answers at once, online or offline; with no saved copy and no answer within two seconds it locks. The web build reads the server's entitlement row instead. (mp-284, mp-335)

- **How the server reads the gate.** The server reads only the two-field entitlement row the webhook writes, and nothing the app sets can open it. A team admin opens the app gate without a subscription; that bypass is client-only. (mp-285, mp-317, mp-318, mp-416)

- **The account comes first.** The account is required and there are no anonymous users. After sign-up the athlete meets the paywall full screen with no close button. (mp-417, mp-493)

- **The lapsed paywall.** A lapsed account's data is untouched, and its paywall is a closable sheet over the read-only app, opened from the "plan ended" bar or any edit or AI tap. (mp-280, mp-457, mp-493)

- **The paywall's shape.** One layout, following Bevel's, in our branding. It opens on a silent clip of about four seconds of our own app in a phone frame (the fuelling timeline, then Vana answering, then the meal plan), recorded from the simulator and bundled with the app, played with `video_player`. When the clip ends the page slides over to four headline features, an "also includes" divider and the rest, with the AI features under one Vana line; the close and ⋯ buttons appear then. With Reduce Motion on it shows the clip's first frame and goes straight to the features. The two plan cards stay pinned above one Continue button through the scroll; the annual card is selected and shows its saving and per-month price, both computed from store prices. Everything it needs that the library lacks (the phone frame that plays the clip, the slide-over, the pinned plan cards, the ⋯ menu, the sheet's entrance) is built once in `kyle_design` on the liquid glass materials, each with a component spec written app-side awaiting Xuan, and the paywall composes them. (mp-493)

- **The ⋯ menu.** One ⋯ button holds Restore purchases, Redeem code, Manage subscription (only with a subscription to manage), Sign out and Delete account, in both presentations. Redeem code opens our own code entry only; there is no App Store offer-code sheet. (mp-494)

- **The Subscription screen.** A Subscription row in Settings opens a screen with the plan status (trial with its end date, active with its renewal date, founding member, or ended), a tick list of what Pro includes with the AI features under one Vana line, Upgrade (opens the paywall sheet, when the plan has ended), Manage subscription (when there is a subscription) and Redeem code. It is built from the same library widgets as the paywall. (mp-495)

- **Products.** Four products on each store and each app, created by hand in App Store Connect and Play Console: monthly $24.99 and annual $199.99, founding monthly $12.49 and founding annual $99.99, each with the seven-day introductory offer. The dev app sells `me_pro_monthly`, `me_pro_annual`, `me_pro_monthly_founding` and `me_pro_annual_founding`. The production app sells the same ids with `_prod` on the end, because Apple refuses an id another app in the team already holds. All four sit in one subscription group and attach to `pro`. If RevenueCat support answers the group question (mp-429 clause 9) by 23 September, their answer decides the grouping; otherwise it is one group, and the founding products come off sale on 30 November. The old monthly and annual products leave every offering and are never sold again. The webhook's fallback list of `pro` product ids gains the eight new ids. (mp-452)

- **What the paywall shows.** The paywall reads RevenueCat's Current Offering, not a fixed offering id, so Xuan's switch to `founding` on 1 October and back to `default` after 30 November needs no release. While the current offering is `founding`, each plan shows the founding price, the matching `default` price struck through beside it, and a "Founding member" line; while it is `default`, it shows the plain price. Every price and the trial line come from the store. The copy lives in the content system. The paywall carries the trial terms, the price after the trial, and links to terms and privacy for review. (mp-453)

- **The webhook takes RevenueCat's own answer.** Granted access reaches the webhook as a `NON_RENEWING_PURCHASE` with store and period type `PROMOTIONAL` and environment `PRODUCTION`, even in sandbox; today the webhook ignores it. On every event for `pro`, granted or bought, the webhook asks RevenueCat's REST API for the customer's current `pro` expiry and writes that as active until. RevenueCat already takes the later of a grant and a subscription, so a trial started during the grace month cannot cut the grace short, and a lapsed trial cannot close a live grant. The row keeps the two fields and the event time. The function needs a RevenueCat secret API key in its environment. (mp-454)

- **The grace grant.** On flip day a script grants 30 days of `pro` through RevenueCat's REST API to every registered account created before the flip, and sets a `founding_member` subscriber attribute. It runs as a dry run by default, printing the accounts and the count, and writes only with an explicit flag; it skips an account that already holds a grant. It runs on dev first, then production with Lee's go. An install that is still anonymous when it opens the new build goes to the account screen; sign-up links onto that anonymous user so the data survives, and a server function then grants the same 30 days when the anonymous user predates the flip and has no grant yet. This is the one place the app still meets an anonymous user; it never starts one. (mp-455)

- **The day-five reminder.** When a purchase starts an introductory trial, the phone schedules a local notification through the existing notification service, not OneSignal, whose client cannot schedule a push. It fires at 10:00 local time two days before the trial ends and says the trial ends in two days, the price after from the store, and that they can cancel any time; tapping it opens the store's subscription page. When the app opens and RevenueCat says the trial will not renew, the notification is cancelled. The text lives in the content system. (mp-456)

- **Three gate states.** The gate answers open (the entitlement is active, or the account is an admin), lapsed (the customer held `pro` once and it has expired) or never (no `pro` ever). Never lands on the paywall and stays there. Lapsed opens the app read-only: every screen carries a bar saying the plan has ended with a Subscribe button, and any edit or AI action opens the paywall instead of running. One write-access provider says whether writes are allowed, and every write controller checks it before writing. The server refuses AI calls for a lapsed account on its own. (mp-457)

- **The server check on every AI function.** Every function that calls a model checks the subscription at the top through the shared check the Vana functions use today: `describe-meal`, `analyze-meal-photo`, `meal-photo`, `ai-coach` and `jade-chat`, alongside `vana-chat`, `vana-action`, `vana-day-notes` and `kroger`. A lapsed account holding bought budget is refused like any other. (mp-429)

- **Codes.** A `codes` table holds each code with its type (coach, influencer or giveaway), its owner, its validity window and its perk. A `redeem-code` function takes a code from a signed-in caller. The owner of a coach code entering it marks their account as a coach and gets 30 days of `pro`. An athlete entering a coach or influencer code gets `coach_code` or `influencer_code` set as a subscriber attribute and a pending pairing with the coach through the existing pairing path. A giveaway code grants 365 days of `pro` once. A wrong, expired or used code gets a plain reason back. The entry is Redeem code in the paywall's ⋯ menu and on the Subscription screen. The existing 24-hour pairing codes stay as they are. (mp-458, mp-494, mp-495)

- **Onboarding without an anonymous session.** The welcome screen no longer starts an anonymous session. Onboarding answers are held on the phone until the account exists and are written to it then. The anonymous-session code in auth, onboarding and settings is archived, except the link for old installs in the grace paragraph above. (mp-459)

- **What ships when.** The build for the 25 September store submission carries the new products, the Current Offering paywall with founding styling, the day-five reminder, the webhook fix and the server check on every AI function. The grace script runs on 1 October. Read-only lapsed mode, codes and onboarding without an anonymous session follow in an update before 8 October, when the first trial can end; until then a lapsed account meets the paywall as it does today. If time runs short, cut from the bottom of that list, never the store build. (mp-460)

- **The Bevel layout in the store build.** The store build also carries the new paywall layout and the Subscription screen. Until the update, a lapsed account meets the paywall full screen; the closable sheet arrives with read-only mode. Redeem code appears in the ⋯ menu and on the Subscription screen only once codes ship. If time runs short, the Subscription screen moves to the update first. (mp-496)

## Testing Decisions

A good test here drives the behaviour a person or a store would see through the highest seam that exists: fake RevenueCat events and fake REST answers in, the row or the answer out; a fake store and a fake notification scheduler in, the gate state and the scheduled reminder out. No test reaches into how a controller stores its fields.

- **The server seam.** The webhook, `redeem-code` and the grace claim are tested through their real handlers with fake RevenueCat events, a fake RevenueCat REST client and a fake database, the way the webhook's tests feed fake events today. The cases: a promotional grant opens the row; a trial started during grace keeps the grace end; a lapsed trial leaves a live grant open; each code type, and each refusal; the grace claim grants once and only for an account that predates the flip. The grace script's selection is the same function the claim uses, tested there. (mp-461)

- **The client seam.** The gate and the paywall are tested through their real notifiers with a fake subscription service and a fake notification scheduler, the way the gate and paywall controller tests work today. The cases: open, lapsed and never from fake customer info; the founding offering shows both prices and the default offering one; a purchase that starts a trial schedules the reminder for the right time, and a trial that will not renew cancels it; a write while lapsed opens the paywall instead of writing. (mp-462)

- **The screen seam.** The paywall and the Subscription screen are tested as widget tests on the real screens with the same fake subscription service: the clip plays and hands over to the features with close and ⋯ appearing then; Reduce Motion skips it; the ⋯ menu lists exactly what each state allows; a never-subscribed account gets no close button; the Subscription screen shows trial, active, founding and ended. Goldens of both presentations and the Subscription screen, light and dark, replace the 09-15 paywall goldens. Each new `kyle_design` widget gets its own widget test in the library. (mp-497)

- **The stores, by hand.** The sandbox run on both stores stays the release gate and gains three steps: the founding offering is current and shows both prices; a hand-granted account opens the app and the server; a sandbox trial raises the day-five reminder on a device with its clock moved on. A person runs it; no CI job does. (mp-463)

Prior art: `test/features/subscription/application/pro_gate_test.dart`, `pro_paywall_controller_test.dart` and `subscription_status_provider_test.dart` for the client seam; `supabase/functions/revenuecat-webhook/index.test.ts` and `supabase/functions/tests/vana/entitlement.test.ts` for the server seam; `test/features/subscription/presentation/goldens/` and the widget tests beside `lib/shared/widgets/kyle_design/` for the screen seam; `scripts/sandbox-trial-wizard.sh` and `docs/release/sandbox-trial-runs/` for the store run.

## Out of Scope

- The monthly Vana budget, the top-up sheet and what it shows (mp-430, mp-342). That is the ai-cost spec.
- Coach-discount products (15% and 30% off, 14-day trial) and their targeting rules. Dormant until 1 December anyway; a later spec.
- The coach cron (re-grant while five athletes are active, +30 days on the first pairing) and the lapse-warning nudge. By hand in the RevenueCat dashboard through November (mp-429 clause 4).
- The webhook to Supabase events to Mixpanel pipeline and the rev-share query. Xuan's Phase 2; they can trail into early October.
- The heads-up email a week before the flip, and the reminder email. Xuan's side.
- Production deploys, the production migration order (open question mp-321) and how testers get in on a production build (open question mp-431).

## Further Notes

- Three things are Lee's or Xuan's, not an agent's: the RevenueCat support question on subscription groups (mp-429 clause 9), creating the products in both store consoles through the browser, and a RevenueCat secret API key for the webhook, the grace script and `redeem-code`.
- Apple gives one introductory offer per subscription group per person, so a lapsed seven-day trial cannot later get another trial in the same group. Copy never promises a second trial.
- A grant made from a sandbox build still arrives as a production event. The webhook must not filter by environment.
- Store submission is around 25 September; the paywall opens 1 October; the first trial can end 8 October; Founding Month closes 30 November.
