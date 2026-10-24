# Pizzalator

Pizza dough calculator. Flutter, Android first, personal use, no backend, no store release yet.

## Read first

- `spec/PRD.md` — the product spec. Formulas in §4 are the source of truth for the calc core.
- `mockups/DESIGN.md` — design guidelines. Tokens in `mockups/design-system/project/tokens.json`.
- `mockups/*.dc.html` — one screen mockup per file; match them when building UI.

## Decisions (do not re-ask)

- Styles: Neapolitan, New York, Detroit, Roman teglia, Sicilian/focaccia, thin/tavern.
- Baker's percentages everywhere; total flour is the pivot. Preferments carve out of totals.
- Flour model: protein % drives hydration; wholemeal portion at ~75% absorption. Custom flours live in Settings; label scan uses on-device ML Kit OCR (`google_mlkit_text_recognition`), never cloud.
- Oven tweaks are suggest-only. The formula never changes without a tap.
- Yeast from time/temp model with a user calibration knob. Sourdough, poolish, biga in v1.
- Routine timers: user's default sequence in PRD §4.7; presets editable and saved.
- Persistence: local JSON files + photos in app docs dir. No DB until it hurts.
- Units: grams for ingredients; cm with inch toggle for sizes.
- Default first launch: UK strong white (13%), home oven + steel.

## Build order

1. Pure Dart calc core (`lib/core/`), no Flutter imports, golden tests per style. Done.
2. Calculator, Ferment, Recipe + bake card screens. Done. 2b. Timers + routine editor. Done. 2c. Settings › Flours + scan.
3. Save/load recipes, JSON export.
4. Bake log + photos.
5. Calibration hints.

## Conventions

- Calc core is `calc(RecipeInputs) -> RecipeOutputs`, deterministic, tested with golden cases (e.g. Neapolitan 1000 g @ 12.5% / 62% → 620 g water, 28 g salt).
- Rounding: flour/water 1 g; salt/oil/sugar 0.1 g; yeast 0.01 g.
- Tokens → `ThemeExtension` (`PizzaColors`, `PizzaText`); fonts via `google_fonts` (Bricolage Grotesque display, Inter body). Tabular numerals on every value.
- Tap targets ≥ 44 px; primary CTA 56 px at the bottom. Dark theme default.
- Animations map to state changes only (see DESIGN.md motion table). Honour reduced motion.
- Heuristic constants (hydration slope `k`, wholemeal 75%, yeast table) are named knobs, not magic numbers, and are marked `// ponytail: calibration knob`.
- Prefer stdlib and already-installed packages. No new dependency for what a few lines do.
- State: Riverpod 3 (`flutter_riverpod`), no code generation. `NotifierProvider` for mutable state, `Provider` for derived values (`lib/state/`). Widgets read state via `ConsumerWidget`; the calc core never imports Riverpod.
- Entry point `lib/main.dart` is wiring only (JSON store on the docs dir, notifications, routine load + timer restore, `runApp`); everything testable lives in `lib/app.dart` and below.

## Workflow: test first

- Write the failing test before the implementation, run it, watch it fail, then write the minimum code to pass. Every behaviour change starts in `test/`.
- Test layout mirrors `lib/`: `test/core/` (calc goldens), `test/state/` (providers via `ProviderContainer.test()`), `test/screens/` and `test/widgets/` (widget tests), `test/app_test.dart` (the whole flow through the real CTAs and back links, store and notifications faked).
- Anything that writes through `jsonStoreProvider` or `notificationsProvider` must override them in tests (in-memory store: real file IO never completes in fake async).
- Line coverage gate: `dart run tool/check_coverage.dart` fails under 98%. Only genuinely untestable files are excluded, listed in that script (currently `lib/main.dart`). Do not lower the threshold; add tests or move logic out of the excluded file.
- Widget tests set `GoogleFonts.config.allowRuntimeFetching = false` in `setUpAll`.
- Lints: `analysis_options.yaml` = `flutter_lints` + strict casts/inference/raw types + extra rules. `flutter analyze` must report no issues before a commit.

## Commands

```
flutter analyze
flutter test --coverage && dart run tool/check_coverage.dart
dart format --set-exit-if-changed lib test tool
flutter run
```

Run the first three before every commit.
