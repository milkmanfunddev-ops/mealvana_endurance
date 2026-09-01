# Foods Database

**Source**: Notion Foods Database
**Data Source URL**: `collection://19fa2b42-b60e-4cd8-bcb3-041fcf602052`
**Database URL**: https://www.notion.so/cc1c5237ab7d4b348b42e7c39de73ed4

---

## Database Schema

| Column | Type | Description |
|--------|------|-------------|
| Name | Title | Food name (primary key) |
| Display Name | Text | How the food appears in templates |
| Serving Size | Text | Standard serving description |
| Carbs (g) | Number | Carbohydrates per serving |
| Protein (g) | Number | Protein per serving |
| Fat (g) | Number | Fat per serving |
| Sodium (mg) | Number | Sodium per serving |
| Fluid (ml) | Number | Fluid content per serving |
| Contains | Multi-select | Allergens: Dairy, Eggs, Fish, Gluten, Peanuts, Sesame, Shellfish, Soy, Tree Nuts |
| Diet Incompatible | Multi-select | Vegan, Vegetarian, Pescatarian, Paleo, Keto, Low-Carb |
| In App DB | Checkbox | Whether food exists in Mealvana app database |
| Source | URL | Nutrition data source reference |

---

## Foods List

### Fruits

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Banana | 1 medium banana | 1 medium (118g) | 27 | 1.3 | 0.4 | 1 | 88 | - | - | Yes |
| Apple | 1 medium apple | 1 medium | 25 | 0.5 | 0.3 | 2 | 156 | - | - | Yes |
| Blueberries | 1 cup blueberries | 1 cup (148g) | 21 | 1.1 | 0.5 | 1 | 125 | - | - | Yes |
| Grapes | 1 cup grapes | 1 cup (151g) | 27 | 1.1 | 0.2 | 3 | 122 | - | - | Yes |
| Dates | 2 dates | 2 dates (48g) | 36 | 0.9 | 0.1 | 1 | 10 | - | - | Yes |
| Raisins | 1/4 cup raisins | 1/4 cup (41g) | 33 | 1.3 | 0.2 | 5 | 6 | - | - | Yes |
| Dried Mango | 1/4 cup dried mango | 1/4 cup (40g) | 31 | 0.5 | 0 | 25 | 5 | - | - | Yes |
| Applesauce | 1 cup applesauce | 1 cup (244g) | 28 | 0.4 | 0.1 | 5 | 213 | - | - | Yes |

### Grains & Breads

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Oatmeal | 1 cup cooked oatmeal | 1 cup cooked | 27 | 5 | 3 | 10 | 206 | Gluten | - | Yes |
| White Rice | 1 cup cooked rice | 1 cup cooked | 45 | 4.3 | 0.4 | 0 | 138 | - | Paleo | Yes |
| Pasta | 1 cup cooked pasta | 1 cup cooked | 43 | 8 | 1.3 | 1 | 105 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Bagel (plain, large) | 1 large plain bagel | 1 large (105g) | 56 | 11 | 1.4 | 443 | 32 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Toast | 1 slice toast | 1 slice | 13 | 2.7 | 0.9 | 142 | 8 | Gluten | Paleo, Keto, Low-Carb | Yes |
| White Bread | 1 slice white bread | 1 slice | 14 | 2.4 | 0.8 | 135 | 10 | Gluten | Paleo, Keto, Low-Carb | Yes |
| English Muffin | 1 English muffin | 1 muffin | 26 | 5 | 1 | 252 | 18 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Rice Cakes (plain) | 1 plain rice cake | 1 cake | 7 | 0.7 | 0.3 | 26 | 0 | - | - | Yes |
| Cereal (low-fiber) | 1 cup cereal | 1 cup | 24 | 2 | 0.5 | 200 | 0 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Granola (low-fat) | 1/2 cup granola | 1/2 cup | 32 | 4 | 3 | 60 | 2 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Pretzels | 1 oz pretzels | 1 oz | 23 | 2.6 | 1 | 486 | 1 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Graham Crackers | 2 sheets graham crackers | 2 sheets | 22 | 1.8 | 2.6 | 169 | 1 | Gluten | Paleo, Keto, Low-Carb | Yes |
| Saltine Crackers | 10 saltine crackers | 10 crackers | 22 | 2.2 | 2 | 318 | 1 | Gluten | Paleo, Keto, Low-Carb | Yes |

