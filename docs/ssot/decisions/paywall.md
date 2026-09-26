# Decisions: Paywall

Feature: paywall
Feature name: Paywall

## mp-266 · Every new account gets a seven-day free trial, then pays
- category: Price and trial
- status: approved
- image: none
- screen: Paywall
- source: Lee on the page 2026-09-14; grill 2026-09-15
- folded: mp-052, mp-270, mp-279

**Context.** The app used to be freemium: a free tier with AI credits, and Pro for meal planning. Lee moved it to a trial model.

**Question.** What does a new account get before it pays?

**Decision.** Seven free days of the whole app, then it must buy. There is no free tier and no separate Pro tier. The App Store or Google Play runs the trial: the athlete subscribes with a card on file, pays nothing for seven days and is charged on day eight unless they cancel. Each person gets one trial, and meal planning does not ship until this model is live.

**Why.** Paying subscribers are the number the business runs on. Letting the store run the trial means the app keeps no trial clock of its own.

**What else was considered.** Keeping free and Pro tiers, or an app-run trial with no card up front.

> 2026-09-26 overhaul: rewritten from mp-266, mp-270, mp-279

## mp-429 · New signups pay $24.99 a month or $199.99 a year, with founding prices until 30 November
- category: Price and trial
- status: approved
- image: none
- screen: Paywall
- source: docs/revenuecat-spec-for-lee.md (Xuan, revised 2026-09-16); spec paywall 2026-09-21
- folded: mp-452, mp-453, mp-506, mp-655

**Context.** Xuan's RevenueCat spec sets the prices and a Founding Month offer for launch. Lee adopted it whole on 21 September.

**Question.** What does Pro cost?

**Decision.** $24.99 a month or $199.99 a year, each with the seven-day free trial. From 1 October to 30 November the founding prices are $12.49 a month and $99.99 a year. The paywall shows the founding price with the regular price struck through beside it, and the founding plans come off sale on 30 November. Discounted coach plans come later, in mid-October at the earliest. Outside the US each store charges its local equivalent.

**Why.** Xuan owns pricing and go-to-market. The founding prices reward the people who join first.

**What else was considered.** The old $9.99 monthly and $69.99 annual plans, which are no longer sold.

