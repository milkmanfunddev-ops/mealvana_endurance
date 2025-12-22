# AI Dietitian - Structured Flow Scenario

## Scenario: "Race Day Nutrition Wizard"

### Overview
A wizard-style flow with clear steps, progress bars, and swipeable screens that integrates AI conversation at key touchpoints. Designed for users who want guided structure to create a comprehensive race day nutrition plan.

---

## Entry Point

User taps "Coach" tab → Sees contextual smart suggestion:

**AI Greeting Card:**
```
👋 Hi [User Name]!

I see you have Boston Marathon coming up in 3 weeks.

What would you like to create today?
□ Race Day Nutrition Plan (Recommended for Boston)
□ Carb Loading Protocol
□ Weekly Training Meal Plan
□ Ask Me Anything (Open Chat)
```

User selects: **"Race Day Nutrition Plan"**

---

## Step 1: Event Selection

**Screen Title:** "Select Your Event"
**Progress:** 1/6 steps complete

**UI Elements:**
- Search bar: "Find your race or create custom event"
- Upcoming events from calendar:
  - ✅ Boston Marathon - Apr 21, 2025 (Selected)
  - Chicago Marathon - Oct 12, 2025
  - Weekly Long Run Template
- "+ Create New Event" button

**AI Conversation Panel (Bottom Sheet):**
```
AI: I pulled up your Boston Marathon! Let me confirm a few details:
• Distance: 26.2 miles
• Date: April 21, 2025
• Location: Boston, MA

I can also look up:
• Course elevation profile (lots of hills!)
• Weather forecast (as we get closer)
• Aid station locations

Is this the event you want to plan for?
```

User: "Yes, but I'm worried about the hills."

```
AI: Great question! The Newton Hills (miles 16-21) are legendary. Here's how we'll address them:

1. Extra carb loading to top off glycogen stores
2. Strategic fueling BEFORE the hills (mile 15)
3. Slower pace strategy to preserve energy
4. Mental preparation in your plan

Let's build a plan that accounts for this tough course!

[Continue] button
```

---

## Step 2: Goal & Context

**Screen Title:** "Tell Me About Your Goals"
**Progress:** 2/6 steps complete

