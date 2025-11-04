Skip to content
Chat history

You said:
We are building an endurance app called mealvana endurance.  We support running workouts but we want to expand to biking and swimming.  Plesae do significant research and give me fueling calculators similar to what we have for running here: 


"""
run_fueling.py — Single-run fueling calculator.

Inputs: age, gender, weight, height, pace, distance, time_before_run_min (+ unit options).
Outputs: duration, speed, distance (mi/km), calories (net & gross), and pre/during macro targets.

Core formulas (evidence-based, acute fueling):
- Time (h): t_h = distance(mi) * pace(min/mi) / 60
- Distance (km): km = miles * 1.60934
- Net kcal (running): ~1 kcal * kg * km  (cost of transport, net of rest)
- Gross kcal: MET * kg * h
    MET from ACSM running VO₂ (level): VO2 (mL/kg/min) = 0.2 * v + 3.5  with v in m/min
    MET = VO2 / 3.5
    mph = 60 / pace(min/mi),  v (m/min) = mph * 26.8224
- Pre-run carbohydrate:
    if 0.25h ≤ h < 1h: 0.5 g/kg
    if 1h ≤ h ≤ 4h:   h * 1.0 g/kg  (cap at 4 g/kg)
    if h < 0.25h:     small top-up ≈ 0.25 g/kg
- During-run carbohydrate (typical for ~1–2.5 h):
    mass-normalized rate r = {0.7, 0.8, 1.0} g/kg/h (gut training)
    clamp absolute rate to [30, 60] g/h
    total_during = rate * t_h
- Pre-run protein (optional): ~0.2 g/kg
- Pre-run fat cap: ≤0.1 g/kg if ≤2h pre-window; ≤0.2 g/kg if >2h

Note: Age/sex/height affect basal/daily needs, but acute intra-session fueling depends
mostly on body mass and duration (GI absorption is the bottleneck).
"""

from dataclasses import dataclass, asdict
from typing import Literal, Tuple, Dict, Any, Union

Gender = Literal["female", "male", "other"]
PaceUnit = Literal["min_per_mile", "min_per_km"]
DistanceUnit = Literal["mi", "km"]
WeightUnit = Literal["kg", "lb"]
HeightUnit = Literal["cm", "in"]
GutTraining = Literal["low", "moderate", "high"]  # selects 0.7 / 0.8 / 1.0 g·kg⁻¹·h⁻¹

LB_TO_KG = 0.45359237
IN_TO_CM = 2.54
MI_TO_KM = 1.60934
MPH_TO_M_PER_MIN = 26.8224

def to_kg(weight: float, unit: WeightUnit) -> float:
    return weight if unit == "kg" else weight * LB_TO_KG

def to_cm(height: float, unit: HeightUnit) -> float:
    return height if unit == "cm" else height * IN_TO_CM

def to_miles(distance: float, unit: DistanceUnit) -> float:
    return distance if unit == "mi" else distance / MI_TO_KM

def parse_pace_to_min_per_mile(pace: Union[str, float], pace_unit: PaceUnit = "min_per_mile") -> float:
    def as_minutes(v: Union[str, float]) -> float:
        if isinstance(v, (int, float)):
            return float(v)
        parts = [p.strip() for p in v.split(":")]
        if len(parts) == 1:
            return float(parts[0])
        mm = float(parts[0] or 0)
        ss = float(parts[1] or 0)
        return mm + ss/60.0
    p = as_minutes(pace)
    return p if pace_unit == "min_per_mile" else p * MI_TO_KM  # min/km -> min/mi

def met_from_pace_min_per_mile(pace_min_per_mile: float) -> float:
    mph = 60.0 / pace_min_per_mile
    v_m_per_min = mph * MPH_TO_M_PER_MIN
    VO2 = 0.2 * v_m_per_min + 3.5  # mL/kg/min (ACSM running, level ground)
    return VO2 / 3.5  # MET

def clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))

def gut_rate(gut: GutTraining = "high") -> float:
    return {"low": 0.7, "moderate": 0.8, "high": 1.0}[gut]

def calc_pre_run_hydration(weight_kg: float, time_before_run_h: float) -> int:
    if time_before_run_h >= 2.0:
        return int(weight_kg * 6)  # 6 mL/kg (middle of 5-7 mL/kg range)
    elif time_before_run_h >= 1.0:
        return int(weight_kg * 4)  # reduced intake closer to run time
    else:
        return int(weight_kg * 2)  # minimal intake if <1h before

def calc_during_run_hydration_rate(duration_h: float, MET: float) -> int:
    base_rate = 500  # mL/h baseline
    if duration_h <= 1.0:
        return int(base_rate * 0.8)  # 400 mL/h for shorter runs
    elif MET >= 8.0:  # high intensity
        return int(base_rate * 1.6)  # 800 mL/h for high intensity
    elif MET >= 6.0:  # moderate intensity
        return int(base_rate * 1.2)  # 600 mL/h for moderate intensity
    else:
        return base_rate  # 500 mL/h for easy pace

def calc_pre_run_sodium(time_before_run_h: float) -> int:
    if time_before_run_h >= 2.0:
        return 500  # mg, moderate pre-loading
    else:
        return 200  # mg, minimal if close to run time

