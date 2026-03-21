---
estimated_steps: 2
estimated_files: 1
skills_used: []
---

# T03: Structural verification script

**Slice:** S06 — Trip History with Calendar & Map View
**Milestone:** M001

## Description

Creates `verify-s06.sh` — a grep-based structural verification script that proves all S06 contract surfaces exist in `index.html`. Follows the exact pattern from `verify-s05.sh` (check function, PASS/FAIL counters, summary line). Organized by category: Leaflet CDN, Calendar UI, Map View, Log View, Video Linking, Navigation Hooks, Console Logging.

## Steps

1. **Write `verify-s06.sh`.** Create the script with a `check()` function matching `verify-s05.sh` pattern. Define ~20 checks across 7 categories:

   **Leaflet CDN (2 checks):**
   - Leaflet CSS link (`leaflet@1.9.4/dist/leaflet.css`)
   - Leaflet JS script (`leaflet@1.9.4/dist/leaflet.js`)

   **Calendar UI (4 checks):**
   - Calendar container (`trips-calendar-view`)
   - Calendar grid (`trips-cal-grid`)
   - Month navigation buttons (`trips-cal-nav`)
   - `getDatesWithTrips` call for date highlighting

   **Map View (4 checks):**
   - `L.tileLayer` for OSM tiles
   - `L.polyline` for route rendering
   - `L.circleMarker` for event markers
   - `invalidateSize` call for container resize fix

   **Log View (3 checks):**
   - Log list container (`trip-log-list`)
   - Log card class (`trip-log-card`)
   - Log badge classes (`trip-log-badge`)

   **Video Linking (2 checks):**
   - `dashcam_videos` query for video chunks (at least one reference in S06 section)
   - `VIEW CLIP` button text

   **Navigation Hooks (3 checks):**
   - `initTripsPage` function
   - `tripsCleanup` function
   - `showTripDetail` function

   **Console Logging (2 checks):**
   - `[TRIPS]` log prefix (at least 5 occurrences)
   - `[TRIPS] Error` error prefix (at least 1 occurrence)

2. **Run and confirm all checks pass.** Execute `bash verify-s06.sh` and verify all 20 checks pass.

## Must-Haves

- [ ] `verify-s06.sh` exists with ~20 structural checks
- [ ] All checks pass against the completed `index.html`
- [ ] Script follows `verify-s05.sh` pattern (check function, PASS/FAIL counters, exit code)

## Verification

- `bash verify-s06.sh` — all checks pass, exit code 0
- `test -f verify-s06.sh` — file exists

## Inputs

- `index.html` — completed by T01 and T02 with all S06 features
- `verify-s05.sh` — reference for script pattern/style

## Expected Output

- `verify-s06.sh` — structural verification script with ~20 checks, all passing
