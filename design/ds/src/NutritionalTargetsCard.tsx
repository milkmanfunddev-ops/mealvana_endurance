import type { CSSProperties } from 'react';
import { Card } from './Card';
import { MacroRing } from './MacroRing';
import { DARK_DEFAULT, V } from './_shared';

export interface NutritionalTargetsCardProps {
  carbs: number;
  protein: number;
  fluids: number;
  targets?: { carbs: number; protein: number; fluids: number };
  /**
   * Bar colours. Defaults follow the app as shipped: carbs Yolk, protein Dragonfruit, fluids the
   * legacy blue — the macro encoding ruling is DEFERRED (Q-SA3), so pass your own until it lands.
   */
  colors?: { carbs: string; protein: string; fluids: string };
  title?: string;
  dark?: boolean;
  style?: CSSProperties;
}

/** "Your Nutritional Targets" — three MacroRings in an outlined card. The activity-details hero. */
export function NutritionalTargetsCard({
  carbs, protein, fluids,
  targets = { carbs: 97, protein: 23, fluids: 444 },
  colors = { carbs: V.yolk, protein: V.dragonfruit, fluids: '#3366FF' },
  title = 'Your Nutritional Targets',
  dark = DARK_DEFAULT, style,
}: NutritionalTargetsCardProps) {
  return (
    <Card title={title} dark={dark} style={style}>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
        <MacroRing label="Carbs" value={carbs} target={targets.carbs} unit="g" color={colors.carbs} dark={dark} />
        <MacroRing label="Protein" value={protein} target={targets.protein} unit="g" color={colors.protein} dark={dark} />
        <MacroRing label="Fluids" value={fluids} target={targets.fluids} unit="ml" color={colors.fluids} dark={dark} />
      </div>
    </Card>
  );
}