def calc_during_run_sodium_rate(duration_h: float) -> int:
    if duration_h <= 1.0:
        return 0  # no sodium supplementation needed for runs ≤1h
    else:
        return 250  # mg/h, typical sports drink concentration

@dataclass
class FuelInput:
    age: int
    gender: Gender
    weight: float
    weight_unit: WeightUnit
    height: float
    height_unit: HeightUnit
    pace: Union[str, float]        # "M:SS" or minutes as float
    pace_unit: PaceUnit = "min_per_mile"
    distance: float = 10.0
    distance_unit: DistanceUnit = "mi"
    time_before_run_min: float = 120.0
    gut_training: GutTraining = "high"

@dataclass
class FuelOutput:
    # Kinematics
    duration_min: float
    duration_h: float
    speed_mph: float
    distance_mi: float
    distance_km: float

    # Energy
    calories_net_kcal: int
    calories_gross_kcal: int
    MET: float

    # Pre-run
    pre_run_carbs_g: int
    pre_run_carbs_rule: str
    pre_run_protein_g_optional: int
    pre_run_fat_g_cap: float

    # During-run
    during_rate_g_per_h: float
    during_total_g: int
    during_mass_norm_rate_g_per_h: float
    during_abs_clamp_range_g_per_h: Tuple[int, int]
    during_mass_norm_total_range_g: Tuple[int, int]

    # Hydration
    pre_run_water_ml: int
    during_water_rate_ml_per_h: int
    during_water_total_ml: int

    # Sodium
    pre_run_sodium_mg: int
    during_sodium_rate_mg_per_h: int
    during_sodium_total_mg: int

def compute_run_fueling(inp: FuelInput) -> FuelOutput:
    weight_kg = to_kg(inp.weight, inp.weight_unit)
    _height_cm = to_cm(inp.height, inp.height_unit)  # placeholder for completeness

    distance_mi = to_miles(inp.distance, inp.distance_unit)
    pace_min_per_mile = parse_pace_to_min_per_mile(inp.pace, inp.pace_unit)
    duration_min = distance_mi * pace_min_per_mile
    duration_h = duration_min / 60.0
    speed_mph = 60.0 / pace_min_per_mile
    distance_km = distance_mi * MI_TO_KM

    # Energy
    calories_net = weight_kg * distance_km  # ~1 kcal/kg/km
    MET = met_from_pace_min_per_mile(pace_min_per_mile)
    calories_gross = MET * weight_kg * duration_h

    # Pre-run carbs
    h_avail = max(0.0, inp.time_before_run_min / 60.0)
    if h_avail >= 1.0:
        h_eff = min(4.0, h_avail)
        pre_carbs_g = h_eff * 1.0 * weight_kg
        pre_rule = f"{h_eff:.2f} h × 1 g/kg"
    elif h_avail >= 0.25:
        pre_carbs_g = 0.5 * weight_kg
        pre_rule = "0.5 g/kg (15–60 min window)"
    else:
        pre_carbs_g = 0.25 * weight_kg   # tiny top-up
        pre_rule = "<15 min → ~0.25 g/kg top-up"

    pre_protein_g_opt = 0.2 * weight_kg
    pre_fat_cap = (0.2 if h_avail > 2.0 else 0.1) * weight_kg

    # During-run carbs
    mass_norm_rate = gut_rate(inp.gut_training) * weight_kg          # g/h
    rate_abs_clamped = clamp(mass_norm_rate, 30.0, 60.0)             # g/h
    total_during_g = rate_abs_clamped * duration_h
    mass_norm_total_min = 0.7 * weight_kg * duration_h
    mass_norm_total_max = 1.0 * weight_kg * duration_h

    # Hydration
    pre_water_ml = calc_pre_run_hydration(weight_kg, h_avail)
    during_water_rate_ml_h = calc_during_run_hydration_rate(duration_h, MET)
    during_water_total_ml = during_water_rate_ml_h * duration_h

    # Sodium
    pre_sodium_mg = calc_pre_run_sodium(h_avail)
    during_sodium_rate_mg_h = calc_during_run_sodium_rate(duration_h)
    during_sodium_total_mg = during_sodium_rate_mg_h * duration_h

    return FuelOutput(
        duration_min=round(duration_min, 2),
        duration_h=round(duration_h, 4),
        speed_mph=round(speed_mph, 3),
        distance_mi=round(distance_mi, 3),
        distance_km=round(distance_km, 3),

        calories_net_kcal=int(round(calories_net)),
        calories_gross_kcal=int(round(calories_gross)),
        MET=round(MET, 2),

        pre_run_carbs_g=int(round(pre_carbs_g)),
        pre_run_carbs_rule=pre_rule,
        pre_run_protein_g_optional=int(round(pre_protein_g_opt)),
        pre_run_fat_g_cap=round(pre_fat_cap, 1),

        during_rate_g_per_h=round(rate_abs_clamped, 1),
        during_total_g=int(round(total_during_g)),
        during_mass_norm_rate_g_per_h=round(mass_norm_rate, 1),
        during_abs_clamp_range_g_per_h=(30, 60),
        during_mass_norm_total_range_g=(
            int(round(mass_norm_total_min)),
            int(round(mass_norm_total_max)),
        ),

        pre_run_water_ml=pre_water_ml,
        during_water_rate_ml_per_h=during_water_rate_ml_h,
        during_water_total_ml=int(round(during_water_total_ml)),

        pre_run_sodium_mg=pre_sodium_mg,
        during_sodium_rate_mg_per_h=during_sodium_rate_mg_h,
        during_sodium_total_mg=int(round(during_sodium_total_mg)),
    )