### Breakfast Items

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Pancakes | 2 medium pancakes | 2 medium | 36 | 6 | 4 | 450 | 48 | Gluten, Eggs, Dairy | Vegan, Paleo, Keto, Low-Carb | Yes |
| Waffles | 2 waffles | 2 waffles | 32 | 5.6 | 6.4 | 475 | 30 | Gluten, Eggs, Dairy | Vegan, Paleo, Keto, Low-Carb | Yes |
| Toaster Waffles | 2 toaster waffles | 2 waffles | 30 | 4 | 5 | 400 | 20 | Gluten, Eggs, Dairy | Vegan, Paleo, Keto, Low-Carb | Yes |
| Scrambled Eggs | 2 scrambled eggs | 2 eggs | 1.6 | 13.6 | 14.4 | 290 | 100 | Eggs | Vegan | Yes |

### Spreads & Sweeteners

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Peanut Butter | 1 tbsp peanut butter | 1 tablespoon | 3.5 | 4 | 8 | 75 | 0 | Peanuts | - | Yes |
| Almond Butter | 2 tbsp almond butter | 2 tablespoons | 6 | 7 | 18 | 2 | 0 | Tree Nuts | - | Yes |
| Honey | 1 tbsp honey | 1 tablespoon | 17 | 0 | 0 | 1 | 3 | - | Vegan | Yes |
| Jam | 1 tbsp jam | 1 tablespoon | 13 | 0 | 0 | 6 | 5 | - | - | Yes |
| Maple Syrup | 2 tbsp maple syrup | 2 tablespoons | 26 | 0 | 0 | 4 | 7 | - | - | Yes |
| Butter | 1 tbsp butter | 1 tablespoon | 0 | 0.1 | 11.5 | 91 | 2 | Dairy | Vegan | Yes |

### Dairy & Alternatives

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Greek Yogurt | 1 cup Greek yogurt | 1 cup | 9 | 17 | 5 | 65 | 200 | Dairy | Vegan | Yes |
| Milk | 1 cup milk | 1 cup (240ml) | 12 | 8 | 8 | 105 | 237 | Dairy | Vegan | Yes |
| Chocolate Milk | 1 cup chocolate milk | 1 cup | 26 | 8 | 8.5 | 150 | 237 | Dairy | Vegan | Yes |

### Vegetables

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Sweet Potato (baked) | 1 medium sweet potato | 1 medium | 26 | 2.3 | 0.1 | 41 | 100 | - | Keto, Low-Carb | Yes |
| Baked Potato | 1 large baked potato | 1 large | 63 | 7 | 0.2 | 17 | 195 | - | Keto, Low-Carb | Yes |

