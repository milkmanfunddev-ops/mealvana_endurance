# Gamification and Monetization Strategy

- Source URL: https://app.notion.com/p/12ee3fdb754c80deb9e3d714667cebbf
- Created: 2024-10-29
- Snapshot date: 2024-11-14
- Ancestor path: Strategy and Research (database) → Homepage
  - https://app.notion.com/p/19ee3fdb754c80d68bc7d95c380d5ad7
  - https://app.notion.com/p/199e3fdb754c8074bbbfe11afe559dee ("Homepage")
- Page properties: Category "product development"

Note: transcribed in full per task instructions; only the "Weekly Meal Planning" gamification example is meal-planning-specific, but the whole page (fortune-cookie virtual currency system) is captured below, including its 8 inline/page comment threads (all included verbatim, none resolved).

## Gamification Structure for Mealvana

### Objective
This proposal presents a gamified virtual currency system to boost engagement and strategically drive monetization in Mealvana. By introducing "fortune cookies" as a currency users can earn or purchase, we create opportunities for increased user retention and optional in-app spending. The system will encourage both consistent engagement and microtransactions, providing revenue potential without a restrictive subscription model.

---

### 1. Gamification and Monetization Mechanism (Fortune Cookies as Virtual Currency)

**Overview:**
The fortune cookie system combines habitual user engagement with opportunities for monetization. Users will initially receive a free allotment of fortune cookies (e.g., 100) `[COMMENT THREAD — see below]`, which they can use to explore features within the app. As they run low, users are incentivized to either earn more through activities or purchase additional cookies to maintain access to premium features.