# Small CLI helper
def main():
    import argparse, json
    p = argparse.ArgumentParser(description="Single-run fueling calculator")
    p.add_argument("--age", type=int, required=True)
    p.add_argument("--gender", type=str, choices=["female","male","other"], required=True)
    p.add_argument("--weight", type=float, required=True)
    p.add_argument("--weight-unit", type=str, choices=["kg","lb"], default="kg")
    p.add_argument("--height", type=float, required=True)
    p.add_argument("--height-unit", type=str, choices=["cm","in"], default="cm")
    p.add_argument("--pace", type=str, required=True, help='e.g., "9:15" or "5:00"')
    p.add_argument("--pace-unit", type=str, choices=["min_per_mile","min_per_km"], default="min_per_mile")
    p.add_argument("--distance", type=float, required=True)
    p.add_argument("--distance-unit", type=str, choices=["mi","km"], default="mi")
    p.add_argument("--time-before-run-min", type=float, required=True)
    p.add_argument("--gut-training", type=str, choices=["low","moderate","high"], default="high")
    args = p.parse_args()

    inp = FuelInput(
        age=args.age,
        gender=args.gender,  # type: ignore
        weight=args.weight,
        weight_unit=args.weight_unit,  # type: ignore
        height=args.height,
        height_unit=args.height_unit,  # type: ignore
        pace=args.pace,
        pace_unit=args.pace_unit,      # type: ignore
        distance=args.distance,
        distance_unit=args.distance_unit,  # type: ignore
        time_before_run_min=args.time_before_run_min,
        gut_training=args.gut_training,    # type: ignore
    )
    out = compute_run_fueling(inp)
    from dataclasses import asdict
    print(json.dumps(asdict(out), indent=2))

if __name__ == "__main__":
    main()

you don't have to give me code, just the formulas.  what foods to digest?  when?  how much?  how much carbs, protein, sodium, fat, and fluids?  and please give me sources.  at the end, if you can please integrate what you have discovered into a core set of formulas for running and swimming that would be great
ChatGPT said:
Could you clarify a few things to tailor the fueling formulas and recommendations for biking and swimming?

What duration range are you targeting for biking and swimming workouts (e.g., 30–90 min, 1–3 hours, ultra-endurance)?

Do you want recommendations for training, racing, or both?

Should the outputs mirror your run_fueling.py structure (e.g., gross/net kcal, macro targets, pre/during windows)?

Any specific population needs (e.g., triathletes, general fitness, masters athletes)?

Once I have this, I’ll do in-depth research and compile the formulas and nutrition strategies for these endurance sports.

You said:
1. all of those.  but this app is for endurance athletes so we should focus on endurance workouts but we also want to support shorter workouts as well
2.  both?  but we would hope recommendations for training should mirror those for racing -- you need to practice your race-day nutrition while you train
3. what do you think?  that would be ideal if it makes sense to do that for biking and swimming
4. triathletes
ChatGPT said:
Great, I’ll gather evidence-based fueling and hydration formulas for biking and swimming workouts, tailored for endurance athletes and triathletes. These will include macronutrient and fluid needs for both training and racing across various durations, along with practical timing and food suggestions. I’ll also work toward harmonizing these guidelines with your existing running model.

I’ll update you once I’ve compiled the formulas and references.

Research completed in 8m · 8 sources · 41 searches
Fueling Formulas for Biking and Swimming for Endurance Athletes

