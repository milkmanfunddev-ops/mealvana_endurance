import { MacroRing } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Carbs = () => <Phone><div style={{ width: 120 }}><MacroRing label="Carbs" value={72} target={97} unit="g" color="var(--me-data-carbs)" /></div></Phone>;
export const Protein = () => <Phone><div style={{ width: 120 }}><MacroRing label="Protein" value={23} target={23} unit="g" color="var(--me-data-protein)" /></div></Phone>;
export const Empty = () => <Phone><div style={{ width: 120 }}><MacroRing label="Fluids" value={0} target={444} unit="ml" color="var(--me-electrolyte)" /></div></Phone>;
export const OnLight = () => <Light><div style={{ width: 120 }}><MacroRing dark={false} label="Carbs" value={48} target={97} unit="g" color="var(--me-yolk)" /></div></Light>;
