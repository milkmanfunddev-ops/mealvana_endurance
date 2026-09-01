import { MacroStat } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Trio = () => (
  <Phone><div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
    <MacroStat value="68g" label="Carbs" color="var(--me-electrolyte)" range={{ min: '50g', max: '190g', position: 0.13 }} />
    <MacroStat value="11oz" label="Fluids" color="var(--me-electrolyte)" range={{ min: '0oz', max: '17oz', position: 0.65 }} />
    <MacroStat value="378mg" label="Sodium" />
  </div></Phone>
);
export const NoRange = () => <Phone><div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)' }}><MacroStat value="82g" label="Carbs" color="var(--me-electrolyte)" /><MacroStat value="49oz" label="Fluids" color="var(--me-electrolyte)" /><MacroStat value="1250mg" label="Sodium" color="var(--me-electrolyte)" /></div></Phone>;
