# S01: Quiet-mode alert engine

**Goal:** App stays completely silent during normal driving unless a genuine threat is detected — crossing, TTC, following distance, lane departure, or drowsiness. Dense traffic scenes produce zero audio. All critical alert paths route through a unified `fireCriticalAlert()` hook for downstream slice consumption.

**Demo:** Run the app pointing at a busy traffic scene. Zero audio unless a real threat dynamic (crossing, approaching, too close) is present. Set `localStorage.setItem('adas_verbose_mode', 'true')` and reload — narration resumes. `window.fireCriticalAlert`, `window.isAlertWorthy`, and `window._lastCriticalAlert` are accessible from the console.

## Must-Haves

- `verboseMode` flag read from `localStorage('adas_verbose_mode')`, defaults to `false` — gates all ambient narration and narration beeps
- Per-object cooldown map keyed by `trackId + alertType` — two simultaneous threats both get alerts
- Density-aware audio gating — scenes with >8 objects suppress audio for stationary/receding objects
- `fireCriticalAlert(type, details)` function routing all critical alert paths (crossing, TTC, following distance, lane departure, drowsiness)
- `isAlertWorthy(scoredDet)` helper returning true only for approach-dynamic threats
- `window._lastCriticalAlert` object updated on every critical alert for downstream hooks
- Indian road tuning of `CLASS_URGENCY` and crossing thresholds
- Existing verbose-mode behavior preserved exactly when `verboseMode === true`

## Verification

All verification is in a single script that checks code structure:

- `bash .gsd/milestones/M001/slices/S01/verify-s01.sh` — greps for required globals, function definitions, verboseMode gate, per-object cooldown map, density threshold, and fireCriticalAlert wiring

Functional verification (manual):
- Run app with default settings → zero narration audio on a busy scene
- Set `adas_verbose_mode` to `'true'` in localStorage, reload → narration resumes
- `window.fireCriticalAlert` is a function, `window.isAlertWorthy` is a function
- Two objects approaching simultaneously → both trigger alerts (not blocked by single cooldown)
- Diagnostic check: `window.alertCooldowns` is an object with keys after alerts fire; `window.verboseMode` reflects localStorage state; stale cooldown entries (keys with timestamps >10s old) indicate stuck state

## Observability / Diagnostics

- Runtime signals: `window._lastCriticalAlert` object with `{ type, details, timestamp }` updated on every critical alert — inspectable from console or downstream code
- Inspection surfaces: `window.alertCooldowns` map showing per-object cooldown state; `window.verboseMode` boolean
- Failure visibility: If alerts aren't firing, check `window.alertCooldowns` for stuck cooldowns; check `window.verboseMode` for unexpected quiet

## Integration Closure

- Upstream surfaces consumed: none (first slice)
- New wiring introduced: `fireCriticalAlert()` global function, `isAlertWorthy()` global function, `window._lastCriticalAlert` object
- What remains before milestone is truly usable end-to-end: S02 (navigation shell), S03 (settings UI for verbose toggle), S04 (video auto-lock consuming `fireCriticalAlert`), S05 (trip event tagging consuming `fireCriticalAlert`), S06 (trip history)

## Tasks

- [x] **T01: Implement quiet-mode gating, per-object cooldowns, and density-aware suppression** `est:45m`
  - Why: Core deliverable — makes the app silent by default (R001), replaces single-timestamp cooldown with per-object map (R006), and adds density-aware audio gating (R005). These three changes are tightly coupled in `handleAlerts()` and its surrounding state variables.
  - Files: `index.html`
  - Do: (1) Add `let verboseMode = localStorage.getItem('adas_verbose_mode') === 'true';` near line 968 with other localStorage reads. (2) Replace single `lastCriticalAlert` timestamp with `const alertCooldowns = {};` map keyed by `trackId + alertType`. (3) Update all cooldown checks in `handleAlerts()` to use the map. (4) Gate the entire `=== REGULAR NARRATION ===` block (lines ~1216-1236) behind `if (verboseMode)`. (5) Add density gate at start of `handleAlerts()`: when `scoredDets.length > 8`, skip audio for objects with no active approach dynamics (TTC >= 5, not crossing, not following-distance). (6) Expose `window.verboseMode` and `window.alertCooldowns` for inspection.
  - Verify: `grep -q 'adas_verbose_mode' index.html && grep -q 'alertCooldowns' index.html && grep -q 'verboseMode' index.html`
  - Done when: App produces zero narration audio with default settings. Per-object cooldown map replaces single timestamp. Dense scenes (>8 objects) only alert on approaching/crossing dynamics.

- [x] **T02: Extract fireCriticalAlert hook, isAlertWorthy helper, wire all alert paths, tune for Indian roads** `est:45m`
  - Why: Delivers the boundary contract (`fireCriticalAlert`, `isAlertWorthy`, `_lastCriticalAlert`) that S04 and S05 depend on. Routes lane departure and drowsiness alerts through the unified hook. Tunes thresholds for Indian road conditions (R002, R010). Creates the verification script for the entire slice.
  - Files: `index.html`, `.gsd/milestones/M001/slices/S01/verify-s01.sh`
  - Do: (1) Extract `fireCriticalAlert(type, details)` function that plays beep, speaks message, updates per-object cooldown, sets `window._lastCriticalAlert = { type, details, timestamp }`. (2) Replace inline critical alert code in `handleAlerts()` (crossing, TTC imminent, TTC warning, following distance) with calls to `fireCriticalAlert()`. (3) Wire lane departure alert (~line 1977) through `fireCriticalAlert('lane_departure', ...)`. (4) Wire drowsiness alarm (~line 1262) through `fireCriticalAlert('drowsiness', ...)`. (5) Extract `isAlertWorthy(scoredDet)` — returns true when detection has TTC < 5, is crossing, or triggers following-distance. (6) Review `CLASS_URGENCY` — cow crossing threshold in `detectCrossing()` at `videoW * 0.03` is reasonable; lower TTC collision area threshold from `frameArea * 0.25` to `frameArea * 0.20` for smaller vehicles like motorcycles. (7) Write `verify-s01.sh` script checking all structural requirements.
  - Verify: `bash .gsd/milestones/M001/slices/S01/verify-s01.sh`
  - Done when: All critical alert paths route through `fireCriticalAlert()`. `window.fireCriticalAlert` and `window.isAlertWorthy` are callable. `window._lastCriticalAlert` updates on every critical event. Verification script passes.

## Files Likely Touched

- `index.html`
- `.gsd/milestones/M001/slices/S01/verify-s01.sh`
