# Pizzalator — Design Guidelines

Mockups: the `.dc.html` files in this folder (one per screen) plus `canvas.json` (frame layout). Live canvas: https://claude.ai/artifact/XuJ1zbQAjXfsVx3gASPYiJ. Design system: `design-system/project/` (tokens, components, brand book) and https://claude.ai/artifact/XcWQBSgPqbYJuPU3DMNgYt.

## Screens

| # | File | Purpose | PRD |
|---|---|---|---|
| 1 | `Main.dc.html` | Calculator: style, entry mode, flour blend, oven, live formula, oven tip | §4.1–4.4 |
| 2 | `Ferment.dc.html` | Leavening, preferment, stage timeline, yeast result | §4.5 |
| 3 | `Recipe.dc.html` | Ingredients (tick-off), schedule, bake card, copy | §4.6 |
| 4 | `BakeLog.dc.html` | Log list, filters, calibration hint | §5 |
| 5 | `LogEntry.dc.html` | Rating, structured outcomes, actuals, photo, notes | §5 |
| 6 | `Timers.dc.html` | Chained routine timers | §4.7 |
| 7 | `Routine.dc.html` | Routine editor and presets | §4.7 |
| 8 | `Flours.dc.html` | Custom flours and label scan | §4.3, §4.8 |

Flow: 1 → 2 → 3 → 6 → 7. 1 → 8. 3 → 5. 1 ↔ 4 ↔ 5.

## Principles

1. **Numbers first.** The output grams are the product. Biggest type on screen is always a number (hydration %, yeast g, timer). Tabular numerals everywhere a value can change.
2. **Floury hands.** Phone sits on the counter. Tap targets ≥ 44 px, primary CTA 56 px, one-handed reach: actions at the bottom, reading at the top. No gestures that need precision (no swipe-to-delete without a visible button).
3. **Dark by default.** Kitchen lighting is bad and the phone is on all day. Warm charcoal ground, no pure black. Light theme exists for daylight; tokens carry both.
4. **Suggest, never silently change.** Oven tips, calibration hints and routine changes are cards with an explicit apply button and a visible diff. The style default is always recoverable.
5. **One accent, one cool.** Ember orange = action, heat, resting dough. Sage teal = cold, done, good outcome. Wheat yellow = hands-on work. Red only for bad outcomes and destructive actions. Never two accents competing on one card.
6. **Motion explains state.** Every animation maps to a dough state or a value change: numbers tween when inputs change, the rest ring breathes, a finished timer dings, a hint collapses when applied. No decorative motion.

## Layout

- Frame 390 × 844 (Android phone, portrait). Content column 350 px with 20 px gutters.
- Header: 56 px top inset (status bar), back link, H1 in display face, optional key number right-aligned.
- Vertical rhythm: 14 px between cards, 12 px inside cards, 10 px between controls in a row.
- Cards: `surface` on `ground`, 1 px `line` border, radius `xl` (20 px), padding 16 px (14 px for list cards).
- Scrolling region is the middle; header and primary CTA stay visible when the content is short.

## Colour (tokens in `design-system/project/tokens.json`)

| Role | Dark | Light | Use |
|---|---|---|---|
| ground | `#15110F` | `#FAF6F0` | Page |
| surface | `#201A17` | `#FFFFFF` | Cards, chips, segmented |
| surface-raised | `#2E2622` | `#F1EAE0` | Selected segment, bars, inactive stars |
| line / line-strong | `#2E2622` / `#3A302B` | `#E4DCD0` / `#D2C8BA` | Borders |
| ink / ink-soft / ink-muted | `#F3EDE4` / `#CFC4B8` / `#A89F93` | `#1A1512` / `#4A423C` / `#6B6058` | Text hierarchy |
| ember / ember-bright | `#E8863A` / `#F3A25B` | `#B85A17` / `#D9752B` | Primary action, hot/rest state, key numbers |
| sage / sage-bright | `#5BA8A0` / `#8FD3CB` | `#2E7E76` / `#3C9A90` | Cold, done, good |
| wheat | `#C9A227` | `#8F6F0E` | Hands-on step |
| alert / alert-bg | `#F0A3A3` / `#3A2222` | `#B3261E` / `#FBE9E7` | Bad outcome, remove |
| ember-tint / ember-line | `#2A1F14` / `#6B4420` | `#FBEADB` / `#E8C4A3` | Tip card |
| sage-tint / sage-line | `#1C2A2A` / `#2F5B57` | `#E3F2F0` / `#9ED0CA` | Hint card |

All text pairs ≥ 4.5:1 on their ground; large numbers ≥ 3:1.

## Type

- Display: **Bricolage Grotesque** 700, letter-spacing −0.02em. H1 30 px, key numbers 34–54 px.
- Body/UI: **Inter**. Body 15/22, small 13/19, caption 12/16 500, label 11/16 600 uppercase +0.08em in `ink-muted`.
- Numbers: Inter 700, `font-variant-numeric: tabular-nums`.
- Both families from Google Fonts, bundled as TTF assets in `assets/google_fonts/` (no runtime fetch; the app has no network permission).

## Components

Button (primary / secondary / icon), Chip (style, filter, preset), Segmented control, Card (plain / tip / hint), Stat (label + big number), Hydration bar, Ring timer, Step row, Switch, Stars, Toast, Bottom sheet. Specs and previews in `design-system/project/components/`.

## Motion

| Pattern | Spec | Where |
|---|---|---|
| rise | translateY 10 px → 0, opacity 0 → 1, 400–450 ms ease, 50–60 ms stagger | Cards on screen enter |
| pop | scale .94 → 1.04 → 1, 300 ms cubic-bezier(.2,.8,.3,1.3) | Chip/segment select |
| tween | value lerp 450 ms, ease-out cubic | Any changed number |
| fill | width/flex-grow 500 ms cubic-bezier(.2,.8,.2,1) | Hydration bar, schedule track |
| breathe | scale 1 → 1.025 → 1, 4 s loop | Rest ring while running |
| ding | ±14° rotate wobble, 600 ms | Timer end |
| collapse | max-height → 0, 450 ms | Hint applied/dismissed |
| slideIn | translateX −14 px, 400 ms | Tip card appears |
| toast | 2 s rise/hold/fade | Save confirmations |

Reduced motion: honour `prefers-reduced-motion`; keep tweens, drop breathe/ding/shimmer.

## Flutter mapping

Tokens → `ThemeData` extension (`PizzaColors`, `PizzaText`). Display face via `google_fonts`. Animations: `AnimatedSwitcher`/`TweenAnimationBuilder` for numbers, `AnimatedContainer` for bars, `CustomPainter` for the ring. Haptics on chip select and timer end.
