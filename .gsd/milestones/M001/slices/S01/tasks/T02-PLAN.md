---
estimated_steps: 5
estimated_files: 2
skills_used:
  - best-practices
  - code-optimizer
---

# T02: Extract fireCriticalAlert hook, isAlertWorthy helper, wire all alert paths, tune for Indian roads

**Slice:** S01 — Quiet-mode alert engine
**Milestone:** M001

## Description

Extract the `fireCriticalAlert(type, details)` unified hook that all critical alert paths call, and the `isAlertWorthy(scoredDet)` helper. These are the boundary contracts S04 (video auto-lock) and S05 (trip event tagging) will consume. Wire lane departure and drowsiness alerts through the same hook. Tune detection thresholds for Indian road conditions. Write the verification script for the entire slice.

After T01, `handleAlerts()` has per-object cooldowns and the narration gate. This task extracts the alert-firing code into a reusable function and wires the remaining alert sources (lane departure, drowsiness) through it.

## Steps

1. **Extract `fireCriticalAlert(type, details)` function.** Create a new global function that:
   - Accepts `type` (string: `'crossing'`, `'ttc_imminent'`, `'ttc_warning'`, `'following_distance'`, `'lane_departure'`, `'drowsiness'`) and `details` (object with contextual info like `{ class: 'person', direction: 'left', ttc: 1.2 }`)
   - Plays the appropriate beep (use existing `playBeep()` — frequency/duration can vary by type)
   - Triggers vibration if available
   - Schedules speech via `setTimeout(() => speak(...), 90)` — **must preserve the existing async pattern, no added latency**
   - Updates the per-object cooldown map (from T01): `alertCooldowns[cooldownKey] = performance.now()`
   - Sets `window._lastCriticalAlert = { type, details, timestamp: performance.now() }`
   - Expose as `window.fireCriticalAlert = fireCriticalAlert;`
   
   Place this function definition AFTER `speak()` and `playBeep()` but BEFORE `handleAlerts()`.

2. **Refactor `handleAlerts()` critical paths to use `fireCriticalAlert()`.** Replace the inline beep+vibrate+speak code in each critical alert block:
   - **Crossing** (~line 1155): `fireCriticalAlert('crossing', { class: sd.det.class, direction: sd.track.crossingDir, trackId })`
   - **TTC imminent** (ttc < 1.5): `fireCriticalAlert('ttc_imminent', { class: ttcObject.det.class, ttc: lowestTTC, trackId })`
   - **TTC warning** (ttc < 3): `fireCriticalAlert('ttc_warning', { class: ttcObject.det.class, ttc: lowestTTC, trackId })`
   - **Following distance**: `fireCriticalAlert('following_distance', { class: sd.det.class, areaRatio, trackId })`
   
   Each call should still be guarded by the per-object cooldown check from T01. The cooldown update moves inside `fireCriticalAlert()`.

3. **Wire lane departure through `fireCriticalAlert()`.** Find the lane departure speech alert (around line 1977 — the block that calls `speak('Lane departure ${departure}!', 'high')` and `playBeep(700, 100)`). Replace with:
   ```javascript
   fireCriticalAlert('lane_departure', { direction: departure, confidence: laneState.confidence });
   ```
   Keep the existing `LANE_SPEECH_COOLDOWN` check as an additional gate (lane departure has its own 4s cooldown separate from the per-object map).

