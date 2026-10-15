# DESIGN_SYSTEM — Quant RD

## Aesthetic
Dark **glassmorphism** by default, with a full light theme. Translucent surfaces,
soft layered shadows, a subtle gradient background, cyan primary and gold accent.

## Colour tokens (`Palette`)
| Token | Dark | Use |
|---|---|---|
| `bgTop` | `#070B1A` | background top |
| `bgBottom` | `#0E1630` | background bottom |
| `surface` | `#111A33` | cards, sheets |
| `accent` (cyan) | `#22D3EE` / `#06B6D4` | primary actions, focus |
| `accentAlt` (gold) | `#F5C451` / `#D4A93A` | premium highlights |
| `textPrimary` | `#E6EDF7` | headings, values |
| `textSecondary` | `#94A3B8` | body |
| `textMuted` | `#64748B` | captions |
| `success` | `#34D399` | gains |
| `warning` | `#FBBF24` | caution |
| `danger` | `#F87171` | losses, errors |
| `info` | `#60A5FA` | neutral emphasis |

Light theme: `#F4F6FB` background, white surfaces, `#0F172A` text, `#0891B2`
accent. Semantic colours resolve through an `AppColors` `ThemeExtension` so both
themes share one API (`context.colors`).

## Glass surfaces
Translucent white fill (6–12 %), 18 px background blur, 1 px hairline border
(10–20 % white), soft shadow. Implemented once in `GlassCard`.

## Type scale
Display 40 / 32, headline 24, title 20 / 16, body 15 / 14 / 12, label 14 / 11.
Tabular figures for all financial numbers.

## Spacing & radii
4 / 8-pt grid: `xxs 4 · xs 8 · sm 12 · md 16 · lg 24 · xl 32 · xxl 48`.
Radii: `xs 8 · sm 12 · md 16 · lg 24 · pill 999`.

## Elevation
`soft` (blur 18, y6), `lifted` (blur 32, y12), `glowCyan` for the brand mark.

## Motion
`instant 120 · fast 200 · standard 320 · slow 480` ms; `emphasized`
(easeOutCubic), `standard` (easeInOutCubic), `decelerate`. Screen changes use a
fade + 2 % slide; buttons and tabs animate with `fast`/`emphasized`.

## Components
`GlassCard`, `SectionHeader`, `MetricTile`, `Pill`, `EmptyState`, `ErrorView`,
`LoadingView`, `FieldLabel`, `EquityCurveChart`, `DrawdownChart`, `PriceChart`.

## Accessibility
44 px+ touch targets, semantic labels on icon buttons, contrast ≥ WCAG AA, text
scaling clamped 0.85–1.4 so layouts never break, colour never the sole status cue
(status is always also labelled).

## Responsiveness
Sidebar is permanent at ≥ 900 px width and becomes a drawer below. Grids reflow
(4 → 2 → 1 columns). No fixed-pixel layouts; everything is constraint-driven.
