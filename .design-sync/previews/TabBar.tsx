import { useState } from 'react';
import { TabBar } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const items = [
  { value: 'timeline', icon: 'calendar' as const, label: 'Timeline' },
  { value: 'events', icon: 'medal' as const, label: 'Events' },
  { value: 'learn', icon: 'graduationCap' as const, label: 'Learn' },
];

// Busy content behind the bar so the dimmed glass + bubble read as materials.
const Busy = ({ children }: { children: React.ReactNode }) => (
  <div style={{ position: 'relative', height: 150, borderRadius: 16, overflow: 'hidden', background: 'linear-gradient(120deg, rgba(28,249,207,0.35), rgba(56,22,51,0.2) 40%, rgba(247,139,20,0.45))' }}>
    <p style={{ margin: 12, fontFamily: 'var(--me-font-body)', fontSize: 13, color: 'var(--me-cream)', opacity: 0.9 }}>
      Long Run · 120 min · Pre / During / Recovery fuel — the bar's dimmed chain mutes busy content behind it.
    </p>
    <div style={{ position: 'absolute', inset: 0 }}>{children}</div>
  </div>
);

export const Expanded = () => {
  const [v, s] = useState('timeline');
  return <Phone><Busy><TabBar items={items} selected={v} onChange={s} /></Busy></Phone>;
};

export const ActiveBubbleOnEvents = () => (
  <Phone><Busy><TabBar items={items} selected="events" onChange={() => {}} /></Busy></Phone>
);

export const Collapsed = () => (
  <Phone><Busy><TabBar collapsed items={items} selected="timeline" onChange={() => {}} /></Busy></Phone>
);
