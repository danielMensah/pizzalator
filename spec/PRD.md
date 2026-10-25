# Pizzalator — Pizza Dough Calculator PRD

Status: v0.4 (2026-10-24). Decisions from the planning session are folded in; remaining open items are in §11.

---

## 1. Problem

Home pizza makers know how much flour they have (or how many pizzas they want) but not how much water, salt, yeast, oil or sugar to add. Existing calculators (PizzApp+, Stadler Made, Pizza Pro, Ooni) assume a fixed flour and mostly ignore the two things that change the answer most at home:

1. **The flour on the shelf.** Italian "00" is an ash grade, not a strength grade; protein runs 9–14% across brands. UK shelves carry "plain" (~10%), "strong" (12–14%) and "very strong / Canadian" (14–15%). People also blend, e.g. 80% strong + 20% wholemeal. A hydration that works at 12.5% protein is soup at 10% and a brick at 15%.
2. **The oven.** A home oven tops out at 250–290 °C vs 430–480 °C for a Neapolitan wood oven. Steel vs stone changes bottom-heat transfer and therefore bake time, browning, and which enrichments help.

Pizzalator takes flour (type + amount, or target pizzas), style, fermentation plan and oven setup, and returns a complete scaled formula, a schedule, a bake card, and a bake log that feeds calibration over time.

## 2. Context and decisions

| Decision | Choice |
|---|---|
| Platform | Flutter, Android first. Personal use; not published to a store for now. No backend. |
| Entry mode | Both: "I have X g flour" and "I want N pizzas of size S". |
| Styles | Neapolitan, New York, Detroit, Roman teglia/al taglio, Sicilian/grandma/focaccia, Thin crust/tavern. |
| Flour input | Presets + custom flours saved in Settings (protein %, fibre, wholegrain); label scan via on-device OCR; blend up to 3 flours by share. |
| Oven setups | Home oven + steel, + stone, no surface (tray), outdoor pizza oven (Ooni/Gozney/wood). |
| Oven dough tweaks | Suggest only. Formula stays pure style; a tip card tells the user what to change. |
| Yeast | Computed from time + temperature (room / fridge / mixed). IDY, ADY, fresh. |
| Preferments | Sourdough starter, poolish, biga all in v1. |
| Units | Metric default; inch toggle for diameters and pan sizes. Ingredients always grams. |
| Persistence | Saved recipes + bake log (rating, notes, photo, structured outcomes, actual times/temps). Local only. |
| First-launch default | UK strong white (13%), home oven + steel, 250–275 °C. |

## 3. Goals / non-goals

**Goals**
- Correct baker's-percentage formula for the six styles.
- Hydration adjusted for flour protein and wholegrain share.
- Yeast or preferment quantities from the fermentation plan.
- Oven-specific bake card and dough suggestions.
- Bake log that makes the next bake better (calibration hints).

**Non-goals (v1)**
- Toppings, sauce, nutrition, social/sharing beyond copy-as-text.
- Bakery scale (> ~5 kg flour).
- Cloud sync, accounts, iOS/store release.

## 4. Core model

All quantities are baker's percentages (flour = 100%). Total flour mass is the pivot; every ingredient = total flour × pct. Preferments are carved out of the totals, never added on top.

### 4.1 Inputs

| Input | Shape | Notes |
|---|---|---|
| Entry mode | `flour` \| `pizzas` | `flour`: total flour g. `pizzas`: count + diameter (cm/in) or pan L×W (cm/in) + thickness preset; app derives total dough → total flour. Switching modes keeps percentages. |
| Style | enum of six | Loads §4.2 defaults. |
| Flours | 1–3 × {preset or custom, share %} | Shares sum to 100; last row auto-balances. Each flour carries `protein_pct`, `wholegrain`. |
| Oven | {kind, surface, max_temp_c} | kind: home \| outdoor. surface: steel \| stone \| none (home only). |
| Fermentation plan | list of stages {hours, temp_c, where: room \| fridge} | Default per style. Up to 3 stages (e.g. 2 h room → 48 h fridge → 2 h room). |
| Leavening | IDY \| ADY \| fresh \| sourdough | Plus optional preferment: none \| poolish \| biga. Sourdough excludes commercial-yeast preferments. |
| Preferment params | {flour_share %, hydration %, hours, temp_c} | Defaults §4.5. |
| Overrides | any baker's % and thickness factor | Advanced panel. Field shows style default and a "modified" badge. |
| Bowl residue | % | Default 0; 10% for Detroit/Roman/Sicilian (sticky doughs; feelingfoodish uses 10%). |

