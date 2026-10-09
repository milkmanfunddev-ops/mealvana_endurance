# 68-009 · Create Custom Food: 'Create Food' stays disabled after the name is typed until something else rebuilds the screen

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Swap picker > Create Custom Food
- decision: 

**Steps.**
1. From the swap picker (Edit Meal swipe), tapped Create Custom Food.
2. Typed name 'tw68 rice cup', unit 'cup', 200 kcal, 45 C, 4 P, 1 F, 5 mg sodium (Before Run was pre-checked).
3. Tapped Create Food four times (23:31:31Z to 23:32:4xZ).
4. Toggled the 'During Run' box on and off, tapped Create Food.

**Expected.**
Create Food is enabled as soon as a name is entered, and one tap creates the food.


**Actual.**
The button stayed dim and did nothing on four taps: no row, no message, no '💾 FoodDetailScreen saving' debug line. After the checkbox toggle (a setState) the button turned bright and one tap created user_foods 4fe1717b… at 23:33:12Z. From code (unverified): onPressed reads _isValid at build and the name field never rebuilds the screen. An athlete who fills the form top to bottom without touching a checkbox cannot save.


**Evidence.**
- runs/68/10h-create-food-no-response.png: dim button with the form filled.
- runs/68/10l-create-food-after-toggle.png: bright button after the toggle.
- runs/68/db-user-foods-after-create.txt: the row only after the toggle.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 74 (swap picker search crash, Create Food button state, barcode per-100 g shown as a serving), fix wave 8 · Lee, 2026-10-09
