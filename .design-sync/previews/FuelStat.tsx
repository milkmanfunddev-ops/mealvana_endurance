import type { ReactNode } from 'react';
import { FuelStat } from '@mealvana/endurance-ds';
import { Phone } from './_frame';

const Row = ({ children }: { children: ReactNode }) => (
  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12, alignItems: 'start' }}>{children}</div>
);

export const SummaryRow = () => (
  <Phone>
    <Row>
      <FuelStat quantity="carbs" delivered={52} unit="g" label="CARBS" bandLow={40} bandHigh={68} target={54} />
      <FuelStat quantity="fluids" delivered={12} unit="oz" label="FLUIDS" bandLow={8} bandHigh={16} target={12} />
      <FuelStat quantity="sodium" delivered={300} unit="mg" label="SODIUM" />
    </Row>
  </Phone>
);
export const OutOfBand = () => (
  <Phone>
    <Row>
      <FuelStat quantity="carbs" delivered={82} unit="g" label="CARBS" bandLow={40} bandHigh={68} target={54} deliveredOutOfBand />
      <FuelStat quantity="fluids" delivered={4} unit="oz" label="FLUIDS" bandLow={8} bandHigh={16} target={12} deliveredOutOfBand />
      <FuelStat quantity="sodium" delivered={0} unit="mg" label="SODIUM" />
    </Row>
  </Phone>
);
export const FluidGate = () => (
  <Phone>
    <Row>
      <FuelStat quantity="carbs" delivered={0} unit="g" label="CARBS" bandLow={0} bandHigh={12} target={0} />
      <FuelStat quantity="fluids" delivered={0} unit="oz" label="FLUIDS" showFigure={false} absentLine="No fluid target for this session" />
      <FuelStat quantity="sodium" delivered={0} unit="mg" label="SODIUM" />
    </Row>
  </Phone>
);
