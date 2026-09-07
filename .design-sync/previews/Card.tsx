import { Card, FoodRow } from '@mealvana/endurance-ds';
import { Phone, Light } from './_frame';

export const Base = () => <Phone><Card><span className="me-body">Run scheduled for Sunday, 7:00 am · 12 mi at 9:00/mi.</span></Card></Phone>;
export const Titled = () => (
  <Phone><Card title="Before Run" subtitle="3 hours before">
    <div style={{ display: 'grid', gap: 10 }}>
      <FoodRow name="Oatmeal, Banana & Honey" kcal={640} carbs={116} protein={16} fat={12} />
      <FoodRow name="Orange Juice" kcal={110} carbs={26} protein={2} fat={0} />
    </div>
  </Card></Phone>
);
export const Accented = () => <Phone><Card accent="var(--me-electrolyte)" title="Net Balance" subtitle="on track"><span className="me-data-xl" style={{ color: 'var(--me-orange)' }}>−133</span> <span className="me-caption">kcal</span></Card></Phone>;
export const OnLight = () => <Light><Card dark={false} title="During Run" subtitle="Every 30 minutes"><FoodRow dark={false} name="Energy Gel" kcal={100} carbs={25} protein={0} fat={0} /></Card></Light>;
