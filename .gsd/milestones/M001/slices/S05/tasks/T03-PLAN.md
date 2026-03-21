---
estimated_steps: 2
estimated_files: 1
skills_used: []
---

# T03: Verification script and requirement validation

**Slice:** S05 — Trip Logging & Video Gallery
**Milestone:** M001

## Description

Write the `verify-s05.sh` script that serves as the objective stopping condition for the slice. It runs 15+ grep-based checks against `index.html` to confirm all contract surfaces, schemas, API methods, event hooks, gallery UI, and integration points are present. This validates requirements R016, R018, R019, R020.

## Steps

1. **Write `verify-s05.sh`.**
   - Create the script with `#!/bin/bash` header and `set -e` removed (want all checks to run even if some fail).
   - Define `FILE="index.html"`, `PASS=0`, `FAIL=0` counters.
   - Define a `check()` function that takes a description and a grep pattern, runs `grep -q "$pattern" "$FILE"`, increments PASS/FAIL, prints result with ✅/❌.
   - Run these checks (minimum 15):
     1. IDB v2: `open('dashcam_db', 2)` or `dashcam_db.*2`
     2. Trip store creation: `dashcam_trips`
     3. Trip store date index: `createIndex.*date` or `'date'`
     4. Trip store startTime index: confirms startTime index on trips store
     5. TripLogger exposed: `window.tripLogger`
     6. TripLogger startTrip: `startTrip`
     7. TripLogger endTrip: `endTrip`
     8. TripLogger addCoordinate: `addCoordinate`
     9. TripLogger addEvent: `addEvent`
     10. TripLogger getTripsForDate: `getTripsForDate`
     11. TripLogger getDatesWithTrips: `getDatesWithTrips`
     12. GPS callback extension: `_checkTripBoundary` or `tripLogger.*checkTripBoundary`
     13. lastLat/lastLng globals: `lastLat` and `lastLng`
     14. DeviceMotionEvent: `devicemotion` or `DeviceMotionEvent`
     15. iOS permission: `requestPermission`
     16. Impact threshold: `IMPACT_THRESHOLD` or `2.0` or `2` (threshold constant)
     17. fireCriticalAlert hook: `tripLogger.addEvent` inside fireCriticalAlert
     18. Gallery init function: `initGalleryPage`
     19. Gallery card rendering: `gallery-card`
     20. Play/blob URL: `createObjectURL`
     21. Blob cleanup: `revokeObjectURL`
     22. Web Share API: `navigator.share` or `navigator.canShare`
     23. Empty state: `NO RECORDINGS`
     24. Gallery init-on-show: `page-gallery.*initGalleryPage` or similar pattern
     25. Trip log prefix: `\[TRIP\]`
     26. Gallery log prefix: `\[GALLERY\]`
   - Print summary: `echo "PASS: $PASS / $((PASS + FAIL))"`.
   - Exit with code 1 if any FAIL > 0, else exit 0.
   - Make executable: `chmod +x verify-s05.sh`.

2. **Run the script and confirm all checks pass.**
   - Execute `bash verify-s05.sh`.
   - All checks should pass against the `index.html` after T01 and T02 are complete.

## Must-Haves

- [ ] `verify-s05.sh` exists and is executable
- [ ] Contains 15+ distinct checks covering IDB schema, TripLogger API, accelerometer, gallery, and integration hooks
- [ ] Each check prints PASS/FAIL with descriptive message
- [ ] Final summary shows total pass/fail count
- [ ] Exit code 0 when all pass, 1 when any fail

## Verification

- `bash verify-s05.sh` — all checks pass
- `test -f verify-s05.sh && test -x verify-s05.sh` — file exists and is executable

## Inputs

- `index.html` — with T01 and T02 changes applied (complete S05 implementation)

## Expected Output

- `verify-s05.sh` — verification script with 15+ checks
