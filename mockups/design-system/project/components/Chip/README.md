# Chip

Single-select pills for style, filter and preset rows. One row scrolls horizontally with `space-2` gaps and bleeds past the gutter.

**Anatomy**: 44px tall (40px in secondary rows such as filters), `radius-pill`, `line-strong` border, `surface` fill, `ink-soft` label at `button` style.

**Selected**: `ember` fill and border, `on-ember` text, `pop` animation on select. Filter and preset chips (not the main style row) select to `ink` fill with `ground` text so a second row never competes with the ember style row.

**Rules**: selection is exclusive within a row; never use chips for multi-select (use tags or checkboxes). Labels are one or two words. The selected chip scrolls into view.
