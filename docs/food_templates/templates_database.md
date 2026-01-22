# Pre-Workout Templates Database

**Source**: Notion Pre-Workout Templates Database
**Data Source URL**: `collection://24d7b8df-dbf2-490c-9eb5-c6131c4620bb`
**Database URL**: https://www.notion.so/4f3838cf5dcf4bb0aaf39fcd3ce594df

---

## Database Schema

| Column | Type | Description |
|--------|------|-------------|
| Template Name | Title | Template name (primary key) |
| Timing Window | Select | 30-60 min (Top-Up), 1-2 hours (Snack), 3-4 hours (Full Meal) |
| Foods | Relation | Links to Foods Database entries |
| Base Servings | Text | Default serving sizes for each food |
| Total Carbs (g) | Number | Total carbs at base serving |
| Total Protein (g) | Number | Total protein at base serving |
| Total Fat (g) | Number | Total fat at base serving |
| Total Sodium (mg) | Number | Total sodium at base serving |
| Total Fluid (ml) | Number | Total fluid at base serving |
| Scaling Notes | Text | How to scale for different body weights |
| Contains Allergens | Text | Allergens present in template |
| Diet Restrictions | Text | Notes on diet compatibility |
| Validation Status | Select | Validated, Needs Adjustment, Failed, Not Yet Tested |
| Dietitian Notes | Text | Notes from dietitian review |

---

## Pre-Workout Templates

### 30-60 min (Top-Up) Window

**Target**: 0.5-1 g/kg carbs | No protein | No fat | No fiber

| Template Name | Base Servings | Carbs | Protein | Fat | Fluid | Sodium | Allergens | Scaling Notes |
|---------------|---------------|-------|---------|-----|-------|--------|-----------|---------------|
| Banana + Sports Drink | 1 banana + 1 cup sports drink | 41 | 1.3 | 0.4 | 325 | 111 | None | 54kg: 1 banana + 0.5 cup (34g); 91kg: 1.5 bananas + 1 cup (55g) |
| Energy Gel + Water | 1-2 gels + 2 cups water | 25 | 0 | 0 | 480 | 50 | None | 54kg: 1 gel (25g); 73kg: 1.5 gels (38g); 91kg: 2 gels (50g) |
| White Bread + Honey | 2 slices bread + 1.5 tbsp honey | 54 | 4.8 | 1.6 | 25 | 271 | Gluten | 54kg: 1.5 slices + 1 tbsp (40g); 91kg: 2.5 slices + 2 tbsp (68g) |
| Applesauce | 1.5 cups applesauce | 42 | 0.6 | 0.2 | 320 | 8 | None | 54kg: 1 cup (28g); 91kg: 2 cups (56g) |
| Dates + Sports Drink | 4 dates + 1 cup sports drink | 86 | 1.8 | 0.2 | 257 | 112 | None | 54kg: 2 dates + 0.5 cup (43g); 91kg: 4 dates + 1 cup (86g) |
| Rice Cakes + Honey | 2-3 rice cakes + 1 tbsp honey | 38 | 1.4 | 0.6 | 55 | 53 | None | 54kg: 2 rice cakes + honey (32g); 91kg: 3 rice cakes + 1.5 tbsp honey (49g) |
| Energy Chews + Water | 1 sleeve chews + 2 cups water | 24 | 0 | 0 | 480 | 70 | None | 54kg: 0.75 sleeve (18g); 91kg: 1.5 sleeves (36g) |
| Dried Fruit Mix | 1/2 cup mixed dried fruit | 40 | 1 | 0.2 | 10 | 15 | None | 54kg: 1/3 cup (27g); 91kg: 3/4 cup (60g) |
| Orange Juice | 2 cups orange juice | 52 | 4 | 0 | 480 | 0 | None | 54kg: 1 cup (26g); 91kg: 2.5 cups (65g) |
| Fig Bars | 2 twin-packs fig bars | 52 | 2 | 3 | 16 | 240 | Gluten | 54kg: 1 pack (26g); 91kg: 2.5 packs (65g) |
| Grapes + Pretzels | 1 cup grapes + 1 oz pretzels | 50 | 3.7 | 1.2 | 123 | 489 | Gluten | 54kg: 0.75 cup grapes + 0.5 oz pretzels (32g); 91kg: 1.5 cups + 1.5 oz (75g) |