### Sports Nutrition - Gels

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Energy Gel | 1 gel packet | 1 packet | 25 | 0 | 0 | 50 | 0 | - | - | Yes |
| GU Energy Gel | 1 GU gel | 1 packet (32g) | 22 | 0 | 0 | 55 | 0 | - | - | No |
| GU Roctane Energy Gel | 1 Roctane gel | 1 packet (32g) | 24 | 0 | 0 | 125 | 0 | - | - | No |
| Maurten Gel 100 | 1 Maurten gel | 1 packet (40g) | 25 | 0 | 0 | 40 | 0 | - | - | No |
| Maurten Gel 100 CAF | 1 caffeinated Maurten gel | 1 packet (40g) | 25 | 0 | 0 | 40 | 0 | - | - | No |
| Maurten Gel 160 | 1 large Maurten gel | 1 packet (65g) | 40 | 0 | 0 | 55 | 0 | - | - | No |
| Huma Gel | 1 Huma chia gel | 1 packet (36g) | 22 | 1 | 1 | 60 | 0 | - | - | No |
| SIS GO Isotonic Gel | 1 SIS isotonic gel | 1 packet (60ml) | 22 | 0 | 0 | 20 | 50 | - | - | No |
| SIS GO Isotonic Gel CAF | 1 SIS caffeinated gel | 1 packet (60ml) | 22 | 0 | 0 | 20 | 50 | - | - | No |
| Spring Energy Gel | 1 Spring Energy gel | 1 packet (45g) | 22 | 0 | 2 | 100 | 0 | - | - | No |
| Hammer Gel | 1 Hammer gel | 1 packet (33g) | 21 | 0 | 0 | 20 | 0 | - | - | No |
| Neversecond C30 Gel | 1 Neversecond C30 gel | 1 packet (60ml) | 30 | 0 | 0 | 200 | 50 | - | - | No |
| Neversecond C30+ CAF Gel | 1 caffeinated C30+ gel | 1 packet (60ml) | 30 | 0 | 0 | 200 | 50 | - | - | No |

### Sports Nutrition - Chews

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Energy Chews | 1 serving chews | 4 chews | 24 | 0 | 0 | 70 | 0 | - | - | Yes |
| GU Energy Chews | 1 sleeve GU chews | 1 sleeve (6 chews) | 24 | 0 | 0 | 50 | 0 | - | - | No |
| Clif Shot Bloks | 1 pack Clif Bloks | 1 packet (6 pieces) | 24 | 0 | 0 | 70 | 0 | - | - | No |
| Honey Stinger Energy Chews | 1 pack Honey Stinger | 1 packet (1.8oz) | 39 | 0 | 0 | 130 | 0 | - | - | No |
| Skratch Labs Energy Chews | 4 Skratch chews | 4 chews | 22 | 0 | 0 | 40 | 0 | - | - | No |
| Precision Fuel PF 30 Chews | 1 pack PF 30 chews | 1 packet | 30 | 0 | 0 | 140 | 0 | - | - | No |

### Sports Nutrition - Waffles & Bars

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Energy Bar | 1 energy bar | 1 bar | 42 | 10 | 5 | 200 | 5 | Varies | Varies | Yes |
| Fig Bar | 1 twin-pack fig bar | 1 twin-pack | 26 | 1 | 1.5 | 120 | 8 | Gluten | Paleo, Keto, Low-Carb | Yes |
| GU Energy Stroopwafel | 1 GU stroopwafel | 1 waffle (32g) | 22 | 1 | 5 | 120 | 0 | Gluten, Dairy | Vegan, Paleo | No |
| Honey Stinger Waffle | 1 Honey Stinger waffle | 1 waffle (30g) | 21 | 1 | 5 | 80 | 0 | Gluten, Dairy, Eggs | Vegan, Paleo | No |
| Stroopwafel (Generic) | 1 stroopwafel | 1 waffle (30g) | 21 | 1 | 7 | 50 | 0 | Gluten, Dairy, Eggs | Vegan, Paleo | No |
| Bonk Breaker Energy Bar | 1 Bonk Breaker bar | 1 bar (55g) | 28 | 5 | 6 | 120 | 0 | Tree Nuts | - | No |
| Clif Builder Bar | 1 Clif Builder bar | 1 bar (68g) | 29 | 20 | 8 | 240 | 0 | Soy | - | No |