Fueling Guidelines and Formulas for Endurance Running, Cycling, and Swimming
Energy Expenditure in Running, Cycling, and Swimming
Endurance activities have different energy costs, which affect how much fuel (calories) athletes burn and need to replace. Running has a well-known energy cost of roughly 1 kcal per kilogram body weight per kilometer
wellyme.org
. In other words, a 70 kg runner burns about 70 kcal per km regardless of speed on level ground (net cost, not counting resting metabolism). This cost is relatively independent of pace
wellyme.org
, though factors like terrain, wind, and running efficiency can modify it
wellyme.org
. For cycling, energy cost per distance is lower (cycling is more efficient), but it increases with speed due to air resistance. For example, cycling on flat terrain at ~16–19 km/h (10–12 mph) is about 6 METs (6 kcal/kg/hour)
en.wikipedia.org
, whereas faster riding (~24–26 km/h or 15–16 mph) can be ~8–10 METs
en.wikipedia.org
otdude.com
. In practical terms, a 70 kg cyclist at ~24 km/h might burn on the order of 600–700 kcal/hour (gross). Per kilometer, that’s roughly 0.3–0.5 kcal per kg (e.g. ~0.4 kcal·kg⁻¹·km⁻¹ at moderate speeds). Swimming has a higher energy cost per distance due to water drag. Moderate-to-vigorous lap swimming (freestyle) is about 8–11 METs
en.wikipedia.org
, which for a 70 kg swimmer translates to ~500–800 kcal/hour. That means a 1 km vigorous swim (which might take ~15–20 minutes) could expend on the order of 200–300 kcal (roughly 3–4 kcal·kg⁻¹·km⁻¹ for a 70 kg person). Individual energy burn varies by stroke (e.g. butterfly burns more than breaststroke) and efficiency, but swimming generally requires substantially more energy per km than running
verywellfit.com
verywellfit.com
.
Note: MET (Metabolic Equivalent of Task) is a unit of exercise intensity. 1 MET ≈ 1 kcal·kg⁻¹·hour⁻¹ (the energy cost of resting quietly)
en.wikipedia.org
. Using MET values is a convenient way to estimate calorie burn: Calories ≈ MET × body weight (kg) × duration (hours)
verywellfit.com
. Many compendiums list METs for activities; for example, ~10 METs for cycling ~15 mph, or ~9–11 METs for moderate/hard swimming
en.wikipedia.org
. Running at moderate paces (e.g. ~9–10 km/h) is ~8–9 METs
en.wikipedia.org
, aligning with the ~1 kcal/kg/km rule of thumb.
Pre-Workout Fueling Strategies
Proper pre-exercise nutrition ensures endurance athletes start workouts or races with full energy stores. The primary focus is on carbohydrates (CHO) to top up muscle and liver glycogen. General guideline: consume 1–4 grams of carbs per kg body weight, 1–4 hours before exercise
pmc.ncbi.nlm.nih.gov
sportsmedicine-open.springeropen.com
. In practice, this means the more time before the session, the more you can eat: e.g. ~1 g/kg if only 1 hour prior, or up to ~3–4 g/kg if you have a 3–4 hour window. This “1–4 g/kg in 1–4 hours” rule is evidence-based for endurance events >60 min
sportsmedicine-open.springeropen.com
gssiweb.org
. For example, a 70 kg triathlete might target ~70 g of carbs 1 hour before a morning workout (a small breakfast like a bagel with jam and a banana), or 200–280 g if eating 3–4 hours ahead (large meal like oatmeal with fruit, toast with honey, and juice). If time is short (<1 hour), a smaller top-up of ~0.5 g/kg is recommended
pmc.ncbi.nlm.nih.gov
 – for instance, ~30 g carbs from a sports drink or a banana 30 minutes pre-exercise. Even <15 min before start, a quick ~0.25 g/kg (~15 g for 60 kg person) high-GI carbohydrate (like a gel or a few bites of a energy bar) can be used as a last-minute boost
pmc.ncbi.nlm.nih.gov
. Include a small amount of protein if tolerable, especially in a pre-workout meal eaten a couple hours in advance. Around 0.2–0.3 g of protein per kg is a common recommendation
sportsmedicine-open.springeropen.com
 – for a 70 kg athlete, ~14–21 g protein (e.g. a cup of Greek yogurt or a scoop of whey) to help maintain muscle and curb hunger. Keep fat and fiber low before workouts, as they slow digestion and may cause gastrointestinal (GI) distress. A general cap is ≤0.1 g/kg of fat if the meal is within 1–2 hours of exercise (e.g. <7 g fat for a 70 kg person), or ≤0.2 g/kg if eaten >2 hours out