---

### 1-2 hours (Snack) Window

**Target**: 1-2 g/kg carbs | 0-10g protein | <10g fat | Low fiber

| Template Name | Base Servings | Carbs | Protein | Fat | Fluid | Sodium | Allergens | Scaling Notes |
|---------------|---------------|-------|---------|-----|-------|--------|-----------|---------------|
| Bagel with Jam | 1 large bagel + 2 tbsp jam | 82 | 11 | 1.4 | 42 | 455 | Gluten | 54kg: 0.75 bagel + 1.5 tbsp jam (62g); 91kg: 1.25 bagels + 2.5 tbsp jam (103g) |
| Toast with Honey + Banana | 2 slices toast + 2 tbsp honey + 1 banana | 87 | 6.7 | 2.2 | 110 | 285 | Gluten | 54kg: 1.5 slices + 1.5 tbsp + 0.5 banana (54g); 91kg: 2.5 slices + 2.5 tbsp + banana (100g) |
| Oatmeal with Banana + Honey | 1 cup oatmeal + 1 banana + 1 tbsp honey | 74 | 6.3 | 3.4 | 292 | 10 | Gluten | 54kg: 0.75 cup oatmeal + banana + honey (57g); 91kg: 1.25 cups oatmeal + banana + 1.5 tbsp honey (91g) |
| Cereal with Milk + Banana | 1.5 cups cereal + 1 cup milk + 1 banana | 75 | 12 | 8.9 | 325 | 405 | Gluten, Dairy | 54kg: 1 cup cereal + 0.75 cup milk + banana (60g); 91kg: 2 cups cereal + milk + banana (92g) |
| Rice Cakes + Banana + Honey | 3 rice cakes + 1 banana + 1 tbsp honey | 68 | 3.4 | 1.3 | 91 | 79 | None | 54kg: 2 rice cakes + banana + 0.5 tbsp honey (51g); 91kg: 3 rice cakes + banana + 1.5 tbsp honey (74g) |
| English Muffin + Jam + OJ | 2 English muffins + 2 tbsp jam + 1 cup OJ | 104 | 12 | 2 | 286 | 516 | Gluten | 54kg: 1.5 muffins + 1.5 tbsp jam + 0.75 cup OJ (78g); 91kg: 2.5 muffins + 2.5 tbsp jam + 1.25 cups OJ (130g) |
| Waffles with Maple Syrup | 2 waffles + 2 tbsp maple syrup + 1 banana | 85 | 6.9 | 6.8 | 67 | 479 | Gluten, Eggs, Dairy | 54kg: 1.5 waffles + 1.5 tbsp syrup + banana (69g); 91kg: 3 waffles + 2.5 tbsp syrup + banana (107g) |
| Smoothie + Toast | 1 cup smoothie + 1 slice toast | 52 | 4.7 | 1.4 | 248 | 152 | Gluten | 54kg: 1 cup smoothie + 0.5 toast (46g); 91kg: 1.5 cups smoothie + 2 slices toast (78g) |
| Pretzels + Banana + Sports Drink | 1.5 oz pretzels + 1 banana + 1 cup sports drink | 76 | 5.2 | 1.9 | 362 | 840 | Gluten | 54kg: 1 oz pretzels + banana + 0.5 cup drink (48g); 91kg: 2 oz pretzels + banana + 1 cup drink (78g) |
| Energy Bar + Banana + OJ | 1 energy bar + 1 banana + 1 cup OJ | 95 | 13.3 | 5.7 | 333 | 201 | Varies | 54kg: 0.75 bar + banana + 0.5 cup OJ (60g); 91kg: 1.25 bars + banana + 1 cup OJ (110g) |
| Graham Crackers + Honey + Banana | 4 sheets graham crackers + 1 tbsp honey + 1 banana | 88 | 5.4 | 5.6 | 94 | 340 | Gluten | 54kg: 2 sheets + 0.75 tbsp honey + banana (54g); 91kg: 5 sheets + 1.5 tbsp honey + banana (104g) |