> 2026-09-26 overhaul: rewritten from mp-429, mp-452, mp-453, mp-506
> 2026-09-26 decided by Claude (Lee's delegation): store price tiers per territory, set in paywall ticket 05 (mp-655)

## mp-417 · Every athlete makes an account before choosing a plan
- category: Price and trial
- status: approved
- image: none
- screen: Paywall
- source: Lee in the terminal 2026-09-16; wave paywall 1 ticket 08
- folded: mp-459, mp-508, mp-509, mp-563, mp-667

**Context.** Onboarding used to let an athlete carry on as a guest with no account. A purchase is stored against an account, so a guest could not pay.

**Question.** How does onboarding end now that everyone pays?

**Decision.** Every athlete signs up, and the app has no guest mode. Onboarding answers stay on the phone until sign-up and then move to the new account. The account screen says what the trial costs, and straight after sign-up the athlete lands on the paywall. When email confirmation is on, the 6-digit code is asked first and the grace month is claimed after it, on the same account.

**Why.** The purchase belongs to an account, so the account has to exist first. Telling the athlete the price before sign-up makes the paywall read as the next step rather than a wall.

**What else was considered.** Choosing a plan before making an account; keeping the guest path.

> 2026-09-26 overhaul: rewritten from mp-417, mp-459, mp-508, mp-509
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code; turning email confirmation on for prod is a separate setting, left as it is (mp-667)

## mp-528 · Two days before the trial ends, the phone reminds the athlete
- category: Price and trial
- status: approved
- image: none
- screen: none (a notification)
- source: spec paywall 2026-09-21; wave paywall 2 ticket 04; Lee in the terminal 2026-09-22
- folded: mp-456, mp-540

**Context.** Xuan's spec asks for a reminder before the free week turns into a charge.

**Question.** How does the athlete hear that the trial is about to end?

**Decision.** At 10:00 two days before the trial ends, the phone shows a notification. It gives the price the athlete will pay and says they can cancel any time, and tapping it opens the page where they manage the subscription. If the trial will not renew, the reminder is cancelled. An athlete who has notifications turned off gets one line after starting the trial asking them to turn them on.

**Why.** An athlete should never be charged by surprise, and an honest reminder builds trust.

**What else was considered.** A banner inside the app on day five.

> 2026-09-26 overhaul: rewritten from mp-528, mp-456, mp-540

## mp-530 · Existing users get one free month and a founding-member mark
- category: Existing users
- status: approved
- image: none
- screen: none (a script Lee runs when the paywall goes live)
- source: spec paywall 2026-09-21; wave paywall 2 ticket 06; Lee in the terminal 2026-09-22
- folded: mp-283, mp-455, mp-541, mp-542

**Context.** People were using the app for free before the paywall. Xuan's spec gives them a grace period.

**Question.** What do accounts made before the paywall get?

**Decision.** Every account that exists when the paywall is switched on gets 30 days of Pro free and is marked as a founding member. That includes paying subscribers and the team's own accounts. The switch-on moment is when Lee actually turns the paywall on, planned for 1 October. Users hear about it by email a week before. Anyone whose free access already runs past those 30 days keeps it and only gets the mark.

**Why.** It thanks early users and avoids locking them out on day one.

**What else was considered.** No grace period for existing accounts; leaving out the team's own accounts.

> 2026-09-26 overhaul: rewritten from mp-530, mp-455, mp-541, mp-542

## mp-555 · Someone who used the app without an account signs up to get their free month
- category: Existing users
- status: approved
- image: none
- screen: Account screen
- source: wave paywall 3 ticket 09
- folded: mp-554, mp-561

**Context.** Before the paywall the app could be used without an account. Those installs cannot buy anything until they have one.

**Question.** What happens to someone who used the app before the paywall without an account?

**Decision.** When they open the new version, they go straight to sign-up and cannot skip it. Signing up keeps everything they had entered and gives them the same free month as existing users. Signing in to a different, existing account does not give a second month. If the claim fails, the app tries again at the next start.

**Why.** A purchase needs an account, and these users should get the same thank-you as everyone else who came before the paywall.

**What else was considered.** Giving the month to any account made before the switch-on.

> 2026-09-26 overhaul: rewritten from mp-555, mp-554
> 2026-09-26 decided by Claude (Lee's delegation): retry a failed grace claim at startup, so no pre-paywall user loses the promised month (mp-530); needs building (mp-561)

## mp-280 · When Pro ends, the athlete sees the paywall and stays signed in
- category: When Pro ends
- status: approved
- folded: mp-614, mp-616
- image: none
- screen: Paywall
- source: grill 2026-09-15; Lee in the terminal 2026-09-23

**Context.** Until 23 September an account whose Pro had ended could see its data read-only under a paywall it could close. Lee ruled that too much work for what it gives.

**Question.** What does an account without Pro see?

**Decision.** The same full-screen paywall a new account sees, with no close button, and the account stays signed in. Nothing in the app opens until they subscribe, restore a purchase or redeem a code. Their data is kept and all of it is back the moment Pro returns. Every way into the paywall replaces the whole app, so there is no swiping back.

**Why.** One paywall for everyone without Pro keeps things simple. Staying signed in means Restore or a new purchase lands on the right account.

**What else was considered.** Read-only access under a paywall that can be closed; signing the account out.

> 2026-09-26 overhaul: rewritten from mp-280
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-614); no separate ended state on the Subscription screen (mp-616)

## mp-505 · Without Pro, every AI feature is refused
- category: When Pro ends
- status: approved
- folded: mp-654
- image: none
- screen: none (algorithm/data)
- source: spec paywall 2026-09-21; wave paywall 1 ticket 02

**Context.** A lapsed account holding leftover bought credits could still describe a meal, analyse a photo or get a coach insight.

**Question.** Which AI features work without Pro?

**Decision.** None. Vana, meal description, meal photos and the coach insight all refuse an account without Pro, even one with bought budget left. The check happens on our server before anything is spent. The app also checks first and opens the paywall at once, so it works offline.

**Why.** Pro is what pays for AI. Refusing before any work starts means an unpaid call costs us nothing.

**What else was considered.** Letting features that cost us nothing through.

> 2026-09-26 overhaul: rewritten from mp-505 and mp-429 clause 11
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-654)