**Form Fields:**
- Goal finish time: [3:30:00] (pre-filled from activity)
- Target pace: [8:00 min/mile] (auto-calculated)
- Have you run this distance before? ○ Yes ● No
- How's your gut training?
  - ○ Low (haven't practiced fueling)
  - ● Moderate (some practice, occasional issues)
  - ○ High (can tolerate 60-90g/hr comfortably)

**AI Conversation Panel:**
```
AI: I see you selected "Moderate" gut training. Let's talk about this because it's crucial for marathon success.

With moderate gut training, I'll plan for:
• 45-60g carbs/hour during the race
• Familiar foods you've tested in training
• Backup options if you experience GI distress

Have you been practicing fueling during your long runs? What products have you tried?
```

User: "I've used Maurten gels on my last 3 long runs. They work pretty well but I got a bit nauseous around mile 18."

```
AI: That's really valuable info! Mile 18 nausea is common and there are a few possible causes:

1. Dehydration (not drinking enough with gels)
2. Too many gels too close together
3. Hitting the wall (glycogen depletion)
4. Newton Hills fatigue combined with gel timing

I'll design your plan to:
✓ Space out Maurten gels properly (every 45 min)
✓ Include hydration cues with each gel
✓ Add a different carb source (sports drink) for variety
✓ Strategic fueling before mile 18

Sound good?
```

User: "Perfect, thanks!"

**[Continue to Next Step] button**

---

## Step 3: Food Preferences & Restrictions

**Screen Title:** "Your Food Preferences"
**Progress:** 3/6 steps complete

**UI Elements:**
- Dietary Preferences: ✓ Omnivore (from profile)
- Allergies: ✓ None (from profile)
- "Edit Preferences" link (goes to settings)

**Race Fuel Preferences (Interactive Selection):**
- Energy Gels:
  - ✅ Maurten Gel 100 (User has used)
  - ⭐ Gu Energy Gel
  - ⭐ Huma Chia Gel
  - ➕ Add more

- Sports Drinks:
  - ⭐ Gatorade Endurance
  - ⭐ Nuun Endurance
  - ➕ Add more

- Real Food Options (pre/post race):
  - ✅ Oatmeal (Liked)
  - ✅ Banana (Liked)
  - ✅ Bagel (Willing to try)
  - ✅ Rice (Liked)
  - ❌ Energy bars (Disliked)

**AI Conversation Panel:**
```
AI: Great! I have your preferences. A few quick questions:

1. Are you comfortable eating 2-3 hours before a 7am race start? (This means a 4-5am wake-up)

2. Do you prefer solid food or liquid nutrition before the race?

3. What about during the race - gels only, or would you like sports drinks at aid stations too?
```

User: "I can wake up at 4am. I like both solid and liquid before. During the race, I want both gels and drinks."

```
AI: Perfect! This gives us a lot of flexibility. Here's what I'm planning:

Pre-Race (4:00am):
• Solid carbs: Oatmeal with banana
• Liquid: Sports drink

During Race:
• Maurten gels (every 45 min)
• Gatorade at aid stations (every 20-30 min)
• Total: ~50g carbs/hour

This combination:
✓ Hits your carb target
✓ Provides variety (easier on stomach)
✓ Uses products you've tested
✓ Accounts for aid station availability

Ready to see your full plan?
```

User: "Yes!"

---

## Step 4: AI Generates Draft Plan

**Screen Title:** "Your Boston Marathon Nutrition Plan"
**Progress:** 4/6 steps complete

**Loading Animation:**
```
🔄 Creating your personalized race day nutrition plan...

✓ Analyzing course profile (Newton Hills noted)
✓ Calculating carb targets (50g/hour for moderate gut training)
✓ Selecting foods you love (Maurten, oatmeal, banana)
✓ Checking Boston Marathon aid stations (water every mile, Gatorade every 2 miles)
✓ Incorporating weather forecast (52°F, partly cloudy - perfect!)
```

**Plan Display (Scrollable Timeline):**

---

### BEFORE THE RACE

#### 3 Days Before (April 18-20) - Carb Loading

**Daily Target:** 8-10g carbs/kg body weight
(For 150 lb athlete: 545-680g carbs/day)

**Why:** Fill glycogen stores to maximum capacity. Research shows 2-3% performance improvement.

**Sample Day Structure:**
- Breakfast: Oatmeal (80g carbs) + Banana (27g) + Honey (17g) = 124g
- Snack: Bagel (45g) + Jam (13g) = 58g
- Lunch: Rice bowl (90g) + Chicken + Veggies = 90g
- Snack: Sports drink (35g) + Pretzels (40g) = 75g
- Dinner: Pasta (75g) + Bread (30g) + Marinara = 105g
- Evening: Rice cakes (30g) + PB (8g) = 38g

**Total:** ~490g carbs (adjust portions to hit your target)

[View Full 3-Day Carb Loading Plan] button
[Generate Shopping List] button

---

#### Race Morning (April 21, 4:00am)

**Target:** 100-150g carbs, 2-4 hours before start

**4:00am - Wake Up & Breakfast**
- Oatmeal: 1 cup dry (80g carbs)
- Banana: 1 medium (27g carbs)
- Honey: 1 tbsp (17g carbs)
- Sports drink: 16 oz (35g carbs)

**Total:** 159g carbs, 600 calories
**Timing:** 3 hours before 7am start

**Why:** Tops off liver glycogen stores depleted during sleep. Familiar, low-fiber foods minimize GI risk.

---

**5:30am - Pre-Start Snack**
- Maurten Gel 100: 1 packet (25g carbs)
- Water: 8 oz

**Total:** 25g carbs
**Timing:** 90 min before start

**Why:** Final carb boost without causing GI distress. Gel is fast-digesting.

---

**6:45am - Final Fuel**
- Maurten Gel 100: 1 packet (25g carbs)
- Water: 4 oz

**Total:** 25g carbs
**Timing:** 15 min before start

**Why:** Immediate carbs for early miles. Small water volume prevents sloshing.

---

### DURING THE RACE

**Distance:** 26.2 miles @ 8:00 min/mile pace = 3:30 finish
**Fueling Strategy:** 50g carbs/hour

**Mile 5 (0:40 elapsed)**
- 🟦 Gatorade at aid station: 8 oz (14g carbs)
- **Why:** First carb intake. Early fueling prevents depletion.

**Mile 8 (1:04 elapsed)**
- 💚 Maurten Gel 100: 1 packet (25g carbs)
- 💧 Water: 4 oz
- **Why:** First gel on schedule. Water for absorption.

**Mile 10 (1:20 elapsed)**
- 🟦 Gatorade at aid station: 8 oz (14g carbs)
- **Why:** Variety + hydration. Gels + sports drink easier on stomach than gels alone.

**Mile 13 (1:44 elapsed)**
- 💚 Maurten Gel 100: 1 packet (25g carbs)
- 💧 Water: 4 oz
- **Why:** Halfway fuel. You're doing great!

**Mile 15 (2:00 elapsed) - ⚠️ BEFORE NEWTON HILLS**
- 💚 Maurten Gel 100: 1 packet (25g carbs)
- 🟦 Gatorade: 8 oz (14g carbs)
- 💧 Water: 4 oz
- **Why:** CRITICAL FUEL BEFORE HILLS! Extra carbs + hydration for miles 16-21 climb.

**Mile 18 (2:24 elapsed) - IN THE HILLS**
- 🟦 Gatorade only: 16 oz (28g carbs)
- ⚠️ SKIP gel if nauseous
- **Why:** Based on your mile 18 nausea history, I'm recommending liquid carbs only here. Easier on stomach during hard effort.

**Mile 21 (2:48 elapsed) - AFTER HEARTBREAK HILL**
- 💚 Maurten Gel 100: 1 packet (25g carbs)
- 💧 Water: 4 oz
- **Why:** You conquered the hills! Final big fuel for closing miles.

**Mile 24 (3:12 elapsed)**
- 🟦 Gatorade: 8 oz (14g carbs)
- **Why:** Almost there! Last carb boost to finish strong.

**Total Carbs During Race:** ~210g (50g/hour avg)
**Total Fluid:** ~80 oz (Gatorade + water)
**Total Sodium:** ~800mg

---

#### Backup Strategies

**If Nauseous:**
- Skip next gel
- Sip Gatorade only
- Walk through aid station
- Resume gels when feeling better

**If Cramping:**
- Increase water intake
- Salt packet at next aid station
- Slow pace slightly

**If Bonking (low energy):**
- Double gel dose (2 gels)
- Slow pace 30 sec/mile
- Focus on next aid station

---

### AFTER THE RACE

#### Within 30 Minutes (Finish Area)

**Target:** 30g protein + 100g carbs

**Immediate Recovery:**
- Chocolate milk: 16 oz (48g carbs, 16g protein)
- Banana: 1 medium (27g carbs)
- Recovery bar: (30g carbs, 15g protein)

**Total:** 105g carbs, 31g protein

**Why:** Starts muscle recovery and glycogen restoration immediately when cells are most receptive.

[What to grab at finish line] button

---

#### Within 2 Hours (Hotel/Restaurant)

**Full Recovery Meal:**
- Rice or pasta: 2 cups (90g carbs)
- Grilled chicken: 6 oz (45g protein)
- Vegetables: 2 cups
- Sports drink: 20 oz (45g carbs)

**Total:** 135g carbs, 50g protein, ~800 calories

**Why:** Complete muscle recovery nutrition. You earned this meal!

---

#### Days 1-3 Post-Marathon

**Recovery Nutrition Focus:**
- High protein: 2g/kg (136g for 150lb athlete)
- Moderate carbs: 5g/kg (340g)
- Anti-inflammatory foods: Berries, fatty fish, turmeric, ginger
- Hydration: Half body weight in oz water daily

**Why:** Repair muscle damage, reduce inflammation, support immune system.

[View Full 3-Day Recovery Plan] button

---

### Summary Card

```
📊 NUTRITION PLAN SUMMARY

Total Pre-Race Carbs: ~200g
During-Race Carbs: ~210g (50g/hr)
Total Sodium: ~800mg
Total Fluid: ~80 oz

Key Products Needed:
• Maurten Gel 100: 6 packets
• Gatorade Endurance: Available at aid stations
• Oatmeal: 1 cup dry
• Bananas: 3 total
• Chocolate milk: 16 oz (for finish)
• Honey: 1 tbsp
• Recovery bar: 1

Estimated Cost: $24
```

[Generate Shopping List] button
[Share Plan (PDF/Email)] button

**⚠️ Remember:**
- ✓ Test this plan in your last 2 long runs
- ✓ Pack gels in your race belt the night before
- ✓ Set 4am alarm for race morning
- ✓ Nothing new on race day!

---

**AI Conversation Panel:**
```
AI: Here's your complete Boston Marathon nutrition plan! 🎉

I've designed this specifically for:
✓ Your moderate gut training level
✓ The challenging Newton Hills at miles 16-21
✓ Your history of mile 18 nausea (liquid carbs instead)
✓ Your preference for Maurten gels
✓ Boston Marathon aid station availability
✓ Perfect race day weather forecast

Key Innovations in YOUR Plan:
1. Extra fuel before mile 15 (pre-hills load)
2. Gatorade-only at mile 18 (where you felt nauseous before)
3. Strategic timing around Newton Hills
4. 3-day carb loading protocol
5. Complete recovery nutrition

What do you think? Any adjustments you'd like to make?

Common changes athletes request:
• Swap Maurten for different gel brand
• Adjust gel timing (closer or farther apart)
• Change pre-race breakfast
• Modify carb loading foods
```

---

## Step 5: Refine & Adjust

**Screen Title:** "Refine Your Plan"
**Progress:** 5/6 steps complete

### Structured Swaps (Visual Interface)

Tap any food item to see alternatives

**Example: User taps "Oatmeal"**

**Swap Options:**
- Bagel with jam (48g carbs) ➜ Close match
- Pancakes with syrup (60g carbs) ➜ Higher carbs
- Rice with eggs (45g carbs) ➜ Different texture
- Granola with yogurt (55g carbs) ➜ Similar feel

### Conversational Refinement (Chat Interface)

User: "I don't actually like oatmeal that much. What else could I eat?"

```
AI: No problem! Let's find something you'll actually enjoy for race morning.

Since you need 100-150g carbs and low fiber, here are great alternatives:

1. Bagel (2) with jam + banana + sports drink = 152g carbs
   → Pro: Super easy, familiar, low fiber
   → Con: Can be dry, need to drink a lot

2. Pancakes (4) with syrup + banana = 145g carbs
   → Pro: Delicious, easy to eat
   → Con: Need access to cooking

3. Rice with honey + scrambled eggs + sports drink = 138g carbs
   → Pro: Savory option if you don't want sweet
   → Con: Unusual breakfast for some people

4. Smoothie bowl: Banana + berries + granola + honey + protein powder = 140g carbs
   → Pro: Easy to consume, customizable
   → Con: Requires blender, cold on cold morning

Which sounds best to you? Or want me to suggest something else?
```

User: "The bagel option sounds good!"

```
AI: Perfect! I'm updating your plan to:

Race Morning Breakfast (4:00am):
• Bagels (2) with jam (90g carbs)
• Banana (1 medium, 27g carbs)
• Sports drink (16 oz, 35g carbs)

Total: 152g carbs

This is actually BETTER than oatmeal because:
✓ No cooking required
✓ Travels well (can prep the night before)
✓ Less likely to upset stomach (lower fiber than oats)
✓ Easy to eat even if you're nervous

Anything else you'd like to adjust?
```

### Macro Adjustment Sliders

- Carbs per hour: [45g] ← ● → [60g]
- Pre-race carbs: [125g] ← ● → [175g]
- Sodium level: [Normal] ● [High] (for heavy sweaters)

**AI responds to slider changes in real-time:**

```
AI: I see you increased carbs to 60g/hour. Here's what changes:

New During-Race Plan:
• Add 1 extra gel (now 7 total instead of 6)
• Mile 18: Gel + Gatorade (instead of Gatorade only)

Why this is good:
✓ More energy for Newton Hills
✓ Better for your 3:30 pace goal

Why this might be risky:
⚠️ You mentioned mile 18 nausea before
⚠️ 60g/hr is at the upper end for moderate gut training

My recommendation: Stick with 50g/hr for Boston, then try 60g/hr in your next marathon after more gut training.

Want to keep the increase or revert to 50g/hr?
```

---

## Step 6: Finalize & Save

**Screen Title:** "Save Your Plan"
**Progress:** 6/6 steps complete ✅

### Final Review Card

```
✅ Boston Marathon Nutrition Plan

Event: Boston Marathon - April 21, 2025
Carb Strategy: 50g/hour moderate gut training
Products: Maurten gels, Gatorade, bagels
Total Cost: $24

Your plan includes:
□ 3-day carb loading protocol
□ Race morning breakfast (4am)
□ Hour-by-hour during-race fueling
□ Backup strategies for common issues
□ Post-race recovery nutrition
□ 3-day recovery plan
□ Shopping list
```

[Save Plan] button (primary CTA)
[Make More Changes] button (secondary)

### AI Final Confirmation

```
AI: We did it! Your Boston Marathon nutrition plan is ready! 🎉

Before you save, let's make sure you're set up for success:

✅ Testing Plan:
• Use this EXACT plan on your next 2 long runs (20+ miles)
• Note any GI issues and we'll adjust before race day
• Practice opening gels while running!

✅ Shopping List:
I generated a shopping list for everything you need. Want me to email it to you?

✅ Calendar Integration:
I'll add reminders to your calendar:
• April 18: Start carb loading
• April 20: Set out race gear (gels, bottle)
• April 21 at 4:00am: Wake up + eat breakfast
• April 21 at 6:45am: Final gel before start

✅ Practice Runs:
Based on your calendar, I see you have long runs on:
• March 30 (20 miles)
• April 6 (22 miles)

Perfect! Use this plan on both runs.

Sound good? Hit [Save Plan] and you're all set!

---

One more thing: I'll check in with you 3 days before the race (April 18) to:
• Review your plan
• Confirm you tested everything
• Make any last-minute adjustments
• Send you good luck vibes! 🍀

You've got this! 💪
```

**User taps [Save Plan]**

### Confirmation Screen

```
✅ Plan Saved!

Your Boston Marathon Nutrition Plan is ready and waiting.

What's been added:
✓ Calendar events for carb loading, race morning meals
✓ Shopping list emailed to you
✓ Reminders set for practice runs
✓ AI check-in scheduled for April 18

Where to find your plan:
• Activities → Boston Marathon → Nutrition tab
• Coach → "Boston Marathon Nutrition Plan" conversation
• Calendar → April 21, 2025
```

[View Full Plan] [Create Another Plan] [Close]

---

## Key Design Elements

### Structure
- 6 clear steps with visual progress indicators
- Swipeable screens with smooth transitions
- Form fields combined with AI conversation
- Each step builds on previous information

### AI Integration Points
1. Event confirmation and course context
2. Gut training discussion and product history
3. Food preference exploration
4. Plan generation with educational explanations
5. Refinement through conversation + visual swaps
6. Final confirmation with testing strategy

### User Control
- Can edit any preference via taps or conversation
- Visual swaps for quick changes
- Macro sliders with real-time AI feedback
- Explicit save action required

### Outputs
- Comprehensive race day plan (before/during/after)
- Shopping list with cost estimate
- Calendar integration with reminders
- Scheduled follow-up check-in
- PDF/email export capability
