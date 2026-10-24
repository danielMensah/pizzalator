# Ring

The timer face. A 236px circle, track in `surface-raised` 14px, arc 14px with round caps starting at 12 o'clock and shrinking clockwise as time runs out.

**Colour by state**: `ember` resting, `wheat` hands-on, `sage` when done. Inside: `label` state word in the arc colour, `display-xl` clock (tabular), step name at `body-strong`, note at `caption`.

**Motion**: `ringIn` on step change; `breathe` loops while a rest runs; `ding` wobble when the arc reaches zero. The arc animates with a 900ms linear transition on `stroke-dashoffset` so one-second ticks look continuous.

**Flutter**: `CustomPainter` with `drawArc`, driven by an `AnimationController` whose value is seconds remaining over total.