### Sports Nutrition - Drink Mixes

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Sports Drink | 1 cup sports drink | 1 cup (240ml) | 14 | 0 | 0 | 110 | 237 | - | - | Yes |
| Maurten Drink Mix 160 | 1 serving Maurten 160 | 1 sachet + 500ml water | 40 | 0 | 0 | 97 | 500 | - | - | No |
| Maurten Drink Mix 320 | 1 serving Maurten 320 | 1 sachet + 500ml water | 80 | 0 | 0 | 194 | 500 | - | - | No |
| SIS Beta Fuel | 1 serving Beta Fuel | 1 sachet + 500ml water | 80 | 0 | 0 | 150 | 500 | - | - | No |
| Skratch Labs Hydration Mix | 1 serving Skratch | 1 scoop + 500ml water | 21 | 0 | 0 | 380 | 500 | - | - | No |
| Tailwind Endurance Fuel | 1 serving Tailwind | 1 scoop + 600ml water | 25 | 0 | 0 | 303 | 600 | - | - | No |
| UCAN Energy Powder | 1 serving UCAN | 1 packet + 400ml water | 23 | 1 | 0 | 180 | 400 | - | - | No |
| Nuun Sport Tablets | 1 Nuun tablet | 1 tablet + 480ml water | 1 | 0 | 0 | 300 | 480 | - | - | No |
| Precision Hydration PH 500 | 1 bottle PH 500 | 1 serving + 500ml water | 18 | 0 | 0 | 500 | 500 | - | - | No |

### Sports Nutrition - Electrolytes & Supplements

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| SaltStick Caps | 1 SaltStick capsule | 1 capsule | 0 | 0 | 0 | 215 | 0 | - | - | No |
| Endurolyte Capsule | 1 Endurolyte cap | 1 capsule | 0 | 0 | 0 | 40 | 0 | - | - | No |

### Sports Nutrition - Cycling-Specific

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Rice Cake (Savory Cycling) | 1 savory rice cake | 1 piece (60g) | 35 | 2 | 3 | 200 | 5 | - | - | No |
| Rice Cake (Sweet Cycling) | 1 sweet rice cake | 1 piece (60g) | 30 | 1 | 1 | 50 | 5 | - | - | No |
| PB&J Sandwich Quarter | 1/4 PB&J sandwich | 1 quarter | 20 | 4 | 4 | 120 | 5 | Gluten, Peanuts | - | No |
| PB&J Bite | 1 PB&J bite | 1 bite (30g) | 15 | 3 | 3 | 90 | 3 | Gluten, Peanuts | - | No |
| Rice Krispies Treat | 1 Rice Krispies treat | 1 bar (22g) | 20 | 0.5 | 1 | 105 | 2 | Dairy | Vegan | No |

### Beverages

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Orange Juice | 1 cup orange juice | 1 cup (240ml) | 26 | 2 | 0 | 0 | 240 | - | Paleo | Yes |
| Water | 1 cup water | 1 cup (240ml) | 0 | 0 | 0 | 0 | 240 | - | - | Yes |
| Coffee | 1 cup black coffee | 1 cup (240ml) | 0 | 0 | 0 | 5 | 237 | - | - | Yes |
| Coca-Cola (Flat) | 8 oz flat cola | 1 cup (240ml) | 27 | 0 | 0 | 30 | 240 | - | - | No |
| Coconut Water | 1 cup coconut water | 1 cup (240ml) | 9 | 2 | 0.5 | 252 | 240 | - | - | No |
| Tart Cherry Juice | 8 oz tart cherry juice | 1 cup (240ml) | 26 | 1 | 0 | 10 | 240 | - | - | No |

### Recovery Drinks

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Core Power Elite Shake | 1 Core Power Elite | 1 bottle (414ml) | 40 | 42 | 9 | 350 | 400 | Dairy | Vegan | No |
| Skratch Recovery Mix | 1 serving Skratch Recovery | 2 scoops + 350ml water | 40 | 20 | 3 | 200 | 350 | Dairy | Vegan | No |
| Hammer Recoverite | 1 serving Recoverite | 1 scoop + 350ml water | 32 | 10 | 1 | 72 | 350 | Dairy | Vegan | No |
| Tailwind Rebuild | 1 serving Rebuild | 2 scoops + 400ml water | 42 | 20 | 0 | 250 | 400 | - | - | No |

