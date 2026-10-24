# Feedback

Small stateful pieces that answer a tap.

- **Switch**: 50×30, `surface-raised` track, `ink` knob; on = `ember` track, knob slides 20px in 250ms with a slight overshoot.
- **Stars**: five 30px glyphs in 44px targets; lit = `ember-bright` fill, unlit = `line-strong` stroke only. A lit star bounces (`scale 1.35`, −8°) on tap.
- **Tag**: `caption` text in a `radius-sm` pill: neutral `surface-raised`/`ink-soft`, good `sage-tint`/`sage-bright`, bad `alert-tint`/`alert`.
- **Toast**: `ink` fill, `ground` text, `radius-md`, bottom-centred above the CTA, 2s `toast` animation. One line, no actions.
- **Bar**: 10px track in `surface-raised`, `radius-pill`, fill in `ember` (hydration) or `sage` (routine progress), `fill` transition. A stacked track (schedule) uses `ember-bright`, `sage`, `wheat` segments with flex-grow proportional to hours.
