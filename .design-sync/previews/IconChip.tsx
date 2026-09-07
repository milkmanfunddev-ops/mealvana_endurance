import { IconChip, Icon } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const CardMarkers = () => (
  <Phone><div style={{ display: 'flex', gap: 14 }}>
    <IconChip color="var(--me-orange)"><Icon name="utensils" size={22} /></IconChip>
    <IconChip><Icon name="personSwimming" size={24} /></IconChip>
    <IconChip><Icon name="personRunning" size={24} /></IconChip>
    <IconChip><Icon name="personBiking" size={24} /></IconChip>
  </div></Phone>
);
export const FilterOutlines = () => (
  <Phone><div style={{ display: 'flex', gap: 12 }}>
    <IconChip size={44} variant="outline" color="var(--me-dragonfruit)"><Icon name="heartPulse" size={18} /></IconChip>
    <IconChip size={44} variant="outline" color="var(--me-orange)"><Icon name="wandMagicSparkles" size={18} /></IconChip>
    <IconChip size={44} variant="outline" color="var(--me-electrolyte)"><Icon name="clock" size={18} /></IconChip>
  </div></Phone>
);
export const Small = () => <Phone><div style={{ display: 'flex', gap: 10 }}><IconChip size={36}><Icon name="personRunning" size={16} /></IconChip><IconChip size={36} color="var(--me-orange)"><Icon name="utensils" size={14} /></IconChip></div></Phone>;
export const OnLight = () => <Light><div style={{ display: 'flex', gap: 14 }}><IconChip color="var(--me-orange)"><Icon name="utensils" size={22} /></IconChip><IconChip><Icon name="personRunning" size={24} /></IconChip></div></Light>;