### Recovery Proteins

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Whey Protein Powder | 1 scoop whey protein | 1 scoop (30g) | 3 | 25 | 1 | 50 | 0 | Dairy | Vegan | No |
| Beef Jerky | 3 oz beef jerky | 3 oz (85g) | 6 | 24 | 3 | 800 | 0 | - | - | No |
| Biltong | 3 oz biltong | 3 oz (85g) | 2 | 30 | 2 | 600 | 0 | - | - | No |
| Cottage Cheese | 1 cup cottage cheese | 1 cup (226g) | 6 | 28 | 2 | 920 | 180 | Dairy | Vegan | No |
| Salmon (Grilled) | 4 oz grilled salmon | 4 oz (113g) | 0 | 25 | 7 | 60 | 70 | Fish | - | No |
| Chicken Breast | 4 oz grilled chicken | 4 oz (113g) | 0 | 31 | 3.5 | 75 | 80 | - | - | No |
| Black Beans (Canned) | 1/2 cup black beans | 1/2 cup (86g) | 20 | 8 | 0.5 | 200 | 50 | - | - | No |

### Recovery Carbs & Meal Components

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| White Rice (Cooked) | 1 cup cooked white rice | 1 cup (158g) | 45 | 4 | 0.4 | 0 | 100 | - | Paleo | No |
| Quinoa (Cooked) | 1 cup cooked quinoa | 1 cup (185g) | 39 | 8 | 4 | 13 | 120 | - | - | No |
| Whole Wheat Tortilla | 1 large tortilla | 1 tortilla (64g) | 36 | 6 | 3 | 400 | 10 | Gluten | Paleo, Keto, Low-Carb | No |
| Avocado | 1/2 avocado | 1/2 medium (68g) | 6 | 1 | 11 | 5 | 50 | - | - | No |
| Frozen Mixed Berries | 1 cup frozen berries | 1 cup (140g) | 17 | 1 | 0.5 | 1 | 120 | - | - | No |
| Frozen Cherries | 1/2 cup frozen cherries | 1/2 cup (78g) | 13 | 1 | 0 | 0 | 65 | - | - | No |
| Ground Flaxseed | 1 tbsp ground flax | 1 tablespoon (7g) | 2 | 1.3 | 3 | 2 | 0 | - | - | No |
| Trail Mix | 1/2 cup trail mix | 1/2 cup (75g) | 35 | 8 | 20 | 80 | 2 | Tree Nuts | - | No |
| Kodiak Power Cup | 1 Kodiak oatmeal cup | 1 cup (60g) | 30 | 12 | 4 | 350 | 0 | Gluten, Dairy | Vegan | No |

### Swimming-Specific Foods

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Maltodextrin Drink Mix | 1 serving maltodextrin | 1 serving + 250ml water | 25 | 0 | 0 | 50 | 250 | - | - | No |
| Maxim Carb Drink | 1 serving Maxim | 1 serving + 250ml water | 30 | 0 | 0 | 80 | 250 | - | - | No |
| Mini Flapjack | 1 mini flapjack | 1 piece (30g) | 18 | 1.5 | 5 | 40 | 3 | Gluten, Dairy | Vegan | No |
| Rice Pudding Cup | 1 small rice pudding | 1 cup (113g) | 20 | 3 | 2 | 90 | 80 | Dairy | Vegan | No |
| Brioche Roll | 1 small brioche | 1 roll (35g) | 20 | 3 | 4 | 160 | 10 | Gluten, Dairy, Eggs | Vegan | No |
| Applesauce Pouch | 1 applesauce pouch | 1 pouch (90g) | 13 | 0 | 0 | 5 | 80 | - | - | No |
| Goldfish Crackers | 1 small pack Goldfish | 1 pack (28g) | 20 | 3 | 5 | 230 | 0 | Gluten, Dairy | Vegan | No |
| Banana Chips | 1 oz banana chips | 1 oz (28g) | 17 | 1 | 7 | 1 | 0 | - | - | No |
| Peanut Butter Packet | 1 peanut butter packet | 1 packet (32g) | 6 | 7 | 16 | 115 | 0 | Peanuts | - | No |

