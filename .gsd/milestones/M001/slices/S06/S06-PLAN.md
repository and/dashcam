# S06: Trip History with Calendar & Map View

**Goal:** Calendar view shows dates with trips, tapping a date lists that day's trips, each trip has a Leaflet map view with route polyline and event markers, plus a chronological log view with video links.
**Demo:** Open trips page → calendar shows highlighted dates → tap a date → see trip cards → tap a trip → map shows route polyline with colored event markers; switch to log tab → chronological event cards with "VIEW CLIP" links for matching video chunks.

## Must-Haves

- Calendar grid with month navigation and cyan-highlighted dates that have trips (R021)
- Trip list for a selected date showing start time, duration, event count
- Leaflet map with OSM tiles, route polyline from trip coordinates, circleMarker for each event (R022)
- Map auto-zooms to route bounds; `invalidateSize()` called after container shown
- Chronological event log with type badges, timestamps, details, and video chunk links (R023)
- MAP / LOG tab toggle on trip detail view
- Navigation flow: calendar → trip list → trip detail (map|log) → back
- Empty states for no trips, no trips on date, no coordinates, no events
- `showPage` / `hidePage` hooks wired for init and cleanup (map teardown)

## Verification

- `bash verify-s06.sh` — all structural checks pass (Leaflet CDN, calendar HTML, map init, polyline, circleMarker, event log, video linking, showPage/hidePage hooks, console log prefixes)

## Observability / Diagnostics

- Runtime signals: `[TRIPS]` console log prefix on all trip page operations; `[TRIPS] Error —` prefix on failures
- Inspection surfaces: Browser console filtered by `[TRIPS]`, Leaflet map instance via `tripsMap` variable
- Failure visibility: Console errors for IDB query failures, missing trip data, Leaflet init failures

## Integration Closure

- Upstream surfaces consumed: `window.tripLogger.getTripsForDate(dateStr)`, `window.tripLogger.getDatesWithTrips()`, `openVideoDatabase()` for video chunk queries, `dashcam_trips` and `dashcam_videos` IDB stores
- New wiring introduced: `initTripsPage()` hook in `showPage()`, `tripsCleanup()` hook in `hidePage()`, Leaflet CDN `<link>` and `<script>` in `<head>` / before main script
- What remains before the milestone is truly usable end-to-end: Full milestone integration verification (all 6 slices working together from a single START action)

## Tasks

- [x] **T01: Leaflet CDN, trips page CSS/HTML scaffold, and calendar + trip list logic** `est:1h30m`
  - Why: Establishes the visual foundation and first interactive feature — calendar date picker with trip listing. Covers R021 fully.
  - Files: `index.html`
  - Do: Add Leaflet CSS `<link>` in `<head>` before `<style>`, add Leaflet JS `<script>` after existing CDN scripts before main `<script>`. Add all S06 CSS in `<style>` block before `</style>`. Replace `#page-trips` placeholder HTML with calendar container, trip-list container, and trip-detail container (map + log). Implement `initTripsPage()` with calendar rendering, month nav, `getDatesWithTrips()` highlighting, date tap → `getTripsForDate()` → trip card list. Wire `showPage('page-trips')` to call `initTripsPage()`. Wire `hidePage('page-trips')` to call `tripsCleanup()` (stub for now, map cleanup in T02).
  - Verify: `grep -q 'leaflet@1.9.4/dist/leaflet.css' index.html && grep -q 'leaflet@1.9.4/dist/leaflet.js' index.html && grep -q 'initTripsPage' index.html && grep -q 'getDatesWithTrips' index.html && grep -q 'getTripsForDate' index.html`
  - Done when: Trips page shows a styled calendar grid with month navigation, dates with trips highlighted cyan, tapping a date shows trip cards below.

- [x] **T02: Map view with route + event markers, log view with video links, and tab toggle** `est:1h30m`
  - Why: Implements the core trip visualization — Leaflet map with polyline/markers and chronological event log with video chunk linking. Covers R022 and R023.
  - Files: `index.html`
  - Do: Implement trip detail view activation when a trip card is tapped. Add MAP/LOG tab toggle. Create Leaflet map in map container with OSM tiles, `L.polyline` from trip coordinates (cyan), `L.circleMarker` for events (red for impact, magenta for ADAS) with popups. Call `map.fitBounds()` and `setTimeout(() => map.invalidateSize(), 100)`. Implement log tab with chronological event cards (time, type badge, subtype, details). Video linking: query `dashcam_videos` for chunks overlapping event time → "VIEW CLIP" button. Complete `tripsCleanup()` with map teardown (`tripsMap.remove()`). Handle empty states: no coordinates → hide map tab, no events → "NO EVENTS" message.
  - Verify: `grep -q 'L.tileLayer' index.html && grep -q 'L.polyline' index.html && grep -q 'L.circleMarker' index.html && grep -q 'invalidateSize' index.html && grep -q 'dashcam_videos' index.html && grep -q 'VIEW CLIP' index.html`
  - Done when: Selecting a trip shows a Leaflet map with route polyline and colored event markers; LOG tab shows chronological events with video links; map properly tears down on page close.

- [x] **T03: Structural verification script** `est:20m`
  - Why: Provides automated proof that all S06 contract surfaces exist in the codebase, matching the verification pattern from S01–S05.
  - Files: `verify-s06.sh`
  - Do: Write `verify-s06.sh` with grep-based checks organized by category: Leaflet CDN (2 checks), Calendar UI (4 checks), Map View (4 checks), Log View (3 checks), Video Linking (2 checks), Navigation Hooks (3 checks), Console Logging (2 checks). Follow verify-s05.sh pattern exactly (check function, PASS/FAIL counters, summary).
  - Verify: `bash verify-s06.sh` — all checks pass
  - Done when: `verify-s06.sh` runs with 20/20 checks passing against the completed index.html.

## Files Likely Touched

- `index.html`
- `verify-s06.sh`
