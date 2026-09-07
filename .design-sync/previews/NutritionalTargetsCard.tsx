import { NutritionalTargetsCard } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const InProgress = () => <Phone><NutritionalTargetsCard carbs={72} protein={18} fluids={300} /></Phone>;
export const Complete = () => <Phone><NutritionalTargetsCard carbs={97} protein={23} fluids={473} /></Phone>;
export const OnLight = () => <Light><NutritionalTargetsCard dark={false} carbs={40} protein={10} fluids={120} /></Light>;