sportsmedicine-open.springeropen.com
. In practice, this means choosing foods like low-fiber, high-carb options: e.g. white rice or pasta, bread with a little peanut butter (thin spread), a fruit smoothie with a bit of protein, etc. Avoid heavy, greasy foods (pizza, fries) or very high-fiber cereals right before training. Pre-exercise hydration is equally important. Aim to drink ~5–10 mL of fluid per kg body weight in the 2–4 hours before exercise
us.usecadence.com
. For a 70 kg athlete, that’s about 350–700 mL of water or sports drink around 2–3 hours prior. If you’re closer to the start (say 1 hour out), you can consume ~3–5 mL/kg (e.g. ~250–350 mL for a 70 kg person)
us.usecadence.com
. Ensure you top up fluids so that you begin exercise well-hydrated (urine pale yellow). It can help to include some sodium (salt) in your pre-event meal or drink, especially if you’ll be sweating heavily. Consuming on the order of ~200–500 mg of sodium before exercise can improve fluid retention
sportsmedicine-open.springeropen.com
. For example, drink 500 mL of an electrolyte sports drink (~300 mg sodium) or have a small salty snack if your meal was low in salt. If you have >2 hours before start, the higher end (~500 mg sodium) is a moderate “pre-load” strategy; if time is short, ~200 mg (a pinch of salt or a small Gatorade) is still useful
sportsmedicine-open.springeropen.com
. This helps delay dehydration and maintain electrolyte balance during the workout. Summary (Pre-Workout): For an endurance session, plan a carb-centered meal or snack based on your timing. For example:
3–4 hours before: a high-carb meal (~3–4 g/kg carbs) such as pasta with marinara and chicken breast, oatmeal with fruit and a sports drink, or rice with sweet potatoes. Include ~0.2–0.3 g/kg protein (lean protein source) and minimal fats.
1–2 hours before: a lighter carb-rich snack (~1–2 g/kg carbs) like a bagel with honey, a bowl of cereal with low-fat milk, or an energy bar plus a banana. Perhaps ~0.1–0.2 g/kg protein (e.g. a hard-boiled egg or some yogurt) if it sits well, and keep fat very low.
<1 hour before: quick carbs (~0.5 g/kg or less) such as a banana, a gel, or a sports drink (~15–30 g carbs). This top-up is optional for shorter workouts but can be crucial before races or long sessions; it should be something easily digestible.
Always practice your pre-race fueling during training to find what works best and to train your gut. Avoid new foods on race day. The goal is to start your run/ride/swim with maximal glycogen stores and proper hydration
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
.
Fueling During Endurance Workouts and Races
During prolonged exercise, carbohydrates, fluids, and electrolytes are the key focus. The body’s stored carbs (glycogen) can fuel only ~60–90 minutes of moderate-to-hard effort, so consuming carbs during longer workouts prevents “hitting the wall” (running out of energy). Likewise, significant sweating can lead to dehydration or sodium loss in multi-hour sessions, so a plan for drinking and electrolyte replacement is needed. Below we outline evidence-based guidelines for during-exercise fueling, which apply similarly to training and racing (endurance athletes should practice in training what they plan to do on race day):
Carbohydrate Intake During Exercise
For workouts under 60 minutes, extra carbs are generally not required during the session
gssiweb.org
 (assuming you ate pre-workout). The body has sufficient glycogen for short efforts, and adding fuel won’t markedly improve performance unless perhaps the exercise is very intense or the athlete was fasted. In high-intensity short events (e.g. a 45-min race), some athletes use a small amount of carbs or a carbohydrate mouth rinse for a performance boost, but for most <1 h training sessions, water is sufficient. For exercise lasting 1–2 hours, consuming carbohydrates can help maintain performance. Aim for roughly 30 g of carbs per hour in this range
