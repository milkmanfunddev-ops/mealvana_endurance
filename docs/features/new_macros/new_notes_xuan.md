There are the main points:
1. Pre-Workout Carb Calculation: 1 g/kg per Hour of Pre-Workout Window
Recommendation: x g/kg for x hours of pre-workout window (e.g., 3-hour window = 3 g/kg total)
Key clarification: The total amount scales with time, but gets distributed across eating opportunities—not stacked/cumulated at each window.
Implementation:
Pre-workout carb calculation is directly linked to pre-workout window length (app already does this correctly)v3 error: Calculated each sub-window separately and added them together, resulting in excessive carb recommendations. Should be one total distributed across windows.

2. Intensity Affects Pre-Workout Window, Not g/kg Directly
Recommendation: Harder/longer workouts → longer ideal pre-workout window → more total carbs (because more hours). But g/kg per hour stays constant at ~1.
Example: If you wake up 30 min before a hard workout, the recommendation is still just ~0.5 g/kg top-off—intensity doesn't change that math.
Implementation:
Suggest an ideal pre-workout window based on intensity/duration, clearly marked as "(ideal)"Allow user to select a different window based on their scheduleCalculate carbs based on the window they choosev3 error: Used intensity as a multiplier in the carb calculation. Remove this—intensity only influences the suggested window, not the g/kg formula.

3. During-Workout Carbs: Absolute Ranges, Not Body-Weight Dependent
Recommendation: Use g/hr bands based on workout duration, not body weight. Gut absorption capacity doesn't scale with body mass.
Research-based bands (for moderate gut training):
refer to v3 Table 1Implementation:
Remove any body-weight scaling from during-workout carb calculationsThese bands represent the 1.0× baseline for moderately gut-trained athletes

4. During-Workout Carbs: Gut Training Applies Multipliers to the Band
Recommendation: Gut training level scales the entire band up or down—not just where you fall within a fixed band.
Multipliers:
Low gut training (0.7×): Reduced capacity, scale band downModerate gut training (1.0×): Baseline, use research bands as-isHigh gut training (1.2×): Expanded capacity, scale band upExample for 120-min workout (base band: 45-60 g/hr):
Low gut (0.7×): 31-42 g/hrModerate (1.0×): 45-60 g/hrHigh gut (1.2×): 54-72 g/hrImplementation:
Apply multiplier to both ends of the band, preserving the rangeRachel suggested display as a range (e.g., "54-72 g/hr") not a single number (the middle point); however, we may need to use the target for now and come up with a better design for the rangev3 error: Used hard caps instead of multipliers. Remove caps; use scaled ranges.