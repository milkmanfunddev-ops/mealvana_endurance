import { Icon, ICON_PATHS } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const Sports = () => (
  <Phone><div style={{ display: 'flex', gap: 18, color: 'var(--me-cream)' }}>
    <Icon name="personRunning" size={22} /><Icon name="personBiking" size={22} /><Icon name="personSwimming" size={22} /><Icon name="personWalking" size={22} /><Icon name="personHiking" size={22} /><Icon name="dumbbell" size={22} />
  </div></Phone>
);
export const Food = () => (
  <Phone><div style={{ display: 'flex', gap: 18, color: 'var(--me-orange)' }}>
    <Icon name="utensils" size={22} /><Icon name="bowlFood" size={22} /><Icon name="appleWhole" size={22} /><Icon name="drumstickBite" size={22} /><Icon name="jar" size={22} /><Icon name="pills" size={22} />
  </div></Phone>
);
export const Chrome = () => (
  <Phone><div style={{ display: 'flex', flexWrap: 'wrap', gap: 18, color: 'var(--me-cream)' }}>
    <Icon name="calendar" size={20} /><Icon name="calendarCheck" size={20} /><Icon name="gear" size={20} /><Icon name="plus" size={20} /><Icon name="minus" size={20} /><Icon name="chevronLeft" size={20} /><Icon name="chevronRight" size={20} /><Icon name="check" size={20} /><Icon name="clock" size={20} /><Icon name="graduationCap" size={20} />
  </div></Phone>
);
export const AllGlyphs = () => (
  <Phone w={375}><div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: 14, color: 'var(--me-cream)' }}>
    {(Object.keys(ICON_PATHS) as Array<keyof typeof ICON_PATHS>).map((n) => (
      <div key={n} style={{ display: 'grid', justifyItems: 'center', gap: 6 }}><Icon name={n} size={18} /><span style={{ fontFamily: 'var(--me-font-body)', fontSize: 8, color: 'var(--me-ink-3)', textAlign: 'center' }}>{n}</span></div>
    ))}
  </div></Phone>
);
