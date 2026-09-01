import { FoodRow } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';
export const Meal = () => <Phone><FoodRow name="Oatmeal with Berries" kcal={777} carbs={102} protein={29} fat={31} onMore={() => {}} /></Phone>;
export const Timeline = () => <Phone><FoodRow name="Greek Yogurt, Granola & Berries" kcal={330} carbs={50} protein={18} fat={6} onMore={() => {}} /><FoodRow name="Chicken & Rice Burrito Bowl" kcal={680} carbs={96} protein={34} fat={18} onMore={() => {}} /></Phone>;
export const DetailOnly = () => <Phone><FoodRow name="Banana" detail="1 medium · 27 g carbs" /></Phone>;
export const OnLight = () => <Light><FoodRow dark={false} name="Energy Gel" kcal={100} carbs={25} protein={0} fat={0} /></Light>;