---

### 3-4 hours (Full Meal) Window

**Target**: 1-4 g/kg carbs | 0.15-0.25 g/kg protein | 0.3-0.5 g/kg fat | Moderate fiber OK

| Template Name | Base Servings | Carbs | Protein | Fat | Fluid | Sodium | Allergens | Scaling Notes |
|---------------|---------------|-------|---------|-----|-------|--------|-----------|---------------|
| Oatmeal + Eggs + Toast + OJ | 1 cup oatmeal + 2 eggs + 1 toast + 1 cup OJ | 99 | 21.5 | 18.4 | 546 | 493 | Gluten, Eggs | 54kg: 0.75 cup oatmeal + 1 egg + toast + OJ (78g carbs, 15g protein); 91kg: 1.5 cups oatmeal + 2 eggs + 2 slices toast + OJ (127g carbs) |
| Bagel + Peanut Butter + Banana + Coffee | 1 bagel + 2 tbsp PB + 1 banana + 1 cup coffee | 93 | 19.3 | 17.4 | 357 | 593 | Gluten, Peanuts | 54kg: 0.75 bagel + 1 tbsp PB + banana + coffee (73g); 91kg: 1.25 bagels + 2 tbsp PB + banana + coffee (113g) |
| Pancakes + Maple Syrup + Eggs | 3 pancakes + 2 tbsp maple syrup + 2 eggs | 82 | 19.6 | 22.4 | 127 | 740 | Gluten, Eggs, Dairy | 54kg: 2 pancakes + 1.5 tbsp syrup + 1 egg (60g carbs); 91kg: 4 pancakes + 3 tbsp syrup + 2 eggs (105g carbs) |
| Rice + Sweet Potato + Eggs | 1 cup rice + 1 sweet potato + 2 eggs | 88 | 19.2 | 15.1 | 438 | 332 | Eggs | 54kg: 0.75 cup rice + 0.75 sweet potato + 1 egg (70g); 91kg: 1.25 cups rice + sweet potato + 2 eggs (113g) |
| Pasta with Light Sauce + Toast | 1.5 cups pasta + light marinara + 1 toast | 91 | 16 | 5 | 180 | 650 | Gluten | 54kg: 1 cup pasta + sauce + toast (65g); 91kg: 2 cups pasta + sauce + 2 toasts (120g) |
| Greek Yogurt + Granola + Banana + Honey | 1 cup yogurt + 0.5 cup granola + 1 banana + 1 tbsp honey | 85 | 22.3 | 8.4 | 295 | 136 | Dairy, Gluten | 54kg: 0.75 cup yogurt + 1/3 cup granola + banana + honey (69g); 91kg: 1.5 cups yogurt + 0.75 cup granola + banana + 1.5 tbsp honey (115g) |
| Waffles + Almond Butter + Banana | 2 waffles + 2 tbsp almond butter + 1 banana + 2 tbsp syrup | 91 | 14.3 | 24.8 | 67 | 481 | Gluten, Eggs, Dairy, Tree Nuts | 54kg: 1.5 waffles + 1 tbsp almond butter + banana + syrup (72g); 91kg: 3 waffles + 2 tbsp almond butter + banana + syrup (118g) |
| Baked Potato + Toast + OJ | 1 large baked potato + 2 slices toast + 1 cup OJ | 116 | 13.4 | 2 | 483 | 311 | Gluten | 54kg: 0.75 potato + 1 toast + 0.75 cup OJ (82g); 91kg: 1.25 potatoes + 2 toasts + 1.25 cups OJ (147g) |
| Rice + Banana + Chocolate Milk | 1 cup rice + 1 banana + 1 cup chocolate milk | 98 | 13.6 | 8.9 | 463 | 151 | Dairy | 54kg: 0.75 cup rice + banana + 0.75 cup milk (78g); 91kg: 1.5 cups rice + banana + 1.25 cups milk (130g) |
| Oatmeal + Blueberries + Honey + Toast | 1.5 cups oatmeal + 1 cup berries + 2 tbsp honey + 1 toast | 105 | 10.5 | 5.9 | 454 | 157 | Gluten | 54kg: 1 cup oatmeal + 0.75 cup berries + 1.5 tbsp honey + toast (78g); 91kg: 2 cups oatmeal + 1 cup berries + 2 tbsp honey + 2 toasts (134g) |
| Cereal + Milk + Toast + Banana | 2 cups cereal + 1 cup milk + 2 slices toast + 1 banana | 113 | 18.7 | 10.7 | 362 | 795 | Gluten, Dairy | 54kg: 1 cup cereal + 0.75 cup milk + 1 slice toast + banana (72g); 91kg: 2 cups cereal + 1 cup milk + 2 slices toast + banana (114g) |

