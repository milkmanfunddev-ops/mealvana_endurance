import { useState } from 'react';
import { SelectionButton, Icon } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const SportGrid = () => {
  const [v, s] = useState('run');
  return (
    <Phone><div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 }}>
      <SelectionButton label="Running" icon={<Icon name="personRunning" size={22} />} isSelected={v === 'run'} onTap={() => s('run')} />
      <SelectionButton label="Cycling" icon={<Icon name="personBiking" size={22} />} isSelected={v === 'bike'} onTap={() => s('bike')} />
      <SelectionButton label="Swimming" icon={<Icon name="personSwimming" size={22} />} isSelected={v === 'swim'} onTap={() => s('swim')} />
    </div></Phone>
  );
};
export const TextOnly = () => <Phone><div style={{ display: 'flex', gap: 12 }}><SelectionButton label="Race day" isSelected onTap={() => {}} /><SelectionButton label="Training" isSelected={false} onTap={() => {}} /></div></Phone>;
export const OnLight = () => <Light><div style={{ display: 'flex', gap: 12 }}><SelectionButton dark={false} label="Running" icon={<Icon name="personRunning" size={22} />} isSelected onTap={() => {}} /><SelectionButton dark={false} label="Cycling" icon={<Icon name="personBiking" size={22} />} isSelected={false} onTap={() => {}} /></div></Light>;
