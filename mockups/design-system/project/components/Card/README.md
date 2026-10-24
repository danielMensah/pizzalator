# Card

The container for every group of controls or results. Three kinds.

- **Plain**: `surface` fill, 1px `line` border, `radius-xl`, `space-4` padding (14px for list cards). The result card uses `line-strong` to read as the most important card.
- **Tip** (oven suggestion): `ember-tint` fill, `ember-line` border, `radius-lg`, a flame icon, `label` in `ember-bright`, copy in `ink`, one secondary button that applies or reverts. Enters with `slideIn`.
- **Hint** (calibration): `sage-tint` fill, `sage-line` border, `radius-xl`, label in `sage-bright`, Apply as a `success` button beside Not now. Leaves with `collapse`.

Cards enter with `rise`, staggered 50–60ms down the screen. A card never nests a card; use a divider row (`line`) instead.
