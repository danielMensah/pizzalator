# Bake analysis — AI calibration from the bake log

Companion to `PRD.md`. Formulas and ranges in PRD §4 stay the source of truth; this spec only adds a way to *suggest* changes to them.

## 1. Story

As a baker with a log of past bakes, I want the app to read that log (outcomes, notes, photos) and tell me what to change next time, with one tap to apply each change, so that every bake is better than the last without me doing the analysis by hand.

## 2. Decisions (agreed 2026-10-24, do not re-ask)

| Decision | Choice |
|---|---|
| Where the model runs | On device only. Gemini Nano via ML Kit GenAI Prompt API (`google_mlkit_genai_prompt`). No cloud call, no API key, no backend. PRD FR8 (no network permission) still holds: AICore downloads the model itself. |
| Target device | Pixel 9 or newer. Nano is the main path; the fallback is a safety net. |
| Fallback | Statistics-only analysis: same screen, same cards, computed by pure Dart rules. Notes and photos are skipped and a badge says why. The feature is never hidden. |
| Trigger | On demand. "Analyse" button; result cached until a new bake is logged. No background runs. |
| Minimum data | 1 bake. The button is always enabled once the log is non-empty. Per-recipe numeric suggestions still need ≥ 2 bakes of that lineage, like rule hints. |
| Surface | A dedicated Analysis screen, entered from the Bake log and from the Recipe screen's hints section. |
| Existing rule hints | Kept. They still fire on the Recipe screen. The analysis takes them as candidates, adds notes and photo evidence, ranks and explains. One apply path shared. |
| What AI may change | Recipe inputs (hydration, salt, oil, sugar, yeast knob, preferment share), oven setup (surface, max temp), fermentation plan (stage hours and temps), routine preset step minutes. |
| What AI may not change | Global knobs: kitchen yeast knob, hydration slope `k`, flour absorption, custom flour data, style defaults, bowl residue. Anything structural (style, flour list, leavening type, preferment type, entry mode, sizes). |
| Inputs | Structured log, free notes, photos (as on-device text descriptions), all recipes together (cross-recipe). |
| Photos | Evidence only. Each photo gets a cached one-line description from the on-device Image Description API; the text is fed to the analysis. A photo never overrides a logged outcome. |
| Suggest-only | Unchanged from PRD: nothing applies without a tap. Every card shows from → to, the reason, and which bakes it rests on. |

## 3. Goals / non-goals

**Goals**
- Turn the log into a short list of concrete, bounded, evidenced changes.
- Make free-text notes and photos count, which the rule hints cannot.
- Work fully offline; degrade to rules without the model.

**Non-goals**
- Chat or follow-up questions.
- Auto-filling outcomes from photos at log time (possible later feature, see §11).
- Changing global calibration knobs.
- Any analysis of toppings, sauce or bake timing beyond the fields listed in §2.
- Running on iOS.

## 4. Pipeline

`analyse()` runs in four steps. Steps 1, 2 and 4 are pure Dart under `lib/core/`; step 3 is the only platform call.

### 4.1 Facts (pure Dart, deterministic)

Input: every `BakeEntry`, every saved recipe, the current oven, routine presets.

Output: an `AnalysisFacts` value, serialisable to compact JSON (this is also the prompt body):

- Bakes grouped into **lineages**: same style + same flour mix (reuse `_mix` from `calibration.dart`, make it public). Each lineage: recipe name(s), bake count, newest first, each bake as `{id, date, rating, outcomes, hydration, yeastKnob, plan, salt/oil/sugar, oven, actuals, notes (≤ 200 chars), photoText}`.
- Per lineage **tallies**: counts of each outcome value; mean rating; trend (rating of last 3 vs previous 3).
- Per lineage **pairings** the rules already know about, as numbers the model can quote: hydration vs dough feel, yeast knob and plan hours vs proof, oven max temp and surface vs bottom, sugar vs crust colour, fridge hours (actual) vs proof.
- **Rule candidates**: the existing `calibrationHints(...)` result for each saved recipe, as `{recipeId, target, field, from, to}`.
- **Kitchen-wide** notes: outcome counts across all lineages; actual room temp and fridge hours ranges.

Cap: newest 30 bakes overall (Nano context is small). Older bakes still count in tallies, only their rows are dropped from the prompt. `// ponytail: calibration knob`.

### 4.2 Photo evidence (on device, cached)

For each photo without a cached description, run ML Kit GenAI Image Description (`google_mlkit_genai_image_description`) and store `{photo, text, modelVersion}` in `photo_descriptions.json`. Skipped when the feature is `UNAVAILABLE`; retried when `DOWNLOADABLE` only after the user taps "Download" (see §6). Descriptions are generic ("a pizza with a charred crust on a wooden board"); that is acceptable evidence, not a measurement.

### 4.3 Model (Gemini Nano, optional)