4. **Wire drowsiness through `fireCriticalAlert()`.** In `playDrowsinessAlarm()` (around line 1245), after the alarm tone oscillator code, replace the `speak('Wake up!...')` call with:
   ```javascript
   fireCriticalAlert('drowsiness', { alarm: true });
   ```
   Keep the alarm oscillator code as-is (it's a distinct alarm tone, not a standard beep).

5. **Extract `isAlertWorthy(scoredDet)` helper.** Create a global function:
   ```javascript
   function isAlertWorthy(sd) {
     if (!sd.track) return false;
     if (sd.track.crossing) return true;
     if (sd.track.ttc < 5) return true;
     // Following distance check
     const speed = currentSpeed || 0;
     if (speed > 20) {
       const [, , bw, bh] = sd.det.bbox;
       const areaRatio = (bw * bh) / ((video.videoWidth || 1280) * (video.videoHeight || 720));
       const isVehicle = ['car', 'bus', 'truck', 'motorcycle'].includes(sd.det.class);
       const areaThreshold = Math.max(0.06, 0.15 - speed * 0.001);
       if (isVehicle && areaRatio > areaThreshold) return true;
     }
     return false;
   }
   window.isAlertWorthy = isAlertWorthy;
   ```
   Place after `fireCriticalAlert`. This can be used by T01's density gating logic and by downstream slices.

6. **Indian road threshold tuning (R010).** In `computeTTC()`, change the collision area threshold from `frameArea * 0.25` to `frameArea * 0.20` — motorcycles are physically smaller and the current 25% threshold means they'd never trigger TTC until filling a quarter of the frame, which is too late. In `detectCrossing()`, the `minHSpeed` of `videoW * 0.03` (3% of frame width/second) is reasonable for cows and dogs — leave it. `CLASS_URGENCY` values are already well-tuned — leave them. Add a comment noting these values are tuned for Indian mixed-traffic conditions.

7. **Write verification script** at `.gsd/milestones/M001/slices/S01/verify-s01.sh`:
   ```bash
   #!/bin/bash
   # Verify S01: Quiet-mode alert engine
   set -e
   FILE="index.html"
   PASS=0; FAIL=0
   check() { if eval "$1"; then echo "PASS: $2"; ((PASS++)); else echo "FAIL: $2"; ((FAIL++)); fi }
   
   check 'grep -q "adas_verbose_mode" $FILE' "verboseMode localStorage key exists"
   check 'grep -q "let verboseMode" $FILE' "verboseMode variable declared"
   check 'grep -q "alertCooldowns" $FILE' "per-object cooldown map exists"
   check 'grep -q "fireCriticalAlert" $FILE' "fireCriticalAlert function exists"
   check 'grep -q "isAlertWorthy" $FILE' "isAlertWorthy function exists"
   check 'grep -q "_lastCriticalAlert" $FILE' "window._lastCriticalAlert hook exists"
   check 'grep -q "isDenseScene\|denseScene\|scoredDets.length > 8\|scoredDets\.length >" $FILE' "density-aware gating exists"
   check 'grep -q "if (verboseMode)" $FILE' "narration gated behind verboseMode"
   check 'grep -q "window.fireCriticalAlert" $FILE' "fireCriticalAlert exposed globally"
   check 'grep -q "window.isAlertWorthy" $FILE' "isAlertWorthy exposed globally"
   check 'grep -q "frameArea \* 0.2" $FILE' "TTC collision area tuned to 0.20"
   
   echo ""
   echo "Results: $PASS passed, $FAIL failed"
   [ $FAIL -eq 0 ] || exit 1
   ```

## Must-Haves

- [ ] `fireCriticalAlert(type, details)` function defined and exposed as `window.fireCriticalAlert`
- [ ] All five critical alert paths (crossing, TTC imminent, TTC warning, following distance, lane departure, drowsiness) route through `fireCriticalAlert()`
- [ ] `window._lastCriticalAlert` updated with `{ type, details, timestamp }` on every critical alert
- [ ] `isAlertWorthy(scoredDet)` function defined and exposed as `window.isAlertWorthy`
- [ ] TTC collision area threshold lowered to `frameArea * 0.20` for motorcycle safety
- [ ] `fireCriticalAlert` preserves synchronous beep + async speech pattern (no added latency)
- [ ] Verification script passes with all checks green

## Verification

- `bash .gsd/milestones/M001/slices/S01/verify-s01.sh` — all checks pass
- `grep -c "fireCriticalAlert(" index.html` — should return 6+ (1 definition + 5+ call sites: crossing, ttc_imminent, ttc_warning, following_distance, lane_departure, drowsiness)

## Inputs

- `index.html` — modified by T01 with verboseMode, per-object cooldowns, density gating

## Expected Output

- `index.html` — modified with `fireCriticalAlert()`, `isAlertWorthy()`, wired alert paths, tuned thresholds
- `.gsd/milestones/M001/slices/S01/verify-s01.sh` — verification script for the entire slice
