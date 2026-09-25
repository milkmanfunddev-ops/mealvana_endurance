# AI metering market survey

Researched 2026-09-20 for the 2026-10-01 subscription launch. Companion to `vana-cost-and-pricing.md`, which holds the app's own cost numbers. This file covers what other companies do.

How to read the sourcing. Five research agents gathered the sources on 2026-09-20, and every access date is that day unless a publication date is given. "Verified" means an agent opened the page. The fetch tool reads a page through a small summarising model, so check any quoted figure against the original before it goes into a spec. UNVERIFIED means the claim came from a search snippet, a secondary site, or a page that refused the fetch. The help centres of OpenAI, Midjourney, Replika, Canva, Perplexity, Poe, WHOOP, MyFitnessPal and Foodvisor all returned 403. "Inferred" marks my own reasoning.

## Conclusions

### Is 600 credits, visible only when empty, with top-ups, in line with the market

Yes on the number and the visibility. The top-ups are new for this category.

1. No fitness, nutrition or wearable app in the survey publishes an AI cap for paying subscribers. Every published cap sits on a free tier, such as SnapCalorie's 3 AI logs a day. Paid tiers say "unlimited" or say nothing. A paid plan with a stated number is therefore stricter on paper than every direct competitor, even if nobody reaches it.
2. Outside fitness, the products closest to Vana in shape fall into two groups. One group runs a hidden budget with a soft landing (ChatGPT, Gemini, Cursor, Midjourney). The other runs visible credits with a hard stop and top-ups (Lovable, Suno, ElevenLabs, Poe, the new GitHub Copilot). Vana's design is the first group's visibility with the second group's cap behaviour. That is a defensible mix for launch, because the soft landing needs a cheaper model that has not passed an eval yet.
3. The number holds up. Grammarly Pro gives 2,000 prompts a month and Premium 1,000, but a Grammarly prompt is a short rewrite. 600 actions is 20 a day. The cost file's heavy athlete needs 494. The typical athlete uses a third of the allowance.
4. No wellness app sells AI credits or top-ups. There is no published consumer reaction either way. RevenueCat's data says hybrid buyers are 7 percent of buyers and 25 percent of revenue across all apps, and that among AI apps the best retainers lean subscription-only. Keep the packs, expect little revenue from them, and treat them as the way out for the rare athlete who runs dry, not as a business line.
5. Pack pricing is normal. The plan's implied rate is $24.99 / 600 = 4.2 cents per credit. The packs cost 10 cents and 8 cents per credit. Lovable charges 30 cents per top-up credit against 25 cents in plan. Copilot charged 4 cents per extra request. A top-up at about twice the plan rate matches the market.

### Cap behaviour

1. Never stop an athlete in the middle of a plan build. Let the conversation that crosses zero finish, then stop. Cursor gives a short grace period at its cap. Lovable pauses the message and resumes after a top-up. Inferred: a plan build is one opener plus 3 to 5 turns, so the grace costs at most about 15 cents.
2. Warn before empty. Show the balance once it falls below about 20 percent, with the reset date. Metronome's review of credit systems says real-time alerts are the one mitigation customers ask for, and the dated backlash in this survey is about surprises, not about published numbers.
3. At empty, show three things: the reset date, the two packs, and what still works without credits, such as manual logging and the existing plan.
4. Move to a soft landing when a cheap model passes the Vana eval. Gemini continues on Flash-Lite. ChatGPT continues on a mini model. Midjourney drops to a slower queue. General chat continues on the cheap model and planning stops, which is option 4(b) in the cost file. One caution: ChatGPT users read the fallback as "the model got worse", and GitHub removed its fallback in June 2026. Tell the athlete when the fallback is active.
5. Take the token pill off the meal-logging screens while the balance is above the warning line. Lambrecht and Skiera (2006) found that watching a meter run lowers enjoyment of the thing metered. Duolingo's Energy system charges per exercise and drew a quit-the-app backlash in 2025. Logging is the daily habit. A counter beside it charges attention for the habit the app most wants. I found no wellness-specific study, so this rests on the general research and the Duolingo case.

### Trial shape

1. Keep the seven-day card-required trial. RevenueCat's 2026 AI retention study found high-retaining AI apps were 12.7 points more likely to use a seven-day trial, and "no trial" was 23.7 points more common among low retainers. Trials of 5 to 9 days convert at a 37.4 percent median. Health and Fitness converts at 37.7 percent.
2. Correct one number in the cost file. The "55 percent of trial cancellations on Day 0" figure belongs to three-day trials. For a seven-day trial it is 39.8 percent on Day 0 and about 64 percent within 24 hours. Most cancel within two hours. A cancelled trial keeps its entitlement for the full week, so anyone who cancels can still spend the whole trial grant.
3. Grant 150 credits for the trial week, as the cost file proposes. Inferred from its profiles: the heavy athlete uses about 114 credits a week, so 150 never runs a real trialist dry. Adapty sees a second conversion peak on days 4 to 7 in Health and Fitness because people "want to see results before committing". An empty wallet on day 5 would land on that peak. 150 avoids it.
4. Limit volume in the trial, not features. RevenueCat's guidance for AI apps is "controlled exposure": a starting allowance in place of an unlimited trial, with every feature available. I found no controlled experiment on whether a trial cap hurts conversion. Nobody has published one.
5. Keep the daily ceilings from the cost file as the script guard (40 openers, 150 turns). Midjourney ended free trials in 2023 over throwaway accounts. On iOS a repeat trial needs a new Apple ID, because Apple allows one introductory offer per subscription group per Apple ID. That bounds abuse better than any web product can. Add App Attest or DeviceCheck only if October data shows repeat trials.
6. Leave Family Sharing off for the subscription. Apple allows up to six people on a shared subscription, and each would draw an allowance.

### AI cost target

Adopt 15 percent of net revenue blended, an alarm at 20 percent, and no single athlete above 50 percent of their own net revenue.