pmc.ncbi.nlm.nih.gov
. This could be as simple as sipping a sports drink with ~6–8% carb (e.g. ~500 mL of Gatorade provides ~30 g), or taking a gel (typically ~20–25 g each) every 30–40 minutes. Even at the lower end (~20–30 g/h), carbs can delay fatigue and keep blood sugar stable for runs, rides, or swims around the 90-minute mark. For longer sessions 2–3 hours, recommended intake rises to about 60 g of carbohydrate per hour
pmc.ncbi.nlm.nih.gov
. This level has been shown to improve endurance performance by providing a steady supply of fuel when glycogen stores are depleting
sportsmedicine-open.springeropen.com
. Many runners and cyclists use a combination of sports drink, gels, or energy chews to reach ~50–60 g each hour (for example, one gel ~20 g plus 500 mL sports drink ~20–30 g, plus maybe a few chews or half a banana). Spreading the intake in small doses every 15–20 minutes can be easier on the stomach than a large amount at once. For very long events >2.5–3 hours (e.g. marathons, triathlons, century rides), higher carb intake can further enhance endurance. Guidelines suggest up to ~90 g of carbs per hour when exercise extends beyond ~2.5 hours
pmc.ncbi.nlm.nih.gov
sportsmedicine-open.springeropen.com
. Intakes in the range of 60–90 g/h have proven beneficial for prolonged exercise, especially when using multiple transportable carbohydrates (mix of glucose + fructose) to improve absorption
pmc.ncbi.nlm.nih.gov
. At these high doses, products like specialized drink mixes (e.g. 90 g/L formulas), gels taken with water, energy bars, or real foods like dates and raisins are often used. Example: on a 4-hour ride, a cyclist might consume one 60 g carb drink per hour and a gel (~30 g) per hour, totaling ~90 g/h. Note that intakes >60 g/h require training the gut to absorb and tolerate the carbs; sudden attempts to ingest 90 g/h without practice can cause GI upset. Indeed, emerging research shows some elite athletes can even absorb ~120 g/h when highly trained
sportsmedicine-open.springeropen.com
, but this is exceptional and typically for ultra-endurance scenarios. For most, 30–60 g/h is a good target for 1–3 h sessions, and 60–90 g/h for longer
pmc.ncbi.nlm.nih.gov
pmc.ncbi.nlm.nih.gov
. What carbs to consume? Opt for easily digestible, quick-absorbing sources. Glucose-based carbohydrates (glucose, maltodextrin, etc.) are the primary fuel, and adding fructose in roughly a 2:1 glucose:fructose ratio helps use multiple gut transport pathways at high intakes
pmc.ncbi.nlm.nih.gov
. Common options include: sports drinks, energy gels, chews, gummy candies, dried fruit (e.g. raisins, dates), bananas, or energy bars with mostly carbs. For running, gels and drinks are popular since they’re easy to carry and digest. Cyclists, with the ability to carry more, often also eat solid foods on long rides: e.g. half a banana, fig bars, homemade rice cakes, or peanut butter sandwiches (especially in ultra events) in addition to sports beverages. During swim sessions, intake is trickier – pool swimmers may sip sports drink during rest intervals, and open-water swimmers rely on support kayaks or feed stations. In triathlons, no fuel is taken during the swim; instead, athletes focus on a carb-rich breakfast and possibly an energy gel right before the swim start, then commence fueling as soon as they’re on the bike. Always test in training which products and timing your stomach tolerates. The type of carb (solid vs gel vs drink) can be based on personal preference, but during exercise the goal is high-GI, quick carbs that don’t cause GI distress
pmc.ncbi.nlm.nih.gov
pmc.ncbi.nlm.nih.gov
.
Hydration and Electrolytes During Exercise
Staying hydrated is vital for endurance performance. Even a 2% loss in body weight from sweat can start to impair performance (heart rate rises, perceived effort increases). Fluid needs vary widely by individual sweat rates and conditions (temperature, humidity), but general guidelines exist. The American College of Sports Medicine (ACSM) suggests athletes drink about 400–800 mL of fluid per hour during endurance exercise
sportsmedicine-open.springeropen.com
. The lower end (~400 mL/h) may suffice in cool weather or for smaller athletes, whereas the upper end (~800 mL/h) is for warm conditions, larger athletes, or heavy sweaters
nenutritionexercise.com
sportsmedicine-open.springeropen.com
. In practical terms, that’s roughly one small water bottle (16 oz) per hour as a starting point, adjusting up or down based on thirst and sweat loss. Tip: Weigh yourself before and after a hard training session – each 1 kg of weight lost ≈ 1 L of sweat not replaced. You don’t need to replace all losses during the exercise (some dehydration is expected), but aim to keep losses <2–3% body weight. Drink to thirst as a simple strategy, while using the 0.4–0.8 L/h range as a reference
nenutritionexercise.com
. For short workouts <1 hour, you may not need to drink much at all, or just a few sips to wet the mouth – especially if you started well hydrated. For runs or rides of 1–2 h, plan periodic drinking (e.g. a few gulps every 15–20 min). Water is fine for up to ~60 min, but beyond that or in high heat, a sports drink with electrolytes is beneficial. Sports drinks not only provide carbs as discussed, but also sodium, which helps maintain fluid balance and stimulate thirst to encourage drinking. Sodium replacement becomes crucial in longer exercises: ACSM recommends ~300–600 mg of sodium per hour when exercising more than 2 hours
sportsmedicine-open.springeropen.com
. Many commercial sports drinks provide ~200–300 mg sodium per 500 mL; endurance formulas or electrolyte mixes can be higher. For reference, sweat contains about 400–700 mg sodium per liter on average (though some “salty sweaters” lose >1000 mg/L). Taking in around half a gram of sodium per hour in long events can stave off hyponatremia (low blood sodium) and help you retain the fluid you drink
sportsmedicine-open.springeropen.com
. This can be achieved by drinking ~1 L of a typical sports drink (which often has ~500–800 mg sodium/L), or supplementing water with salt tablets or salty snacks. If the workout is ~1–2 h, sodium needs are lower – on the order of 150–300 mg/h, which you’d get from a half-strength sports drink or a few electrolyte chews. Very short sessions (<1 h) generally don’t require added salt during, as the body’s stores suffice. Hydration plan examples: A marathon runner might target ~500 mL per hour (two cups) of a sports drink, delivering both fluid and ~300 mg sodium hourly. An Ironman triathlete on the bike leg could drink ~750 mL per hour (one large bottle) of electrolyte drink and water combined, especially if it’s hot, and then adjust intake on the run leg when gastric comfort is trickier. Listen to your body’s thirst and watch for signs: dark urine or >2% body weight loss indicates you should increase fluid intake; feeling bloated or sloshing means you may be drinking too much. Remember: both dehydration and over-hydration can impair performance – avoid both extremes by balancing fluid and electrolytes.
Sport-Specific Considerations
Running: Because running jostles the stomach, choose low-bulk, easily digestible fuels during runs. Energy gels, chews, and sports drinks are ideal. Many runners take ~1 gel every 30–45 min with a few sips of water. Hydration can be challenging if water stations are infrequent; plan to carry a bottle or use aid stations to hit ~400–600 mL per hour as needed. In training runs under ~90 min, many runners go with just water (or nothing) to avoid carrying weight, but for key long runs, it’s wise to practice your planned marathon fueling (carbs + electrolytes)
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
. Be cautious with fiber and fat intake in the hours before running to minimize GI upset. Also note that running in heat increases sweat rate significantly, so adjust fluid/electrolyte intake upward on hot days.
Cycling: Cyclists can often tolerate more solid food during exercise, since the bike is lower-impact on the gut. On long rides, it’s common to mix solid snacks (energy bars, bananas, PB&J sandwiches, etc.) with gels and drinks. Aim to eat/drink small amounts frequently – e.g. sip sports drink every 10–15 min, eat a portion of a bar or half a banana every 30 min, to reach your carb targets. Because cyclists can carry bottles, hitting fluid goals (0.5–0.8 L/h) is usually easier than for runners. Make sure to include electrolytes (either in the drink or via salt pills) for rides beyond ~2 hours. In races like triathlons or bike events, many athletes front-load nutrition on the bike (taking advantage of easier digestion) – for example, a triathlete might consume 60–90 g/h on the bike, knowing it’s harder to eat on the run. Practice this strategy in training rides so your gut adapts to higher intake. Lastly, if you’re using a power meter or cycling computer, note that calorie estimates can guide fueling – e.g. if you burn ~700 kcal/hour, plan to ingest ~250–350 kcal/h (mainly from carbs) since the body can’t absorb calories as fast as it expends them.
Swimming: Fueling during swimming is the toughest due to physical constraints. For pool sessions, try to start well-fueled and hydrated, as you can’t easily drink mid-lap. If it’s a long set (>60–90 min), keep a sport drink at the end of the pool to sip during rest intervals. Elite swimmers often have a bottle with carb solution on deck to drink between sets. In open-water or triathlon swims, you typically don’t take nutrition during the swim (except in ultra-distance swim races where a support crew hands off drinks). Thus, focus on pre-swim fueling – make sure to have that 1–4 g/kg carb in the pre-race meal and possibly a gel right before the gun. For triathletes, T1 (transition from swim to bike) is the first chance to rehydrate and fuel: many will have a bottle of electrolyte drink waiting and start consuming it immediately on the bike. If a swim workout leaves you very sweaty (yes, swimmers do sweat in water!), be sure to rehydrate and replenish electrolytes after the session. Swimmers sometimes underestimate fluid loss because they don’t feel sweat; a quick weigh-in can confirm if you lost weight during a long swim. In summary, swimming relies on pre- and post-fueling more than intra-session fueling, except for the rare cases of multi-hour continuous swims with feeding boats.
Core Formulas and Calculations for Fueling
To integrate these guidelines into your app, you can use core formulas for each discipline that estimate session duration, energy expenditure, and fuel needs, then tie in the nutrition recommendations:
Running Formulas: If a user inputs their pace and distance, calculate the duration: time (h) = distance × pace. For example, 10 km at 5:00 min/km is 50 min or 0.833 h. Convert units as needed (1 mi = 1.609 km). Estimate calories burned using the known cost of running: ~1 kcal × body weight (kg) × distance (km)
wellyme.org
 (this gives the net energy cost above resting). For instance, a 70 kg person running 10 km expends ~70*10 = 700 kcal (net). For a more precise total (gross) calorie burn, account for resting metabolism via MET: you can derive MET from pace using the ACSM equation for running. Example: Running at 5:00 min/km (which is 12 km/h) is about 9.8 METs
