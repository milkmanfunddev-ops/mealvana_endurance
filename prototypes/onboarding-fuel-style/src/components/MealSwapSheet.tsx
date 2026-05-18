import { useEffect } from 'react';
import {
  MealTemplate,
  Phase,
  PHASE_LABEL,
  TEMPLATES_BY_PHASE,
} from '../data/templates';

interface Props {
  phase: Phase;
  currentId: string;
  onPick: (template: MealTemplate) => void;
  onClose: () => void;
}

const css: Record<string, React.CSSProperties> = {
  scrim: {
    position: 'absolute',
    inset: 0,
    background: 'rgba(0, 0, 0, 0.55)',
    display: 'flex',
    alignItems: 'flex-end',
    zIndex: 10,
    animation: 'meScrimIn 220ms cubic-bezier(0.2,0.8,0.2,1)',
  },
  sheet: {
    width: '100%',
    maxHeight: '80%',
    background: 'var(--me-bg-dark)',
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    borderTop: '1px solid rgba(248, 246, 235, 0.10)',
    display: 'flex',
    flexDirection: 'column',
    boxShadow: 'var(--me-shadow-lg)',
    animation: 'meSheetIn 280ms cubic-bezier(0.2,0.8,0.2,1)',
  },
  grabber: {
    width: 44,
    height: 4,
    background: 'rgba(248, 246, 235, 0.25)',
    borderRadius: 4,
    margin: '12px auto 4px',
  },
  header: {
    padding: '8px 20px 12px',
    display: 'flex',
    flexDirection: 'column',
    gap: 4,
  },
  eyebrow: {
    fontFamily: 'var(--me-font-mono)',
    fontSize: 11,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
    color: 'var(--me-fg-on-dark-muted)',
    margin: 0,
  },
  title: {
    fontFamily: 'var(--me-font-display)',
    fontWeight: 700,
    fontSize: 22,
    color: 'var(--me-orange)',
    margin: 0,
  },
  list: {
    flex: 1,
    overflowY: 'auto',
    padding: '4px 20px 28px',
    display: 'flex',
    flexDirection: 'column',
    gap: 10,
  },
  card: {
    display: 'flex',
    flexDirection: 'column',
    padding: 14,
    background: 'var(--me-surface-card-dark)',
    border: '1px solid rgba(248, 246, 235, 0.10)',
    borderRadius: 'var(--me-radius-md)',
    textAlign: 'left',
    width: '100%',
    transition:
      'border-color var(--me-duration-base) var(--me-ease-out), box-shadow var(--me-duration-base) var(--me-ease-out)',
  },
  cardSelected: {
    borderColor: 'var(--me-orange)',
    boxShadow: 'var(--me-shadow-glow)',
  },
  body: {},
  name: {
    fontFamily: 'var(--me-font-display)',
    fontWeight: 700,
    fontSize: 15,
    color: 'var(--me-cream)',
    margin: '2px 0 2px',
  },
  desc: {
    fontFamily: 'var(--me-font-body)',
    fontSize: 12,
    lineHeight: 1.35,
    color: 'var(--me-fg-on-dark-muted)',
    margin: 0,
  },
  badge: {
    alignSelf: 'flex-start',
    fontFamily: 'var(--me-font-mono)',
    fontSize: 10,
    letterSpacing: 0.4,
    textTransform: 'uppercase',
    color: 'var(--me-orange)',
    padding: '2px 8px',
    background: 'rgba(247, 139, 20, 0.12)',
    borderRadius: 'var(--me-radius-pill)',
    marginTop: 6,
  },
};

export function MealSwapSheet({ phase, currentId, onPick, onClose }: Props) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const options = TEMPLATES_BY_PHASE[phase];

  return (
    <div style={css.scrim} role="dialog" aria-modal="true" onClick={onClose}>
      <style>{`
        @keyframes meSheetIn {
          from { transform: translateY(100%); }
          to   { transform: translateY(0); }
        }
        @keyframes meScrimIn {
          from { opacity: 0; }
          to   { opacity: 1; }
        }
      `}</style>
      <div style={css.sheet} onClick={e => e.stopPropagation()}>
        <div style={css.grabber} aria-hidden />
        <div style={css.header}>
          <p style={css.eyebrow}>{PHASE_LABEL[phase]} workout</p>
          <h2 style={css.title}>Pick a different formula</h2>
        </div>
        <div style={css.list}>
          {options.map(t => {
            const selected = t.id === currentId;
            return (
              <button
                key={t.id}
                type="button"
                onClick={() => onPick(t)}
                style={{ ...css.card, ...(selected ? css.cardSelected : null) }}
              >
                <div style={css.body}>
                  <h3 style={css.name}>{t.name}</h3>
                  <p style={css.desc}>{t.shortDescription}</p>
                  {t.isDefault && <span style={css.badge}>Mealvana default</span>}
                </div>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