---

## During-Run Templates

**Target**: 30-90 g/hr depending on duration and gut training
**Research Source**: `/docs/food_templates/research/during_run_research.md`

| Template Name | Foods | Carbs/hr | Best For | Notes |
|---------------|-------|----------|----------|-------|
| Classic Marathon Gel Schedule | 6 GU Energy Gels + water at aid stations | 50-60g | First-time marathoners, 3:30-5:00 finish | Most common beginner approach |
| Maurten High-Carb Marathon | 7 Maurten Gel 100 + optional 2 CAF gels | 60-70g | Sub-3 hour marathoners | Hydrogel technology, premium |
| Gel + Sports Drink Combo | 3-4 gels + sports drink at aid stations | 50-70g | Hot weather races | Addresses hydration + fuel |
| SIS Isotonic No-Water-Needed | 6-8 SIS GO Isotonic Gels | 55-65g | Minimal gear runners | No water needed |
| Energy Chews Strategy | 6-8 packets energy chews + water | 48-64g | Runners who dislike gel texture | Easier to dose gradually |
| Natural/Real Food Ultra | Gels + dates + pretzels + potatoes + cola | 60-80g | Ultra marathons 4+ hours | Variety prevents flavor fatigue |
| Huma Chia-Based Natural | 6-8 Huma Gels | 42-60g | Sensitive stomachs | All-natural ingredients |
| Caffeine-Boosted Late Race | Regular gels miles 1-16, caffeinated 18-24 | 50-60g | Experienced marathoners | Strategic caffeine timing |
| Spring Energy Whole Food | Spring Energy gels + dates + fig bars | 50-70g | Trail runners, ultras | Whole food ingredients |
| High-Volume Carb Loading | Maurten Gel 160 + dual-source drinks | 90-120g | Elite runners, trained guts | REQUIRES extensive gut training |
| Trail Running Mixed-Source | Gels + waffles + pretzels + fruit + broth | 50-70g | Trail ultras with varied terrain | Terrain dictates format |
| Budget-Friendly Marathon | Homemade chews + generic sports drink + fig bars | 50-60g | Cost-conscious runners | $5-10 total vs $25-40 branded |

---

## During-Bike Templates

**Target**: 60-120 g/hr depending on duration and gut training
**Research Source**: `/docs/food_templates/research/during_bike_research.md`

| Template Name | Foods | Carbs/hr | Best For | Notes |
|---------------|-------|----------|----------|-------|
| Beginner Century Rider | 1 bottle sports drink + 1 gel/hr + banana every 2hr | 60g | First century rides | Simple, gentle on stomach |
| Mixed Strategy | 1 bottle Skratch + 2 GU gels/hr + optional PB&J | 70g | Balanced approach | Familiar flavors |
| All-Liquid Approach | 1 bottle SIS Beta Fuel OR Maurten 320 | 80g | High intensity | May cause flavor fatigue |
| Solid Food Lover | Homemade rice cake + PB&J quarter + sports drink | 70g | Pros | Savory options prevent fatigue |
| Ironman Triathlete (Gut Trained) | 1 bottle Maurten 320 + 1 stroopwafel + salt cap | 95g | Half/Full Ironman | Meets sodium needs |
| Tour de France Mountain | 2 bottles high-carb mix + 1 rice cake | 120g | Elite racing | Requires months of gut training |
| Budget-Friendly Option | Homemade sports drink + Rice Krispies Treat + stroopwafel | 65g | Training rides | Cost-effective |
| Savory Strategy | Bacon rice cake + electrolyte drink + Clif Bloks | 79g | Hours 3-4+ | Combat sweet fatigue |
| Convenience Store Raid | Coca-Cola + Snickers bar + banana | 74g | Emergency option | Surprisingly effective |
| High-Carb Trained Athlete | Precision Hydration + 2 Maurten Gel 100 OR SIS + gel | 100g | Trained gut | 6-10 weeks gut training needed |
| Real Food Purist | PB&J sandwich + coconut water + date/fig bar | 67g | Minimal processing | Easier digestion for some |
| Fondo/Gran Fondo Strategy | 1 bottle Tailwind + Honey Stinger Waffle every 45min | 80g | Long group rides | High sodium content |

