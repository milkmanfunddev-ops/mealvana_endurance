# During-Workout Templates

## Overview

During-workout templates mirror the preworkout template system: composite food combinations with proportional scaling via `component_quantities`. The algorithm scales the template to hit macro targets, then uses adjustment items to fine-tune.

Key difference from preworkout: during templates are normalized **per hour** and multiplied by activity duration.

## Current During-Phase Food Pool

| Food | Carbs | Sodium | Fluid | Max/hr | Type |
|------|-------|--------|-------|--------|------|
| energy_gel | 25g | 55mg | 20ml | 10 | gel (indivisible) |
| energy_chews | 25g | 80mg | 0ml | 5 | chew |
| sports_drink | 30g | 200mg | 480ml | 6 | sports_drink |
| high_carb_drink_mix | 60g | 160mg | 500ml | 5 | drink_mix |
| electrolyte_drink_mix | 15g | 400mg | 0ml | 3 | supplement |
| electrolyte_tablet | 2g | 300mg | 0ml | 4 | supplement (indivisible) |
| energy_bar | 35g | 150mg | 0ml | 3 | bar (cycling only) |
| stroopwafel | 22g | 80mg | 0ml | 5 | bar (cycling only) |
| water | 0g | 0mg | 480ml | 6 | beverage |
| banana | 27g | 1mg | 0ml | 2 | real_food (non-default) |

## Templates

### 1. Gel + Water (The Classic Runner)

- **Sports**: running, triathlon
- **Components**: `{ energy_gel: 1.0, water: 0.5 }`
- **Per 1x**: 25g carbs, 55mg sodium, 260ml fluid
- **Scaling**: Gel is anchor. 2x = 2 gels + 1 bottle. 3x = 3 gels + 1.5 bottles.
- **Max**: 4x/hr (100g carbs)
- **Adjust**: +sodium: add electrolyte_tablet. -carbs: fewer gels.

### 2. Gel + Sports Drink (The Dual Source)

- **Sports**: running, cycling, triathlon
- **Components**: `{ energy_gel: 1.0, sports_drink: 1.0 }`
- **Per 1x**: 55g carbs, 255mg sodium, 500ml fluid
- **Scaling**: Both scale together. 1.5x = 82g carbs.
- **Max**: 3x/hr (165g carbs, capped by target)
- **Adjust**: -carbs: reduce sports_drink to 0.5 first. +sodium: already strong, tablet if needed.

### 3. Chews + Electrolyte Drink (The Chewer)

- **Sports**: running, cycling
- **Components**: `{ energy_chews: 1.0, electrolyte_drink_mix: 0.5 }`
- **Per 1x**: 32.5g carbs, 280mg sodium
- **Scaling**: Chews scale for carbs. Electrolyte drink scales slower.
- **Max**: 3x chews, 1.5x electrolyte
- **Adjust**: +fluid: must add water (neither component has much). +carbs: more chews.

### 4. Sports Drink Only (The Minimalist)

- **Sports**: running, cycling, triathlon
- **Components**: `{ sports_drink: 1.0 }`
- **Per 1x**: 30g carbs, 200mg sodium, 480ml fluid
- **Scaling**: Linear. 2 bottles = 60g, 3 bottles = 90g.
- **Max**: 4x/hr (capped by fluid target before carb target)
- **Adjust**: +sodium: add electrolyte_tablet. Weakness: can't exceed ~60g carbs without exceeding fluid needs.

### 5. High-Carb Drink + Gel (The 90g+ Protocol)

- **Sports**: running (gut-trained), cycling, marathon, Ironman
- **Components**: `{ high_carb_drink_mix: 1.0, energy_gel: 1.0, electrolyte_tablet: 1.0 }`
- **Per 1x**: 87g carbs, 515mg sodium, 520ml fluid
- **Scaling**: 1x = 1 hour of high-performance fueling. Repeat per hour, don't scale much.
- **Max**: 1.5x/hr (130g carbs, elite only)
- **Adjust**: -carbs: drop the gel (60g/hr from drink alone). -sodium: drop tablet. +sodium: add second tablet.

