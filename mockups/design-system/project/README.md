# Pizzalator Design System

Pizzalator is a dough calculator for the home kitchen. The phone lives on the counter next to the scale, often with flour on it, in bad light, for hours. The interface is built for that: big numbers, big targets, a dark warm ground, one hot colour for action and one cool colour for everything cold or done.

## Voice

Short, concrete, second person. "Add 1.5% oil." not "It is recommended that oil be added." Numbers carry units and one decimal at most. Labels are nouns (Hydration, Oven, Schedule), buttons are verbs (Plan fermentation, Save bake, Apply −2 pp). No exclamation marks, no emoji.

## Principles

1. **Numbers are the product.** The largest type on any screen is a value: hydration, yeast grams, a timer. Everything else supports reading that value fast.
2. **Floury hands.** Every control is at least `tap-min` (44px); the one primary action per screen is `tap-cta` (56px) and sits at the bottom. No precision gestures.
3. **Dark first, warm.** `ground` is a warm charcoal, never black. The light theme is for daylight and prints; both themes ship in `tokens.json`.
4. **Suggest, never silently change.** Oven tips, calibration hints and routine edits are cards with an explicit apply button and a visible diff.
5. **One hot, one cool.** `ember` means action, heat, a resting dough. `sage` means cold, done, a good outcome. `wheat` marks hands-on work. `alert` only for bad outcomes and removal.
6. **Motion explains state.** Numbers tween when inputs change, the rest ring breathes, a finished timer dings, an applied hint collapses. Nothing moves for decoration.

## Colour

Use roles, not hexes. `ground` → `surface` → `surface-raised` is the elevation ladder; borders are `line`, or `line-strong` for controls and the result card. Text is `ink`, `ink-soft`, `ink-muted` in that order of importance; `ink-muted` is also the colour of every uppercase label. Tinted cards pair a tint with its line: `ember-tint` + `ember-line` for tips, `sage-tint` + `sage-line` for hints. Never put `ember` text on `ember-tint`; use `ember-bright` for the label and `ink` for the copy.

Contrast: every text token is at least 4.5:1 on the grounds its usage note names, in both themes. `ember-bright` in the light theme is for 28px+ numbers only.

## Type

Two families, both hosted on Google Fonts, no files: **Bricolage Grotesque** for display (titles and hero numbers, weight 700, tight tracking) and **Inter** for everything else. All values use `font-variant-numeric: tabular-nums` so digits do not jump while they tween. The `label` style is uppercase with 0.08em tracking and always `ink-muted` or a tinted-card bright colour.

## Spacing and shape

Screen gutter `space-5`. Cards use `space-4` padding and `radius-xl`; controls inside use `space-3` gaps. Inputs and buttons are `radius-md`, chips and tracks `radius-pill`, sheets `radius-2xl` at the top. Shadows exist only where the UI floats: the selected segment, the FAB, the sheet, and the input focus ring.

## Iconography

Inline stroke SVG, 24-unit grid, stroke 1.8–2.2, round caps, currentColor. Icons are never the only label on a control except the FAB and back arrows, which carry `aria-label`. No emoji, no filled glyphs except stars.

## Motion

| name | spec | use |
|---|---|---|
| rise | translateY 10px → 0, opacity 0 → 1, 400–450ms ease, 50–60ms stagger | card entrance |
| pop | scale .94 → 1.04 → 1, 300ms cubic-bezier(.2,.8,.3,1.3) | chip or segment select |
| tween | value lerp 450ms ease-out cubic | any changed number |
| fill | width / flex 500ms cubic-bezier(.2,.8,.2,1) | bars and tracks |
| breathe | scale 1 → 1.025, 4s loop | rest ring while running |
| ding | ±14° wobble, 600ms | timer end |
| collapse | max-height → 0, 450ms | hint applied or dismissed |
| toast | 2s rise, hold, fade | confirmations |

Respect `prefers-reduced-motion`: keep tweens and fills, drop breathe, ding and shimmer.

## Components

Button, Chip, Segmented, Card, Stat, Bar, Ring, StepRow, Switch, Stars, Toast, Sheet. Each has a README with states and a live preview. They are specs for the Flutter widgets, not a web bundle.

## Flutter mapping

`tokens.json` → a `ThemeExtension` with `PizzaColors` and `PizzaText`; fonts via `google_fonts`. Numbers: `TweenAnimationBuilder`; bars: `AnimatedContainer`/`AnimatedFractionallySizedBox`; ring: `CustomPainter` with an `AnimationController`; haptics on chip select and timer end.
