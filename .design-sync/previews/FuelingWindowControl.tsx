import { FuelingWindowControl } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const ClassDefault = () => <Phone><FuelingWindowControl label="Pre-Run Fueling Window" minutes={180} maxMinutes={240} caption="3 h — long session" /></Phone>;
export const MidGrid = () => <Phone><FuelingWindowControl label="Pre-Ride Fueling Window" minutes={75} maxMinutes={240} /></Phone>;
export const ClampBound = () => <Phone><FuelingWindowControl label="Pre-Swim Fueling Window" minutes={35} maxMinutes={35} caption="Capped: session in 35 min" /></Phone>;
export const Floor = () => <Phone><FuelingWindowControl label="Pre-Activity Fueling Window" minutes={0} maxMinutes={240} /></Phone>;
