import { TripleAction } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

export const Inline = () => <Phone><TripleAction inline /></Phone>;
export const PinnedOnScreen = () => (
  <div style={{ position: 'relative', width: 375, height: 220, background: 'var(--me-blackberry)', color: 'var(--me-cream)', borderRadius: 20, overflow: 'hidden' }}>
    <div className="me-section-title" style={{ padding: 17 }}>Upcoming Events</div>
    <TripleAction />
  </div>
);
