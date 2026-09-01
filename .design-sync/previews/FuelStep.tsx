import { FuelStep } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Snack = () => <Phone><FuelStep title="Pre-Workout Snack" timing="Now – 30 min out" foods="Orange Juice + Bread / Toast" stats={[{ value: '50g', label: 'Carbs' }, { value: '8oz', label: 'Fluids' }]} /></Phone>;
export const TopOff = () => <Phone><FuelStep title="Top-Off" timing="Last 30 min" foods="Energy Chews + Sports Drink" stats={[{ value: '20g', label: 'Carbs' }, { value: '4oz', label: 'Fluids' }]} /></Phone>;
