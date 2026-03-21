---
estimated_steps: 5
estimated_files: 1
skills_used:
  - best-practices
  - code-optimizer
---

# T01: Implement quiet-mode gating, per-object cooldowns, and density-aware suppression

**Slice:** S01 — Quiet-mode alert engine
**Milestone:** M001

## Description

Make the dashcam app silent by default. Three tightly-coupled changes to the alert pipeline in `index.html`:

1. **Verbose mode flag** — Add `verboseMode` read from localStorage, defaulting to `false`. Gate all ambient narration (object counting, zone-based speech) behind this flag.
2. **Per-object cooldowns** — Replace the single `lastCriticalAlert` timestamp with a per-object cooldown map so two simultaneous threats both produce alerts.
3. **Density-aware suppression** — When >8 objects are detected in a frame, suppress audio for objects that aren't actively approaching or crossing.

All changes are in the single `index.html` file. The existing behavior must be fully preserved when `verboseMode === true`.

## Steps

1. **Add `verboseMode` flag** near line 968 (where other localStorage reads happen):
   ```javascript
   let verboseMode = localStorage.getItem('adas_verbose_mode') === 'true';
   ```
   Also expose as `window.verboseMode = verboseMode;` for console inspection by downstream code.

2. **Replace single cooldown with per-object map.** Around line 962, remove or keep `lastCriticalAlert` as a secondary rate-limiter, and add:
   ```javascript
   const alertCooldowns = {};
   window.alertCooldowns = alertCooldowns;
   ```
   Change cooldown checks in `handleAlerts()` from `now - lastCriticalAlert > CRITICAL_COOLDOWN` to:
   ```javascript
   const cooldownKey = (trackId || 'global') + '_' + alertType;
   if (now - (alertCooldowns[cooldownKey] || 0) > CRITICAL_COOLDOWN) {
     alertCooldowns[cooldownKey] = now;
     // ...fire alert...
   }
   ```
   Apply this pattern to all three critical alert paths: crossing (~line 1155), TTC imminent (~line 1178), TTC warning (~line 1186), and following distance (~line 1207). Each path needs a unique `alertType` string: `'crossing'`, `'ttc_imminent'`, `'ttc_warning'`, `'following_distance'`. Keep `lastFollowingAlert` with its own 3s cooldown as before, but also key by track ID.

3. **Remove `return` after critical alerts.** Currently, each critical alert block ends with `return;` which means only one critical alert fires per frame even if multiple distinct threats exist. Change this: remove the `return` after each critical alert block. Instead, after firing an alert, add the object/type to a `firedThisFrame` set and skip duplicates. This allows a crossing pedestrian AND a TTC warning for a different vehicle in the same frame.

4. **Gate narration behind `verboseMode`.** Find the `=== REGULAR NARRATION ===` section (around lines 1216-1236). Wrap the entire block in `if (verboseMode) { ... }`. This includes both the narration beeps (`playBeep(BEEP_FREQS[zone], 60)`) and the `speak(message, ...)` call. Both must be silenced in quiet mode.

5. **Add density-aware suppression.** At the top of `handleAlerts()`, after the early return for empty `scoredDets`, add density gating:
   ```javascript
   const isDenseScene = scoredDets.length > 8;
   ```
   Then in each critical alert check, add an additional condition: if `isDenseScene` is true, only fire the alert if the specific object has active approach dynamics — `track.ttc < 5`, `track.crossing === true`, or the following-distance check already implies proximity. For the crossing and TTC paths this is already true (they check `track.crossing` and `track.ttc`). For the following-distance path, it's already proximity-based. So the density gate primarily affects the narration path: when `isDenseScene && verboseMode`, reduce narration frequency (double the interval) or suppress entirely.

## Must-Haves

- [ ] `verboseMode` defaults to `false` when `adas_verbose_mode` is not set in localStorage
- [ ] Zero narration audio (no `speak()` calls from the regular narration block) when `verboseMode` is false
- [ ] Narration beeps from the regular narration block are also silenced in quiet mode
- [ ] Per-object cooldown map keyed by trackId + alertType
- [ ] Two simultaneous threats (different track IDs) can both fire alerts in the same frame
- [ ] Dense scenes (>8 objects) don't produce more audio than sparse scenes with the same threats
- [ ] When `verboseMode === true`, behavior matches current (pre-change) behavior exactly
- [ ] `window.verboseMode` and `window.alertCooldowns` accessible from console

## Verification

- `grep -q "adas_verbose_mode" index.html` — flag exists
- `grep -q "alertCooldowns" index.html` — per-object cooldown map exists
- `grep -q "if (verboseMode)" index.html` — narration block is gated
- `grep -q "isDenseScene" index.html` — density awareness exists
- `grep -c "return;" index.html` in the handleAlerts critical section — should be fewer returns than before (alerts no longer short-circuit)

## Inputs

- `index.html` — existing alert engine, specifically lines 940-985 (state variables), 1139-1240 (`handleAlerts` function)

## Expected Output

- `index.html` — modified with verboseMode flag, per-object cooldowns, density gating, and narration gating

## Observability Impact

- **New signals:** `window.verboseMode` (boolean) reflects current quiet/verbose state. `window.alertCooldowns` (object) exposes per-object cooldown timestamps keyed by `trackId_alertType`.
- **Changed signals:** `lastCriticalAlert` still updated on every critical alert for backward compatibility, but per-object cooldowns in `alertCooldowns` are the authoritative source.
- **Inspection:** To diagnose missing alerts, check `window.alertCooldowns` for stuck cooldowns (timestamps close to `performance.now()` that block re-firing). Check `window.verboseMode` to confirm quiet/verbose state.
- **Failure visibility:** If no alerts fire in a threatening scene, inspect `alertCooldowns` — a key with a recent timestamp means the cooldown is still active. If `verboseMode` is unexpectedly `false`, the user needs `localStorage.setItem('adas_verbose_mode', 'true')` and reload.
