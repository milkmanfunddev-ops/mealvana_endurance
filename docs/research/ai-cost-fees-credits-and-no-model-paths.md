# Store fees, credits, no-model meal logging, attestation, and dev measurements

Researched 2026-09-20. Companion to `docs/research/vana-cost-and-pricing.md` (prices, caching, metering) and `docs/revenuecat-spec-for-lee.md`. It does not repeat Claude platform features, gateway or Supabase pricing, or the code-level audit, which other agents cover.

How it was made. External facts were gathered by four research subagents from the pages linked, read through a summarising fetcher on 2026-09-20. I did not reopen those pages myself. Anything a primary page did not confirm is marked UNVERIFIED. Confirm a figure at its source before acting on it. Dev measurements are mine: SELECT-only queries on the DEV project (`vlmtsdzpnjnavdgytcmi`), SQL in Part 5. Nothing was written, deployed or built.

How thin the data is. Dev holds 8 users, 230 planning conversations, 157 general conversations, 46 describe-meal calls and 37 photo calls. General chat is dominated by the eval script from one account. Cache reads were logged only from 09-15, so dollar figures computed from `vana_calls` price unlogged rows as uncached and are upper bounds. Treat every share below as a direction, not a forecast.

## Ranked summary

Dollar effects are per subscriber per month unless marked one-off. "Typical athlete" is the $2.86 profile from the cost doc.

| # | Option | Effect | Effort | Risk | Owner decides |
|---|---|---|---|---|---|
| 1 | Confirm Apple Small Business Program enrolment today | +$3.75 on $24.99 monthly, +$2.50 annual, +$1.88 founding monthly, +$1.25 founding annual, against the 30% rate. Larger than the whole AI bill | S (a form) | None. The rate starts 15 days after the end of the fiscal month of approval, so October sales pay 30% if this is not already done | Who the Account Holder is, and which associated accounts to list |
| 2 | AWS Activate Founders credits, spent on Claude through gateway Bedrock BYOK | One-off $1,000 to $5,000, which is 420 to 2,100 subscriber-months of AI at the blended $2.38 | S to apply, S to M to wire and test | Haiku p50 about 300 ms slower on Bedrock in one snapshot. Cache entries do not cross providers. New-account Bedrock quotas may start at zero (UNVERIFIED) | Whether slower chat is acceptable while credits last |
| 3 | Do not draft a planning opener nobody reads | 45% of planning openers in dev got no reply. Worth up to $0.03 for the typical athlete, more for a heavy one. Bounds the uncapped-opener exposure | S to M | Changes the screen's first impression | Whether the opener drafts on screen open or on first intent |
| 4 | Reuse a drafted opener for 10 to 30 minutes when the last one went unanswered | $0.03 to $0.08 | S | Stale if the plan changed in the window, so key the reuse on plan and Doll version | Whether reuse fits the "drafted, never templated" rule. It is the same draft shown again, not a template |
| 5 | Meal logging ladder, cheap tiers only: own history and saved meals first, then the small-model eval already planned | History tier about $0.03 to $0.06. The small model is the other agent's lever (65% of $0.63) | S for history, M for the eval | Wrong match on a loose text key. Require exact normalised match and show the source | Whether a silent history hit is acceptable or needs a "same as last time?" prompt |
| 6 | Web checkout for iOS US (RevenueCat Web Purchase Link + Stripe) | +$0.19 to +$0.86 at a 33% web share once on 15%, before any conversion loss. The one published test shows web-only losing more than it saves | M | Apple may win a link-out commission (5% for SBP members proposed, UNVERIFIED). Sales tax becomes yours. Refunds and disputes become yours | Not for Oct 1. Revisit as an annual-plan experiment in Q1 2027 |
| 7 | Food database tier (self-hosted USDA FDC plus alias table) | About $0.10 to $0.15 at today's Sonnet price, a third of that after a small-model move | M to L | Wrong-food matches that look confident | Not worth it for cost. Worth it later for determinism and latency at volume |
| 8 | Serve deterministic chips ("I like these", "Next: dinner", "Other options") without the model | About 26% of planning turns. $0.22 today, $0.08 after the caching fix | M | Loses the two-sentence "why these fit your week" line, which the persona requires to name a training fact | Whether a picker without fresh prose is acceptable for those taps |
| 9 | App Attest and Play Integrity | $0 in normal operation. Bounds abuse only | L | Forked low-use Flutter packages, a web and debug allowlist that becomes the weak point | Not now. The entitlement gate and allowance already exist. Revisit if logs show abuse that survives the paywall |
| 10 | Gate background extraction on short conversations | At most $0.04 | S | Misses a one-line "remember that..." message, which is exactly what extraction is for | Not worth it |
| 11 | Anthropic startup form | Unknown. Credits need institutional funding | S (two minutes) | None | Submit it, expect nothing |
| 12 | Google, Microsoft, Vercel startup programmes, Supabase credits | $0 usable for Claude, or not eligible | | Microsoft's page says Claude on Foundry charges the card on file, not Azure credits | Skip |
| 13 | Commercial nutrition APIs (Nutritionix, Edamam, FatSecret, Passio) | Negative. Each costs more per call than Sonnet or forbids storing macros | | | Skip |

## Part 1. Store fees and web checkout

### (a) Reduced store rates

