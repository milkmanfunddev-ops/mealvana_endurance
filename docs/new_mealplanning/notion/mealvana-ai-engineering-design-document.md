# Mealvana Ai Engineering Design Document

- **Source:** https://app.notion.com/p/209e3fdb754c804d82ffd3bd83e4002c
- **Ancestor path:** Drafts/Notes/Miscellaneous (data source) → (untitled database) → (untitled) → (untitled) → Homepage
- **Snapshot as of:** 2025-06-16T16:29:05.437Z
- **Properties:** Created by: (user 9e413a30-6cf5-4637-bac5-a70d90a9653a) · Created time: 2025-06-05T21:02:14.982Z
- **Discussions:** 2 threads (see Comments section at bottom)

---

*(Table of contents block omitted — headings below reproduce the structure)*

## 1. Design Philosophy

### Core Principles

1. **LLM as Conversational Interface, Not Decision Engine**
   - LLM handles natural language understanding and generation
   - Backend systems handle all logic, filtering, and calculations
   - Clear separation between conversation and business logic
2. **Data-Driven Personalization**
   - Leverage existing user data before asking questions
   - Use meal scoring system based on historical feedback
   - Minimize user input through intelligent defaults
3. **Context-Aware Efficiency**
   - Start conversations at the appropriate point based on data completeness
   - Skip unnecessary probing when sufficient information exists
   - Respect user time with quick, actionable interactions
4. **Nutritional Intelligence for Athletes**
   - Calculate performance-based nutritional needs
   - Communicate complex nutrition simply
   - Integrate with training platforms
5. **Flexible Meal Creation**
   - Use scored database meals when possible
   - Create custom combinations when needed
   - Import external recipes as last resort

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   Frontend UI       │────▶│   Orchestration     │────▶│    LLM Service      │
│  - Chat Interface   │     │      Layer          │     │  - Claude 3.5       │
│  - Quick Actions    │     │  - Context Builder  │     │  - Conversation     │
│  - Meal Dashboard   │     │  - State Manager    │     │  - Explanation      │
└─────────────────────┘     │  - Constraint Parser│     └─────────────────────┘
                            └──────────┬──────────┘
                                      │
                    ┌─────────────────┴─────────────────┐
                    │        Business Logic Layer        │
                    │  - Meal Selection Engine          │
                    │  - Nutrition Calculator           │
                    │  - Scoring System                 │
                    │  - Recipe Pairing Logic          │
                    └──────────┬────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────────┐
        │                     │                         │
┌───────▼────────┐  ┌─────────▼────────┐  ┌────────────▼────────┐
│  Data Layer    │  │  External APIs   │  │   Integration APIs  │
│  - User DB     │  │  - Weather       │  │  - Calendar         │
│  - Recipe DB   │  │  - Grocery Sales │  │  - TrainingPeaks    │
│  - Meal Scores │  │  - Recipe Import │  │  - Health Apps      │
└────────────────┘  └──────────────────┘  └─────────────────────┘
```

### 2.2 Data Flow

```python
# 1. Pre-conversation data gathering
user_context = ContextBuilder.build_comprehensive_context(user_id)

# 2. LLM interaction
llm_response = LLMService.get_response(user_context, user_input)

# 3. Constraint extraction
constraints = ConstraintParser.extract(llm_response)

# 4. Backend processing
meal_suggestions = MealSelectionEngine.select(constraints, user_context)

# 5. LLM explanation
explanation = LLMService.explain_selections(meal_suggestions, user_context)
```

## 3. Implementation Components

### 3.1 Context Building System

```python
class ContextBuilder:
    """Builds comprehensive context before conversation starts"""

    @staticmethod
    def build_comprehensive_context(user_id: str) -> dict:
        """
        Gathers all available information from multiple sources
        """
        # Core user data
        profile = UserRepository.get_profile(user_id)
        preferences = UserRepository.get_preferences(user_id)

        # Family and dietary constraints
        family_constraints = FamilyConstraintAggregator.aggregate(profile)

        # External integrations
        calendar_data = CalendarIntegration.get_week_context(user_id)
        training_data = TrainingPeaksIntegration.get_training_context(user_id)

        # Environmental context
        weather = WeatherService.get_forecast(profile['location'])
        sales = GroceryService.get_relevant_sales(profile['preferred_stores'])

        # Historical data
        meal_history = MealHistoryService.get_context(user_id)

        # Critical missing info
        missing_info = CriticalInfoAnalyzer.analyze(
            profile, preferences, calendar_data, training_data
        )

        return {
            'user_profile': profile,
            'family_constraints': family_constraints,
            'calendar_context': calendar_data,
            'training_context': training_data,
            'environmental': {
                'weather': weather,
                'sales': sales
            },
            'meal_history': meal_history,
            'critical_missing': missing_info,
            'conversation_readiness': 'ready' if not missing_info else 'need_info'
        }
