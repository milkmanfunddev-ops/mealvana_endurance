import { MacroDonut } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const Row = () => (
  <Phone w={428}><div style={{ display: 'flex', justifyContent: 'space-between' }}>
    <MacroDonut size={118} label="Carbs" value={184} target={253} color="var(--me-data-carbs)" caption="70 g left" />
    <MacroDonut size={118} label="Protein" value={29} target={85} color="var(--me-data-protein)" caption="57 g left" />
    <MacroDonut size={118} label="Fat" value={31} target={64} color="var(--me-data-fat)" caption="34 g left" />
  </div></Phone>
);
export const WithPlanned = () => <Phone><div style={{ display: 'flex', justifyContent: 'center' }}><MacroDonut size={160} label="Carbs" value={120} target={253} planned={80} color="var(--me-data-carbs)" caption="133 g left" /></div></Phone>;