1. RevenueCat's published rule for subscription apps is that AI cost near 3 percent of revenue per user is fine, 17 percent is a "structural margin problem", and above 20 percent is a concern.
2. Duolingo is the best public consumer comparison. AI cost it 60 basis points of gross margin in FY25 (72.8 to 72.2 percent), and it guides to about 70 percent for FY26 as AI reaches more users. Management over-guided the drag every quarter of 2025 because unit costs fell faster than planned. Video Call went from about 30 cents to under 1 cent a call.
3. Investors accept 50 to 60 percent gross margin for AI-first products. A $24.99 consumer app with store fees already taken out should hold 65 to 75 percent, which leaves the same 15 to 20 percent the cost file reached.
4. In dollars: 15 percent of net is $3.19 on the monthly plan, $2.13 on annual, $1.59 on founding monthly and $1.06 on founding annual. Today's blended $2.38 fits only the full-price plans. After the caching fix, the estimated $1.36 fits everything except founding annual, which sits at 19 percent. RevenueCat reports 68 percent of Health and Fitness revenue on annual plans, so founding annual is the plan to watch.
5. Do not tighten the cap to fix margin. Fixed-shape AI tasks got much cheaper everywhere in the survey (Duolingo 30x, Character.AI 33x, Notion 3x, WHOOP 85 percent). The products that had to reprice were open-ended agent tools on flat plans (Copilot, Cursor, Claude Code, Replit). Vana's turns are bounded by step limits, which puts it in the first group.

### Three things to copy

1. WHOOP's prompt work. WHOOP Coach is the closest product to Vana. In April 2026 WHOOP described a template language that renders only the context a question needs. It cut prompt tokens by almost 80 percent, raised cache hits 3.5 times, and cut agent cost about 85 percent, while positive ratings rose 5 percent. Character.AI reports a 95 percent cache rate from truncating history at fixed points so the prefix stays stable. Both support levers 1 and 2 in the cost file and suggest the saving could exceed its 40 percent estimate.
2. A soft landing at the cap, as Gemini, ChatGPT, Cursor and Midjourney do, once a cheap model passes the eval.
3. Fixed-shape, precomputed output for the high-volume moments. Strava writes one summary per activity and has no chat. Duolingo generates the first question of a Video Call while the call is ringing and carries a short list of facts between calls, not the transcript. Instacart answers 98 percent of queries from an offline cache. For Vana that means openers built from data fetched before the call, in one step, and a facts list in place of long history.

### Three things to avoid

1. Changing limits without notice. Perplexity cut Deep Research from about 500 a day to 20 a month with one changelog line, and annual subscribers said they had been misled. Anthropic tightened Claude Code limits without notice in July 2025 and drew the same press. Publish the allowance in the help centre, and only ever raise it for existing subscribers.
2. A unit whose cost the user cannot know before acting. Replit's effort-based pricing produced "I blew through $70 in a night". Cursor apologised and refunded three weeks of charges after moving from 500 requests to a dollar pool. Keep one credit per action. Do not adopt cost-weighted credits.
3. The word "unlimited". Cursor, Copilot, Claude and Cal AI's "Unlimited Plan" all use or used it, and the first three had to take it back in public. Say "600 AI actions a month, about 20 a day". Also avoid the Garmin Connect+ position, where the AI is the only thing the subscription adds. That drew a 10,000-upvote boycott thread. The paywall copy should sell plans and fuelling numbers, with Vana as the way to get them.

## Comparison table

Prices are USD and list. "None published" means a first-party page was read and said nothing.

| Product | Price | Limit visible | Unit | At the cap | Top-ups | Backlash on limits |
|---|---|---|---|---|---|---|
| Cal AI | about $9.99 a month or $29.99 a year, varies by test cohort, UNVERIFIED | Paid: none published, plans named "Unlimited". Free: gate at the scan | photo scans | hard paywall | none. Only consumable is a $0.99 streak restore | trial auto-charge complaints. Apple pulled the app for two days in April 2026 over a checkout design |
| SnapCalorie | about $59 a year, UNVERIFIED | Free: yes, "3 AI logs per day". Paid: none | AI logs a day | upsell to Premium | none | none found |
| MacroFactor | $11.99 a month, $71.99 a year, UNVERIFIED | none published | none | n/a | none | none found |
| MyFitnessPal Premium+ | $24.99 a month, $99.99 a year | none published | none | free users hit the Premium gate | none | paywall creep in general. A May 2026 report of free scans going 5 to 0 is low trust |
| Lose It | $39.99 a year on the App Store listing | none published | none | free users gated | none | price rise, third-party only |
| Noom | about $70 a month, $209 a year, UNVERIFIED | none published | none | n/a | none | none on AI |
| Fuelin | $29 a month, $139 a year. With dietitian $99 and $399 | none published | none | n/a | none. Higher tier sells humans | none on limits |
| Hexis | EUR 24.99 a month, EUR 129.99 a year | no AI chat or AI logging named | n/a | n/a | none | none |
| WHOOP Coach | $199 to $359 a year, Coach in every tier | none published. Reports of a daily cap could not be confirmed either way | unknown | unknown | none for AI | quality complaints, none on limits |
| Strava Athlete Intelligence | $11.99 a month, $79.99 a year | no limit. One summary per activity, no chat | n/a | n/a | none | called "pointless" in 2024. About value, not limits |
| Oura Advisor | $5.99 a month, $69.99 a year | none published | none | n/a | none | none found |
| Garmin Connect+ | $6.99 a month, $69.99 a year | no limit. Pushed insights | n/a | n/a | none | severe, about paying again after hardware |
| TrainingPeaks | $19.95 a month, $134.99 a year | no AI features on the pricing page | n/a | n/a | n/a | n/a |
| Runna | $19.99 a month, $119.99 a year | none published | none | n/a | none | plan quality, not limits |
| Zing Coach | about $20 a month, $59.99 a year, UNVERIFIED | none published | none | n/a | none | not researched |
| Fitbod | $15.99 a month, $95.99 a year | none. Algorithmic, no chat | n/a | n/a | none | none |
| Alma | $19 a month, $199 a year | none published | none | n/a | none | none found |
| Duolingo Max | $29.99 a month, $168 a year, UNVERIFIED | no cap found on Video Call or Roleplay. Free tier Energy is visible | energy units on free | free: wait, watch ads, spend gems, or subscribe | gems | Energy drew quit-the-app pieces in 2025 |
| Notion AI | bundled in Business, about $20 a seat | hidden rolling six-hour and monthly allowance | none published | temporary pause, or admin enables paid credits | credits at provider rates, no markup | one team burned about $1,500 of agent credits in a month, UNVERIFIED |
| Grammarly | Pro about $12 to $30 a month | yes, counter in the app | prompts a month: Free 100, Premium 1,000, Pro 2,000 | hard stop, "You're out of prompts" | none | none found |
| Perplexity Pro | $20 a month, Max $200 | hidden. Users found the numbers at an internal endpoint | searches per day, week or month by feature | blocked until reset, upsell to Max | none | strong in Feb 2026 after silent cuts, UNVERIFIED first-party |
| Poe | $4.99 to $249.99 a month, UNVERIFIED. Annual $49.99 to $2,499.99 verified | yes | compute points, price set per bot | stop, buy more | yes, price in app | not researched |
| Character.AI | c.ai+ $9.99 a month, UNVERIFIED | free: caps on regenerations, reported March 2026 | queue priority, swipes | waiting room or slower replies | in-app currency extends free caps, UNVERIFIED | under-18 chat removal in late 2025 |
| Replika | Pro $19.99, Ultra $29.99 a month, UNVERIFIED | weekly caps inside Platinum, UNVERIFIED | uses per week by feature | stop | gems and coins are cosmetic | not researched |
| Canva | Pro about $15 a month | pooled monthly allowance by tier, UNVERIFIED | AI uses: Pro 2,000 standard, 200 premium | stop until reset | none found | 2024 Teams price rise, $119.99 to $500 a year, justified by AI features |
| Cursor | Pro $20 a month | partly. Dollar pool of model usage | dollars at API rates | grace, then the Auto model or pay at cost | pay at cost with a spend limit | July 2025 apology and refunds after the unit change |
| GitHub Copilot | Pro $10, Pro+ $39 a month | yes | until June 2026, 300 or 1,500 premium requests. Now token credits, $10 or $39 included | before: fall back to an included model. Now: stop, fallback removed | $0.04 a request before. Now credits at API rates | "You will get less, but pay the same price", April 2026 |
| Lovable | Pro about $25 a month, UNVERIFIED | yes | credits, 0.5 to 2 per message | message pauses until credits arrive | $15 per 50 on Pro. Plan credits roll over | cost per message varies |
| Suno | Pro $8, Premier $24 a month | yes | credits | stop | yes, never expire, need an active plan | none found |
| ElevenLabs | $6 to $99 a month | yes | one credit per character | stop or overage | rollover up to two months | none found |
| Midjourney | $10 to $120 a month, UNVERIFIED | yes | fast GPU hours | unlimited slow queue on $30 and up | $4 an hour, never expire | trial abuse ended free trials in 2023 |
| ChatGPT Plus | $20 a month | hidden message caps per window, UNVERIFIED | messages per 3 hours | switches to a mini model | none | users read the fallback as a worse model |
| Claude Pro and Max | $20, $100, $200 a month | usage meter shown, no published number | five-hour sessions plus weekly limit | stop until reset, or pay API rates | extra usage at API rates with a spend cap | July 2025 silent tightening. March 2026 "maxed out every Monday" |
| Gemini | AI Pro $19.99 a month, UNVERIFIED | multipliers only, no numbers | compute per five hours and per week | continues on Flash-Lite | pay-as-you-go credits announced May 2026 | none found |
| Flo, Headspace Ebb, Wysa, Snapchat My AI | bundled or free | none published | none | n/a | none | none |