---

## During-Swim Templates

**Target**: Context-dependent (pool practice vs marathon swimming)
**Research Source**: `/docs/food_templates/research/during_swim_research.md`

**Note**: Standard triathlon swims (including Ironman 2.4 mile) do NOT require during-swim fueling. These templates are for:
1. Pool practice breaks (>1 hour workouts)
2. Marathon/ultra-distance open water racing (>10km with feed support)

### Pool Practice Templates

| Template Name | Foods | Carbs | Best For | Notes |
|---------------|-------|-------|----------|-------|
| Minimal Hydration Break | 8-12 oz sports drink | 15-20g | 60-75 min practices | Consumed at wall between sets |
| Quick Energy Boost | 16 oz sports drink + ½ banana OR 1-2 dates | 40-50g | 90-120 min practices | One break midway |
| Extended Practice Fuel | 20-24 oz sports drink + dried fruit + pretzels | 60-70g | 2+ hour practices | Two hourly breaks |
| Double-Session Fuel | 12-16 oz sports drink + applesauce pouch + crackers | 45-55g | Between two practices | 30-60 min break |

### Marathon/Ultra Open Water Templates

| Template Name | Foods | Carbs/feed | Best For | Notes |
|---------------|-------|------------|----------|-------|
| Standard Marathon Feed (Warm Water) | 8-10 oz warm carb drink + 1 gel | 60-70g | 10km-25km, >18°C | Feed every 30-60 min |
| Cold Water Marathon Feed | 10-12 oz warm carb drink + 1-2 gels + optional fat | 80-100g | Channel swims, <16°C | Feed every 20-30 min |
| Ultra-Distance Real Food Feed | 8 oz carb drink + gel + treat (flapjack/brioche) | 90-110g | 25km+ swims | Alternate gel-only and real food |
| Minimal Marathon Feed | 6 oz concentrated carb drink + no-water gel | 70-80g | Fast swimmers | <30 sec feed stop |
| Protein-Enhanced Ultra Feed | 8 oz carb drink + gel + PB packet or protein shake | 70-80g + 8-10g protein | 3+ hour swims | Start after first 3 hours |

---

## Post-Workout Recovery Templates

**Target**: 1.0-1.2 g/kg carbs + 20-40g protein within 0-30 min
**Research Source**: `/docs/food_templates/research/post_workout_research.md`

### Immediate Recovery (0-30 Minutes)

| Template Name | Foods | Carbs | Protein | Ratio | Best For |
|---------------|-------|-------|---------|-------|----------|
| Classic Chocolate Milk | 16 oz low-fat chocolate milk | 52g | 16g | 3.25:1 | Budget, widely available |
| Banana Berry Protein Smoothie | Banana + berries + whey + Greek yogurt | 60-65g | 35-40g | 1.7:1 | Home recovery, antioxidants |
| Tart Cherry Juice + Protein | 8-16 oz tart cherry + whey or yogurt | 50-60g | 25-30g | 2:1 | Heavy training, inflammation |
| Recovery Protein Shake | 2 scoops recovery powder + water/milk | 40-50g | 15-25g | 3:1 | Convenience, travel |
| Greek Yogurt Parfait | Greek yogurt + granola + berries + honey | 55-60g | 20-25g | 2.5:1 | Solid food preference |
| Bagel + Nut Butter + Protein | Whole bagel + PB + honey + milk | 65-70g | 20-25g | 3:1 | Athletes who prefer solid food |

### Full Recovery Meals (30-120 Minutes)