If the Prompt API reports `AVAILABLE`: one request with a fixed system preamble and `AnalysisFacts` JSON. The preamble asks for JSON only, in this shape:

```json
{
  "summary": "two or three sentences",
  "suggestions": [
    {
      "recipeId": "…",          // or null for oven / routine targets
      "target": "recipe|oven|plan|routine",
      "field": "hydration",     // from the allowed list in §5
      "to": 64.0,
      "why": "one sentence",
      "bakes": ["id", "id"],   // evidence, must exist in the log
      "confidence": "low|medium|high"
    }
  ]
}
```

Hard rules applied **after** the model, in Dart, never trusted to the prompt:
- Parse strictly. A malformed response falls back to §4.4 with the badge reason "Model answer unusable".
- Drop any suggestion whose `field` is not allowed, whose `to` is outside the bounds in §5, whose `recipeId` is unknown, or whose `bakes` list is empty or names an unknown bake.
- Clamp the step size per §5; if clamping changes `to`, keep the suggestion with the clamped value.
- Deduplicate against rule candidates on `(recipeId, field)`: keep one card, the model's `why` if present.
- At most 8 suggestions, highest confidence first. `// ponytail: calibration knob`.
- 60 s timeout; on timeout fall back to §4.4 with reason "Model took too long".

### 4.4 Fallback (pure Dart)

Suggestions = rule candidates from §4.1 plus these statistics-only rules, each with templated text:
- Lineage with ≥ 3 bakes and rating trend down by ≥ 1: "Ratings slipping" card with no apply, listing which outcomes went wrong most.
- Under-proof in ≥ 2 of the newest 3 bakes with an actual fridge time logged shorter than the plan's: suggest plan fridge hours = median actual.
- Notes keyword scan (sticky, tacky, soupy → wet; stiff, tight, tore → dry; flat, dense → under; collapsed, soured → over). A keyword hit counts as weak evidence and is shown as such; it never produces an apply on its own.

Summary text in fallback mode is a fixed sentence: "Rules only. N bakes, M lineages."

## 5. Allowed fields and bounds

Every bound is a named constant in `lib/core/analysis.dart`, marked `// ponytail: calibration knob`.

| Target | Field | Bound on `to` | Max step per suggestion |
|---|---|---|---|
| recipe | hydration (pp) | style range from PRD §4.2 ± 5 | 3 pp |
| recipe | salt % | 1.5–3.5 | 0.5 |
| recipe | oil % | 0–8 | 1 |
| recipe | sugar / malt % | 0–4 (malt 0–1.5 for Roman) | 1 (0.5) |
| recipe | yeastKnob | 0.5–2.0 | 0.3 |
| recipe | preferment flour share % | PRD §4.5 range for that preferment | 10 |
| plan | stage hours | PRD §4.1 stage limits; total plan ≥ 2 h | 50 % of current |
| plan | stage temp °C | room 16–30, fridge 3–8 | 3 |
| oven | maxTempC | `OvenSetup.maxTempRange` | 25 |
| oven | surface | steel / stone / none, home only | n/a |
| routine | step minutes | 1–240 | 50 % of current |

Sourdough recipes: only plan hours and temps, salt, hydration. No yeast knob.

## 6. UX

New route `/analysis`. Mockup to add: `mockups/Analysis.dc.html`, following `mockups/DESIGN.md`.

**Entry points**
- Bake log: app bar action "Analyse". Disabled with tooltip "Log a bake first" when the log is empty.
- Recipe screen: a link row under the hints section, "Full analysis", visible when the log is non-empty.

**States**
1. *Idle, no report yet*: explainer card ("Reads your N bakes on this phone. Nothing leaves the device.") and the primary CTA "Analyse N bakes" (56 px, bottom).
2. *Model not downloaded* (`DOWNLOADABLE`): a card above the CTA, "On-device AI available. Download once via Android AICore (about 2 GB) for notes and photo reading." with a "Download" button and progress. "Analyse" still works in rules mode meanwhile.
3. *Running*: progress with the current step name (Reading photos 3 of 7 / Thinking / Checking suggestions) and a Cancel button. Cancel returns to the last report or idle.
4. *Report*:
   - Header: date, bake count, source badge "On-device AI" or "Rules only · reason".
   - Summary paragraph (model) or the fixed fallback sentence.
   - Suggestion cards grouped by recipe, then oven, then routine. Each card: title (field), from → to in the recipe's own units, "why", evidence chips (bake date + top tag; tap opens the log entry), confidence dot, and two buttons: **Apply** / **Not now**. Same card component as `CalibrationHint` with evidence chips added.
   - "Ratings slipping" and keyword-only cards have no Apply.
   - Stale banner at the top when a bake was logged after the report: "New bake since this analysis" with a "Re-run" button. The old report stays readable.
5. *Empty report*: "Nothing to change yet. Keep logging." plus the tallies as a small table so the screen is not blank.