### Savory Snack Options

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Salted Boiled Potato | 1 small salted potato | 1 small (100g) | 15 | 2 | 0 | 300 | 60 | - | Keto, Low-Carb | No |
| Potato Chips | 1 oz potato chips | 1 oz (28g) | 15 | 2 | 10 | 170 | 0 | - | - | No |
| Snickers Bar | 1 Snickers bar | 1 bar (52g) | 33 | 4 | 12 | 140 | 3 | Peanuts, Dairy | Vegan | No |
| Peanut M&Ms | 1 small pack M&Ms | 1 pack (42g) | 25 | 4 | 11 | 25 | 0 | Peanuts, Dairy | Vegan | No |

### Other

| Name | Display Name | Serving Size | Carbs | Protein | Fat | Sodium | Fluid | Contains | Diet Incompatible | In App |
|------|--------------|--------------|-------|---------|-----|--------|-------|----------|-------------------|--------|
| Superhero Muffin | 1 superhero muffin | 1 muffin | 35 | 6 | 10 | 180 | 20 | Gluten, Eggs | Vegan, Paleo, Keto | Yes |

---

## New Foods Added (January 2026)

**Total New Foods Added: 92**

### Sports Nutrition - Gels (13 new)
- GU Energy Gel, GU Roctane, Maurten Gel 100/100 CAF/160, Huma Gel, SIS GO Isotonic/CAF, Spring Energy, Hammer Gel, Neversecond C30/C30+ CAF

### Sports Nutrition - Chews (6 new)
- GU Energy Chews, Clif Shot Bloks, Honey Stinger Energy Chews, Skratch Labs Energy Chews, Precision Fuel PF 30 Chews

### Sports Nutrition - Waffles & Bars (5 new)
- GU Stroopwafel, Honey Stinger Waffle, Generic Stroopwafel, Bonk Breaker Bar, Clif Builder Bar

### Sports Nutrition - Drink Mixes (9 new)
- Maurten 160/320, SIS Beta Fuel, Skratch Labs Hydration, Tailwind Endurance, UCAN Energy, Nuun Sport, Precision Hydration PH 500

### Sports Nutrition - Electrolytes (2 new)
- SaltStick Caps, Endurolyte Capsule

### Sports Nutrition - Cycling-Specific (5 new)
- Savory/Sweet Rice Cakes, PB&J Quarter/Bite, Rice Krispies Treat

### Beverages (3 new)
- Flat Coca-Cola, Coconut Water, Tart Cherry Juice

### Recovery Drinks (4 new)
- Core Power Elite, Skratch Recovery Mix, Hammer Recoverite, Tailwind Rebuild

### Recovery Proteins (7 new)
- Whey Protein Powder, Beef Jerky, Biltong, Cottage Cheese, Salmon, Chicken Breast, Black Beans

### Recovery Carbs & Meal Components (9 new)
- White Rice, Quinoa, Whole Wheat Tortilla, Avocado, Frozen Berries/Cherries, Ground Flaxseed, Trail Mix, Kodiak Power Cup

### Swimming-Specific Foods (9 new)
- Maltodextrin/Maxim Drink Mix, Mini Flapjack, Rice Pudding Cup, Brioche Roll, Applesauce Pouch, Goldfish Crackers, Banana Chips, Peanut Butter Packet

### Savory Snack Options (4 new)
- Salted Boiled Potato, Potato Chips, Snickers Bar, Peanut M&Ms

---

## Notes

- All nutrition data should be verified against USDA FoodData Central or manufacturer data
- "In App DB" indicates whether the food exists in the Mealvana Supabase foods table
- Allergen tagging is by what the food CONTAINS, not what it's suitable for
- Diet incompatibility means the food cannot be eaten on that diet
- New foods added are marked "In App: No" until imported into Supabase

## Research Sources

- `/docs/features/food_templates/research/during_run_research.md` - 27 foods
- `/docs/features/food_templates/research/during_bike_research.md` - 18 foods
- `/docs/features/food_templates/research/during_swim_research.md` - 15 foods
- `/docs/features/food_templates/research/post_workout_research.md` - 20 foods
- `/docs/features/food_templates/research/transition_research.md` - 12 foods