## mp-609 · RevenueCat alone decides who has Pro
- category: When Pro ends
- status: approved
- image: none
- screen: none (algorithm/data)
- source: grill 2026-09-15; wave mealplanning 2 ticket 19; Lee in the terminal 2026-09-23 and 2026-09-25
- folded: mp-284, mp-285, mp-317, mp-335, mp-454, mp-503, mp-679, mp-684, mp-686

**Context.** Access used to depend on several flags and tester shortcuts in the app and on the server.

**Question.** Where does the answer to "has this person paid?" come from?

**Decision.** From RevenueCat, the service that handles purchases for both stores. The app and the server keep only a copy of its answer and never grant access themselves. The phone's saved copy lets a subscriber in offline, but a phone with no answer at all counts as locked until the network returns. A saved copy stays valid for 15 minutes past its expiry, so a slightly late renewal does not lock anyone out. The 15 minutes apply only to a subscription set to renew; cancelled plans, trials that won't convert and grants end on time.

**Why.** One source of truth means the app and the server can never disagree about who paid.

**What else was considered.** Keeping tester switches and an app-side trial clock; letting the app in while the answer is unknown.

> 2026-09-26 overhaul: rewritten from mp-609, mp-284, mp-335, mp-679
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-684)

## mp-416 · The team's admin accounts skip the paywall screen
- category: When Pro ends
- status: approved
- image: none
- screen: Paywall
- source: Lee in the terminal 2026-09-16

**Context.** Once RevenueCat became the only gate, the team's own test accounts met the paywall on every device.

**Question.** Does a team admin account see the paywall?

**Decision.** No. An account the team marks as admin by hand goes straight into the app. There is no other exception: no build switch and no tester shortcut. The server still refuses admins the AI features unless they have a subscription or a granted month.

**Why.** Lee: admin accounts must be able to use the app like normal. Marking them by hand keeps the exception to accounts the team names.

**What else was considered.** A dev-only bypass switch in the build.

> 2026-09-26 overhaul: rewritten from mp-416

## mp-535 · Coaches get in free through their own code
- category: Coach codes and restore
- status: approved
- image: none
- screen: none (algorithm/data)
- source: docs/revenuecat-spec-for-lee.md (Xuan); wave paywall 2 ticket 07
- folded: mp-286, mp-458

**Context.** Xuan's spec sets how coaches get access, replacing the earlier rule that coaches pay like everyone else.

**Question.** How does a coach get Pro?

**Decision.** A coach enters their own coach code and gets 30 days of Pro at once, so they never see the paywall. They get another 30 days when their first athlete pairs, then Pro stays free while five of their athletes are active. An athlete who enters a coach's code is paired with that coach. Through November the later grants are done by hand in RevenueCat.

**Why.** Coaches bring athletes. Their access should never block that.

**What else was considered.** Coaches paying like everyone else.

> 2026-09-26 overhaul: rewritten from mp-535 and mp-429 clause 4

## mp-598 · Codes are our own, redeemed in the app, once per account
- category: Coach codes and restore
- status: approved
- image: docs/ssot/decisions/images/mealplanning/subscription.png
- screen: Subscription screen
- source: spec paywall 2026-09-21; wave paywall 2 ticket 07; wave paywall 6 ticket 18; Lee in the terminal 2026-09-22
- folded: mp-544, mp-599, mp-600, mp-601, mp-660, mp-685

**Context.** Apple and Google offer their own promo codes, but they cannot pair a coach or record who referred an athlete.

**Question.** How do promo codes work?

**Decision.** We keep our own codes: coach codes, influencer codes (which record who referred the athlete) and giveaway codes (a year of Pro). Each code works once per account, and a giveaway code works once in total. Codes are entered from Redeem code, which is on the paywall's ⋯ menu and on the Subscription screen at every stage of a plan. A refused code shows a plain reason so the athlete can fix a typo, and a code is never used up if something fails on our side. A code stays used even after the account that redeemed it is deleted, and a redeemed code updates the app at once, including a coach pairing.

**Why.** Our codes work on both platforms, for lapsed athletes too, and they tell us who came from a coach, an influencer or a giveaway.

**What else was considered.** Apple's and Google's offer codes.

> 2026-09-26 overhaul: rewritten from mp-598, mp-599, mp-544, mp-458
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-685, mp-660: a repeat code from the same coach is refused with a plain reason); pairing refresh needs building (mp-600)

