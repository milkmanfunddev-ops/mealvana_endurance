import { SecondaryButton, Icon } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const AddRow = () => (
  <Phone><div style={{ display: 'flex', gap: 12 }}>
    <SecondaryButton size="sm" outline="dashed" icon={<Icon name="plus" size={12} />} style={{ flex: 1 }}>Add Food</SecondaryButton>
    <SecondaryButton size="sm" outline="dashed" tone="orange" icon={<Icon name="plus" size={12} />} style={{ flex: 1 }}>Add Activity</SecondaryButton>
  </div></Phone>
);
export const Neutral = () => <Phone><div><SecondaryButton>View Details</SecondaryButton></div></Phone>;
export const Orange = () => <Phone><div><SecondaryButton tone="orange">Edit Macros</SecondaryButton></div></Phone>;
export const Small = () => <Phone><div style={{ display: 'flex', gap: 10 }}><SecondaryButton size="sm">Skip</SecondaryButton><SecondaryButton size="sm" tone="orange">Swap</SecondaryButton></div></Phone>;
export const Disabled = () => <Phone><div><SecondaryButton disabled tone="orange">Edit Macros</SecondaryButton></div></Phone>;
export const OnLight = () => <Light><div style={{ display: 'flex', gap: 10 }}><SecondaryButton dark={false} tone="orange">Edit Macros</SecondaryButton><SecondaryButton dark={false}>Skip</SecondaryButton></div></Light>;