en.wikipedia.org
. Then gross kcal = MET × body weight (kg) × time (h)
verywellfit.com
. In our example, 9.8 MET × 70 kg × 0.833 h ≈ 571 kcal, which is the exercise energy plus resting metabolic cost (the net 700 kcal is higher because the 1 kcal/kg/km formula slightly overestimates for slower speeds; at faster speeds net vs gross difference shrinks). The app can display both net and gross calories. With duration known, apply the carb guidelines: pre-run carbs = if time <=15 min, ~0.25 g/kg; 15–60 min, ~0.5 g/kg; 1–4 h, ~1 g/kg per hour available (max 4 g/kg)
pmc.ncbi.nlm.nih.gov
. During-run carbs = plan for ~30 g/h if >1 h, up to ~60 g/h for runs ~2–3 h
pmc.ncbi.nlm.nih.gov
. (For marathoners or ultras, up to 90 g/h if they can tolerate, though the app might conservatively cap at 60). Hydration: if run <1 h, suggest ~200–500 mL water; if longer, target ~500 mL/h (adjust for heat)
sportsmedicine-open.springeropen.com
. Sodium: if run >2 h or very sweaty, ~300–600 mg/h
sportsmedicine-open.springeropen.com
; otherwise optional. The app could output, for example: “For your 10 km (50 min) run, drink ~0.4–0.5 L of water during (small sips), and you may not need mid-run carbs. Pre-run, have ~70–140 g carbs in the 1–2 hours before, e.g. a bagel and banana
pmc.ncbi.nlm.nih.gov
. Limit fiber/fat; a little protein (~14 g) is okay
sportsmedicine-open.springeropen.com
.”
Cycling Formulas: Cyclists might input either distance and average speed, or duration and intensity. Calculate duration as time = distance / speed. Example: 40 km at 30 km/h = 1.33 h. Calorie burn can be estimated via MET corresponding to the speed or power. Using MET: a leisure pace ~16 km/h is 6 MET, moderate ~20 km/h is ~8 MET, race pace ~30+ km/h can be 12–16 MET
en.wikipedia.org
otdude.com
. Suppose 30 km/h is ~12 MET; then gross kcal = 12 × weight_kg × time_h. For a 70 kg rider, that’s 12×70×1.33 ≈ 1116 kcal for 40 km. If power (watts) is known, a more direct formula is: Energy (kJ) = power (W) × time (seconds) (since 1 W = 1 J/s), then convert J to kcal (divide by 4184). Accounting for human efficiency (~20–25%), actual calories burned ~4–5 times the work output. For simplicity, MET-based or weight-speed formulas suffice for the app. After getting calories and time, apply fueling needs: during-ride carbs ~30 g/h if 1–2 h, 60 g/h if 2–3 h, up to 90 g/h if >3 h
sportsmedicine-open.springeropen.com
. Fluids ~500–750 mL/h (cyclists often need more if riding hard, due to sweat and cooling from airflow)
sportsmedicine-open.springeropen.com
. Sodium ~300 mg/h for rides >2 h (which is usually met by a sports drink: e.g. 1 L of typical sports drink has ~500–600 mg sodium)
sportsmedicine-open.springeropen.com
. The app can also suggest how to meet the carb intake on the bike (e.g. “60 g/h could be 1 gel + 1 sports drink per hour”). Pre-ride fueling is the same guidelines as running (1–4 g/kg carbs, etc., scaled to time available)
sportsmedicine-open.springeropen.com
. One nuance: for very long cycling (4–6 h), the app might allow including some fats/protein (e.g. real food) since cyclists sometimes eat bars or sandwiches on ultra rides, but keep advice cautionary (too much fat can still upset stomach).
Swimming Formulas: Swimmers might input distance and pace per 100 m, or just duration. Calculate time: e.g. 2000 m at 2:00/100 m = 40 min (0.67 h). Calorie burn can use MET estimates by stroke/intensity. For moderate freestyle (~2:00/100 m pace), assume ~8 MET
en.wikipedia.org
; our 70 kg swimmer in 0.67 h burns ~8×70×0.67 ≈ 375 kcal. (If it were vigorous 1:30/100 m pace, maybe ~10 MET, yielding ~468 kcal in 40 min). Swimming energy cost per distance is high; roughly, 2000 m for a 70 kg person might expend ~300–400 kcal (as calculated). Fueling during swims is often minimal, so the app should emphasize pre-fueling and post-fueling. For a workout around an hour, suggest a sports drink bottle poolside: e.g. ~30 g carbs in a 500 mL drink, sipping during breaks, to both hydrate and fuel. For long swim sets >90 min, they may ingest up to ~60 g/h of carbs (if feasible, via brief stops). In open water, feeding every ~15–30 min with a quick carb drink (tread water at a boat or buoy) is a strategy for marathon swimmers – e.g. ~20 g every 20 min. The app can output: “Because feeding mid-swim is difficult, ensure you eat ~1–4 g/kg carbs in the 1–4 h before your swim
pmc.ncbi.nlm.nih.gov
. If your swim is ~1 h or less, you likely don’t need to consume carbs during. For longer swims, if possible, drink ~250 mL of sports drink every 20–30 min (aiming for ~30–60 g carbs/hour)
pmc.ncbi.nlm.nih.gov
. Stay hydrated: ~400–800 mL/hour fluid
sportsmedicine-open.springeropen.com
 if you have opportunities to drink. After the swim, replenish with a recovery snack (carbs + some protein) to reload your muscles.” Though the app is focused on during exercise fueling, reminding users that swim sessions rely on pre-planned fuel (and emphasizing post-swim recovery if that’s within scope) can be valuable.