### 6. Bar + Sports Drink (The Cyclist's Steady State)

- **Sports**: cycling only
- **Components**: `{ energy_bar: 1.0, sports_drink: 1.0 }`
- **Per 1x**: 65g carbs, 350mg sodium, 480ml fluid
- **Scaling**: Bar provides solid sustained energy, sports drink provides fluid.
- **Max**: 2x bars + 3x sports drink/hr
- **Adjust**: +carbs: add gel as supplement. -carbs: half bar. +sodium: electrolyte_tablet.

### 7. Stroopwafel + Sports Drink (The Sweet Rider)

- **Sports**: cycling only
- **Components**: `{ stroopwafel: 1.0, sports_drink: 1.0 }`
- **Per 1x**: 52g carbs, 280mg sodium, 480ml fluid
- **Scaling**: Waffles are indivisible. Sports drink in 0.5 increments.
- **Max**: 3 waffles + 2 bottles/hr
- **Adjust**: +carbs: add another waffle (+22g jump). -carbs: reduce sports drink. +sodium: electrolyte_tablet.

### 8. High-Carb Drink Only (The Bottle-Only Protocol)

- **Sports**: running, cycling, triathlon
- **Components**: `{ high_carb_drink_mix: 1.0, electrolyte_tablet: 1.0 }`
- **Per 1x**: 62g carbs, 460mg sodium, 500ml fluid
- **Scaling**: Drink mix scales for carbs. Tablet scales for sodium.
- **Max**: 2x drink mix (120g carbs), 3x tablets
- **Adjust**: +carbs: 1.5 scoops per bottle. -sodium: drop tablet (160mg built into drink).

### 9. Bar + High-Carb Drink + Water (The Long Ride Endurance)

- **Sports**: cycling, triathlon bike leg
- **Components**: `{ energy_bar: 1.0, high_carb_drink_mix: 1.0, water: 0.5 }`
- **Per 1x**: 95g carbs, 310mg sodium, 740ml fluid
- **Scaling**: 1x is nearly a full hour for high-output cyclist.
- **Max**: 1.5x/hr (142g carbs, extreme)
- **Adjust**: -carbs: drop to 0.5 bar or remove bar. +sodium: electrolyte_tablet. Water ensures adequate fluid alongside concentrated drink.

### 10. Banana + Gel + Water (The Natural + Fast Hybrid)

- **Sports**: cycling, ultra running
- **Components**: `{ banana: 1.0, energy_gel: 1.0, water: 0.5 }`
- **Per 1x**: 52g carbs, 56mg sodium, 260ml fluid
- **Scaling**: Banana for real food, gel for fast carbs.
- **Max**: 2 bananas + 3 gels + 2 bottles/hr
- **Adjust**: +sodium: always needs electrolyte_tablet (template is low sodium). -carbs: drop banana or gel.

## Strategy Changes

### Template + Adjustment Items

Each template defines core components that scale together, plus adjustment items for fine-tuning:

- **Adjust UP sodium**: electrolyte_tablet or electrolyte_drink_mix
- **Adjust UP carbs**: add extra gel or chews
- **Adjust DOWN carbs**: reduce sports_drink first, then primary carb
- **Adjust UP fluid**: add water bottles

This differs from preworkout's pure proportional scaling. During-workout needs **asymmetric adjustment** (e.g., more sodium without more carbs).

### Per-Hour Normalization

Templates define nutrition **per hour**. Algorithm multiplies by duration, then caps to macro targets.

### Activity Type Gating

- **Running**: no bars, no stroopwafels -- only things consumable while moving
- **Cycling**: solids allowed (bars, waffles, banana)
- **Triathlon**: bike leg uses cycling templates, run leg uses running templates
- **Universal**: gels, chews, drink mixes work everywhere

### Brick/Triathlon Handling

Different templates per segment:
- Swim: no during nutrition
- Bike: cycling template
- Run: running template
- T1/T2: quick gel + sip of sports drink