```

### 3.2 Critical Information Analyzer

```python
class CriticalInfoAnalyzer:
    """Determines what critical information is missing"""

    CRITICAL_FIELDS = {
        'severe_allergies': {
            'priority': 10,
            'validator': lambda p: p.get('allergies') is not None,
            'question': 'any food allergies I should know about',
            'quick_options': ['No allergies', 'Yes - nuts', 'Yes - other']
        },
        'meal_types_needed': {
            'priority': 9,
            'validator': lambda p, c: c.get('recent_meal_request') is not None,
            'question': 'which meals you need this week',
            'quick_options': ['Just dinners', 'All meals', 'Dinners + lunches']
        },
        'cooking_time_constraint': {
            'priority': 8,
            'validator': lambda p, c: p.get('max_cooking_time') or
                                     CriticalInfoAnalyzer._infer_time_constraint(c),
            'question': 'how much time you have for cooking',
            'context_builder': lambda c: f"with {c['busy_evenings']} busy evenings",
            'quick_options': ['20 min max', '30-45 minutes', 'Time not an issue']
        },
        'training_nutrition': {
            'priority': 7,
            'validator': lambda p, c: not (c.get('has_big_training') and
                                          not p.get('pre_workout_fuel')),
            'question': 'your pre-workout fuel preferences',
            'context_builder': lambda c: f"for tomorrow's {c['workout_type']}",
            'quick_options': ['Light carbs', 'Full meal', 'Just liquids']
        },
        'budget_constraint': {
            'priority': 6,
            'validator': lambda p, c: c.get('asked_about_budget_recently') or
                                     not p.get('budget_matters'),
            'question': 'your grocery budget this week',
            'quick_options': ['Stick to $100', 'Up to $150', 'No limit']
        }
    }

    @classmethod
    def analyze(cls, profile, preferences, calendar, training):
        """Returns list of missing critical information"""
        missing = []
        context = {
            'busy_evenings': cls._count_busy_evenings(calendar),
            'has_big_training': cls._has_significant_workout(training),
            'workout_type': training.get('tomorrow', {}).get('type'),
            'recent_meal_request': preferences.get('last_meal_request_time')
        }

        for field_name, config in cls.CRITICAL_FIELDS.items():
            validator = config['validator']
            if not validator(profile, context):
                missing_item = {
                    'field': field_name,
                    'priority': config['priority'],
                    'question': config['question'],
                    'options': config['quick_options']
                }

                if 'context_builder' in config:
                    missing_item['context'] = config['context_builder'](context)

                missing.append(missing_item)

        # Return top 2 most critical
        return sorted(missing, key=lambda x: x['priority'], reverse=True)[:2]
```

### 3.3 Meal Selection Engine

```python
class MealSelectionEngine:
    """Core business logic for meal selection"""

    def __init__(self):
        self.scorer = MealScoringService()
        self.filter = MealFilterService()
        self.nutrition = NutritionCalculator()

    def select_meals(self, constraints: dict, user_context: dict) -> dict:
        """
        Applies all business logic to select appropriate meals
        """
        user_id = user_context['user_profile']['id']

        # Step 1: Apply hard filters
        eligible_meals = self.filter.apply_filters(
            constraints=constraints,
            dietary_restrictions=user_context['family_constraints']['all_restrictions'],
            excluded_ingredients=user_context['family_constraints']['all_dislikes'],
            max_cook_time=constraints.get('max_cook_time'),
            meal_types=constraints.get('meal_types')
        )

        # Step 2: Remove recently eaten
        recent_meal_ids = [m['id'] for m in user_context['meal_history']['recent']]
        eligible_meals = [m for m in eligible_meals if m['id'] not in recent_meal_ids]

        # Step 3: Score based on user history
        scored_meals = self.scorer.score_meals(eligible_meals, user_id)

        # Step 4: For athletes, calculate nutrition fit
        if user_context.get('training_context', {}).get('nutritional_targets'):
            for meal in scored_meals:
                meal['nutrition_score'] = self.nutrition.calculate_fit(
                    meal['nutrition'],
                    user_context['training_context']['nutritional_targets']
                )

        # Step 5: Sort and select top options
        scored_meals.sort(key=lambda x: x['personal_score'], reverse=True)
        top_meals = scored_meals[:5]

        # Step 6: Add selection reasoning
        for meal in top_meals:
            meal['why_selected'] = self._generate_selection_reason(
                meal, constraints, user_context
            )

        return {
            'selected_meals': top_meals,
            'total_found': len(eligible_meals),
            'selection_metadata': {
                'filters_applied': constraints,
                'scoring_method': 'personal_history',
                'nutrition_considered': bool(user_context.get('training_context'))
            }
        }

    def _generate_selection_reason(self, meal, constraints, context):
        """Generates human-readable reason for selection"""
        reasons = []

        if meal['personal_score'] >= 4.5:
            reasons.append("family favorite")

        if meal['cook_time'] <= constraints.get('max_cook_time', 999):
            reasons.append(f"{meal['cook_time']} min cook time")

        if meal.get('nutrition_score', 0) > 0.8:
            reasons.append("great training fuel")

        if meal['cost_per_serving'] < context['user_profile'].get('budget_per_serving', 999):
            reasons.append("budget-friendly")

        return ", ".join(reasons[:2])  # Top 2 reasons