### 4.2 Style defaults (baker's %, base flour 12.5% protein)

| | Neapolitan | New York | Detroit | Roman teglia | Sicilian / focaccia | Thin / tavern |
|---|---|---|---|---|---|---|
| Hydration default (range) | 62 (58–65) | 63 (60–67) | 72 (70–75) | 80 (75–85) | 70 (65–75) | 52 (48–55) |
| Salt | 2.8 (2.5–3.0) | 2.2 (2.0–2.5) | 2.2 (2.0–2.5) | 2.5 (2.2–2.8) | 2.2 (2.0–2.5) | 2.0 (1.8–2.2) |
| Oil | 0 | 2.5 (2–3) | 3 (0–4) | 2.5 (2–3) | 4 (3–6) + pan oil | 4 (3–6) |
| Sugar / malt | 0 | 1.5 sugar | 1 sugar | 0.5 malt | 1 sugar | 1 sugar |
| IDY reference (24 h @ 20 °C) | 0.10 | 0.30 | 0.60 | 0.30 | 0.50 | 0.30 |
| Default plan | 2 h room + 24 h fridge | 1 h room + 48 h fridge | 1 h room + 24 h fridge | 1 h room + 48 h fridge | 1 h room + 24 h fridge | 1 h room + 48 h fridge |
| Weight rule | 0.354 g/cm² (250 g / 30 cm) | 0.37 g/cm² (TF 0.085 oz/in²; 14" ≈ 370 g) | 0.457 g/cm² (2.95 g/in²; 10×14" ≈ 413 g) | 0.55 g/cm² (30×40 cm ≈ 660 g) | 0.50 g/cm² (33×46 cm ≈ 760 g) | 0.26 g/cm² (TF 0.06; 12" ≈ 190 g) |
| Thickness presets | thin / std / thick = ×0.85 / 1.0 / 1.15 | same | 2.75 / 2.95 / 3.15 g/in² | same ×0.85/1/1.15 | same | same |
| Flour target | W 250–320, 11.5–13% | 12.5–14% | 12.5–14% | 13–14.5% (W 320+) | 12–13.5% | 11.5–12.5% |
| Shape | round | round | rect pan | rect pan | rect pan | round, rolled |

Sources: AVPN disciplinare 2024 (W 250–320, absorption 55–62%), Gozney hydration guide, pizzamaking.com (Lehmann thickness-factor method; TXCraig1 yeast model), feelingfoodish Detroit calculator (2.95 g/in², 10% residue). Roman, Sicilian and thin-crust numbers are consensus ranges from the same forum; treat as starting points.

### 4.3 Flour model

Preset = `{name, region, protein_pct, wholegrain}`.

| Preset | Protein % | Notes |
|---|---|---|
| Italian 00 pizza (Caputo Pizzeria class) | 12.5 | Fine mill; feels wetter at equal hydration. |
| Italian 00 weak (supermarket) | 10.5 | Warn for high-hydration styles. |
| Italian 0 / Manitoba | 14 | |
| UK plain | 10 | Warn: weak gluten. |
| UK strong white | 13 | **Default.** Sainsbury's 13.7, Doves 12–14. |
| UK very strong / Canadian | 14.5 | Waitrose Canadian 15. |
| US all-purpose | 11.5 | |
| US bread flour | 12.7 | |
| Wholemeal / whole wheat | 13 | `wholegrain`. Absorbs ~75% (Lehmann); bran delays absorption. |
| Semolina rimacinata | 12.5 | Typical 10–20% blend. |
| Custom | user | Protein (and fibre) off the bag or via label scan (§4.8); wholegrain toggle. |

**Hydration adjustment** (linear; calibrate from bake log):

```
P_eff            = Σ share_i × protein_i                 over white flours (renormalised)
H_white          = clamp(H_style + k × (P_eff − 12.5), H_min, H_max)     k = 1.0 pp per 1 % protein
water_g          = Σ_white  flour_i × H_white
                 + Σ_wholegrain flour_i × max(H_white + 10, 75)
H_displayed      = water_g / total_flour_g
```

Wholegrain share > 0 → show autolyse/soaker tip (Lehmann). Advanced panel exposes `k` and the wholegrain absorption (75) as knobs.

**Gluten warning**: `P_eff < 11` and style ∉ {Neapolitan, thin} → "weak flour for this style; expect tearing / flat crust; blend in strong flour". `H_displayed > 70` and `P_eff < 12` → same warning.

**Custom flours (Settings › Flours).** The preset list is a starting point; users add their own. Each custom flour = `{name, brand?, protein_pct, fibre_pct?, wholegrain: bool, notes?}`. Custom flours appear in every flour picker beside presets, can be edited, duplicated from a preset, deleted (recipes keep a snapshot so old bakes still compute). Presets are read-only but can be duplicated.

Why protein: UK/EU retail bags print only the nutrition panel, never W strength or P/L. Protein per 100 g is the best label proxy for gluten quantity and therefore absorption and chew; it is what the hydration rule in this section uses. Fibre per 100 g is the label tell for wholegrain: white flours sit around 3 g, wholemeal 7–11 g; the app auto-ticks `wholegrain` when fibre ≥ 6 g and lets the user override. Everything else on the label (carbs, fat, salt, energy) does not change the formula and is not stored.

**Label scan (§4.8)** fills these fields from a photo.

### 4.8 Flour label scan (on-device)

Goal: photograph the nutrition panel on a flour bag and get protein, fibre and a wholegrain guess without typing.

Approach, v1: on-device OCR + rules. No cloud, no account, works offline on any Android 5+ phone with Google Play services.
- Flutter package `google_mlkit_text_recognition` (ML Kit Text Recognition v2, Latin script). Model is bundled or downloaded once by Play services.
- Parse: find the "per 100 g" column; regex rows `protein|proteine|proteínas|eiweiß` and `fibre|fiber|ballaststoffe|fibres` followed by a number and `g`. Prefer the 100 g column over "per serving". Return `{protein, fibre, confidence}`; confidence = low when two candidate columns disagree or a value is outside 5–20 g protein / 0–15 g fibre.
- UI: camera viewfinder with a guide box, auto-capture when text is stable, then a confirm sheet showing recognised values with the matching label crop highlighted; user corrects and saves. Gallery import for an existing photo.
- Failure path: "Could not read the panel" → manual entry form pre-filled with whatever was found. Photo is never required.

Later (not v1): ML Kit GenAI Prompt / Image Description APIs on Gemini Nano for messy or non-Latin labels. Only on recent flagships (Pixel 10, Galaxy S26 class per Google's current device list), foreground only, so it is an enhancement on top of OCR, not the baseline.

### 4.4 Oven model (suggest-only)

Oven never changes the formula. It produces (a) a tip card with suggested baker's-% edits the user can apply with one tap each, (b) warnings, (c) the bake card.

| Setup | Suggested dough edits | Bake card |
|---|---|---|
| Outdoor ≥ 400 °C | None. Warn if sugar/malt > 0 for Neapolitan: burns. | 60–90 s, turn every 20–30 s. Pan styles: 300–320 °C door-open or warn. |
| Home + steel | Neapolitan: +1.5 oil, +1 sugar or +0.5 malt for browning; cap hydration 65. Others: none. | Preheat 45–60 min at max; steel 2nd-from-top rack; broil/grill last 1–2 min. NY 5–7 min; thin 6–8; Detroit/Sicilian in pan on lower-middle rack 12–16 min; Roman 15–20 min, steel optional. |
| Home + stone | As steel; Neapolitan cap 63 (slower bottom browning). | Preheat 60 min; middle rack; NY 7–9 min; finish under grill on top rack. |
| Home, no surface | Neapolitan: warn "use NY instead"; same enrichment tips. | Inverted preheated tray; NY 9–12 min; pan styles unaffected. |

`max_temp_c < 260` and style = Neapolitan → warning recommending NY.

### 4.5 Leavening model

**Commercial yeast.** IDY % for the whole plan from a time/temperature table fitted to TXCraig1's prediction model (pizzamaking.com). Multi-stage plans combine stages per Craig's multi-stage method (not a simple sum). Fridge-only plans get +30% (community reports the model under-doses cold ferments).

```
idy_pct   = lookup(plan)                     interpolated; room 16–30 °C, fridge 3–8 °C
ady_pct   = idy_pct × 1.25
fresh_pct = idy_pct × 3.0
```
Global "my kitchen runs fast/slow" ±% knob in settings (`ponytail: calibration knob`). Below 0.1 g show "pinch" guidance and suggest a yeast slurry or a larger batch.

**Poolish.** Defaults: 30% of total flour (20–50), 100% hydration, 12–16 h @ 20 °C, IDY 0.1% of poolish flour (0.25% for 8 h). Final-dough yeast = plan yeast × 0.5 (knob).

**Biga.** Defaults: 50% of total flour (30–100), 50% hydration (45–55), 16–24 h @ 16–18 °C, IDY 0.7% of biga flour. Final-dough yeast = plan yeast × 0.5. 100% biga allowed (Neapolitan style).

**Sourdough.** Starter 15% of total flour (10–25), starter hydration 100 (50–125). Commercial yeast = 0. Plan defaults to 4–6 h room bulk + 12–24 h fridge; no time/temp model in v1 (show starter %, user adjusts from log).

Preferment carve-out: `final_flour = total_flour − pref_flour`, `final_water = total_water − pref_water`. Shown as two ingredient tables (preferment, final dough) and two schedule stages.

### 4.6 Outputs

- Ingredient tables (preferment if any, final dough): flour per type, water, salt, yeast/starter, oil, sugar/malt. Totals, ball/pan weight, ball count.
- Effective hydration and effective protein.
- Water temperature to hit 24 °C final dough temp: `T_water = 3 × 24 − T_flour − T_room − friction` (friction 2 °C hand, 6 °C mixer). Preferment plans use 4-factor form.
- Schedule: preferment → mix + routine → bulk → fridge (in the container) → divide into balls → warm-up (N h before bake) → bake, the order the §4.7 routine runs. Absolute times if user enters target bake time.
- Bake card (§4.4).
- Tip card (oven suggestions, each with one-tap apply).
- Warnings.
- Copy as plain text.

### 4.7 Dough handling routine and chained timers

After mixing, the dough goes through a fixed sequence of hands-on steps and covered rests. The app runs this as one chain of timers so the user never has to remember what comes next or set a timer by hand.

**Default routine** (user's own; editable, saved per recipe):

| # | Step | Kind | Duration | Note |
|---|---|---|---|---|
| 1 | Mix all ingredients | active | ~5 min | Water, yeast, sugar, flour; salt and oil after a short rest |
| 2 | Rest in bowl, covered | rest | 30 min | Cover with napkins / cloth |
| 3 | Fold in bowl 4–6× | active | ~2 min | |
| 4 | Rest, covered | rest | 15 min | |
| 5 | Fold in bowl again | active | ~2 min | |
| 6 | Rest, covered | rest | 15 min | |
| 7 | Knead on the counter | active | 10 min | Timed active step |
| 8 | Rest on counter, covered | rest | 30 min | |
| 9 | Stretch, fold, shape one ball | active | ~5 min | Folding traps air; into the container |
| 10 | Bulk in container | rest | Room bulk hours, then (cold plan) fridge hours from the fermentation plan | Pulled from §4.5 plan; the fridge part is its own timer |
| 11 | Divide into balls | active | ~5 min | Then final proof per plan |

**Behaviour**
- Steps are `{name, kind: active | rest, minutes, note}`. Add, remove, reorder, edit minutes. Reset to default.
- A rest timer ends → local notification + sound/vibration → the next step shows with its instruction. Rest-to-active transitions wait for a "Done, next" tap (hands are busy); active-to-rest transitions start the rest timer on the tap. Option: auto-start everything.
- Active steps with a duration (knead 10 min) run a count-up or count-down timer too; untimed active steps just show the instruction.
- Step 10's duration is bound to the fermentation plan: room bulk hours, then on a cold plan a fridge rest in the container. The room-bulk end says "into the fridge", the fridge end "take out of fridge"; dividing follows, then the plan's warm-up.
- Timers survive app background/kill: store `stepIndex` + `endsAt` timestamp, reschedule local notifications on launch. Elapsed-time catch-up when reopened.
- Skip, +5 min, pause. Progress bar for the whole routine with total time remaining and projected "balls ready at HH:MM".
- Routine start can be triggered from the Recipe screen; the schedule (§4.6) absorbs the routine's total so the "mix at" time is correct.

**Routine presets.** The routine above is the built-in default. Users edit any step (name, kind, minutes, note), add/remove/reorder, and save the result as a named preset ("Same-day NY", "Cold Detroit"). A recipe points at one preset; "Reset to default" restores the built-in. Presets export with recipes (FR9).


## 5. Recipes and bake log

**Recipe** = all inputs + overrides + name. Save/load/duplicate/delete. Last-used recipe restored on launch.

**Bake log entry** (linked to a recipe snapshot):
- Date, rating 1–5, free notes.
- Photo (camera or gallery; stored in app documents dir).
- Structured outcomes: dough feel (too wet / right / too dry), proof (under / right / over), crust colour (pale / right / burnt), crumb (dense / right / open), bottom (soggy / right / burnt).
- Actuals: room temp, fridge hours, oven temp, bake minutes, surface used.

**Calibration hints** (rule-based, shown on the recipe after ≥ 2 logs):
- 2× "too wet" with same flour mix → suggest hydration −2 pp (or `k` down).
- 2× "too dry" → +2 pp.
- 2× "under-proofed" → yeast knob +15%; "over" → −15%.
- "pale" on home oven → suggest sugar/malt tip; "burnt bottom" on steel → suggest raising rack / lowering temp.
Hints are one-tap apply; never silent.

**Bake analysis** (on-device AI over the whole log, notes and photos): see `spec/bake-analysis.md`.

## 6. Functional requirements

- FR1 Style switch re-applies defaults but keeps explicitly edited fields (badge + "reset to style").
- FR2 Flour rows add/remove; last row auto-balances to 100%.
- FR3 Mode toggle re-derives flour ↔ pizzas without losing percentages.
- FR4 Live recalculation; no submit.
- FR5 Advanced panel exposes every baker's %, thickness factor, `k`, wholegrain absorption, yeast knob.
- FR6 Rounding: flour/water 1 g; salt/oil/sugar 0.1 g; yeast 0.01 g.
- FR7 cm/in toggle for sizes; grams only for ingredients.
- FR8 Fully offline; no network permission required.
- FR9 Recipe export/import as JSON (and copy-as-text) for backup since there is no cloud.
- FR10 Chained routine timers (§4.7) with local notifications; running timers persist across app restarts.
- FR11 Routine presets: edit, save as named preset, reset to default; stored per recipe.
- FR12 Settings › Flours: add/edit/delete custom flours; label scan fills protein and fibre via on-device OCR (§4.8); manual entry always available.

## 7. Non-functional

- Pure Dart calc: `calc(RecipeInputs) → RecipeOutputs`, no Flutter imports. One test file with golden cases per style (e.g. Neapolitan 1000 g at 12.5% / 62% → 620 g water, 28 g salt).
- Local storage: single JSON document per recipe and per log entry in app docs dir; photos as files. No DB until > hundreds of entries.
- Mobile first, floury hands: large tap targets, output numbers readable at arm's length, dark mode.
- Accessible: labelled fields, TalkBack order sane.

## 8. Suggested build order (ponytail)

1. Calc core + golden tests (styles, flour model, yeast table, preferment carve-out).
2. Single-screen calculator UI with advanced panel, oven tip card, bake card.
2b. Routine timers screen with local notifications; routine editor + presets.
2c. Settings › Flours with custom flours; label scan via google_mlkit_text_recognition.
3. Save/load recipes, JSON export.
4. Bake log + photos.
5. Calibration hints.

Each step is usable on its own; stop when it is good enough for your kitchen.

## 9. Risks

- Yeast tables disagree ±30% across sources; the knob and log exist to absorb this.
- Label OCR misreads (1 vs 7, decimal commas, per-serving columns). Confirm sheet and range checks catch most; manual entry is one tap away.
- Protein % is a proxy for W / P/L; two 13% flours can behave differently. Keep hydration override one tap away.
- Oven guidance is heuristic, not measured.
- Six styles × four ovens × three preferments = many defaults to get wrong; golden tests cover each style once, bake log covers the rest.

## 10. Success

- You can enter flour + style + oven and bake from the output without opening another calculator.
- After three logged bakes per style, calibration hints converge (no hint repeats for a style).

## 11. Open items

- Yeast table values: fit from Craig's chart thread (need the actual numbers; pizzamaking.com thread msg 271967).
  Until then the calc uses the Ferment mockup model: activity doubles every 8 °C, plans count as at least 2 equivalent hours, IDY clamped to 0.03–1.2 %.
- Detroit (0.60) and Sicilian (0.50) IDY references put their default 1 h + 24 h fridge plans over the 1.2 % clamp (≈ 2.1 % and 1.7 %): confirm or lower them against the fitted table.
- Roman/Sicilian/thin weight rules and hydration ranges: confirm against your own pans after first bakes.
- Sourdough timing model: none in v1; revisit if starter bakes log "under/over" repeatedly.
- Whether thickness presets should be per-style named (e.g. Detroit "classic / thick") or generic.
