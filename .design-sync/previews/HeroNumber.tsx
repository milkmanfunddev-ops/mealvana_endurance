import { HeroNumber } from '@mealvana/endurance-ds';
import { Phone } from './_frame';
export const DoneSoFar = () => <Phone><HeroNumber label="Done so far" value="411" unit="kcal" caption={<>+519 planned → <b style={{ color: 'var(--me-electrolyte)', fontWeight: 500 }}>930</b> projected</>} /></Phone>;
export const Centered = () => <Phone><HeroNumber align="center" label="Eaten" value="1,107" unit="/ 1,928 kcal" caption="57% of target · 821 to go" color="var(--me-orange)" /></Phone>;
