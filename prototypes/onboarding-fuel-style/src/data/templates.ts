export type Phase = 'before' | 'during' | 'after';

export interface MealTemplate {
  id: string;
  phase: Phase;
  name: string;
  shortDescription: string;
  ingredients: string[];
  timingNote: string;
  macroNote: string;
  isDefault?: boolean;
  swatch: string;
}

/**
 * Template data mirrors the seeded rows in the Supabase tables. Source:
 *   - docs/templates/templates_now.txt (pre)
 *   - supabase/migrations/20260406320000_during_workout_templates_complete.sql (during)
 *   - supabase/migrations/20260408200000_post_workout_templates.sql (post)
 *
 * Defaults chosen to be "normal" — what a typical recreational endurance
 * athlete would already be doing without any fancy product onboarding.
 */
export const PRE_TEMPLATES: MealTemplate[] = [
  {
    id: 'pre.oatmeal_banana',
    phase: 'before',
    name: 'Oatmeal + Banana',
    shortDescription: 'Rolled oats with banana and a splash of milk.',
    ingredients: ['Oatmeal', 'Banana', 'Milk'],
    timingNote: '3 hours before',
    macroNote: '~58g carbs · 9g protein',
    isDefault: true,
    swatch: 'linear-gradient(135deg, #F5C97A 0%, #F78B14 100%)',
  },
  {
    id: 'pre.oatmeal_pb_banana',
    phase: 'before',
    name: 'Oatmeal + Banana + PB',
    shortDescription: 'Oats with banana and a spoon of peanut butter.',
    ingredients: ['Oatmeal', 'Banana', 'Peanut butter'],
    timingNote: '3 hours before',
    macroNote: '~65g carbs · 13g protein',
    swatch: 'linear-gradient(135deg, #C98A4B 0%, #F78B14 100%)',
  },
  {
    id: 'pre.bagel_pb_banana',
    phase: 'before',
    name: 'Bagel + PB + Banana',
    shortDescription: 'Bagel topped with peanut butter and sliced banana.',
    ingredients: ['Bagel', 'Peanut butter', 'Banana'],
    timingNote: '3 hours before',
    macroNote: '~72g carbs · 16g protein',
    swatch: 'linear-gradient(135deg, #D9A56B 0%, #B07034 100%)',
  },
  {
    id: 'pre.toast_pb_banana',
    phase: 'before',
    name: 'Toast + PB + Banana',
    shortDescription: 'Whole-wheat toast, peanut butter, banana slices.',
    ingredients: ['Bread', 'Peanut butter', 'Banana'],
    timingNote: '3 hours before',
    macroNote: '~52g carbs · 12g protein',
    swatch: 'linear-gradient(135deg, #E5C79A 0%, #B07034 100%)',
  },
  {
    id: 'pre.yogurt_granola_honey',
    phase: 'before',
    name: 'Yogurt + Granola + Honey',
    shortDescription: 'Greek yogurt with granola and a drizzle of honey.',
    ingredients: ['Greek yogurt', 'Granola', 'Honey'],
    timingNote: '3 hours before',
    macroNote: '~55g carbs · 15g protein',
    swatch: 'linear-gradient(135deg, #F5E9C9 0%, #C9A86B 100%)',
  },
  {
    id: 'pre.gel_water',
    phase: 'before',
    name: 'Energy Gel + Water',
    shortDescription: 'For shorter windows — quick carbs, no digestion time.',
    ingredients: ['Energy gel', 'Water'],
    timingNote: '<30 min before',
    macroNote: '~25g carbs · 0g protein',
    swatch: 'linear-gradient(135deg, #F78B14 0%, #DC2597 100%)',
  },
];