**Apply semantics**
- Recipe field: edits the saved recipe. If that recipe is the active working copy, the working copy too. Toast "Hydration now 64 %" as hints do today.
- Plan: same, on `inputs.plan`.
- Oven: edits the global oven setup.
- Routine: edits that recipe's routine preset steps.
- After Apply the card collapses to a done row. Applying never re-runs the analysis.
- "Not now" hides the card; same id scheme as hints (`field:recipeId:newestBakeId`) so a newer bake raises it again.

Reduced motion: card collapse is a fade, per DESIGN.md.

## 7. Data and persistence

JSON files in the app docs dir via `JsonStore`:
- `analysis.json`: the last `AnalysisReport` `{createdAt, newestBakeId, source, reason, summary, suggestions[], tallies}` and the dismissed suggestion ids.
- `photo_descriptions.json`: map of photo file name → `{text, modelVersion}`.

No new DB. Both files are parsed with the same "bad shape set aside, never destroy" policy as `hints`.

## 8. Privacy and offline

- All inference on device. No network permission is added; AICore handles the model download outside the app.
- The report, photo descriptions and prompt never leave the device. Export (PRD FR9) does not include them.
- The explainer card states this in one sentence.

## 9. Failure modes

| Condition | Behaviour |
|---|---|
| Prompt API `UNAVAILABLE` | Rules only. Badge reason "No on-device AI on this phone". |
| `DOWNLOADABLE`, not downloaded | Rules only plus the download card. |
| Model timeout or crash | Rules only. Reason shown. The facts step never reruns. |
| Malformed or out-of-bounds output | Bad suggestions dropped silently; if none survive, rules only with reason "Model answer unusable". |
| Image description unavailable | Photos skipped; evidence chips still show the thumbnail. |
| Log empty | Entry points disabled. |

## 10. Testing

- `test/core/analysis_test.dart`: golden cases. Synthetic logs → expected `AnalysisFacts` JSON and expected fallback suggestions. Cases: two wet bakes → hydration −2; under-proof with short actual fridge → fridge hours = median; sourdough lineage never gets a yeast knob card; step clamping; dedupe against rule candidates; the 30-bake cap.
- `test/core/analysis_parse_test.dart`: model output parser. Valid, malformed, unknown field, out of bounds, unknown bake id, unknown recipe id, > 8 suggestions.
- `test/state/analysis_test.dart`: provider with the model faked (`NanoClient` interface with an in-memory fake; the real one is a thin wrapper around the plugin). Covers run, cancel, cache, stale detection, apply to saved recipe and working copy, dismiss.
- `test/screens/analysis_test.dart`: every state in §6 and both entry points.
- `test/app_test.dart`: Bake log → Analyse → Apply → Recipe shows the new value.
- `lib/services/nano.dart` (plugin wrapper) joins `lib/main.dart` in the coverage exclusion list in `tool/check_coverage.dart`; it is a platform channel and cannot run in `flutter_test`. It must contain no logic: status check, one prompt call, one describe call, close.
- Prompt preamble lives in a Dart constant with a golden test that pins it, so a change is a visible diff.

## 11. Build order (ponytail)

1. `lib/core/analysis.dart`: facts, bounds, fallback rules, parser. Goldens. No plugin yet.
2. Analysis screen in rules-only mode, entry points, persistence, apply. Whole flow in `app_test.dart`.
3. `NanoClient` + `lib/services/nano.dart` with `google_mlkit_genai_prompt`; badge, download card, timeout.
4. Photo descriptions with `google_mlkit_genai_image_description`.
5. Later, separate spec: outcome prefill from photo at log time.

Prerequisite for steps 3–4: both plugins (0.3.1) need Dart SDK ^3.12 and Flutter ≥ 3.44. `pubspec.yaml` is on Dart ^3.11.3, so steps 3–4 start with a Flutter upgrade (and `google_mlkit_text_recognition` moves to 0.17.1 at the same time).

## 12. Acceptance

- With 4 synthetic bakes (2 wet at 62 %, 2 under-proofed at knob 100 %), rules-only mode shows exactly two apply cards: hydration 62 → 60 and yeast knob 100 % → 115 %, each citing both bakes.
- Apply on the hydration card changes the saved recipe and the working copy, and the card collapses; the Recipe screen shows 60 %.
- On a Pixel 9 with Nano downloaded, the badge reads "On-device AI" and the summary mentions a note or photo detail that no rule could know.
- Airplane mode changes nothing.
- A model response with a `to` of 90 % hydration never reaches the screen.
- Coverage gate stays at 98 % with `lib/services/nano.dart` excluded.

## 13. Open items

- Prompt API multimodal input (`ImagePart`) could replace the Image Description step and read photos with full context. Try it after step 4 if descriptions prove too generic.
- Nano prompt budget: confirm the 30-bake cap fits once the real token limit is known on device; lower the cap if the model truncates.
- English-only model output in v1.
- Whether "Ratings slipping" should also look at actual room temperature drift (needs more logged actuals first).
