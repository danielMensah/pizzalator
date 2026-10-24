# StepRow

A routine or schedule step in a list: kind icon, name and sub-line, value, optional controls.

**Anatomy**: 50–60px tall, `line` divider, kind icon in a 30–34px `radius-sm` square (`surface-raised`; `ember` when current; `sage-tint` when past), name at `body-strong`, sub-line at `caption` in `ink-muted`, duration at `number` in `ink-muted`.

**States**: `past` at 45% opacity; `now` with `ember-tint` background. In the editor the row adds a grip, a kind toggle, −/+ step buttons (44px) and a remove button in `ink-muted` that turns `alert` on hover; removal slides the row out to the right.

**Timeline variant** (recipe schedule): a 12px dot and a 2px `line` connector replace the icon; the current dot pulses in `ember`, past dots are `sage`.