## 1. How apps meter AI and what happens at the limit

### Fitness, nutrition and wearables

No paying subscriber in this group sees a number. The details below add to the brief survey in the cost file.

Cal AI. The App Store lists in-app purchases named "Unlimited" at $2.99, $5.99, $9.99, $19.99 and $29.99, plus a $0.99 "Streak Restore" ([App Store](https://apps.apple.com/us/app/cal-ai-calorie-tracker/id6480417616)). Superwall's case study says Cal AI ran 123 paywall experiments and places the paywall at 46 trigger points including the camera scan, and that trial-to-paid conversion improved 31 percent over 12 months ([Superwall](https://superwall.com/case-studies/cal-ai)). A three-day card-required trial is reported by third parties, UNVERIFIED. Apple removed the app on 2026-04-15 and restored it by 04-17 after a post showed a Stripe checkout styled like Apple's payment sheet ([PiunikaWeb, 2026-04-16](https://piunikaweb.com/2026/04/16/cal-ai-removed-from-app-store-viral-payment-sheet-post/)). MyFitnessPal acquired Cal AI in March 2026 ([TechCrunch, 2026-03-02](https://techcrunch.com/2026/03/02/myfitnesspal-has-acquired-cal-ai-the-viral-calorie-app-built-by-teens/)).

SnapCalorie. "SnapCalorie is FREE for up to 3 AI logs per day!" ([FAQ](https://www.snapcalorie.com/faq.html)). This is the clearest published AI cap in nutrition, and it is on the free tier.

MacroFactor. The AI logging help article has no wording on limits or fair use ([help](https://help.macrofactorapp.com/en/articles/258-ai-food-logging)). No free tier.

MyFitnessPal. Premium+ is $24.99 a month or $99.99 a year. Premium is $79.99 a year. Meal Scan and voice logging are in both paid tiers, and the meal planner is Premium+ only ([pricing](https://www.myfitnesspal.com/premium)). No subscriber limit is published. Consumer Tech Wire reported on 2026-05-01 that free Meal Scan went from 5 a day to zero and the iOS rating fell from 4.6 to 4.2 ([article](https://consumertechwire.com/news/myfitnesspal-paywall-expansion-may-2026/)). Low trust, UNVERIFIED.

Lose It, Noom, Lifesum, Foodvisor, January AI, Alma. Nothing published on limits. AI logging is a paid feature in each. Sources: [Lose It listing](https://apps.apple.com/us/app/lose-it-calorie-counter/id297368629), [Noom press release, 2024-06-27](https://www.noom.com/in-the-news/noom-introduces-ai-enabled-products-to-enhance-on-demand-health-care-and-interactive-coaching-2/), [Lifesum release](https://lifesum.com/page/lifesum-transforms-meal-tracking-with-world-first-ai-powered-multimodal-tracker), [January AI listing](https://apps.apple.com/us/app/january-ai-health-tracker/id6470235391), [Alma, TechCrunch 2025-02-05](https://techcrunch.com/2025/02/05/former-whoop-execs-new-app-alma-uses-ai-for-all-things-nutrition).

Fuelin. Autopilot $29 a month or $139 a year. Copilot with dietitian access $99 a month or $399 a year ([App Store](https://apps.apple.com/us/app/fuelin-performance-nutrition/id1579806995)). The "AI Food Logger" is included with no stated limit. The upsell is a human.

Hexis. EUR 24.99 a month or EUR 129.99 a year. The athlete page names no AI chat or AI logging ([Hexis](https://hexis.live/athlete-app)).

WHOOP. Coach is in every tier from $199 a year ([Engadget](https://www.engadget.com/2242774/most-expensive-whoop-membership-life-why-pay/)). It is "powered by OpenAI" ([WHOOP](https://www.whoop.com/us/en/thelocker/whoop-unveils-the-new-whoop-coach-powered-by-openai/)). Three searches and the WHOOP community forum produced no "limit reached" thread, and the help page returned 403, so a hidden daily cap is UNVERIFIED in both directions. WHOOP's only pay-per-use product is lab tests, $199 to $899 ([Android Authority](https://www.androidauthority.com/whoop-drops-membership-for-advanced-labs-3699949/)).

Strava. $11.99 a month or $79.99 a year. Athlete Intelligence is one generated summary per activity with an opt-out ([support](https://support.strava.com/en-us/articles/15401629-athlete-intelligence-on-strava)). Fortune quoted users calling it "kind of pointless" ([Fortune, 2024-10-11](https://fortune.com/2024/10/11/strava-app-artificial-intelligence-fitness-athletic-memes)).

Oura Advisor. $5.99 a month or $69.99 a year, no cap wording ([membership](https://support.ouraring.com/hc/en-us/articles/4409086524819-Oura-Membership), [Advisor](https://support.ouraring.com/hc/en-us/articles/39512345699219-Oura-Advisor)).

Garmin Connect+. $6.99 a month or $69.99 a year, launched 2025-03-27 ([DC Rainmaker](https://www.dcrainmaker.com/2025/03/garmin-connect-plus-subscription-walkthrough.html)). A boycott post reached 10,000 upvotes ([gHacks, 2025-03-31](https://www.ghacks.net/2025/03/31/garmins-new-subscription-service-sparks-backlash-from-users/)). TechRadar called the AI "hilariously bad" ([TechRadar](https://www.techradar.com/health-fitness/smartwatches/garmins-new-subscription-ai-feature-is-hilariously-bad-so-far)). The complaint was paying again after hardware for a thin feature.

TrainingPeaks, Runna, Zing, Fitbod. [TrainingPeaks pricing](https://www.trainingpeaks.com/pricing/for-athletes/) names no AI. [Runna](https://www.runna.com/pricing) is $19.99 a month or $119.99 a year with a seven-day trial. [Fitbod](https://fitbod.me/faqs/) is $15.99 a month or $95.99 a year. Zing is about $20 a month ([TechRadar](https://www.techradar.com/health-fitness/zing-coach-is-an-app-that-reveals-the-true-power-of-ai-training)). None publishes a limit.

Future. On 2026-06-19 Future dropped its AI trainer beta before pricing it, to "double down on what we do best", meaning human coaches ([Athletech News](https://athletechnews.com/future-pulls-the-plug-on-ai-personal-training-commits-to-human-coaches/)).

Price bands. Mass-market calorie apps run $30 to $100 a year. AI nutrition coaching runs $139 to $199 a year (Fuelin Autopilot, Alma). Endurance products with human or deep planning run $130 to $400 a year. At $199.99 Mealvana sits at the top of the AI-coach band and level with Alma.

### General consumer and prosumer AI

Three patterns cover the set.

Bundled with no cap. Flo Premium includes "Unlimited access to Flo Health Assistant" ([Flo](https://help.flo.health/hc/en-us/articles/360042141812-What-is-included-in-Flo-Premium)). Headspace Ebb is in the paid plan with no cap ([Headspace](https://www.headspace.com/ai-mental-health-companion)). Snapchat My AI is free with only misuse restrictions ([Snap](https://help.snapchat.com/hc/en-us/articles/13889139811860-Staying-Safe-with-My-AI)). These are low-volume text chats with few tools.

Hidden budget with a soft landing.
- Gemini. "Compute-based usage limits" refresh every five hours up to a weekly limit, published only as multipliers. Subscribers "continue your conversation with Flash-Lite" ([Google](https://support.google.com/gemini/answer/16275805?hl=en)). Pay-as-you-go top-up credits were announced 2026-05-19 ([9to5Google](https://9to5google.com/2026/05/19/google-ai-ultra-100/)).
- ChatGPT. Secondary sources agree on a message cap per window, then an automatic switch to a mini model. UNVERIFIED because OpenAI's help centre refused the fetch ([CustomGPT](https://customgpt.ai/chatgpt-plus-limits-2026/)). No consumer top-ups.
- Cursor. Pro is $20 with $20 of frontier-model usage at API prices, then the Auto model or pay at cost ([June 2025 pricing](https://cursor.com/blog/june-2025-pricing)). From September 2025 Auto also counts against the pool ([Aug 2025 pricing](https://cursor.com/blog/aug-2025-pricing)).
- Midjourney. At the end of fast hours, $30-and-up plans drop to an unlimited slower queue. Extra fast hours cost $4 and do not expire. UNVERIFIED ([eesel](https://www.eesel.ai/blog/midjourney-pricing)).
- Claude. Five-hour sessions plus weekly limits since 2025-08-28, which Anthropic said would affect "less than 5% of subscribers" ([Anthropic on X](https://x.com/AnthropicAI/status/1949898502688903593)). A usage meter is shown with no number. At the cap the user waits or turns on extra usage "billed at standard API pricing rates" with a spend cap ([support](https://support.claude.com/en/articles/12429409-)).
- Notion. A "rolling, six-hour or monthly usage allowance" with no number. At the cap "you may see a temporary pause", or an admin lets the team use paid credits, charged "at each provider's published rates, with no markup" ([Notion](https://www.notion.com/help/notion-ai-faqs)).
- Perplexity. Hidden limits that users found at an internal endpoint. MakeUseOf reported Deep Research going from about 500 a day to 20 a month between November 2025 and February 2026, announced by one changelog line. UNVERIFIED first-party ([MakeUseOf, 2026-02-21](https://www.makeuseof.com/bought-annual-perplexity-subscription-lied/)).

Visible credits, hard stop, top-up.
- Grammarly. "Grammarly Free users have 100 prompts per month, Grammarly Premium users have 1000 prompts per month, and Grammarly Pro… have access to 2000 prompts per month." At the cap the error reads "You're out of prompts". No top-up ([Grammarly](https://support.grammarly.com/hc/en-us/articles/17776038294285-Error-message-You-re-out-of-prompts)). This is the closest consumer precedent for a published monthly count inside a subscription, and I found no press backlash about it.
- Poe. Compute points. Annual tiers run from $49.99 for "10 thousand points/day" to $2,499.99 for 8.25M points a month ([Poe](https://poe.com/subscription_plans)). "Unused points do not roll over" and more can be bought ([FAQ snippet](https://help.poe.com/hc/en-us/articles/19945140063636-Poe-Purchases-FAQs)). Each bot sets its own point price, so the user must learn a price list.
- Lovable. 0.5 to 2 credits per message, top-ups "$15 per 50 credits", rollover while subscribed, and at zero "the message pauses, and you can add credits to resume" ([Lovable](https://docs.lovable.dev/introduction/plans-and-credits)).
- Suno. Monthly credits do not roll over. "Purchased top-up credits do not expire, but require an active subscription to use" ([Suno](https://suno.com/pricing)).
- ElevenLabs. One credit per character. "Unused credits roll over for up to two months" ([ElevenLabs](https://elevenlabs.io/pricing)).
- GitHub Copilot. Until June 2026, 300 premium requests on Pro, $0.04 each after, and at the cap "you can still use Copilot with one of the included models" ([docs](https://docs.github.com/en/copilot/concepts/billing/copilot-requests)). From 2026-06-01 it bills tokens against included credits because "the current premium request model is no longer sustainable", and "Fallback experiences will no longer be available" ([GitHub, 2026-04-27](https://github.blog/news-insights/company-news/github-copilot-is-moving-to-usage-based-billing/)).
- Replit. Effort-based pricing from 2025-06-18, a checkpoint costing "as little as $0.06 to multiple dollars". Replit said the rollout "did not meet our standards" ([Replit, 2025-07-12](https://replit.com/blog/effort-based-pricing-recap)). The Register quoted "I blew through $70 in a night" ([The Register, 2025-09-18](https://www.theregister.com/2025/09/18/replit_agent3_pricing/)).
- Canva. Pooled monthly AI allowances per tier, UNVERIFIED ([eesel](https://www.eesel.ai/blog/canva-ai-pricing)). The 2024 Teams rise from $119.99 to $500 a year was justified by AI features and called "one of the biggest increases I have ever seen" ([TechCrunch, 2024-09-03](https://techcrunch.com/2024/09/03/canva-has-increased-prices-for-its-teams-product)).

Companion and learning apps.
- Duolingo. No published cap on Max's Video Call or Roleplay. Luis von Ahn floated metering in February 2026: "on Super you only get 1 per day versus Max unlimited" ([Q4 2025 call](https://www.fool.com/earnings/call-transcripts/2026/05/04/duolingo-duol-q4-2025-earnings-transcript/)). The free tier's Energy gives 25 units and charges one per exercise, right or wrong. A writer quit after a 700-day streak when energy ran out during a perfect lesson ([Android Authority, 2025-10-01](https://www.androidauthority.com/quitting-duolingo-energy-system-3599842/)).
- Character.AI. The paid tier sells queue priority, not message counts. Free-tier caps on regenerations arrived in March 2026, extendable with an in-app currency, UNVERIFIED ([PiunikaWeb, 2026-03-11](https://piunikaweb.com/2026/03/11/character-ai-limits-swipes-go-ons-memos-free-users/)).
- Replika. Weekly per-feature caps inside the top tier, UNVERIFIED ([eesel](https://www.eesel.ai/blog/replika-ai-pricing)).

What the backlash has in common. The dated complaints cluster on a silent cut (Perplexity, Claude in July 2025, [TechCrunch 2025-07-17](https://techcrunch.com/2025/07/17/anthropic-tightens-usage-limits-for-claude-code-without-telling-users/)), a cost unknown before the action (Replit), and a badly explained unit change (Cursor, [TechCrunch 2025-07-07](https://techcrunch.com/2025/07/07/cursor-apologizes-for-unclear-pricing-changes-that-upset-users/)). Published caps that stayed put, such as Grammarly's and Suno's, drew none I could find.

## 2. What companies say about AI cost of goods

Duolingo, the fullest public record.
- Q4 2024: gross margin fell about 120 basis points to 71.9 percent "due to… increased generative AI costs due to the increased adoption of Duolingo Max", with Max at 5 percent of subscribers ([letter, 2025-02-27](https://www.sec.gov/Archives/edgar/data/1562088/000156208825000039/q4fy24duolingo12-31x24shar.htm)).
- Q1 2025: 71.1 percent. Cost work landed "ahead of schedule", including "model optimizations that significantly reduced costs for Role Play" ([letter, 2025-05-01](https://www.sec.gov/Archives/edgar/data/1562088/000156208825000098/q1fy25duolingo3-31x25share.htm)).
- Q3 2025: the full-year guide improved to a decline of about 80 basis points on "lower-than-expected AI costs". Von Ahn: "Costs are coming down. They've come down just without us doing anything." Max was 9 percent of subscribers ([letter](https://www.sec.gov/Archives/edgar/data/1562088/000162828025049514/q3fy25duolingo9-30x25share.htm), [call](https://www.fool.com/earnings/call-transcripts/2025/11/06/duolingo-duol-q3-2025-earnings-call-transcript/)).
- The FY25 guide went 170, 150, about 100, then 80 basis points. The result was about 60.
- Q1 2026: CFO Gillian Munson said "on a per-unit basis, the costs have come down a lot" while total cost rises with adoption ([call, 2026-05-04](https://www.fool.com/earnings/call-transcripts/2026/05/04/duolingo-duol-q1-2026-earnings-transcript/)).
- Q2 2026: Video Call fell from about $0.30 to "under $0.01 per video call" on open-weight models. AI in cost of revenue is "tens of millions of dollars". Year-end gross margin guide rose to about 70 percent ([call, 2026-08-05](https://www.fool.com/earnings/call-transcripts/2026/08/12/duolingo-duol-q2-2026-earnings-call-transcript/)).

Notion. CFO Rama Katkar said AI costs fell about 3x in two years through model work ([Mostly Metrics, 2025-11-09](https://www.mostlymetrics.com/p/can-bad-gross-margins-ever-be-a-good-sign)). The often-repeated claim that AI takes about 10 points off a 90 percent margin could not be traced to a source. UNVERIFIED.

Intercom Fin. Eoghan McCabe: "Originally, it cost us $1.21 per resolution… we made it dramatically cheaper. So we've very healthy margin now" ([The Split, 2025-09-15](https://www.thespl.it/p/inside-intercoms-ai-turnaround-eoghan)). Fin launched at $0.99 a resolution, so about minus 22 percent gross margin, priced on the belief that costs would fall.

Character.AI. Serving cost cut "by a factor of 33" since late 2022. Commercial APIs "would cost at least 13.5X more" ([blog, 2024-06-20](https://blog.character.ai/optimizing-ai-inference-at-character-ai-2/)).

Perplexity. Reported 2024 revenue of about $34M against about $57M of compute, model and web costs, with much of it booked as R&D. UNVERIFIED secondary reporting ([The Deep Dive](https://thedeepdive.ca/did-perplexity-fudge-its-numbers/)). Inferred: about 2 cents a query.

OpenAI. Sam Altman, January 2025: "we are currently losing money on openai pro subscriptions! people use it much more than we expected." UNVERIFIED snippet ([Yahoo](https://finance.yahoo.com/news/sam-altman-says-losing-money-080700756.html)). SaaStr cites a compute margin of about 70 percent by October 2025, up from about 35 percent in January 2024, UNVERIFIED ([SaaStr, 2025-12-22](https://www.saastr.com/have-ai-gross-margins-really-turned-the-corner-the-real-math-behind-openais-70-compute-margin-and-why-b2b-startups-are-still-running-on-a-treadmill/)).

Anthropic. PitchBook put compute at $0.71 per revenue dollar in Q1 2026 ([Yahoo, 2026-06-10](https://finance.yahoo.com/markets/stocks/articles/anthropics-gross-margin-most-important-070500338.html)). The weekly limits followed users running Claude Code "continuously in the background, 24/7", one of whom "consumed tens of thousands in model usage on a $200 plan" ([Yahoo, 2025-07-28](https://finance.yahoo.com/news/anthropic-unveils-rate-limits-curb-192115244.html)).

Coding tools. The WSJ reported in 2023 that Copilot lost about $20 per user per month on a $10 plan, UNVERIFIED ([The Register](https://www.theregister.com/2023/10/11/github_ai_copilot_microsoft/)). TechCrunch in August 2025: margins on code generation products "are either neutral or negative" ([TechCrunch](https://techcrunch.com/2025/08/07/the-high-costs-and-thin-margins-threatening-ai-coding-startups/)). Replit's gross margin went 9.8 percent, 36.1 percent, 23 percent across Dec 2024 to Jul 2025 ([Tanay Jaipuria](https://www.tanayj.com/p/the-gross-margin-debate-in-ai)).

Fitness and wellness. Nothing first-party on AI cost per user from WHOOP, Oura, Strava, MyFitnessPal or Noom. Cal AI's CTO moved to a specialised model on Inference.net, 66 percent faster, and "cost and latency went down", with no dollar figure ([Inference.net](https://inference.net/case-study/cal-ai/)). Canva and Grammarly publish no cost figures.

Rules of thumb.
- RevenueCat: track "AI cost per MAU" against revenue per user. $0.18 on $6 is about 3 percent and fine. $0.60 on $3.50 is 17 percent and a "structural margin problem". Above 20 percent is a concern ([RevenueCat, 2026-03-26](https://www.revenuecat.com/blog/growth/ai-feature-cost-subscription-app-margins)).
- OnlyCFO: AI products run about 50 percent gross margin, which is acceptable with high lifetime value or a falling cost curve ([OnlyCFO, 2025-08-24](https://www.onlycfo.io/p/shut-up-about-ai-gross-margins-only)).
- a16z: gross margin of 85 to 90 percent is "an orange flag" that the product has little AI use ([a16z, 2025-11](https://www.a16z.news/p/moats-before-gross-margins-revisited)).
- Bessemer State of AI 2025: the fastest-growing AI startups average about 25 percent gross margin and steadier ones about 60 percent. UNVERIFIED ([Bessemer](https://www.bvp.com/atlas/the-state-of-ai-2025)).
- The "inference is 23 percent of revenue" line in circulation misquotes ICONIQ, which says 23 percent of AI product cost ([SaaStr](https://saastr.com/inference-costs-average-23-of-revenue-at-ai-b2b-companies-how-will-you-pay-for-it)).
- RevenueCat 2026: AI apps convert trials at 8.5 percent against 5.6 percent and earn $30.16 against $21.37 in year-one value, but retain worse, 21.1 against 30.7 percent on annual plans ([TechCrunch, 2026-03-10](https://techcrunch.com/2026/03/10/ai-powered-apps-struggle-with-long-term-retention-new-report-shows)).

Price trend. a16z measured a 10x a year fall in price at constant quality, UNVERIFIED ([a16z](https://a16z.com/llmflation-llm-inference-cost/)). Epoch AI measured 9x to 900x depending on the capability bar ([Epoch, 2025-03-12](https://epoch.ai/data-insights/llm-inference-price-trends)). The counterpoint from Ethan Ding is that tokens per task grew 10 to 100 times, so flat plans for open-ended agents fail ([Ding, 2025-07-31](https://ethanding.substack.com/p/ai-subscriptions-get-short-squeezed)). Duolingo shows both: unit cost down 30x, margin guided down because more users get the feature.

## 3. Published techniques for cutting inference cost

Trimming and caching the prompt.
- WHOOP Coach built a template language with conditional rendering. It "cut our average prompt tokens by almost 80%", improved cache hits 3.5 times, cut time to first token about 20 percent, and brought "Overall Agent costs down by ~85%" ([WHOOP engineering, 2026-04-07](http://engineering.prod.whoop.com/hyper-prompt-markup-language/)).
- Character.AI keeps a per-conversation cache between turns. "Our system achieves a 95% cache rate" ([blog](https://blog.character.ai/optimizing-ai-inference-at-character-ai-2/)). Its prompt library truncates history "up to a fixed truncation point–only moving this truncation point on average every k turns", so the cached prefix survives ([Prompt Poet, 2024-08-14](https://blog.character.ai/introducing-prompt-poet/)). This is the same idea as lever 2 in the cost file.
- Anthropic's caching launch quotes Notion's Simon Last: "We're excited to use prompt caching to make Notion AI faster and cheaper" ([Anthropic, 2024-08-14](https://www.anthropic.com/news/prompt-caching)).

Routing and cascades.
- RouteLLM cut cost "over 85%" on one benchmark at 95 percent of GPT-4 quality ([LMSYS, 2024-07-01](https://www.lmsys.org/blog/2024-07-01-routellm/)).
- GPT-5 shipped with "a real-time router", and after limits "a mini version of each model handles remaining queries". Quotes from snippets ([OpenAI](https://openai.com/index/introducing-gpt-5/)).
- Notion is reported to send about 75 percent of AI traffic through an automatic model picker. UNVERIFIED ([ZenML](https://www.zenml.io/llmops-database/building-sustainable-ai-products-through-model-agnosticism-and-cost-optimization)).
- Even routing did not keep Cursor's Auto unlimited. It joined the metered pool in September 2025.

Small and fine-tuned models.
- Intercom replaced GPT-4.1 with a fine-tuned 14B Qwen model for one high-volume step and "saved almost all of those several hundred thousand a month" ([Chain of Thought, 2026-02-26](https://chainofthought.show/podcast/49-how-intercom-cut-250k-month-by-ditching-gpt-for-qwen/)).
- Instacart distilled an 8B model to within 0.1 F1 of its teacher and cut latency from 700 ms to 300 ms ([Instacart, 2025-11-21](https://company.instacart.com/tech-innovation/building-the-intent-engine-how-instacart-is-revamping-query-understanding-with-llms)).
- Notion: "By fine-tuning models, we reduced latency from about 2 seconds to 350 milliseconds" ([Fireworks, 2025-07-25](https://fireworks.ai/blog/Story-Notion)).
- Grammarly serves one model of over 1B parameters at about 100 billion requests a week, with no cost figure ([Superhuman blog](https://blog.superhuman.com/scaling-gec-inference/)).
- Duolingo's Video Call fell below 1 cent on open-weight models (section 2).

Precompute and offline generation.
- Duolingo generates lessons offline with human review ([Duolingo, 2023-06-22](https://blog.duolingo.com/large-language-model-duolingo-lessons/)) and generates a Video Call's first question "when your Video Call is ringing" ([Duolingo, 2025-04-22](https://blog.duolingo.com/ai-and-video-call)).
- Instacart precomputes answers for common queries. "Only 2% of queries needed real-time inference."
- Strava generates one summary per uploaded activity and offers no chat.

Limiting context.
- Duolingo asks after each call "What important information have we learned about the User?" and carries a list of facts into the next call in place of the transcript. The stated reason is quality.
- Microsoft's LLMLingua reports "up to 20x compression" for a 1.5 point loss ([Microsoft Research, 2023-12-07](https://www.microsoft.com/en-us/research/blog/llmlingua-innovating-llm-efficiency-with-prompt-compression/)).
- Khan Academy cut Khanmigo's district price from $60 to $35 per student, partly "by tweaking the prompts" ([EdWeek, 2023-11-15](https://www.edweek.org/technology/khan-academy-plans-to-shake-up-writing-instruction-with-ai-tool/2023/11)).

On-device models.
- Apple named fitness apps using its free on-device model for structured extraction and summaries, including SmartGym, 7 Minute Workout and Train Fitness ([Apple, 2025-09-29](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)).
- Grammarly runs a model of about 1B parameters on device at 210 tokens a second on an M2, for offline reliability ([Grammarly, 2025-04-25](https://www.grammarly.com/blog/engineering/efficient-on-device-writing-assistance/)).
- The cost file already rules this out for Vana's chat. Nothing here changes that.

Shaping usage through the interface. No company states that it chose a scoped interface to save money. The examples are structural. Duolingo's Video Call follows a fixed four-part script. Strava has no free-text input. RevenueCat describes Photo Lab using stock previews to show AI value "without incurring compute costs" ([RevenueCat, 2025-10-29](https://www.revenuecat.com/blog/growth/ai-subscription-app-pricing)). Inferred for Vana: chips and one-tap actions produce short, predictable turns, and the cost file's proposed log field for chip taps would show what they save.

Rate shaping and abuse.
- Sam Altman, 2025-03-27: "our GPUs are melting. we are going to temporarily introduce some rate limits" ([X](https://x.com/sama/status/1905296867145154688)).
- Midjourney ended free trials on 2023-03-28 over "massive amounts of people making throwaway accounts". UNVERIFIED snippet ([Engadget](https://www.engadget.com/midjourney-ends-free-trials-of-its-ai-image-generator-due-to-extraordinary-abuse-153853905.html)).
- Cursor fingerprints machines: "Too many free trial accounts used on this machine". Forum evidence only ([GitHub issue](https://github.com/chengazhen/cursor-auto-free/issues/22)).
- Indie iOS developers use DeviceCheck with a proxy in front of the model key ([AIProxy](https://www.aiproxy.com/)). Vana already calls models from edge functions behind auth, so its exposure is the account, not the key.
- RevenueCat reports hard paywalls convert downloads at 10.7 percent against 2.1 percent for freemium, and AI apps choose them to avoid compute for people who will never pay.

## 4. Trial economics

RevenueCat State of Subscription Apps 2026, 115,000 apps ([report](https://www.revenuecat.com/state-of-subscription-apps), [summary, 2026-03-19](https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026)).

| Trial length | Median trial to paid | Share of cancellations on Day 0 |
|---|---|---|
| 3 to 4 days | 25.5% | 55.4% |
| 5 to 9 days, 7-day row for Day 0 | 37.4% | 39.8% |
| 14 days | not given | 35.7% |
| 17 to 32 days, 30-day row for Day 0 | 42.5% | 31.1% |

- For seven-day trials, 64 percent of cancellations fall in the first 24 hours ([RevenueCat, 2026-05-05](https://www.revenuecat.com/blog/growth/post-purchase-screen)). "Most trial cancellations happened within the first two hours" ([RevenueCat, 2026-03-23](https://www.revenuecat.com/blog/growth/free-trials-dont-make-sense-anymore)).
- Health and Fitness: trial to paid 37.7 percent, 82.1 percent of trial starts on install day, year-one realised value $35.64.
- Annual plans: 35 percent of annual subscribers turn off renewal in month one and 72 percent within the year.
- Hard paywall against freemium at day 35: 10.7 against 2.1 percent.
- The 2025 report put the Health and Fitness refund rate at 4.71 percent, among the highest ([2025 report](https://www.revenuecat.com/state-of-subscription-apps-2025)).
- AI apps, 3,519 studied: seven-day trials go with high retention, and subscription-only was 16.4 points more common among high retainers, though a quarter of the best retainers sell consumables ([RevenueCat, 2026-08-18](https://www.revenuecat.com/blog/growth/ai-app-retention-study)).

Adapty 2026, 16,000 apps ([Health and Fitness benchmarks, 2026-03-27](https://adapty.io/blog/health-fitness-app-subscription-benchmarks/)). Install to trial 14.5 percent in North America. Trial to paid 42.2 percent. Annual plans are 61 percent of category revenue. High-priced annual plans return $70 in lifetime value against $17 for low-priced ones. 86.1 percent of conversions happen on Day 0 with a second peak on days 4 to 7. Global median prices are $12.99 a month and $38.42 a year, UNVERIFIED, so $24.99 and $199.99 are about twice and five times the medians.

Do Day-0 cancellers keep using the product. No published data from Superwall, Purchasely, Qonversion, Apphud or Sub Club. RevenueCat's writers treat Day-0 cancels as a guidance problem and give no experiment numbers.

How others limit costly features in trials. RevenueCat recommends "controlled exposure": limit by volume, give starting credit allowances in place of unlimited trials, and set daily or monthly caps ([2025-10-29](https://www.revenuecat.com/blog/growth/ai-subscription-app-pricing), [2026-03-26](https://www.revenuecat.com/blog/growth/ai-feature-cost-subscription-app-margins)). Examples, all UNVERIFIED snippets: Cursor capped its trial at 150 fast requests, Runway grants 125 credits once, Suno and ElevenLabs offer free tiers with no paid trial, and ChatGPT Plus has no general trial.

Does limiting AI in the trial hurt conversion. Not found. The only adjacent evidence is Elena Verna's reverse-trial material, which concerns web SaaS.

Store rules on eligibility. Apple: "Customers can redeem one introductory offer per subscription group" ([Apple](https://developer.apple.com/app-store/subscriptions/)), checked in StoreKit 2 with `isEligibleForIntroOffer`. Google Play sets eligibility per offer, by default for users who never held the subscription ([Google](https://support.google.com/googleplay/android-developer/answer/12154973)).

Refund abuse on packs. Apple sends `CONSUMPTION_REQUEST` for any product type and wants a reply within 12 hours. "You must obtain valid consent from the customer before sharing their personal data with Apple" ([Apple](https://developer.apple.com/documentation/appstoreserverapi/send-consumption-information)). Without consent wording at purchase, the app cannot contest a refund on a spent pack.

## 5. Consumer credits and top-ups

Reaction to visible credits against hidden caps. No controlled study exists for consumer AI, and none for wellness. What exists:
- Lambrecht and Skiera, "Paying Too Much and Being Happy About It", Journal of Marketing Research 2006. People overpay for flat rates because of insurance, overestimation of use, and the taxi meter effect, where a running meter lowers enjoyment ([journal](https://journals.sagepub.com/doi/10.1509/jmkr.43.2.212)). Read from a summary.
- Prelec and Loewenstein, "The Red and the Black", Marketing Science 1998. Prepaid consumption "can be enjoyed as if it were free". Inferred: an allowance inside the subscription reads as prepaid, and a counter on every action undoes that.
- Catherine Tucker in Slate cites a bank that raised revenue 15 percent by moving from per-transaction fees to a flat fee ([Slate, 2013-12-18](https://slate.com/news-and-politics/2013/12/the-taxi-meter-effect-why-do-consumers-hate-paying-by-the-mile-or-the-minute-so-much.html)).
- Kyle Poyar: "Credit-based pricing can be hard to predict, hard to manage, and feel like a black-box", and 70 to 80 percent of tokens come from 10 percent of users ([Growth Unhinged, 2025-09-03](https://kylepoyar.substack.com/p/ai-credit-pricing)).
- Metronome: "Our finance team likes it. Our customers don't know what a credit does." Its mitigations are a cost preview before the action, a live balance, and predictable overage ([Metronome, 2025-09-22](https://metronome.com/blog/the-rise-of-ai-credits-why-cost-plus-credit-models-work-until-they-dont)).
- Duolingo Energy is the consumer case of per-action scarcity on a daily habit, with the backlash in section 1.

Apple's rules.
- Guideline 3.1.1: "Any credits or in-game currencies purchased via in-app purchase may not expire, and you should make sure you have a restore mechanism for any restorable in-app purchases" ([guidelines](https://developer.apple.com/app-store/review/guidelines/)). Packs never expire.
- Guideline 3.1.2(a): "Subscriptions may include consumable credits, gems, in-game currencies, etc." Apple says nothing on whether the subscription's own credits may expire at period end. RevenueCat treats that as allowed and offers "Auto-expire at the end of billing cycle" for subscription grants only ([RevenueCat](https://www.revenuecat.com/docs/offerings/virtual-currency/expiring-currencies)). Vendor guidance, not Apple's text.
- Consumables cannot be restored. "Consumable Apple In-App Purchases also don't appear in the current entitlements" ([StoreKit](https://developer.apple.com/documentation/storekit/transaction/currententitlements)). The pack balance must live server-side against the account, which the wallet already does.
- Family Sharing covers "auto-renewable subscriptions or non-consumables", not consumables, and is off by default per product ([Apple](https://developer.apple.com/documentation/storekit/supporting-family-sharing-in-your-app)).
- Spend order: RevenueCat deducts expiring currency before non-expiring. The wallet should spend the monthly allowance before pack credits.
- Commission: consumables pay 15 percent under the Small Business Program and 30 percent otherwise ([Apple](https://developer.apple.com/app-store/small-business-program/)).
- US web top-ups: the guidelines now allow links to outside purchase on the US storefront. The Ninth Circuit on 2025-12-11 allowed Apple a cost-based commission still to be set ([Fenwick](https://www.fenwick.com/insights/publications/ninth-circuit-largely-upholds-ruling-in-epic-v-apple)). Google Play's US programme starts charging reported fees on 2026-10-01 ([Google](https://support.google.com/googleplay/android-developer/answer/15582165)). Not worth building for launch.
- Google Play: virtual currency must be used only in the app where it was bought. No expiry rule ([Google](https://support.google.com/googleplay/android-developer/answer/9858738)).

RevenueCat's currency feature. It grants on purchase and renewal, supports "a separate currency grant amount specifically for free trials", removes a prorated amount on refund, and needs Flutter SDK 9.1.0 or later ([docs](https://www.revenuecat.com/docs/offerings/virtual-currency/subscriptions)). It cannot grant monthly on an annual subscription. Staff confirmed on 2026-03-04 that a webhook plus your own scheduler is the workaround ([community](https://community.revenuecat.com/tips-discussion-56/monthly-virtual-currency-schedules-for-annual-subscriptions-grant-expire-reset-7495)). Most Health and Fitness revenue is annual, so the app's own wallet remains the right home for the allowance.

Patterns that reduce worry about running out.
- A soft landing: Midjourney's slow queue, Gemini's Flash-Lite, ChatGPT's mini model, Cursor's Auto.
- Rollover: ElevenLabs up to two months, Lovable while subscribed. Inferred for Vana: a one-month rollover would cost little because the typical athlete uses a third of the allowance, but it doubles the worst case. Decide from October data.
- Packs that never expire, stated plainly. Suno does this. Apple requires it anyway.
- Monthly reset, not daily. Duolingo's daily energy produced the strongest consumer reaction in the survey. Keep daily limits as invisible script guards.
- A published, stable number. Grammarly.
- Naming. No data compares "credits", "tokens", "energy" or "messages". Inferred: "tokens" collides with the technical term and "energy" carries Duolingo's baggage. "Credits" is the most common word in the set.

## Gaps

- No first-party confirmation for ChatGPT, Midjourney, Canva, Replika, Perplexity or Poe limits, or for a WHOOP Coach daily cap.
- No study of visible meters against hidden caps in consumer AI, and nothing specific to wellness.
- No experiment on trial caps and conversion.
- No first-party AI cost per user from any fitness or nutrition company.
- Several 2026 events came from single secondary sources and should be checked before anyone repeats them: the Cal AI removal, the MyFitnessPal free-scan change, and the Perplexity cuts.