## mp-494 · Restore, Redeem code, Manage, Sign out and Delete account sit in one ⋯ menu
- category: Coach codes and restore
- status: approved
- folded: mp-689
- image: docs/ssot/decisions/images/mealplanning/bevel-paywall-menu.png
- screen: Paywall
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21

**Context.** The old paywall stacked these as text buttons under the prices. Bevel puts them all behind one menu.

**Question.** Where do the paywall's secondary actions go?

**Decision.** Into one ⋯ menu in the paywall's top corner: Restore purchases, Redeem code, Manage subscription, Sign out and Delete account. Every paywall has the same menu, so a new account can also sign out or delete itself. Manage subscription appears only when the account has a store subscription to manage. Delete account warns that a store subscription keeps renewing until it is cancelled in the store.

**Why.** The screen stays clean with one button to press. Apple wants account deletion easy to find, and a labelled menu meets that.

**What else was considered.** Keeping Sign out and Delete account as visible buttons.

> 2026-09-26 overhaul: rewritten from mp-494
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-689)

## mp-493 · The paywall follows Bevel's layout in our branding and opens on a clip of the app
- category: The paywall screen
- status: approved
- image: docs/ssot/decisions/images/mealplanning/bevel-paywall-hero.png
- screen: Paywall
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21; wave paywall 2 ticket 14; wave paywall 3 ticket 15
- folded: mp-537, mp-559, mp-566

**Context.** Xuan liked the Bevel app's paywall and asked for something like it. Ours was a price list with a stack of buttons.

**Question.** What does the paywall look like?

**Decision.** Bevel's layout in our colours, type and copy. It opens on a silent four-second clip of our own app, which a tap skips, then slides over to the features. Two plan cards, annual on top and already selected with its saving shown, sit pinned above one Continue button the whole time. They stay stacked on small phones too.

**Why.** Showing the product sells it. The price never scrolls away, and there is only one button to press.

**What else was considered.** Restyling the old price list; side-by-side plan cards.

> 2026-09-26 overhaul: rewritten from mp-493, mp-537, mp-559
> 2026-09-26 decided by Claude (Lee's delegation): recorded as built, checked in code (mp-566)

## mp-538 · The paywall leads with four reasons to pay
- category: The paywall screen
- status: approved
- image: none
- screen: Paywall
- source: wave paywall 2 ticket 14

**Context.** Apple reviews the paywall, so what it lists is a product decision.

**Question.** Which features does the paywall list?

**Decision.** Four headlines: a fuel plan for every session, Vana as your nutrition coach, shopping lists from your plan, and your training already synced from Garmin, TrainingPeaks and FinalSurge. Under "also includes" come recipes with cooking mode, brick workouts, hydration checks, your own fuel formulas and daily targets. All the AI features sit under the one Vana line. Kroger delivery is not listed, because it does not reach every athlete.

**Why.** The headlines are the reasons to pay, and grouping the AI under Vana gives one clear reason instead of four.

**What else was considered.** Listing Kroger; a separate line for each AI feature.

> 2026-09-26 overhaul: rewritten from mp-538

## mp-495 · Settings has a Subscription screen showing the plan and what Pro includes
- category: The paywall screen
- status: approved
- image: docs/ssot/decisions/images/mealplanning/subscription.png
- screen: Settings > Subscription
- source: docs/research/paywall-bevel-teardown.md; Lee in the terminal 2026-09-21 and 2026-09-23; wave paywall 4 ticket 16
- folded: mp-558, mp-580, mp-581, mp-615, mp-617, mp-618, mp-619

**Context.** Before the paywall, an athlete had nowhere in the app to see their plan.

**Question.** Where does an athlete see and manage their plan?

**Decision.** Subscription is the first row in Settings. Its screen shows one status (on trial, founding member or active), with the date the trial ends, the plan renews or it stops. It lists what Pro includes. Free access that someone granted shows where it came from, such as the grace month, a code or a coach, and how many days are left. Manage subscription appears only for a real store subscription. The server stores where each grant came from (grace month, a code, or a coach's own code), so the screen never guesses from its length.

**Why.** An athlete should be able to check their plan without a trip to the App Store.

**What else was considered.** A bare "Have a code?" row in Settings.

> 2026-09-26 overhaul: rewritten from mp-495, mp-558, mp-580, mp-581
> 2026-09-26 decided by Claude (Lee's delegation): store the grant's source on the server; today a coach's 30-day code shows as "Grace month"; needs building (mp-615)