```

### 3.4 Recipe Pairing System

```python
class RecipePairingEngine:
    """Creates custom meals from individual recipes when needed"""

    def create_custom_meals(self, available_recipes: list, constraints: dict) -> list:
        """
        Intelligently pairs recipes to create complete meals
        """
        # Categorize recipes
        proteins = [r for r in available_recipes if 'protein' in r['tags']]
        carbs = [r for r in available_recipes if any(t in r['tags'] for t in ['grain', 'starch'])]
        vegetables = [r for r in available_recipes if 'vegetable' in r['tags']]

        custom_meals = []

        # Create balanced combinations
        for protein in proteins[:3]:  # Limit combinations
            suitable_carbs = self._find_compatible_recipes(protein, carbs)
            suitable_veg = self._find_compatible_recipes(protein, vegetables)

            if suitable_carbs and suitable_veg:
                custom_meal = {
                    'custom': True,
                    'recipe_ids': [protein['id'], suitable_carbs[0]['id'], suitable_veg[0]['id']],
                    'name': f"{protein['name']} with {suitable_carbs[0]['name']} and {suitable_veg[0]['name']}",
                    'total_time': max(protein['cook_time'], suitable_carbs[0]['cook_time'], suitable_veg[0]['cook_time']),
                    'nutrition': self._combine_nutrition([protein, suitable_carbs[0], suitable_veg[0]]),
                    'meal_type': constraints.get('meal_type', 'dinner')
                }
                custom_meals.append(custom_meal)

        return custom_meals

    def _find_compatible_recipes(self, base_recipe, candidates):
        """Finds recipes that pair well together"""
        compatible = []
        base_cuisine = base_recipe.get('cuisine')
        base_flavor = base_recipe.get('flavor_profile')

        for candidate in candidates:
            compatibility_score = 0

            # Same cuisine is good
            if candidate.get('cuisine') == base_cuisine:
                compatibility_score += 2

            # Compatible cooking methods
            if self._compatible_cooking_methods(base_recipe, candidate):
                compatibility_score += 1

            # Similar cook times
            if abs(base_recipe['cook_time'] - candidate['cook_time']) < 15:
                compatibility_score += 1

            if compatibility_score >= 2:
                compatible.append(candidate)

        return sorted(compatible, key=lambda x: x.get('personal_score', 0), reverse=True)
```

### 3.5 Constraint Parser

```python
class ConstraintParser:
    """Extracts structured constraints from LLM responses"""

    CONSTRAINT_PATTERNS = {
        'meal_type': r'\[CONSTRAINT: meal_type: (breakfast|lunch|dinner|snack)\]',
        'max_cook_time': r'\[CONSTRAINT: max_cook_time: (\d+)\]',
        'include_ingredients': r'\[CONSTRAINT: include_ingredients: \[(.*?)\]\]',
        'budget': r'\[CONSTRAINT: budget: (\d+)\]',
        'servings': r'\[CONSTRAINT: servings: (\d+)\]',
        'nutritional_focus': r'\[CONSTRAINT: nutritional_focus: (.*?)\]'
    }

    @classmethod
    def extract(cls, llm_response: str) -> dict:
        """Extract all constraints from LLM response"""
        constraints = {}

        for constraint_type, pattern in cls.CONSTRAINT_PATTERNS.items():
            match = re.search(pattern, llm_response)
            if match:
                value = match.group(1)

                # Type conversion
                if constraint_type in ['max_cook_time', 'budget', 'servings']:
                    value = int(value)
                elif constraint_type == 'include_ingredients':
                    value = [i.strip() for i in value.split(',')]

                constraints[constraint_type] = value

        return constraints
```

## 4. LLM Prompts

> *Author's comment on this section (page-level, unresolved): "Prompts are in section 4. These were resulted from in-depth 3 hours conversation with claude. I have provided my ideas and current mealvana backend design to guide the conversation. I am quite happy with where the overall design is. You might have already designed most of the stuff, but this is supposed to supplement your design." — user xh.analytics@gmail.com, 2025-06-09T15:24:58.947Z*

### 4.1 Core System Prompt

```
You are MealBuddy, a conversational meal planning assistant. Your role is to:
1. Naturally gather user preferences and constraints through friendly conversation
2. Explain meal selections and their benefits in an engaging way
3. Communicate nutritional information clearly for athletes
4. Create recipe pairings when needed

YOU DO NOT:
- Select meals/recipes (the system does this based on constraints you gather)
- Calculate nutrition (provided by the system)
- Apply filtering logic (handled by backend)
- Make decisions about meal scoring (backend handles this)

