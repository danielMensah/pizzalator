# Segmented

Two to four mutually exclusive options that change what a card shows: entry mode, oven surface, leavening type, recipe tabs, outcome scales.

**Anatomy**: container `surface` fill, `line-strong` border, `radius-md` (14px), 4px inner padding, 4px gaps; buttons 40px tall, `radius-md` (10px), `ink-muted` label at `body-sm` 500. Selected: `surface-raised` fill, `ink` text, `shadow-segment`.

**Outcome variant** (log entry): the selected segment is tinted by meaning, `sage-tint` + `sage-bright` for good and `alert-tint` + `alert` for bad, so a filled form reads at a glance.

**Rules**: labels fit on one line at 13px in a 390px frame; four segments max. Use chips when the row needs to scroll, tabs when the options are whole screens.