#### Key Monetization Strategies:
- **Tiered Cookie Purchases:** Offering cookie bundles at multiple price points (e.g., $0.99 for 100 cookies, $4.99 for 600 cookies, $9.99 for 1,300 cookies `[COMMENT THREAD]`) allows flexibility, encouraging microtransactions for those who prefer gradual spending, while also catering to users willing to make larger one-time purchases.
- **Incentivized Spending:** Premium features like advanced meal plans, detailed nutrition information, and exclusive coupons are locked behind cookies, subtly encouraging spending without impacting essential functions. This balance enables us to reach a wide user base while creating natural conversion points to paid content.
- **Special Offers and Event Bundles:** Seasonal or limited-time offers on cookie bundles (e.g., holiday sales, New Year's fitness kick-off discounts) increase purchase likelihood by creating a sense of urgency and aligning with users' lifestyle needs.

#### Earning Fortune Cookies:
- **Daily Engagement:** Users earn cookies by logging in consistently, with bonus cookies for maintaining streaks (e.g., extra cookies for a 7-day streak).
- **Weekly Meal Planning:** Completing a weekly meal plan grants cookies to encourage regular planning habits.
- **Providing Feedback or Taking Surveys:** Users who provide feedback or complete surveys earn additional cookies, providing us valuable user insights.
- **Recipe Sharing and Social Engagement:** Users earn cookies for sharing recipes or meal plans on social media, helping boost app visibility.
- **Referrals:** Users can earn cookies by inviting friends who sign up and engage with the app.

#### Spending Fortune Cookies:
- **Unlocking Premium Meal Plans:** `[COMMENT THREAD]` Cookies can unlock curated or specialized meal plans (e.g., family-friendly, low-carb, seasonal).
- **Access to Nutrition Information:** `[COMMENT THREAD]` Users can use cookies to access in-depth nutritional information for each recipe or meal plan.
- **Importing Recipes:** `[COMMENT THREAD]` Users can spend cookies to import recipes directly from URLs or images, saving time on data entry.
- **Exclusive Coupons and Deals:** `[COMMENT THREAD]` Users can unlock coupons, grocery deals, or discount codes with cookies, adding value for those planning meals on a budget.
- **Customization Options:** `[COMMENT THREAD]` Cookies could unlock customization features, such as editing meal plan templates, adding themes, or filtering recipes based on dietary needs.

---

### 2. Implementation Examples (User Journey)

**Example 1: Weekly Meal Planner**
- *User Action*: A user logs in every Monday to plan their meals for the week.
- *Reward* `[COMMENT THREAD]`: Upon completing the weekly meal plan, the user receives 10 cookies.
- *Optional Spending*: The user can spend these cookies on viewing exclusive nutrition details for each meal.

**Example 2: Daily Cooking Habit**
- *User Action*: A user logs in daily and marks each meal as "cooked" to maintain a streak.
- *Reward*: The user earns 5 cookies each day and an additional 20 cookies if they complete a 7-day streak.
- *Optional Spending*: The user spends cookies on personalized recipe suggestions based on their cooking history.

**Example 3: Social and Community Engagement**
- *User Action*: The user shares their weekly meal plan on social media.
- *Reward*: The user earns 15 cookies for social sharing and an additional 20 cookies for each friend they invite who signs up.
- *Optional Spending*: `[COMMENT THREAD]` Cookies can unlock group meal plans to share with their new friends on the app.

---

### 3. Apple Store Considerations for Monetization
Ensuring Mealvana's monetization strategy aligns with Apple's guidelines is key to a successful launch and ongoing App Store compliance.
1. **In-App Purchase System (IAP) Setup**: All cookie purchases must be set up through Apple's IAP system, with Mealvana retaining 70-85% of the revenue after Apple's standard 15-30% commission.
2. **User-Friendly Pricing Tiers:** Apple users tend to respond best to tiered pricing, with options for smaller, more frequent purchases alongside larger-value bundles. By testing various bundle sizes (e.g., 100 cookies for $0.99, 500 for $4.99), we can find an optimal balance that caters to diverse user preferences and maximizes revenue.
3. **Restore Purchase Option and Account Security**: Apple requires that all purchases be restorable, so we will link purchases to the user's Apple ID for continuity across devices. This will minimize user frustration and avoid the need for refund requests.
4. **Transparent Descriptions of Cookie Usage:** Apple mandates clear descriptions of any in-app purchase items. Each spendable feature, such as premium meal plans, coupon access, and recipe importing, will have in-app explanations to prevent confusion and streamline the App Store review process.

---

### 4. Aspirant Apps with Similar Systems
Here are successful apps with gamified virtual currency systems that have inspired Mealvana's model:
- **Duolingo**
  - *Currency*: Gems (virtual currency).
  - *Mechanism*: Gems are earned through lesson completion and spent on accessing bonus content. Duolingo's streaks and daily challenges promote regular use, which has proven effective in maintaining high user engagement.
- **MyFitnessPal**
  - *Mechanism*: Gamified streaks and achievements are rewarded for consistently logging meals and exercise. While not currency-based, its rewards for habit formation have successfully promoted consistent use.
- **Pokemon Go**
  - *Currency*: Pokecoins.
  - *Mechanism*: Earned through in-game actions and can be spent on premium items. Its daily engagement and reward system have created a strong habit-forming loop.
- **Sweatcoin**
  - *Currency*: Sweatcoins.
  - *Mechanism*: Users earn Sweatcoins based on daily steps and can exchange them for rewards or donate to charity. It's a strong model for building user loyalty and habit formation through rewards.

---

### Next Steps
1. **Initial Implementation and Testing:** Develop a basic fortune cookie earning and spending system, focusing first on weekly meal planning and daily cooking interactions.
2. **User Testing and Feedback:** Conduct a pilot test to gather user feedback on the fortune cookie system. Adjust rewards and costs as needed to ensure the balance is engaging `[COMMENT THREAD]` but fair.
3. **In-App Purchase Setup in App Store Connect:** Set up IAP tiers for fortune cookies `[COMMENT THREAD]` and ensure secure handling of transaction data.
4. **Launch and Monitor Analytics:** Track user engagement, cookie purchases, and feature usage. This data will help us understand the system's effectiveness and make adjustments to optimize retention and monetization.

---

## Brainstorm for Design and Wording
- Whenever a user gets to a feature and it is behind a game token, potential wording:
  - "This is a premium feature"
  - "Would you like to unlock this premium feature for 1 month?"
  and then if it's part of a free trial or they are using it for the first time it can say:
  - "unlock 0" with the image of the cookie
  - "start free trial 0" with the image of the cookie
- Whenever the user gains a cookie we can use the same design as the "Congratulations you created a meal plan" pop-up, but instead of "Close" at the bottom it can say "Claim 1" with the image of cookie (and the one can be subbed for whatever amount makes sense)
- On the meal plan page where we show the amount of cookies that they have we should also include a plus button as a way to demonstrate that they can pay to get more

[image: screenshot from a mobile game showing a green "+" button next to a currency counter — used as a reference for how to indicate users can buy more coins/keys]

*I gave a couple examples of what this might look like on the figma components page* — links to an embedded external object (Figma components reference), not resolvable via this tool (block id `13ee3fdb-754c-8074-b57b-d40d40865494`).

---

## Comments/Discussion

8 discussion threads found on this page (all unresolved, all page/inline comments — no replies beyond what's listed):

1. **Inline, anchored near "Reward: Up...0 cookies."** (Example 1 — Weekly Meal Planner reward)
   - Faith Good (faith.l.good@gmail.com), 2024-10-31T14:28:44.427Z: "Because the automation of creating a meal plan is so fast and easy are we not worried about a user creating a bunch of fake meal plans to earn point toward what they want and then just use the past meal plans feature to go back to the actual meal plan"
   - Faith Good, 2024-10-31T14:29:20.458Z: "Or are you saying we will only reward them once a week?"

2. **Page-level comment**
   - Xuan (xh.analytics@gmail.com), 2024-10-30T14:58:34.445Z: "while I am writing this strategy, I also realize how complicated this system is going to be—I don't want us to jump into the deep end of it immediately, because is this the right thing for us to do?"

3. **Inline, anchored near "Users will...e.g., 100)"** (free allotment of fortune cookies)
   - Faith Good, 2024-10-31T14:24:54.609Z: "The only thing I am worried about with this is does this interest our target demographic"

4. **Inline, anchored near "e.g., $0.9...00 cookies"** (tiered cookie purchase pricing)
   - Faith Good, 2024-10-31T14:25:16.511Z: "This is really smart"

5. **Inline, anchored near "Unlocking ...ary needs."** (Customization Options spend category)
   - Faith Good, 2024-10-31T14:27:16.610Z: "I think with earning and spending we need to figure out an economic way that will not make them feel like they are always having to buy cookies to 'play' but still incentivizes them to spend some"

6. **Inline, anchored near "Cookies ca...n the app."** (Example 3 — group meal plans)
   - Faith Good, 2024-10-31T14:29:54.800Z: "I am not sure what you mean by a group meal plan"

7. **Inline, anchored near "b" (Next Steps #2, "engaging ... but fair")**
   - Lee Martin (lee.b.martin@gmail.com), 2024-10-31T14:42:02.706Z: "This is a good direction and I like it. We're just going to have to start off with an MVP"

8. **Inline, anchored near "cookies" (Next Steps #3, IAP tiers)**
   - Lee Martin (lee.b.martin@gmail.com), 2024-10-31T14:43:02.430Z: "MVP suggestions:"