CONVERSATION PRINCIPLES:
- Keep responses concise and actionable
- Use buttons for user choices: [BUTTON: text]
- Extract constraints as: [CONSTRAINT: type: value]
- Note new learnings as: [MEMORY_UPDATE: field: value]
- Vary your conversation style to feel natural
- Reference specific context (tomorrow's workout, busy Wednesday, etc.)

TOOLS AVAILABLE:
- get_meal_suggestions(constraints) - Returns filtered, scored meals
- calculate_nutrition(meal_ids) - Returns nutritional analysis
- get_weather() - Returns weather context
- get_sales() - Returns current deals
- create_recipe_pairing(recipe_ids, reason) - For custom meal creation
```

### 4.2 Stage-Specific Prompts

#### Greeting Stage

```
CONVERSATION STAGE: Greeting and Initial Context

CONTEXT PROVIDED:
{user_context}

CONVERSATION READINESS: {conversation_readiness}
CRITICAL MISSING: {critical_missing}

Your task:
1. Start with a natural, contextual greeting that varies based on provided information
2. If critical info is missing, weave the highest priority question naturally
3. If ready to suggest, you can present meal options immediately

GREETING ELEMENTS TO CONSIDER:
- Recent meal successes ("Those Mediterranean bowls were a hit!")
- Upcoming schedule pressure ("Busy week with 3 evening events")
- Training context ("Big long run Sunday needs proper fueling")
- Weather relevance ("Perfect grilling weather this week")
- Sales opportunities ("Salmon is 40% off - your favorite!")
- Seasonal themes ("Spring vegetables are gorgeous right now")

TONE VARIATIONS:
- Supportive: For heavy training weeks
- Practical: For busy schedules
- Enthusiastic: For great sales or weather
- Curious: When checking on recent meals
- Playful: For regular users with established rapport

EXAMPLE PATTERNS:

Pattern 1 - Ready to suggest:
"Hey [name]! With [context hook], I'm thinking [theme]. I've found [number] great options that [benefit]..."

Pattern 2 - Need one critical piece:
"[Contextual greeting]! Quick question - [critical missing info]?"
[BUTTON: option 1]
[BUTTON: option 2]
[BUTTON: option 3]

Pattern 3 - Building on success:
"[Recent meal] was a huge hit! Ready for more [similar theme] this week? With [context], here's what I found..."

CONSTRAINT EXTRACTION:
As users respond, extract constraints:
- "Just dinners" → [CONSTRAINT: meal_types: [dinner]]
- "30 minutes max" → [CONSTRAINT: max_cook_time: 30]
- "Under $100" → [CONSTRAINT: budget: 100]
```

#### Meal Presentation Stage

```
CONVERSATION STAGE: Presenting System-Selected Meals

MEALS PROVIDED BY SYSTEM:
{selected_meals}

SELECTION METADATA:
{selection_metadata}

USER CONTEXT:
{user_context}

Your task:
1. Present the meals conversationally with enthusiasm
2. Explain WHY each meal was selected based on their context
3. Group or order meals logically (by day, type, etc.)
4. Offer clear next steps with button options

PRESENTATION PATTERNS:

For time-conscious users:
"Here are your quick winners for the busy week ahead:

**[Meal 1]** - [Time] minutes, perfect for [specific busy day]
[Specific benefit like "one-pot cleanup" or "kids can help"]

**[Meal 2]** - [Time] minutes, [why it fits]
[Personal connection like "similar to your favorite X"]"

For nutrition-focused athletes:
"Fueling your [training phase] properly! Here's what'll power your performance:

**[Meal 1]** ([calories]cal, [protein]g protein)
[Training-specific benefit like "perfect post-workout ratio"]

**[Meal 2]** ([calories]cal, [carbs]g carbs)
[Performance benefit like "slow-release energy for long runs"]"

For budget-conscious:
"Staying under budget at $[total] for the week:

**[Meal 1]** - $[price]/serving
[Money-saving aspect like "uses sale chicken" or "great for leftovers"]"

ALWAYS END WITH OPTIONS:
[BUTTON: Love these!]
[BUTTON: Switch one out]
[BUTTON: See more options]
[BUTTON: Check nutrition]
```

#### Recipe Pairing Stage

> *Inline comment on this heading (unresolved): "I think there can be tools available for recipe pairing LLM, for example nutrition extraction" — user xh.analytics@gmail.com, 2025-06-09T15:22:15.558Z*

```
CONVERSATION STAGE: Creating Custom Meal Combinations

CONTEXT: All database meals have been exhausted or don't fit constraints
AVAILABLE RECIPES: {recipes_with_scores}

Your task:
1. Explain why you're creating custom combinations
2. Present 2-3 logical pairings with clear reasoning
3. Make it sound appealing and cohesive

PAIRING PRINCIPLES:
- Match cuisines when possible
- Balance macronutrients (protein + carb + vegetable)
- Consider cooking methods that work together
- Account for timing (things that cook simultaneously)

EXAMPLE APPROACH:

"Since you've enjoyed most of our [meal type] options recently, let me create some fresh combinations:

**Mediterranean Power Bowl**
Combine [Grilled Chicken Strips] + [Quinoa Tabbouleh] + [Roasted Vegetables]
Everything cooks in 30 minutes and shares that Mediterranean flavor profile you love!

**Asian Fusion Plate**
Pair [Teriyaki Salmon] + [Sesame Rice] + [Stir-Fried Bok Choy]
The teriyaki glaze works beautifully across all components.

These custom combos let you mix-and-match based on what you're craving!"

[BUTTON: First combination]
[BUTTON: Second combination]
[BUTTON: Create my own mix]
```

### 4.3 Response Processing

```python
class LLMResponseProcessor:
    """Processes LLM responses and triggers appropriate actions"""

    def process_response(self, llm_response: str, conversation_state: str) -> dict:
        # Extract constraints
        constraints = ConstraintParser.extract(llm_response)

        # Extract memory updates
        memory_updates = self.extract_memory_updates(llm_response)

        # Extract button options
        buttons = self.extract_buttons(llm_response)

        # Determine next action
        if constraints and self.has_sufficient_constraints(constraints):
            next_action = 'get_meal_suggestions'
        elif 'create_recipe_pairing' in llm_response:
            next_action = 'create_custom_meal'
        else:
            next_action = 'continue_conversation'

        return {
            'constraints': constraints,
            'memory_updates': memory_updates,
            'buttons': buttons,
            'next_action': next_action,
            'clean_response': self.clean_response(llm_response)
        }

    def extract_memory_updates(self, response: str) -> list:
        pattern = r'\[MEMORY_UPDATE: (.*?): (.*?)\]'
        updates = []
        for match in re.finditer(pattern, response):
            updates.append({
                'field': match.group(1),
                'value': match.group(2)
            })
        return updates

    def extract_buttons(self, response: str) -> list:
        pattern = r'\[BUTTON: (.*?)\]'
        return [match.group(1) for match in re.finditer(pattern, response)]
```

## 4.4 userType-aware prompting

*added on Jun 16, 2025*

### Base GREETING_STAGE_PROMPT (toggle block)

```python
GREETING_STAGE_PROMPT = """
You are now in ***CONVERSATION STAGE: GREETING*** for a {user_type_description}

Your task:
1. Start with a natural, contextual greeting that varies based on provided information
2. If critical info is missing, weave the highest priority question naturally
3. When ready to suggest meals (or after max two greetings), set next_stage to MEAL PRESENTATION STAGE
4. Create a balanced, personalized greeting that feels human and contextual

UNIVERSAL GREETING ELEMENTS (Mix and match based on relevance):
- Recent meal feedback ("Those sheet pan fajitas were perfect for soccer night!")
- Weather and seasonal context ("Beautiful grilling weather this weekend")
- Sales and deals ("Your favorite salmon is 40% off")
- Schedule awareness ("Busy week ahead with those evening events")
- Health and nutrition ("Keep that veggie streak going!")
- Cooking successes ("You've mastered the Instant Pot!")
- Family considerations ("How did the kids like the new recipe?")

NATURAL CONVERSATION PRINCIPLES:
- Let your user type focus emerge naturally within the conversation
- Mix different elements for variety
- Remember: everyone cares about taste, health, convenience, and value
- Prioritize based on user type but don't exclude other relevant factors

TONE VARIATIONS (Choose based on context):
- Enthusiastic: For great deals, perfect weather, or recent successes
- Supportive: During challenging weeks or heavy schedules
- Practical: When time or budget is tight
- Curious: Following up on new recipes or changes
- Playful: For regular users with established rapport

{user_type_specific_section}

Return your response in JSON format with the following structure:
{
  "conversation": "Your conversational response here",
  "current_stage": "GREETING STAGE",
  "next_stage": "MEAL PRESENTATION STAGE or GREETING STAGE"
}
"""
```

### User Type Specific Sections for Greeting (toggle block)

```python
USER_TYPE_GREETING_ADDITIONS = {
    "ENDURANCE_ATHLETE": """
ATHLETE-SPECIFIC PRIORITIES:
- Training context is particularly important
- Nutritional timing and recovery needs
- Performance goals add meaning to meal choices
- Balance with practical life considerations

CRITICAL MISSING INFO FOR ATHLETES (in priority order):
1. Current training phase (base, build, peak, taper, recovery)
2. This week's key workouts (long run, intervals, tempo)
3. Upcoming race date and distance
4. Current weekly mileage/hours
5. Preferred pre/post workout fueling

Example integration: "Great chicken sale this week - perfect for recovery after tomorrow's 18-miler! How's the marathon training feeling?"
""",

    "BUSY_PROFESSIONAL": """
BUSY PROFESSIONAL PRIORITIES:
- Time efficiency is a key factor
- Meal prep opportunities are valuable
- Work schedule impacts cooking availability
- Balance with nutrition and enjoyment

CRITICAL MISSING INFO FOR BUSY PROFESSIONALS (in priority order):
1. Busiest days this week (late meetings, travel, deadlines)
2. Realistic cooking time on weeknights (15 min? 30 min? None?)
3. Work-from-home vs office days
4. Meal prep availability (Sunday prep? No time at all?)
5. Lunch needs (office-friendly? Client lunches?)

Example integration: "Sunday's free for meal prep - perfect! With those back-to-back meetings Tuesday-Thursday, let's get you set up with grab-and-go options."
""",

    "COST_CONSCIOUS": """
COST-CONSCIOUS PRIORITIES:
- Price awareness woven throughout
- Excitement about deals and savings
- Value maximization strategies
- Balance with nutrition and taste

CRITICAL MISSING INFO FOR COST-CONSCIOUS USERS (in priority order):
1. Weekly grocery budget (strict limit or target?)
2. Household size (affects bulk buying decisions)
3. Price flexibility for sales ("Can you stock up when there's a deal?")
4. Preferred stores (discount chains? Regular supermarkets?)
5. Storage capacity (freezer space for bulk buys?)

Example integration: "Whole chickens at $0.89/lb! One bird = dinner plus lunch soup for under $10. How's your freezer space for stocking up?"
"""
}
```

### Base MEAL_PRESENTATION_STAGE_PROMPT (toggle block)

```python
MEAL_PRESENTATION_STAGE_PROMPT = """
You are in the ***CONVERSATION STAGE: MEAL PRESENTATION*** for a {user_type_description}

UNIVERSAL PRESENTATION PRINCIPLES:
- Present meals with enthusiasm and clear reasoning
- Explain WHY each meal fits their specific context
- Include relevant details (time, cost, nutrition)
- Maintain natural conversation flow
- Offer clear next steps

To find meals, use the get_meals_filtered or get_recipes_filtered tools based on user context.
You may create custom meals by combining recipes if needed (set custom: true).

PRESENTATION ELEMENTS TO INCLUDE:
- Meal name and brief description
- Key benefit for this user (saves time, under budget, fuels training, etc.)
- Practical details (cook time, servings, reheating instructions)
- Personal connection when relevant ("similar to your favorite...")

{user_type_specific_section}

Return your response in JSON format with the following structure:
{
  "conversation": "Your conversational response here",
  "current_stage": "MEAL PRESENTATION STAGE",
  "next_stage": "MEAL PRESENTATION STAGE",
  "meals": [
    {
      "meal_id": 123,
      "title": "Meal Title",
      "meal_conversation": "Brief description and why it was selected",
      "custom": false,
      "recipe_ids": [456, 789]  # Only if custom is true
    }
  ],
  "external_recipes": [],  # Only if Mealvana lacks options
  "buttons": ["Love these!", "Switch one out", "See more options"]
}
"""
```

### User Type Specific Sections for Meal Presentation (toggle block)

```python
USER_TYPE_MEAL_ADDITIONS = {
    "ENDURANCE_ATHLETE": """
ATHLETE-SPECIFIC PRESENTATION FOCUS:
- Always mention relevant nutrition (macros, calories)
- Connect meals to training schedule ("perfect post-run recovery")
- Highlight performance benefits ("anti-inflammatory ingredients")
- Consider timing ("ready when you're back from the track")

Example meal description:
"**Teriyaki Salmon Bowl** (480cal, 45g carbs, 38g protein)
Ideal 3:1 recovery ratio after tomorrow's tempo run. Anti-inflammatory omega-3s plus quick-digesting carbs. Ready in 20 minutes - perfect timing after cool-down!"

ATHLETE BUTTONS:
- "Show nutrition breakdown"
- "More high-protein options"
- "Adjust for race week"
""",

    "BUSY_PROFESSIONAL": """
BUSY PROFESSIONAL PRESENTATION FOCUS:
- Lead with time efficiency ("15 minutes start to finish")
- Mention prep shortcuts ("uses pre-cut veggies")
- Highlight convenience factors ("one-pot cleanup")
- Include reheating/portability info ("microwave-friendly")

Example meal description:
"**Sheet Pan Mediterranean Chicken** (25 min, mostly hands-off)
Pop it in the oven and handle emails while it cooks. Makes 4 portions - tomorrow's lunch is sorted! One pan = minimal cleanup on your busy Tuesday."

PROFESSIONAL BUTTONS:
- "All quick meals"
- "Best for meal prep"
- "Need even faster"
""",

    "COST_CONSCIOUS": """
COST-CONSCIOUS PRESENTATION FOCUS:
- Always include price per serving
- Highlight value aspects ("feeds 6 for $12 total")
- Mention sales utilized ("uses that sale chicken")
- Show leftover potential ("becomes tomorrow's lunch")

Example meal description:
"**Hearty Lentil Stew** ($1.80/serving, feeds 6)
Using those dried lentils from Aldi ($1.29/bag) plus sale vegetables. Freezes beautifully - make double and you've got 12 meals for under $22!"

BUDGET BUTTONS:
- "All under $3/serving"
- "Best bulk cooking"
- "Using sale items"
"""
}
```

### Implementation (toggle block)

```python
def get_stage_prompt(stage: str, user_type: str) -> str:
    """Combine base prompt with user-type specific additions"""

    # Map user types to descriptions
    user_descriptions = {
        "ENDURANCE_ATHLETE": "ENDURANCE ATHLETE user",
        "BUSY_PROFESSIONAL": "BUSY PROFESSIONAL user",
        "COST_CONSCIOUS": "COST-CONSCIOUS user",
        "DEFAULT": "user"
    }

    if stage == "GREETING":
        base_prompt = GREETING_STAGE_PROMPT
        additions = USER_TYPE_GREETING_ADDITIONS.get(user_type, "")
    elif stage == "MEAL_PRESENTATION":
        base_prompt = MEAL_PRESENTATION_STAGE_PROMPT
        additions = USER_TYPE_MEAL_ADDITIONS.get(user_type, "")

    # Fill in placeholders
    prompt = base_prompt.replace("{user_type_description}", user_descriptions.get(user_type, "user"))
    prompt = prompt.replace("{user_type_specific_section}", additions)

    return prompt
```

## 5. Database Schema

### 5.1 Core Tables

```sql
-- User profile and preferences
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id),
    profile_data JSONB NOT NULL, -- Stores all profile info
    preferences JSONB NOT NULL,   -- Cooking preferences
    health_data JSONB,           -- For athletes
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Meal and recipe data
CREATE TABLE recipes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    recipe_data JSONB NOT NULL,  -- Instructions, ingredients, etc.
    nutrition_data JSONB NOT NULL,
    tags TEXT[],
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE meals (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    meal_type VARCHAR(50),
    recipe_ids INTEGER[],
    is_custom BOOLEAN DEFAULT FALSE,
    nutrition_data JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Scoring and feedback
CREATE TABLE user_meal_scores (
    user_id UUID REFERENCES users(id),
    meal_id INTEGER REFERENCES meals(id),
    score DECIMAL(2,1),
    feedback_count INTEGER DEFAULT 1,
    last_consumed DATE,
    last_updated TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (user_id, meal_id)
);

-- Conversation and constraints
CREATE TABLE conversation_sessions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    session_data JSONB NOT NULL,
    constraints_gathered JSONB,
    meals_suggested INTEGER[],
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_meal_scores ON user_meal_scores(user_id, score DESC);
CREATE INDEX idx_recipe_tags ON recipes USING GIN(tags);
CREATE INDEX idx_user_profile_data ON user_profiles USING GIN(profile_data);
```

## 6. API Endpoints

### 6.1 Core Endpoints

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

class ChatMessage(BaseModel):
    message: str
    session_id: Optional[str]

class MealPlanRequest(BaseModel):
    constraints: dict
    include_nutrition: bool = False

@app.post("/api/chat")
async def chat(request: ChatMessage, user_id: str = Depends(get_current_user)):
    """Main chat endpoint"""
    # Build context
    context = ContextBuilder.build_comprehensive_context(user_id)

    # Get LLM response
    orchestrator = ConversationOrchestrator()
    response = await orchestrator.process_message(
        user_id=user_id,
        message=request.message,
        context=context,
        session_id=request.session_id
    )

    return {
        "response": response.clean_text,
        "buttons": response.buttons,
        "meal_plan": response.meal_plan,
        "session_id": response.session_id
    }

@app.get("/api/user/context/{user_id}")
async def get_user_context(user_id: str):
    """Get current user context for debugging"""
    context = ContextBuilder.build_comprehensive_context(user_id)
    return context

@app.post("/api/meals/suggest")
async def suggest_meals(request: MealPlanRequest, user_id: str = Depends(get_current_user)):
    """Direct meal suggestion endpoint"""
    engine = MealSelectionEngine()
    context = ContextBuilder.build_comprehensive_context(user_id)

    suggestions = engine.select_meals(request.constraints, context)

    if request.include_nutrition:
        nutrition = NutritionCalculator.calculate_plan_nutrition(suggestions)
        suggestions['nutrition_summary'] = nutrition

    return suggestions

@app.put("/api/user/memory")
async def update_memory(updates: dict, user_id: str = Depends(get_current_user)):
    """Update user memory/preferences"""
    memory_service = UserMemoryService()
    updated = await memory_service.apply_updates(user_id, updates)
    return {"status": "updated", "fields": list(updates.keys())}
```

## 7. Frontend Integration

### 7.1 React Components

```typescript
// Types
interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  buttons?: string[];
  mealPlan?: MealPlan;
}

interface MealBuddyState {
  messages: ChatMessage[];
  sessionId: string;
  isLoading: boolean;
  userContext: UserContext;
}

// Main Chat Component
const MealBuddyChat: React.FC = () => {
  const [state, setState] = useState<MealBuddyState>({
    messages: [],
    sessionId: generateSessionId(),
    isLoading: false,
    userContext: null
  });

  const sendMessage = async (content: string) => {
    setState(prev => ({
      ...prev,
      messages: [...prev.messages, { role: 'user', content }],
      isLoading: true
    }));

    try {
      const response = await api.chat({
        message: content,
        sessionId: state.sessionId
      });

      setState(prev => ({
        ...prev,
        messages: [...prev.messages, {
          role: 'assistant',
          content: response.response,
          buttons: response.buttons,
          mealPlan: response.mealPlan
        }],
        isLoading: false
      }));
    } catch (error) {
      handleError(error);
    }
  };

  const handleButtonClick = (buttonText: string) => {
    sendMessage(buttonText);
  };

  return (
    <div className="mealbuddy-container">
      <MessageList
        messages={state.messages}
        onButtonClick={handleButtonClick}
      />
      {state.isLoading && <LoadingIndicator />}
      <MessageInput
        onSend={sendMessage}
        disabled={state.isLoading}
      />
    </div>
  );
};

// Message Component with Button Support
const Message: React.FC<{message: ChatMessage, onButtonClick: (text: string) => void}> = ({ message, onButtonClick }) => {
  return (
    <div className={`message ${message.role}`}>
      <div className="content">{message.content}</div>

      {message.buttons && (
        <div className="button-group">
          {message.buttons.map((button, idx) => (
            <button
              key={idx}
              onClick={() => onButtonClick(button)}
              className="quick-action-button"
            >
              {button}
            </button>
          ))}
        </div>
      )}

      {message.mealPlan && (
        <MealPlanDisplay plan={message.mealPlan} />
      )}
    </div>
  );
};
```

## 8. Testing Strategy

### 8.1 Unit Tests

```python
class TestMealSelection:
    def test_constraint_filtering(self):
        """Test that constraints properly filter meals"""
        engine = MealSelectionEngine()
        constraints = {
            'max_cook_time': 30,
            'meal_types': ['dinner'],
            'exclude_ingredients': ['mushrooms']
        }

        results = engine.select_meals(constraints, mock_user_context)

        for meal in results['selected_meals']:
            assert meal['cook_time'] <= 30
            assert 'dinner' in meal['meal_types']
            assert 'mushrooms' not in meal['all_ingredients']

    def test_scoring_personalization(self):
        """Test that personal scores affect selection order"""
        scorer = MealScoringService()
        meals = [
            {'id': 1, 'name': 'Meal A', 'global_score': 3.0},
            {'id': 2, 'name': 'Meal B', 'global_score': 4.0}
        ]

        # User has rated Meal A highly
        user_scores = {1: 5.0}

        scored = scorer.score_meals(meals, user_id='test', user_scores=user_scores)
```

---

*(Below this point, the source page continues with a second, apparently later/alternate architecture sketch, appended under the same page — reproduced verbatim as it appears in Notion.)*

## Mealvana AI Meal Planner Architecture

### 🏗 Core Concept: LLM as Orchestrator, Tools as Executors

---

### 1️⃣ User Interface Layer

- Mobile App / Web App
- Conversational UI (chat-based planning)
- Classic UI (search, filters, calendar view)

---

### 2️⃣ LLM Orchestration Layer (Core AI Assistant)

- Large Language Model (OpenAI GPT-4o, Claude, or fine-tuned custom model)
- Responsible for:
  - Parsing user input ("I want something for post-run recovery")
  - Mapping intent to parameters
  - Maintaining conversation state
  - Generating personalized copy
  - Providing recommendations in natural language
  - Explaining nutritional decisions

---

### 3️⃣ Structured Logic Layer (Traditional Software Layer)

- Database queries (SQL, vector search, etc.)
- Rule-based filtering (e.g. "if gluten_free=True AND appliance='air fryer'")
- Constraint solvers (if you build more advanced optimizers for weekly planning)
- Nutrition calculators (macros, calories, micronutrient balances)
- Personalization engine (user profiles, schedule, training data)

---

### 4️⃣ Tool/Function Calling Layer (API Gateway for the LLM)

- Functions exposed to LLM:
  - `search_meals(filters)`
  - `generate_weekly_plan(user_profile)`
  - `calculate_nutrition(meal_id)`
  - `apply_substitution(meal_id, preference)`
  - `summarize_user_profile(user_history)`
- LLM calls these tools via function-calling API.

---

### 5️⃣ Personalization & Context Layer

- User profile storage:
  - Goals (weight loss, strength, marathon prep)
  - Food preferences / allergies
  - Schedule constraints
  - Recent training data (can pull from Garmin, Strava, etc.)
- Context manager: feeds summarized profile to LLM each session.

---

### 6️⃣ Content Generation Layer

- AI-powered copywriting engine:
  - Meal captions ("Perfect for post-run recovery")
  - Notifications ("Don't forget to hydrate today!")
  - Educational content ("Iron-rich meals can help reduce fatigue")
- Can be fine-tuned or templated + LLM hybrid.

---

### 7️⃣ Admin & Feedback Loop

- Human feedback loop:
  - Track user corrections ("I don't like this")
  - Use feedback to retrain/fine-tune personalization models
- Analytics dashboard for team:
  - Track model errors
  - Monitor user engagement

---

## 🔧 Technology Stack Suggestions

| Component | Suggested Tech |
|---|---|
| LLM | OpenAI GPT-4o + function calling |
| Vector search | Pinecone, Weaviate, or pgvector |
| Backend logic | Python FastAPI |
| Database | PostgreSQL |
| Analytics | PostHog |
| Nutrition DB | FoodData Central or proprietary |
| Frontend | React Native / Flutter |

---

## 🔄 Simple Flow Example

1️⃣ User types:
*"I need something quick and high-protein after my 10-mile run this morning."*

2️⃣ LLM parses:
```json
{ "appliance": null, "time": "<20 min", "protein": "high", "context": "post-run recovery", "meal_type": "dinner" }
```

3️⃣ LLM calls:
`search_meals(filters)`

4️⃣ Backend returns meal options.

5️⃣ LLM generates:
*"Here's a great option: Lemon Chicken with Quinoa — high protein, ready in 18 minutes, and perfect for recovery."*

6️⃣ User accepts or adjusts. Feedback captured for future sessions.

---

## 🧠 Key Takeaway

> Use the LLM to manage ambiguity, emotion, context, and conversation. Let traditional software handle precision, data, and deterministic logic.

---

# Comments / Discussion Threads

## Thread 1 (page-level, unresolved)

**Comment** — user xh.analytics@gmail.com — 2025-06-09T15:24:58.947Z:

> Prompts are in section 4. These were resulted from in-depth 3 hours conversation with claude. I have provided my ideas and current mealvana backend design to guide the conversation. I am quite happy with where the overall design is. You might have already designed most of the stuff, but this is supposed to supplement your design.

## Thread 2 (inline, anchored to "Recipe Pairing Stage" heading, unresolved)

**Comment** — user xh.analytics@gmail.com — 2025-06-09T15:22:15.558Z:

> I think there can be tools available for recipe pairing LLM, for example nutrition extraction