Apple Small Business Program ([Apple](https://developer.apple.com/app-store/small-business-program/)).

- Eligibility: proceeds of $1M or less in the prior calendar year across all apps, or new to the App Store. The Account Holder enrols, accepts the current Paid Apps agreement, and lists every Associated Developer Account (more than 50% ownership either way, or ultimate decision authority).
- Rate: 15% on all in-app purchases. Enrolled, a subscription pays 85% from day one. Not enrolled, it pays 70% until the subscriber has one year of paid service, then 85% ([Apple subscriptions](https://developer.apple.com/app-store/subscriptions/)).
- Timing: the rate starts 15 days after the end of the fiscal month in which Apple approves. Apple's example is approved Feb 10, effective March 14. Approval in fiscal September would mean roughly Oct 11, approval in October mid-November (my estimate, UNVERIFIED against Apple's fiscal calendar). Every founding subscriber who buys before the effective date still moves to 85% once it starts, because the rate applies to the developer, not the subscriber.
- Verify: App Store Connect, Business, Agreements. Then set the SBP flag and effective date in RevenueCat's app settings so its revenue charts are right ([RevenueCat](https://www.revenuecat.com/blog/engineering/small-business-program)). The financial reports showing 85% proceeds is a sensible second check, UNVERIFIED on an Apple page.
- The existing cost doc already assumes 15%. I found no record in the repo that enrolment happened. That is the single check worth making today.

Google Play. The subagent reports that Google changed US fees on 2026-06-30: auto-renewing subscriptions pay a 10% service fee plus a 5% billing fee when Google Play Billing is used, 15% in total, with no enrolment and no revenue ceiling ([Google service fees](https://support.google.com/googleplay/android-developer/answer/112622), [Google fee change](https://support.google.com/googleplay/android-developer/answer/16954621), [Android Developers blog](https://android-developers.googleblog.com/2026/06/play-expanded-billing.html)). The older 15% first-$1M tier needs an Account Group and still applies elsewhere ([Google](https://support.google.com/googleplay/android-developer/answer/10632485)). Whether the new US schedule needs that enrolment is UNVERIFIED. Create the Account Group anyway, it costs nothing. Either way subscriptions on Play pay 15% from day one.

### (b) Link-outs and web checkout in the US, September 2026

Apple.

- Guideline 3.1.1(a) says entitlements "are not required for developers to include buttons, external links, or other calls to action in their United States storefront apps", and 3.1.3 exempts the US storefront from the ban on steering ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)). No entitlement. US storefront only, so the link must be hidden elsewhere.
- Commission today: zero, since the April 30, 2025 contempt order.
- That may not last. On Dec 11, 2025 the Ninth Circuit upheld contempt but let Apple recover costs "genuinely and reasonably necessary" and sent the rate back to the district court ([Fenwick](https://www.fenwick.com/insights/publications/ninth-circuit-largely-upholds-ruling-in-epic-v-apple), [Courthouse News](https://www.courthousenews.com/apples-fight-over-commissions-for-linked-out-app-store-purchases-continues-in-federal-court/)). The Supreme Court granted cert on June 30, 2026 (No. 25-1311, [docket](https://www.supremecourt.gov/search.aspx?filename=/docket/docketfiles/html/public/25-1311.html)), a stay was denied Aug 13, and Apple's merits brief was filed Sept 14. One outlet reports Apple proposing 15% standard, 10% for programmes and renewals, and 5% for Small Business members ([MacObserver](https://www.macobserver.com/news/apple-epic-link-out-commission-proposal-15-percent/)); the outlet did not read the docket, so UNVERIFIED.

Google, US. External content links: declare, integrate the external links API, enrol. 10% on subscriptions bought within 24 hours of the tap, fees from Oct 1, 2026 ([Google](https://support.google.com/googleplay/android-developer/answer/16470497)). US alternative billing: 10% on subscriptions, no billing fee, you report transactions and carry PCI duties ([Google](https://support.google.com/googleplay/android-developer/answer/16497028)). 10% to Google plus about 4% to Stripe is 14%, against 15% on Play Billing. Not worth it on Android.

### (c) RevenueCat web checkout

- Fees. RevenueCat: free to $2,500 monthly tracked revenue, then 1%, the same on every route, no web surcharge ([pricing](https://www.revenuecat.com/pricing/), [announcement](https://www.revenuecat.com/blog/company/introducing-revenuecat-billing)). Stripe: 2.9% + $0.30 per charge, Stripe Tax 0.5% where registered, $15 per dispute, Stripe Billing 0.7% only if Stripe Billing is the subscription engine ([Stripe](https://stripe.com/pricing)). Whether RevenueCat Web Billing avoids the 0.7% is UNVERIFIED. Paddle as merchant of record: 5% + $0.50 ([Paddle](https://www.paddle.com/pricing)), supported by RevenueCat ([docs](https://www.revenuecat.com/docs/web/integrations/paddle)). Lemon Squeezy has no RevenueCat integration that I found (UNVERIFIED).
- One identity. A Web Purchase Link is `https://pay.rev.cat/<token>/<app_user_id>`. With the Supabase uid in the link the purchase lands on the same RevenueCat customer and the `pro` entitlement check does not change ([docs](https://www.revenuecat.com/docs/web/web-billing/web-purchase-links)). Purchasing already requires a registered account (spec section 5), so the anonymous Redemption Link flow is not needed.
- Flutter change. One `url_launcher` call from the paywall, shown only on the US storefront, and a `CustomerInfo` refresh on resume. The existing webhook keeps feeding the `entitlements` cache. The "manage subscription" screen needs a branch, because a web subscriber does not appear in iOS Settings and manages through RevenueCat's hosted portal.
- Trials are supported on web ([docs](https://www.revenuecat.com/docs/web/web-billing/configuring-overview)). Apple's one-intro-offer rule does not bind a web trial, so a lapsed trialist could take a second trial on the web unless the backend blocks it.
- Tax. With Stripe you are the merchant of record. RevenueCat computes tax through Stripe Tax only in states where you have registered; US prices are tax-exclusive ([docs](https://www.revenuecat.com/docs/web/web-billing/tax)). About 25 states tax SaaS and the usual nexus threshold is $100k or 200 transactions per state ([Stripe guide](https://stripe.com/guides/introduction-to-saas-taxability-in-the-us), [nexus](https://stripe.com/resources/more/sales-tax-nexus-laws)). At launch the exposure is the home state. Apple and Google carry all of this on store sales. Paddle carries it for about 2.6 points more than Stripe.
- Risks. Refunds are issued by you and end access at once. Disputes cost $15 and Stripe Tax does not reverse on them. Failed renewals retry for up to 30 days ([docs](https://www.revenuecat.com/docs/web/web-billing/subscription-lifecycle)); card failure rates against Apple's billing retry are UNVERIFIED. Review risk is showing the link outside the US storefront.
- Conversion. The only controlled test is RevenueCat with Dipsea, US iOS, May 2025, about 12,500 users ([RevenueCat](https://www.revenuecat.com/blog/growth/iap-vs-web-purchases-conversion-test/)). Initial conversion: 27.0% IAP only, 18.1% web only, 23.5% for both with a 30% web discount. Net proceeds per user at a 15% store fee: $2.53, $1.96 and $2.17. For a Small Business member, web-only earned 86 cents per IAP dollar. One app, short horizon.

### (d) Net revenue per subscriber per month

Annual plans divided by 12. RevenueCat's 1% applies equally everywhere and is left out. "Stripe + Tax" is 2.9% + $0.30 + 0.5%. The two "if" columns show what the web route nets if the reported proposals become rules.

| Plan | Store 30% | Store 15% | Stripe | Stripe + Tax | Stripe + Tax + Billing 0.7% | Paddle | If Apple takes 5% on link-outs | Google link-out at 10% |
|---|---|---|---|---|---|---|---|---|
| $24.99 monthly | $17.49 | $21.24 | $23.97 | $23.84 | $23.67 | $23.24 | $22.59 | $21.34 |
| $199.99 annual | $11.67 | $14.17 | $16.16 | $16.07 | $15.96 | $15.79 | $15.24 | $14.41 |
| Founding $12.49 monthly | $8.74 | $10.62 | $11.83 | $11.77 | $11.68 | $11.37 | $11.14 | $10.52 |
| Founding $99.99 annual | $5.83 | $7.08 | $8.07 | $8.02 | $7.97 | $7.87 | $7.61 | $7.19 |

The $0.30 fixed fee is charged monthly on a monthly plan and once a year on an annual plan, which is why annual gains more per dollar.

Blended net when some subscribers pay on the web (Stripe + Tax), and the gain over all-store:

| Plan | Store at 15%: 20% web | 33% web | 50% web | Store at 30%: 20% web | 33% web | 50% web |
|---|---|---|---|---|---|---|
| $24.99 monthly | $21.76 (+$0.52) | $22.10 (+$0.86) | $22.54 (+$1.30) | $18.76 (+$1.27) | $19.59 (+$2.09) | $20.67 (+$3.17) |
| $199.99 annual | $14.55 (+$0.38) | $14.80 (+$0.63) | $15.12 (+$0.95) | $12.55 (+$0.88) | $13.12 (+$1.45) | $13.87 (+$2.20) |
| Founding $12.49 monthly | $10.85 (+$0.23) | $11.00 (+$0.38) | $11.19 (+$0.57) | $9.35 (+$0.60) | $9.74 (+$1.00) | $10.25 (+$1.51) |
| Founding $99.99 annual | $7.27 (+$0.19) | $7.39 (+$0.31) | $7.55 (+$0.47) | $6.27 (+$0.44) | $6.56 (+$0.72) | $6.93 (+$1.10) |

Reading it. Web share only moves iOS subscribers, and Android gains about a point. A 33% web share of iOS is perhaps 20 to 25% of all subscribers. On 15%, that is worth 20 to 60 cents per subscriber per month before counting one lost conversion. In the Dipsea test, offering both routes cost 14% of proceeds per user. At these prices a 14% loss is $1 to $3 per subscriber per month, several times the fee saving. Verdict: enrol in the Small Business Program, launch IAP only, and do not build web checkout before Oct 1. If it is tried later, offer it for annual plans on iOS US only, beside IAP, as a RevenueCat experiment with proceeds per paywall view as the measure.

## Part 2. Credits and startup programmes

| Programme | Amount | Eligibility | How to apply | Lasts | Catch | Verdict |
|---|---|---|---|---|---|---|
| AWS Activate Founders ([AWS](https://aws.amazon.com/startups/credits)) | $1,000 to start, up to $5,000 | Bootstrapped or self-funded, pre-Series B, founded within 10 years, paid-tier AWS account | Online form, no partner needed | 12 months (UNVERIFIED, third-party) | See below | Apply |
| AWS Activate Portfolio | Up to $200,000 | Organization ID from a VC or accelerator | Through the provider | Same | Not eligible today | Skip |
| Anthropic Claude for Startups ([Anthropic](https://claude.com/programs/startups)) | Not published. The $5k, $25k, $100k tiers are third-party claims (UNVERIFIED) | Anyone may join. Credits need institutional equity funding, company under 4 years old, no earlier Anthropic credits | Form with a Console account and company email | Not stated | First-party API only, not Bedrock or Vertex | Submit, expect nothing |
| Vercel AI Gateway free credit ([pricing](https://vercel.com/docs/ai-gateway/pricing), [FAQ](https://vercel.com/docs/ai-gateway/faq)) | $5 a month (UNVERIFIED on a primary page) | Any team | Automatic | Monthly | Ends when you buy credits. The free-tier model list has no Anthropic model ([list](https://vercel.com/ai-gateway/models?freeTier=true)) | Useless here |
| Vercel for Startups ([Vercel](https://vercel.com/startups/credits)) | Up to $30,000 | Series A or earlier, within 12 months of a round, proof from an approved partner | Through the partner | 1 year | At most half of each month's credit may go to the AI Gateway. The backend is not on Vercel | Not eligible |
| Vercel AI Accelerator ([recap](https://vercel.com/blog/2026-vercel-ai-accelerator-recap)) | Over $200,000 per team | 39 teams chosen. 2026 cohort ended April 16 | Applications "later this year" | | Low odds | Watch only |
| Supabase | No public programme ([page](https://supabase.com/solutions/startups)). Mercury perks list $300 ([Mercury](https://mercury.com/perks)). Other claims UNVERIFIED | | | | | Skip |
| Google for Startups, Start tier ([Google](https://startup.google.com/cloud/)) | Up to $2,000 over a year | No equity funding, founded within 5 years | Online | 1 year | Third-party models such as Claude on Vertex are billed directly and not covered (UNVERIFIED, seen in a search snippet of the FAQ) | Skip |
| Google Scale and AI tiers | $100k to $350k | Equity-backed | | 2 years | Not eligible | Skip |
| Microsoft for Startups ([Microsoft](https://www.microsoft.com/en-us/startups)) | Up to $150,000 | Not stated | Founders Hub | Not stated | Claude on Foundry is billed through Azure Marketplace. Credit-only subscriptions are unsupported and "the credit card will be charged instead of Azure Credits" ([Microsoft Learn](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-claude)) | Skip. A billing trap |

AWS credits and Claude. AWS said on 2024-04-02 that Activate credits are "redeemable for third-party models on Amazon Bedrock" and named Anthropic ([AWS](https://aws.amazon.com/blogs/startups/aws-activate-credits-now-accepted-for-third-party-models-on-amazon-bedrock/)). The credit terms exclude AWS Marketplace and do not mention Bedrock ([terms](https://aws.amazon.com/awscredits/)). No newer page reversing this was found; the FAQ did not render, so "still current" is likely, not proven. Check the first Bedrock invoice line before relying on it.

Gateway BYOK. The gateway accepts Bedrock keys (`accessKeyId`, `secretAccessKey`, `region`) and Vertex credentials, with "no markup or fee" ([BYOK](https://vercel.com/docs/ai-gateway/authentication-and-byok/byok)). The model slug in code stays `anthropic/claude-haiku-4.5`. Routing is pinned with `providerOptions.gateway.order` and `only` ([provider options](https://vercel.com/docs/ai-gateway/models-and-providers/provider-options)). That is one config object, not a rewrite.

Catches that cost money or quality:

- BYOK needs a purchased gateway credit balance. A failed BYOK call falls back to the gateway's own credentials and bills that balance. BYOK spend is not counted in gateway budgets.
- The cost doc's caching fix pins `only: ['anthropic']` because a cache written at one provider cannot be read at another. With credits the pin becomes `only: ['bedrock']`. Never mix providers inside one conversation.
- Prompt caching on Bedrock supports 5 minute and 1 hour TTL, 4 checkpoints, and the same minimums (4,096 tokens for Haiku 4.5, 1,024 for Sonnet 4.6). Cross-region inference "may lead to increased cache writes" ([AWS](https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html)). Gateway automatic caching works on Anthropic, Vertex and Bedrock ([Vercel](https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching)). Vertex details UNVERIFIED.
- Latency, one snapshot on 2026-09-20 from the gateway endpoint pages: Haiku 4.5 p50 460 ms at Anthropic, 775 ms at Bedrock, 920 ms at Vertex. Sonnet 4.6 was about level (930, 845, 795). Chat runs on Haiku, so Bedrock adds about 300 ms to the first token of every step.
- Regional Bedrock and Vertex endpoints for Haiku 4.5 cost 10% more than the global ones.
- New AWS accounts may show Claude quotas of zero until access is granted (UNVERIFIED, search snippet).
- The `vana_calls` cost formula and `gatewayCostUsd` should still report correctly, but verify that on the first BYOK call, since the money is no longer the gateway's.

A sensible split: send the latency-tolerant calls (describe-meal, photo analysis, extract, day notes, summary, about 25% of spend) to Bedrock first and keep chat on Anthropic. That spends credits more slowly and avoids the latency cost where an athlete is waiting.

Value: $1,000 covers about 420 subscriber-months at the blended $2.38, or 735 after the caching fix. For the first months of a founding cohort that is most of the AI bill. Owner decides: apply (yes), and which calls route to Bedrock.

## Part 3. Meal logging without the big model

### What the two functions do

`supabase/functions/describe-meal/index.ts`: authenticates, checks the credit wallet (`ensureAndCheckCredits`), makes one `generateObject` call on `DESCRIBE_MEAL_MODEL` (Sonnet 4.6) with a fixed prompt, returns a `MealAnalysis` (items, per-item macros, totals, slot, confidence), and logs to `jade_calls` and `ai_usage`. `analyze-meal-photo/index.ts` does the same with an image pulled from private storage. Neither function stores the athlete's input text. Neither looks anything up before calling the model. The client (`lib/features/meal_logging/application/meal_ai_service.dart`) calls them straight from the describe and photo screens.

Two things already exist and matter here. The log sheet already offers Recent and Saved meals, a barcode scan (`log_scanned_food_screen.dart`) and manual entry; in dev 46 of 240 logs came from a saved meal and 110 were manual, so repeat eating mostly never reaches the model. And `supabase/functions/_shared/food_sources/` already has USDA FDC barcode and text search, Open Food Facts, a GTIN normaliser, and the `nutrition_products` write-through cache with a generated `resale_ok` column that keeps OFF rows apart. A bulk USDA backfill was considered and rejected on 2026-07-16 (`cache.ts` header).

### Food databases

| Source | Price | May we store the macros? | Attribution | Parses a meal sentence? | Barcode | Verdict |
|---|---|---|---|---|---|---|
| USDA FoodData Central ([API](https://fdc.nal.usda.gov/api-guide/), [downloads](https://fdc.nal.usda.gov/download-datasets/)) | Free | Yes, CC0 | Requested, not required | No, keyword search | Yes on Branded (the app's `usda.ts` already matches on GTIN) | The only clean source. 1,000 requests an hour per IP, and an edge function is one IP, so self-host the generic sets if used for text |
| Open Food Facts ([terms](https://world.openfoodfacts.org/terms-of-use)) | Free | Yes, under ODbL share-alike | Required with a link | No | Yes, about 973,000 US products | Already integrated. Keep rows in their own table, never merged. 15 reads a minute per IP |
| Nutritionix ([Syndigo guide](https://docx.syndigo.com/developers/docs/nutritionix-api-guide)) | No public free tier. About $1,850 a month (UNVERIFIED, secondary) | UNVERIFIED | UNVERIFIED | Yes, the best one | Yes | $1,850 buys 264,000 Sonnet describe calls. Skip |
| Edamam ([Nutrition](https://developer.edamam.com/edamam-nutrition-api), [Food DB](https://developer.edamam.com/food-database-api)) | $29 to $299 a month | Four macros only, and only while subscribed | Logo and link, enforced by suspension | Line-based | 700k codes | Our log history would depend on a subscription. Skip |
| FatSecret ([editions](https://platform.fatsecret.com/api-editions), [storable data](https://platform.fatsecret.com/docs/guides/storable-data), [terms](https://platform.fatsecret.com/terms)) | Free tier, Premier free under $1M revenue | No. 24 hour limit, only ids | Required | Paid add-on | Yes | Terms also bar using it "to provide diet, nutrition or health advice". Skip |
| Passio ([pricing](https://www.passio.ai/pricing), [cost page](https://www.passio.ai/cost-breakdown)) | $99 to $2,999 a month, token-metered | UNVERIFIED | OFF notice | Yes | Yes | A photo costs $0.05 to $0.075 at the best rate, four to six times Sonnet. It is an LLM behind an API. Skip |
| Others: Spoonacular (1 hour cache cap), CalorieNinjas (undisclosed data, assumes 100 g when no quantity), API Ninjas (no caching under $99), Calorie Mama ($0.10 an image), LogMeal and Spike (no public price) | | | | | | Skip |

Barcode scanning itself is free: `mobile_scanner` uses ML Kit and Apple Vision ([pub.dev](https://pub.dev/packages/mobile_scanner)). UPCitemdb carries no nutrition facts.

### What dev data says

The input text is not stored anywhere, so repeats cannot be measured on inputs. The nearest evidence is the 41 live `meal_logs` rows with `source = 'describe'`, whose `name` is the model's own title for the meal. Classified by hand:

| Kind | Examples | Count | Share |
|---|---|---|---|
| One generic food with a count or size | banana (3), peach, 4 eggs, 3 boiled eggs, oatmeal, cinnamon graham crackers, cotton candy grapes, 8 oz mocha | 10 | 24% |
| One branded product | Factor frozen dinner, Nuri protein drink, FrogFuel, Starbucks Doubleshot | 4 | 10% |
| A list of simple foods | "3 eggs and a corncob", "rice and eggs", "scrambled eggs, whole wheat toast with butter, and banana", "grilled chicken, brown rice, and steamed broccoli" | 5 | 12% |
| Composite or home dish | spaghetti with meatballs, teriyaki salmon bowl, leek and squid with white rice, grandma's spaghetti | 22 | 54% |

Repeats: the same athlete logged the same name twice in 1 of 41 cases (2%). Across athletes, 3 of 41 (7%) shared a normalised name ("oatmeal with blueberries", "banana"). Eight users over three months is too few to project from, and saved meals already absorb repeat eating. The honest range for "a database could answer this" is 24% with a plain single-food lookup and about 35 to 45% if a parser also splits simple lists and branded items go to barcode. Photos (29 logs) are outside all of this; no database answers a photo.

Add the input to the log to measure this properly: store a normalised hash of the description and its length in `ai_usage` (not the text), plus `n_items` and `confidence` from the result. One month of prod gives the real repeat rate.

### The ladder

| Tier | What it does | Expected share of describe calls | Saves per call | Effort | Comment |
|---|---|---|---|---|---|
| 0 | The screen suggests the athlete's own matching saved and recent meals as they type, on device from Drift | 5 to 10% | $0.0077 | S | No privacy question, no server work. Do this |
| 1 | Server exact-match on the athlete's own past describe results, keyed on normalised text | 2 to 5% | $0.0077 | S | Needs the input stored per athlete. Low yield because tier 0 catches most |
| 2 | Cross-user cache keyed on normalised text | 5 to 10% at scale, under 1% at launch | $0.0077 | S to M | See privacy below. Only short, generic inputs are worth caching, and those are the ones tier 3 also answers |
| 3 | Deterministic parser ("number, unit, food") plus a curated alias table of 300 to 500 athlete foods pinned to FDC ids with FNDDS portion weights | 20 to 30% | $0.0077 | M to L | The alias table is the work. Trigram search alone ranks raw rice above cooked rice. Set a confidence floor and fall through |
| 4 | Small model (Haiku 4.5 measured at $0.0027, or a cheaper gateway model) behind a 50-meal eval | The rest of text | about $0.005 | M | Already lever 3 in the cost doc. It dominates every tier above |
| 5 | Sonnet 4.6 | Low-confidence results and photos until a photo eval passes | | | |

A cheaper variant of tier 3: let the small model only split the sentence into items and quantities, and take the numbers from FDC. That removes invented macros, which is a quality gain more than a cost one.

Money. The typical athlete makes 12 describe and 4 photo calls a week: $0.40 plus $0.23, $0.63 a month. Tier 0 saves 3 to 6 cents. Tiers 1 to 3 together save at most 30% of $0.40, about $0.12, and once tier 4 lands the same 30% is worth $0.04. Building and curating a food alias table to save 4 to 12 cents per subscriber per month is not worth it for cost. Do tier 0 and tier 4. Revisit tier 3 when describe volume passes roughly 100,000 calls a month, or sooner if deterministic numbers for common foods become a product goal.

### Privacy of a cross-user cache

A meal description is health-adjacent free text and can carry identifying detail: a brand tied to a condition, a restaurant and city ("iced Vietnamese coffee from Sunshine's Bakery" is in the dev data), a name ("grandma's spaghetti"), a medication. A shared cache keyed on that text stores one athlete's words where another athlete's request can hit them. The response leaks nothing directly, since the hit returns macros, but the table itself is a store of user text detached from its owner, which complicates deletion requests and the privacy policy's description of how inputs are used. If it is ever built: cache only inputs that pass a strict shape (short, no digits beyond quantities, every token in a food vocabulary), store the normalised key and the result with no user id, write an entry only after two different athletes have produced the same key, and say so in the privacy policy. Given the 7% ceiling seen in dev, the recommendation is not to build it.

## Part 4. App attestation

### What already protects the model endpoints

Every model-calling function requires a Supabase JWT. `_shared/ai/credits.ts` calls `ensure_allowance`, which grants the monthly allowance only when the entitlement is active, and returns 402 when the wallet is empty. `_shared/vana/rate-limit.ts` limits calls per user from `vana_calls`. So the design the research recommends as "most protection for least work" (an entitlement gate fed by RevenueCat webhooks plus a per-user budget) is already in place. Its gaps are narrower than "no protection":

- `ensureAndCheckCredits` and `checkRateLimit` both fail open on a database error.
- Openers debit nothing and have no daily cap (cost doc, item 3 of "Ship on Oct 1").
- A trial gets the full allowance today (cost doc, item 2).
- The RevenueCat webhook must reject SANDBOX events on prod, or a sandbox purchase grants a real allowance. Worth a check in `revenuecat-webhook`. Note the project memory: the prod webhook is deliberately environment-unfiltered for other reasons, so this needs the owner's ruling, not a quiet fix.

With those closed, an abuser needs a store account with a payment method per trial (Apple grants one intro offer per subscription group per customer, Google one per subscription ([Apple](https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/), [Google](https://support.google.com/googleplay/android-developer/answer/12154973))) and can burn at most the trial grant: 150 credits, under $5.

### Apple App Attest and DeviceCheck

Flow ([Apple](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)): `generateKey()` makes a Secure Enclave key, `attestKey()` runs once against a server challenge, `generateAssertion()` signs each sensitive request. Server checks ([Apple](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)): decode the CBOR attestation, verify the `x5c` chain to Apple's App Attest root, check the nonce extension, the key id, the App ID hash, counter zero and the environment `aaguid`; per assertion, verify the signature with the stored public key and require a strictly increasing counter. The fraud receipt gives an approximate count of attestations per device over 30 days ([Apple](https://developer.apple.com/documentation/devicecheck/assessing-fraud-risk)). No fee is stated (free, UNVERIFIED in writing). Limits are far above this app's scale. Check `isSupported`; the simulator is unsupported (UNVERIFIED on these pages, widely known). Apple says it "can't definitively pinpoint a device with a compromised operating system". It does not stop a real app driven on a jailbroken phone, a device farm, or many accounts on one device. DeviceCheck's two per-device bits can mark "this device already had a trial".

### Google Play Integrity

Standard requests (warm-up, a few hundred ms, `requestHash`) or classic (seconds, nonce, 5 per app instance per minute) ([overview](https://developer.android.com/google/play/integrity/overview), [classic](https://developer.android.com/google/play/integrity/classic)). Verdicts: `appRecognitionVerdict`, `deviceRecognitionVerdict`, `appLicensingVerdict` ([verdicts](https://developer.android.com/google/play/integrity/verdicts)). Quota 10,000 requests a day, increases take up to a week ([setup](https://developer.android.com/google/play/integrity/setup)); no price stated (UNVERIFIED as free). Standard tokens must be decoded by Google's `decodeIntegrityToken` endpoint with a service account ([standard](https://developer.android.com/google/play/integrity/standard)). Failure modes: emulators, debug and sideloaded builds (UNRECOGNIZED_VERSION, UNLICENSED), devices without Play services, custom ROMs. Exact per-case mapping and internal-track behaviour UNVERIFIED.

### Flutter packages (pub.dev, 2026-09-20)

| Package | Version, age | Likes | Publisher | App Attest assertions |
|---|---|---|---|---|
| [firebase_app_check](https://pub.dev/packages/firebase_app_check) | 0.4.8, 6 days | 207 | firebase.google.com | Managed |
| [app_device_integrity](https://pub.dev/packages/app_device_integrity) | 1.1.0, 21 months | 36 | bubotech.co | No |
| [app_attest_integrity](https://pub.dev/packages/app_attest_integrity) | 1.0.0, 13 months | 12 | bam.tech | Yes |
| [app_attest](https://pub.dev/packages/app_attest) | 0.2.1, 48 days | 3 | unverified | Yes |
| [device_integrity](https://pub.dev/packages/device_integrity) | 1.0.3, 16 days | 4 | unverified | Yes |
| [play_integrity_flutter](https://pub.dev/packages/play_integrity_flutter) | 0.0.1, 3 years | 6 | unverified | n/a |

Everything except Firebase is small enough that adopting it means maintaining a fork. Firebase App Check wraps App Attest, Play Integrity and reCAPTCHA on web, and a non-Firebase backend can verify its token: fetch the JWKS at `https://firebaseappcheck.googleapis.com/v1/jwks`, verify RS256, check `iss`, `aud` and `exp` ([Firebase](https://firebase.google.com/docs/app-check/custom-resource-backend)). `jose` in Deno can do that (not shown in a Supabase doc, UNVERIFIED there). Replay protection is beta and Node Admin SDK only. reCAPTCHA is free to 10,000 assessments a month, then $8 to 100,000 ([Google](https://docs.cloud.google.com/recaptcha/docs/compare-tiers)). The debug provider covers simulators and CI ([Firebase](https://firebase.google.com/docs/app-check/flutter/debug-provider)). The cost is adding `firebase_core` and a Firebase project to a Supabase app.

### Verification in a Deno edge function

Raw App Attest: `npm:` and `node:crypto` `X509Certificate` are available in Deno ([Deno](https://docs.deno.com/runtime/fundamentals/node/)); `node-app-attest` offers `verifyAttestation` and `verifyAssertion` ([GitHub](https://github.com/uebelack/node-app-attest)). Whether these run in the Supabase edge runtime is UNVERIFIED and would be the first spike. Store `(key_id, user_id, public_key, counter, env)` in Postgres. Each assertion costs one read, one counter write and an ECDSA verify, a few ms of CPU plus a round trip (my estimate). The lighter pattern is to attest once per session and mint a short-lived server token, which is what App Check does; it reopens replay for the token's lifetime.

### Staged rollout, if it is ever needed

1. Log only: the client sends the token, the function records the verdict beside each `vana_calls` and `ai_usage` row, nothing is refused. Two weeks shows the share of real traffic that fails (old OS, custom ROMs, web).
2. Soft: unattested clients get a smaller daily budget.
3. Enforce on the model-calling functions only (`vana-chat`, `describe-meal`, `analyze-meal-photo`, `ai-coach`, `vana-day-notes`), never on sync or auth.
4. Web and debug builds need an allowlist path (reCAPTCHA, a debug token). Whatever a script can imitate on that path is the new weakest point. Firebase's guidance is to enforce only when legitimate traffic is nearly all verified ([Firebase](https://firebase.google.com/docs/app-check/monitor-metrics)).

### Cheaper guards

- Supabase Auth rate limits: sign-ups and sign-ins 30 per 5 minutes per IP, anonymous sign-ins 30 an hour, all configurable ([Supabase](https://supabase.com/docs/guides/auth/rate-limits)).
- CAPTCHA on sign-up: hCaptcha and Turnstile are supported and Dart `signUp` takes `captchaToken` ([Supabase](https://supabase.com/docs/guides/auth/auth-captcha)). Easy on web, moderate on mobile (WebView, hostname check). Add it to the web build only.
- Email confirmation is off on dev and not set up (project memory). Turning it on for prod raises the cost of an account.
- Per-IP limits: Supabase's documented Upstash example keys on the user id, not the IP ([Supabase](https://supabase.com/docs/guides/functions/examples/rate-limiting)). Reading `x-forwarded-for` is undocumented (UNVERIFIED). The existing per-user limiter is the better key.
- Require an active trial or subscription before any model call: already true through `ensure_allowance`.

Effect: $0 per subscriber in normal operation. Attestation is L effort for a threat the paywall already prices at under $5 per abusive account. Not worth it now. The S-sized work is the four gaps listed at the top of this part. Owner decides: fail open or fail closed on the credit check, and the sandbox-event question.

## Part 5. Measurements from dev

Cost formula used on `vana_calls`, matching the cost doc's upper bound: `((input - cache_read) x 1.25 + cache_read x 0.10 + output x 5) / 1e6` for Haiku, 3.75 / 0.30 / 15 for Sonnet. Rows before 09-15 have no cache read logged and are priced as fully uncached.

### (a) Chip taps against typed text

The data does not distinguish them. `contracts.ts` says "chip taps are plain user messages", and no `vana_messages` row with role `user` has any metadata (536 of 536 are empty). Proxy: a user message counts as a chip tap when its text equals an option the previous assistant message offered (`choices.options` or `meal_picker.chips`), or one of the app's own picker chips ("I like these", "Other options", "Next: ...", "That's my week").

| Kind | User messages | Matched an offered option | Matched an app chip | Chip share | Mean length |
|---|---|---|---|---|---|
| meal_planning | 264 | 71 | 57 | 48% | 23 chars |
| general | 272 | 4 | 0 | 1.5% | 51 chars |

General chat is mostly the eval script (one account, the same questions 5 to 21 times), so its figure says nothing about athletes. The proxy undercounts taps whose label the app rewrites and overcounts anyone who types a label by hand.

Most common labels in planning: "I like these" 32, "Batch-cook staples" 20, "That's my week" 13, "Dinners only" 10, "Dinners and lunches" 10, "Next: <type>" 10, "Confirm my plan" 10, "Not those, show me other options" 8, "Under 20 min" 7, "Use what I have" 6, "Draft my whole week" 5, "Other options" 5, "No recipe only" 5.

"I like these", "Next: <type>", "Other options", "Not those" and "That's my week" are 68 of 264 planning turns, 26%. Each has a fixed meaning the server could act on without a model call, at the cost of the fresh two-sentence rationale. Worth about $0.22 a month for the typical athlete today and $0.08 after the caching fix. Owner decision, row 8 of the summary.

What to log: on every user message write `metadata.input` as `chip_app`, `chip_model`, `typed`, `widget` or `voice`, and the chip label. The cost doc's logging list already asks for this; the proxy above is what to replace.

### (b) Cost per outcome

Planning conversations, all 230, $10.39 in total:

| Bucket | Conversations | Calls | Spend | Share of spend | Mean user messages |
|---|---|---|---|---|---|
| A. Confirmed (a `confirmPlan` tool call, or the plan row is `confirmed` now) | 18 | 79 | $1.88 | 18% | 3.3 |
| B. Plan has meals, no sign of a confirm | 43 | 115 | $2.84 | 27% | 1.7 |
| C. No plan meals at all | 169 | 284 | $5.67 | 55% | 0.8 |

- Inside a confirmed conversation a plan costs $0.10 (4.4 calls). Counting all planning spend against the 18 confirmed plans, a confirmed plan costs $0.58.
- 82% of planning spend sits in conversations with no evidence of a confirm. Bucket B is uncertain: 47 plans are `archived`, and an archived plan may once have been confirmed from the plan bar, which makes no model call and leaves no trace. `meal_plans` needs a `confirmed_at` column to settle it.
- Conversations with one user message or none: 173 of 230, $4.64, 45% of planning spend. Of that, 88 conversations with no reply at all cost $1.63, all of it openers.
- General chat, $2.97 in total: 139 of 157 conversations have one user message or none and take $1.67, 56%. Mostly the eval script.
- Logged meals: 46 describe calls produced 44 logs, so $0.0080 per describe-logged meal. 37 photo calls produced 29 logs (1.28 calls per log, retakes and the "not food" case), so about $0.0166 per photo-logged meal. Across all 240 logs of every source the model cost is $0.0033 per logged meal, because 65% of logs never touch a model.

Dev inflates abandonment: developers open the planning screen to look at it. Even at half this rate, an opener drafted on screen open is the largest single source of spend with no outcome.

### (c) Opener reuse

`vana_calls` does not record the screen, and `vana_conversations.context` holds the Doll, not the Situation. Proxy for "same screen": same user and same opener kind.

| Opener kind | Openers | Spend | Another within 10 min | Within 30 min | Within 10 min and the earlier one got no reply | Within 30 min, no reply | Spend on those (30 min) |
|---|---|---|---|---|---|---|---|
| meal_planning | 194 | $3.69 | 130 (67%) | 149 (77%) | 56 (29%) | 64 (33%) | $1.14 (31%) |
| general | 28 | $0.30 | 10 (36%) | 13 (46%) | 5 (18%) | 6 (21%) | $0.07 (23%) |

The safe case for reuse is the unanswered one: the athlete left and came back, nothing was said, and the same draft is still true unless the plan or the Doll changed. Reusing it for 30 minutes would have saved 31% of planning opener spend in dev, 27% at 10 minutes. Hot restarts and test runs inflate this. For the typical athlete (one planning and seven general openers a week, $0.36 a month) a realistic saving is 3 to 8 cents. It matters more as an abuse bound: reopening a screen in a loop stops costing anything. Log the Situation's screen key on `vana_calls` so the real figure can be read in October.

### (d) Background calls on short conversations

| Function | Calls | On conversations with 1 user message | With 2 | With 3 or more | Spend | Spend on 2 or fewer |
|---|---|---|---|---|---|---|
| vana.extract | 81 | 72 | 1 | 8 | $0.157 | $0.127 |
| vana.episode | 5 | 0 | 0 | 5 | $0.010 | $0 |
| vana.summary | 2 | 0 | 0 | 2 | $0.006 | $0 |

73 of 81 extract calls (90%) ran on conversations with two or fewer user messages. Episode and summary already wait for longer conversations. The whole extract line is $0.0016 a call and about 5 cents a month for the typical athlete, and a one-message conversation such as "remember that I cannot stand the smell of cooked broccoli" is exactly what extraction exists for. A rule that skips extraction when the only user message was a chip tap would be safe once (a) is logged. Saving under 4 cents. Not worth its own ticket.

### SQL

```sql
-- inventory
select 'meal_logs_by_source' k, source v, count(*) n, count(distinct user_id) users from meal_logs group by source
union all select 'ai_usage', function_name||' / '||model, count(*), count(distinct user_id) from ai_usage group by 2
union all select 'vana_calls', function_name||' / '||coalesce(model,''), count(*), count(distinct user_id) from vana_calls group by 2
union all select 'vana_messages_role', role, count(*), count(distinct user_id) from vana_messages group by role
union all select 'vana_conv_kind', kind, count(*), count(distinct user_id) from vana_conversations group by kind order by 1,3 desc;

-- Part 3: describe and photo logs (the model's name for the meal; the input is not stored)
select source, lower(trim(name)) as name, jsonb_array_length(coalesce(items,'[]'::jsonb)) n_items, calories,
       substr(user_id::text,1,4) u, log_date
from meal_logs where source in ('describe','photo') and not is_deleted order by source, created_at;

-- (a) do user messages carry any metadata?
select role, k, count(*) from vana_messages m
left join lateral jsonb_object_keys(coalesce(m.metadata,'{}'::jsonb)) k on true group by 1,2 order by 1,3 desc;

-- (a) chip proxy
with msgs as (
  select m.*, c.kind conv_kind,
    lag(m.metadata) over (partition by m.conversation_id order by m.created_at) prev_meta
  from vana_messages m join vana_conversations c on c.id=m.conversation_id
), u as (
  select msgs.*,
   (select array_agg(lower(o)) from jsonb_array_elements(case when jsonb_typeof(prev_meta->'ui_parts')='array' then prev_meta->'ui_parts' else '[]'::jsonb end) p,
      jsonb_array_elements_text(coalesce(p->'options', p->'chips', '[]'::jsonb)) o) offered,
   exists(select 1 from jsonb_array_elements(case when jsonb_typeof(prev_meta->'ui_parts')='array' then prev_meta->'ui_parts' else '[]'::jsonb end) p where p->>'kind'='meal_picker') prev_picker
  from msgs where role='user'
)
select conv_kind, count(*) user_msgs,
  count(*) filter (where lower(trim(content)) = any(offered)) matched_offered_chip,
  count(*) filter (where not (lower(trim(content)) = any(coalesce(offered,'{}'))) and (lower(trim(content)) in ('i like these','other options','that''s my week','confirm','review') or lower(trim(content)) like 'next: %')) matched_app_chip,
  count(*) filter (where offered is not null or prev_picker) had_chips_available,
  round(avg(length(content))) avg_len
from u group by 1;

-- (a) most common user messages
select c.kind, case when lower(trim(m.content)) like 'next: %' then 'next: <type>' else lower(trim(left(m.content,60))) end label,
       count(*) n, count(distinct m.user_id) users
from vana_messages m join vana_conversations c on c.id=m.conversation_id
where m.role='user' group by 1,2 having count(*)>=3 order by 3 desc limit 40;

-- (b) plan status
select status, is_deleted, count(*), count(conversation_id) with_conv from meal_plans group by 1,2;

-- (b) planning spend by outcome
with cost as (
  select conversation_id, count(*) calls,
   sum(case when model like '%sonnet%' then ((input_tokens-coalesce(cache_read_tokens,0))*3.75 + coalesce(cache_read_tokens,0)*0.30 + output_tokens*15)/1e6
            else ((input_tokens-coalesce(cache_read_tokens,0))*1.25 + coalesce(cache_read_tokens,0)*0.10 + output_tokens*5)/1e6 end) usd
  from vana_calls where conversation_id is not null and function_name<>'vana.embed' group by 1),
conv as (
  select c.id,
    (select count(*) from vana_messages m where m.conversation_id=c.id and m.role='user') user_msgs,
    (exists(select 1 from vana_messages m where m.conversation_id=c.id and m.role='assistant' and (m.metadata->'tool_calls')::text ilike '%confirmPlan%')
      or exists(select 1 from meal_plans p where p.conversation_id=c.id and p.status='confirmed')) confirmed,
    exists(select 1 from meal_plans p join plan_meals pm on pm.plan_id=p.id where p.conversation_id=c.id) plan_with_meals
  from vana_conversations c where c.kind='meal_planning')
select case when confirmed then 'A confirmed' when plan_with_meals then 'B plan has meals' else 'C no plan meals' end bucket,
 count(*) convs, sum(calls) calls, round(sum(usd)::numeric,2) usd, round(avg(user_msgs),1) avg_user_msgs,
 count(*) filter (where user_msgs<=1) convs_le1, round(sum(usd) filter (where user_msgs<=1)::numeric,2) usd_le1
from conv left join cost on cost.conversation_id=conv.id group by 1 order by 1;
-- A second query with the same CTEs grouped by kind and user-message bucket (0, 1, 2, 3+) gave the general-chat
-- figures and the 88 no-reply planning conversations.

-- (c) opener reuse
with o as (
  select v.*, ((input_tokens-coalesce(cache_read_tokens,0))*1.25 + coalesce(cache_read_tokens,0)*0.10 + output_tokens*5)/1e6 usd,
    lag(created_at) over (partition by user_id, function_name order by created_at) prev_at,
    lag(conversation_id) over (partition by user_id, function_name order by created_at) prev_conv
  from vana_calls v where function_name like 'vana.opener%' and model like '%haiku%'),
f as (select o.*, (select count(*) from vana_messages m where m.conversation_id=o.prev_conv and m.role='user') prev_conv_user_msgs from o)
select function_name, count(*) openers, round(sum(usd)::numeric,2) usd,
 count(*) filter (where created_at-prev_at <= interval '10 min') within10,
 count(*) filter (where created_at-prev_at <= interval '30 min') within30,
 count(*) filter (where created_at-prev_at <= interval '10 min' and prev_conv_user_msgs=0) within10_prev_unanswered,
 count(*) filter (where created_at-prev_at <= interval '30 min' and prev_conv_user_msgs=0) within30_prev_unanswered,
 round(sum(usd) filter (where created_at-prev_at <= interval '30 min' and prev_conv_user_msgs=0)::numeric,2) usd30_unans
from f group by 1;

-- (d) background calls by conversation length
with b as (select v.function_name, v.conversation_id,
  ((input_tokens-coalesce(cache_read_tokens,0))*1.25 + coalesce(cache_read_tokens,0)*0.10 + output_tokens*5)/1e6 usd,
  (select count(*) from vana_messages m where m.conversation_id=v.conversation_id and m.role='user') user_msgs_total
  from vana_calls v where function_name in ('vana.extract','vana.episode','vana.summary'))
select function_name, count(*) calls, round(sum(usd)::numeric,3) usd,
 count(*) filter (where user_msgs_total=1) m1, count(*) filter (where user_msgs_total=2) m2,
 count(*) filter (where user_msgs_total>=3) m3plus, round(sum(usd) filter (where user_msgs_total<=2)::numeric,3) usd_le2
from b group by 1;
```

## Decisions for the owner

1. Is the Apple Small Business Program enrolment approved, and from what date? If unknown, check App Store Connect today.
2. Apply to AWS Activate Founders: yes or no. If yes, route (a) only background and meal-logging calls to Bedrock, or (b) everything.
3. Planning opener: (a) draft on screen open as now, (b) draft on first intent, (c) draft on open but reuse an unanswered draft for 30 minutes.
4. Deterministic chips without a model call: (a) no, keep the fresh rationale, (b) yes for "Other options" and "Next" only, (c) yes for all five.
5. Web checkout: (a) not before 2027, (b) an annual-plan experiment on iOS US after the founding window closes.
6. Meal logging: (a) on-device suggestions from saved and recent meals plus the small-model eval, no database tier, (b) also build the FDC alias tier.
7. Credit and rate-limit checks fail open today. (a) keep, (b) fail closed on the model endpoints.
8. Sandbox RevenueCat events on prod: confirm they cannot grant a real allowance.

## Sources

Store fees and link-outs
- https://developer.apple.com/app-store/small-business-program/
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/app-store/review/guidelines/
- https://www.revenuecat.com/blog/engineering/small-business-program
- https://support.google.com/googleplay/android-developer/answer/112622
- https://support.google.com/googleplay/android-developer/answer/16954621
- https://support.google.com/googleplay/android-developer/answer/10632485
- https://support.google.com/googleplay/android-developer/answer/16470497
- https://support.google.com/googleplay/android-developer/answer/16497028
- https://support.google.com/googleplay/android-developer/answer/17161464
- https://android-developers.googleblog.com/2026/06/play-expanded-billing.html
- https://www.fenwick.com/insights/publications/ninth-circuit-largely-upholds-ruling-in-epic-v-apple
- https://www.courthousenews.com/apples-fight-over-commissions-for-linked-out-app-store-purchases-continues-in-federal-court/
- https://www.supremecourt.gov/search.aspx?filename=/docket/docketfiles/html/public/25-1311.html
- https://www.techtimes.com/articles/327527/20260915/app-store-commission-limbo-enters-new-phase-apples-epic-merits-brief-opens-scotus-fight.htm
- https://www.macobserver.com/news/apple-epic-link-out-commission-proposal-15-percent/

RevenueCat web, Stripe, Paddle
- https://www.revenuecat.com/pricing/
- https://www.revenuecat.com/blog/company/introducing-revenuecat-billing
- https://www.revenuecat.com/docs/web/web-billing/web-purchase-links
- https://www.revenuecat.com/docs/web/redemption-links
- https://www.revenuecat.com/docs/web/web-billing/configuring-overview
- https://www.revenuecat.com/docs/web/web-billing/tax
- https://www.revenuecat.com/docs/web/web-billing/subscription-lifecycle
- https://www.revenuecat.com/docs/web/integrations/stripe
- https://www.revenuecat.com/docs/web/integrations/paddle
- https://www.revenuecat.com/blog/growth/iap-vs-web-purchases-conversion-test/
- https://stripe.com/pricing
- https://stripe.com/guides/introduction-to-saas-taxability-in-the-us
- https://stripe.com/resources/more/sales-tax-nexus-laws
- https://www.paddle.com/pricing
- https://www.lemonsqueezy.com/pricing

Credits and BYOK
- https://claude.com/programs/startups
- https://vercel.com/docs/ai-gateway/pricing
- https://vercel.com/docs/ai-gateway/faq
- https://vercel.com/ai-gateway/models?freeTier=true
- https://vercel.com/startups/credits
- https://vercel.com/blog/2026-vercel-ai-accelerator-recap
- https://vercel.com/docs/ai-gateway/authentication-and-byok/byok
- https://vercel.com/docs/ai-gateway/models-and-providers/provider-options
- https://vercel.com/docs/ai-gateway/models-and-providers/automatic-caching
- https://ai-gateway.vercel.sh/v1/models/anthropic/claude-haiku-4.5/endpoints
- https://supabase.com/solutions/startups
- https://supabase.com/docs/guides/platform/credits
- https://mercury.com/perks
- https://aws.amazon.com/startups/credits
- https://aws.amazon.com/blogs/startups/aws-activate-credits-now-accepted-for-third-party-models-on-amazon-bedrock/
- https://aws.amazon.com/awscredits/
- https://docs.aws.amazon.com/bedrock/latest/userguide/prompt-caching.html
- https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- https://startup.google.com/cloud/
- https://www.microsoft.com/en-us/startups
- https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-claude

Food data
- https://fdc.nal.usda.gov/api-guide/
- https://fdc.nal.usda.gov/download-datasets/
- https://fdc.nal.usda.gov/data-documentation/
- https://world.openfoodfacts.org/terms-of-use
- https://openfoodfacts.github.io/openfoodfacts-server/api/
- https://opendatacommons.org/licenses/odbl/summary/
- https://docx.syndigo.com/developers/docs/nutritionix-api-guide
- https://developer.edamam.com/edamam-nutrition-api
- https://developer.edamam.com/food-database-api
- https://platform.fatsecret.com/api-editions
- https://platform.fatsecret.com/terms
- https://platform.fatsecret.com/docs/guides/storable-data
- https://www.passio.ai/pricing
- https://www.passio.ai/cost-breakdown
- https://pub.dev/packages/nutrition_ai
- https://pub.dev/packages/mobile_scanner
- https://spoonacular.com/food-api/pricing
- https://calorieninjas.com/pricing
- https://api-ninjas.com/pricing
- https://dev.caloriemama.ai/

Attestation and guards
- https://developer.apple.com/documentation/devicecheck
- https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity
- https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
- https://developer.apple.com/documentation/devicecheck/assessing-fraud-risk
- https://developer.apple.com/documentation/devicecheck/preparing-to-use-the-app-attest-service
- https://developer.android.com/google/play/integrity/overview
- https://developer.android.com/google/play/integrity/verdicts
- https://developer.android.com/google/play/integrity/setup
- https://developer.android.com/google/play/integrity/standard
- https://developer.android.com/google/play/integrity/classic
- https://firebase.google.com/docs/app-check/custom-resource-backend
- https://firebase.google.com/docs/app-check/flutter/default-providers
- https://firebase.google.com/docs/app-check/flutter/debug-provider
- https://firebase.google.com/docs/app-check/monitor-metrics
- https://docs.cloud.google.com/recaptcha/docs/compare-tiers
- https://docs.deno.com/runtime/fundamentals/node/
- https://github.com/uebelack/node-app-attest
- https://supabase.com/docs/guides/auth/rate-limits
- https://supabase.com/docs/guides/auth/auth-captcha
- https://supabase.com/docs/guides/functions/examples/rate-limiting
- https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields
- https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-introductory-offers-for-auto-renewable-subscriptions/
- https://support.google.com/googleplay/android-developer/answer/12154973

Not verified on a primary page: Apple's fiscal-month effective dates for October, the reported Apple link-out commission proposal, whether the new US Play fee needs an Account Group, whether RevenueCat Web Billing avoids Stripe Billing's 0.7%, Anthropic credit tiers, the $5 gateway free credit, AWS credit expiry and new-account Bedrock quotas, Google's exclusion of partner models from credits, Nutritionix pricing, Vertex prompt caching details, App Attest and Play Integrity being free, simulator support, and whether `node-app-attest` runs in the Supabase edge runtime. The Google Play fee change of 2026-06-30 and the Supreme Court grant of 2026-06-30 post-date my own knowledge and rest entirely on the subagent's reading of the linked pages.