In summary, the fueling principles for running, cycling, and swimming are fundamentally similar – tailored to duration and intensity rather than the specific sport. Endurance athletes (including triathletes who do all three) should center their nutrition around: Carbohydrates for energy (before and during exercise)
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
, Fluids for hydration (with a balance of electrolytes like sodium to replace sweat losses)
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
, and a small amount of protein when appropriate (mainly before or after, since during-exercise protein is only needed in ultra-endurance events). By using the formulas above to estimate time, energy, and sweat losses, Mealvana Endurance can give personalized recommendations – for both long endurance workouts and shorter training sessions – that mirror evidence-based race-day nutrition strategies. Following these guidelines will help athletes train effectively and be prepared to perform at their best on race day
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
. Sources:
Stanhewicz et al., Sports Medicine - Open (2024) – Marathon nutrition guidelines (carbs 1–4 g/kg pre, 60–90 g/h during, 300–600 mg Na⁺/h, 400–800 mL/h fluid)
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
sportsmedicine-open.springeropen.com
.
Ault et al., Nutrients (2023) – “Food-first” approach for endurance carbs (pre-exercise 1–4 g/kg, during 30–60 g/h for 1–3 h, up to 90 g/h for >3 h, use easily transportable carbs like gels, bananas, raisins)
pmc.ncbi.nlm.nih.gov
pmc.ncbi.nlm.nih.gov
.
Wallis & Podlogar (GSSI, 2022) – Contemporary sports nutrition perspectives (reiterating 1–4 g/kg pre, 30–90 g/h during endurance exercise; use glucose+fructose at higher rates)
gssiweb.org
gssiweb.org
.
Verywell Fit (2023) – Calorie burn estimates (swimming METs for different strokes; ~716 kcal/h for moderate freestyle at 150 lb)
verywellfit.com
.
Wellyme (2024) – Running energy cost (≈1 kcal/kg/km), negligible speed effect
wellyme.org
wellyme.org
.
Wikipedia Compendium of Activities – MET values (cycling 10–12 mph ~6 MET; swimming moderate-hard 8–11 MET)
en.wikipedia.org
en.wikipedia.org
.






Sources




No file chosenNo file chosen
ChatGPT can make mistakes. Check important info.
