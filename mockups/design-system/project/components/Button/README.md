# Button

One primary action per screen, secondary actions beside it, icon-only buttons only for back, log and add.

**Variants**
- `primary`: `ember` fill, `on-ember` text, `radius-lg` (18px as the CTA, `radius-md` inline). Height `tap-cta` (56px) when it is the screen's CTA, 48px inline.
- `secondary`: `surface` fill, `line-strong` border, `ink` text, 48px. Also the shape of the step buttons (+/−) at 44×44 with `radius-md`.
- `success`: `sage` fill, dark text. Used for Apply and for a primary that has just completed (Copied, Saved) so the state is visible without a toast.
- `icon`: 44×44, `surface` fill, `line` border, `radius-lg`, `aria-label` required.

**States**: hover brightens 8% (desktop only); active scales to .96 in 150ms; disabled is 40% opacity with no interaction. Focus ring uses `shadow-focus`.

**Rules**: label is a verb phrase, max three words plus a number ("Apply −2 pp"). Never two primaries on one screen. A link styled as a button (navigation) is an `<a>` with the same classes, never a button inside a link.