| Template Name | Foods | Carbs | Protein | Best For |
|---------------|-------|-------|---------|----------|
| Chicken Sweet Potato Bowl | Chicken + sweet potato + broccoli + rice | 70-75g | 40-45g | Dinner recovery, meal prep |
| Salmon Rice Bowl | Salmon + rice + avocado + vegetables | 60-65g | 35-40g | Anti-inflammatory focus |
| Breakfast Burrito | Whole wheat tortilla + eggs + beans + cheese | 50-55g | 30-35g | Morning workout recovery |
| Burrito Bowl (Chipotle-Style) | Rice + chicken/steak + beans + veggies | 65-70g | 35-40g | Eating out post-workout |
| PB&J + Milk | 2 slices bread + PB + jelly + 12oz milk | 60-65g | 20-25g | Budget, classic |
| Recovery Beef Jerky + Trail Mix | 3oz jerky + trail mix + sports drink | 50-55g | 30-35g | Ultra runners, portable |
| Core Power Shake | 1 bottle Core Power Elite | 40g | 42g | Grab-and-go, no prep |
| Kodiak Power Cup + Fruit | Kodiak cup + banana/berries + milk | 60-65g | 20-25g | Sweet tooth, quick |

---

## T1 Transition Templates (Swim → Bike)

**Target**: 10-30g carbs, consumable in 10-45 seconds
**Research Source**: `/docs/food_templates/research/transition_research.md`

| Template Name | Foods | Carbs | Time | Best For |
|---------------|-------|-------|------|----------|
| Quick Hydration Start | Sports drink bottle on bike (2-3 sips while mounting) | 5-10g | 5-10 sec | Sprint/Olympic |
| Gel + Hydration | 1 energy gel (taped/bento box) + sports drink sips | 25-30g | 15-20 sec | Half-Ironman |
| Electrolyte Boost | Salt capsule + sports drink (4-5 sips) | 10-15g | 10-15 sec | Hot conditions |
| Energy Chews | 2-3 pre-opened chews + water/sports drink | 15-20g | 20-30 sec | Ironman, sensitive stomachs |
| Bottle Banking | 1/4 of high-carb bottle (90g/500ml) | 20-25g | 15-20 sec | Ironman, carb banking |
| Solid Food Option | 1/2 pre-peeled banana + water | 15g | 30-45 sec | Ironman, comfort food |

---

## T2 Transition Templates (Bike → Run)

**Target**: 5-25g carbs, GI-safe for running
**Research Source**: `/docs/food_templates/research/transition_research.md`

| Template Name | Foods | Carbs | Time | Best For |
|---------------|-------|-------|------|----------|
| Gel Flask Grab-and-Go | Pre-filled flask (3-4 gels) + sports drink sips | 5-10g | 10 sec | All distances |
| Ziplock Bag System | Ziplock with 6-8 gels + cold sports drink sip | 5-10g | 5-10 sec | Half/Full Ironman |
| Caffeinated Gel Boost | 1 caffeinated gel (100mg caffeine) + water | 25g | 15-20 sec | Mental reset |
| Solid Food Comfort | 1/2 banana or pretzels + sports drink | 15-20g | 30-45 sec | Ironman, iron guts only |
| Energy Chews | 1 packet (2-3 chews) + sports drink | 15-20g | 20-30 sec | Gentle on stomach |
| Flat Cola Strategy | Flat Coca-Cola (4-5 gulps, ~150ml) | 15-20g | 15-20 sec | Pro secret weapon |
| Minimalist Hydration | Water only, grab gels for run course | 0g | 5 sec | Sprint/Olympic |

---

## Timing Window Options (Schema Updated)

**Current Pre-Workout Options:**
- 30-60 min (Top-Up)
- 1-2 hours (Snack)
- 3-4 hours (Full Meal)

**New During-Workout Options:**
- During Run (30-120g/hr based on duration)
- During Bike (60-120g/hr based on duration)
- During Swim - Pool Practice (>1hr)
- During Swim - Marathon (>10km)

**New Recovery Options:**
- Post-Workout (0-30 min) - Immediate
- Post-Workout (30-120 min) - Extended

**New Transition Options:**
- T1 Transition (Swim → Bike)
- T2 Transition (Bike → Run)