export const DURING_TEMPLATES: MealTemplate[] = [
  {
    id: 'during.gel_water',
    phase: 'during',
    name: 'Gel + Water',
    shortDescription: 'Energy gel every 30 min, sipped with water.',
    ingredients: ['Energy gel', 'Water'],
    timingNote: 'every 30 min',
    macroNote: '~22g carbs / 30 min',
    isDefault: true,
    swatch: 'linear-gradient(135deg, #F78B14 0%, #DC2597 100%)',
  },
  {
    id: 'during.gel_water_sports_drink',
    phase: 'during',
    name: '(Gel + Water) + Sports Drink',
    shortDescription: 'Gel + water plus a sports drink for extra carbs and sodium.',
    ingredients: ['Energy gel', 'Water', 'Sports drink'],
    timingNote: 'every 30 min',
    macroNote: '~40g carbs / 30 min',
    swatch: 'linear-gradient(135deg, #DC2597 0%, #1CF9CF 100%)',
  },
  {
    id: 'during.chew_water',
    phase: 'during',
    name: 'Chew + Water',
    shortDescription: 'Energy chews with water — chewable alternative to gels.',
    ingredients: ['Energy chews', 'Water'],
    timingNote: 'every 30 min',
    macroNote: '~24g carbs / 30 min',
    swatch: 'linear-gradient(135deg, #FBA748 0%, #DC2597 100%)',
  },
  {
    id: 'during.sports_drink_only',
    phase: 'during',
    name: 'Sports Drink Only',
    shortDescription: 'Liquid-only fueling — easiest on the stomach.',
    ingredients: ['Sports drink'],
    timingNote: 'continuous sipping',
    macroNote: '~30g carbs / hr',
    swatch: 'linear-gradient(135deg, #1CF9CF 0%, #DC2597 100%)',
  },
  {
    id: 'during.bar_sports_drink_water',
    phase: 'during',
    name: 'Bar + Sports Drink + Water',
    shortDescription: 'For long efforts — bar gives volume, drink gives sodium.',
    ingredients: ['Energy bar', 'Sports drink', 'Water'],
    timingNote: 'every 60 min',
    macroNote: '~50g carbs / hr',
    swatch: 'linear-gradient(135deg, #C98A4B 0%, #1CF9CF 100%)',
  },
  {
    id: 'during.high_carb_mix_water',
    phase: 'during',
    name: 'High Carb Drink Mix + Water',
    shortDescription: 'Single bottle of high-carb mix — minimal logistics.',
    ingredients: ['High carb drink mix', 'Water'],
    timingNote: 'continuous sipping',
    macroNote: '~90g carbs / hr',
    swatch: 'linear-gradient(135deg, #F78B14 0%, #1CF9CF 100%)',
  },
];

export const POST_TEMPLATES: MealTemplate[] = [
  {
    id: 'post.chocolate_milk',
    phase: 'after',
    name: 'Classic Chocolate Milk',
    shortDescription: 'Cold chocolate milk — gold-standard recovery drink.',
    ingredients: ['Chocolate milk'],
    timingNote: 'within 30 min',
    macroNote: '~26g carbs · 16g protein',
    isDefault: true,
    swatch: 'linear-gradient(135deg, #5A2A1C 0%, #381633 100%)',
  },
  {
    id: 'post.protein_shake',
    phase: 'after',
    name: 'Recovery Protein Shake',
    shortDescription: 'Whey protein blended with milk and a banana.',
    ingredients: ['Whey protein', 'Milk', 'Banana'],
    timingNote: 'within 30 min',
    macroNote: '~32g carbs · 28g protein',
    swatch: 'linear-gradient(135deg, #F5E9C9 0%, #C9A86B 100%)',
  },
  {
    id: 'post.banana_berry_smoothie',
    phase: 'after',
    name: 'Banana Berry Protein Smoothie',
    shortDescription: 'Banana, mixed berries, whey, and milk — blended.',
    ingredients: ['Banana', 'Berries', 'Whey protein', 'Milk'],
    timingNote: 'within 30 min',
    macroNote: '~45g carbs · 25g protein',
    swatch: 'linear-gradient(135deg, #DC2597 0%, #F78B14 100%)',
  },
  {
    id: 'post.yogurt_parfait',
    phase: 'after',
    name: 'Greek Yogurt Parfait',
    shortDescription: 'Greek yogurt layered with granola and berries.',
    ingredients: ['Greek yogurt', 'Granola', 'Berries'],
    timingNote: 'within 60 min',
    macroNote: '~48g carbs · 22g protein',
    swatch: 'linear-gradient(135deg, #F5E9C9 0%, #DC2597 100%)',
  },
  {
    id: 'post.bagel_nut_butter_banana',
    phase: 'after',
    name: 'Bagel + Nut Butter + Banana',
    shortDescription: 'Bagel with nut butter and sliced banana on top.',
    ingredients: ['Bagel', 'Nut butter', 'Banana'],
    timingNote: 'within 60 min',
    macroNote: '~72g carbs · 16g protein',
    swatch: 'linear-gradient(135deg, #D9A56B 0%, #B07034 100%)',
  },
  {
    id: 'post.pbj_milk',
    phase: 'after',
    name: 'PB&J + Milk',
    shortDescription: 'Classic peanut butter and jelly with a glass of milk.',
    ingredients: ['Bread', 'Peanut butter', 'Jelly', 'Milk'],
    timingNote: 'within 60 min',
    macroNote: '~58g carbs · 18g protein',
    swatch: 'linear-gradient(135deg, #F5C97A 0%, #B07034 100%)',
  },
];

export const TEMPLATES_BY_PHASE: Record<Phase, MealTemplate[]> = {
  before: PRE_TEMPLATES,
  during: DURING_TEMPLATES,
  after: POST_TEMPLATES,
};

export const DEFAULT_IDS: Record<Phase, string> = {
  before: PRE_TEMPLATES.find(t => t.isDefault)!.id,
  during: DURING_TEMPLATES.find(t => t.isDefault)!.id,
  after: POST_TEMPLATES.find(t => t.isDefault)!.id,
};

export const PHASE_LABEL: Record<Phase, string> = {
  before: 'Before',
  during: 'During',
  after: 'After',
};
