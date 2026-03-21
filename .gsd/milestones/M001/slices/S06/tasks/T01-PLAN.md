---
estimated_steps: 6
estimated_files: 1
skills_used:
  - frontend-design
  - accessibility
---

# T01: Leaflet CDN, trips page CSS/HTML scaffold, and calendar + trip list logic

**Slice:** S06 — Trip History with Calendar & Map View
**Milestone:** M001

## Description

Establishes the complete visual foundation for the trips page and implements the calendar date picker with trip listing — delivering R021 (calendar-style date picker showing which dates have trips). This is the first half of S06: after this task, the trips page is a fully functional calendar browser. The second task will add map and log views for individual trips.

The app is a single `index.html` file (~3827 lines). All CSS goes in the existing `<style>` block, all HTML in the `#page-trips` div, all JS at script scope before the closing `</script>`.

## Steps

1. **Add Leaflet CDN links.** Insert Leaflet CSS `<link>` in `<head>` on the line *before* the `<style>` tag (line 9). Insert Leaflet JS `<script>` after the existing CDN scripts (after line 1299, the human.js script) but before the main `<script>` tag (line 1301). Use version 1.9.4 from unpkg:
   - CSS: `https://unpkg.com/leaflet@1.9.4/dist/leaflet.css`
   - JS: `https://unpkg.com/leaflet@1.9.4/dist/leaflet.js`

2. **Add all S06 CSS.** Insert a new section in the `<style>` block before `</style>` (currently line 1060). Add a section comment `/* === S06: Trips page === */` and define styles for:
   - `#page-trips .page-content` — flex column, stretch, overflow-y auto, padding 16px, gap 12px (mirrors gallery)
   - `.trips-calendar` — calendar container
   - `.trips-cal-header` — month navigation row: flex, space-between, align-items center
   - `.trips-cal-nav` — navigation buttons (← →): Orbitron font, cyan color, no background, cursor pointer
   - `.trips-cal-month` — month/year label: Orbitron 0.55rem, letter-spacing 0.15em, cyan
   - `.trips-cal-grid` — 7-column CSS grid, gap 4px
   - `.trips-cal-day-label` — day-of-week headers (S M T W T F S): Orbitron 0.35rem, color #3a6a7a
   - `.trips-cal-day` — day cells: centered, Orbitron 0.4rem, padding 8px, border-radius 4px, cursor pointer
   - `.trips-cal-day.has-trip` — cyan glow highlight: `box-shadow: 0 0 8px var(--cyan-glow)`, `border: 1px solid var(--cyan)`, color cyan
   - `.trips-cal-day.selected` — selected date: background `rgba(0,240,255,0.15)`
   - `.trips-cal-day.empty` — empty grid cells: no pointer, no hover
   - `.trips-cal-day.today` — current date: border cyan-dim
   - `.trip-card` — card styling matching gallery-card pattern: `rgba(0, 15, 25, 0.6)` bg, border, border-radius 4px, padding 12px 16px, flex column, gap 8px, cursor pointer
   - `.trip-card-header` — flex row, space-between
   - `.trip-card-time` — Orbitron 0.5rem, cyan, letter-spacing 0.15em
   - `.trip-card-meta` — Share Tech Mono 0.4rem, color #3a6a7a
   - `.trip-card-badge` — event count badge: Orbitron 0.35rem, amber background/border/color, padding 2px 8px
   - `.trips-empty` — empty state text matching `.gallery-empty`: Orbitron 0.7rem, letter-spacing 0.2em, color #2a4a5a
   - `.trip-detail-tabs` — tab bar: flex row, gap 0
   - `.trip-detail-tab` — tab button: Orbitron 0.45rem, padding 8px 16px, border 1px solid var(--border), background transparent, color #3a6a7a, cursor pointer
   - `.trip-detail-tab.active` — active tab: cyan border, cyan color, cyan glow
   - `.trip-map-container` — map container: width 100%, height 300px, border-radius 4px, border 1px solid var(--border), overflow hidden
   - `.trip-log-list` — event log container: flex column, gap 8px
   - `.trip-log-card` — event card: background rgba(0,15,25,0.6), border, padding 10px 14px, border-radius 4px, flex column, gap 4px
   - `.trip-log-time` — Orbitron 0.4rem, cyan
   - `.trip-log-badge` — type badge: Orbitron 0.35rem, padding 2px 8px, border-radius 2px
   - `.trip-log-badge.impact` — red bg/border/color
   - `.trip-log-badge.adas` — magenta bg/border/color
   - `.trip-log-details` — Share Tech Mono 0.38rem, color #5a8a9a
   - `.trip-log-video-btn` — "VIEW CLIP" button: Orbitron 0.35rem, cyan border, cyan color, padding 4px 10px, cursor pointer

3. **Replace `#page-trips` HTML.** Replace the current placeholder content in `#page-trips` (between the opening div and the closing div, lines ~1280-1290) with:
   - Keep existing `.page-header` with BACK button and title
   - Replace `.page-content` contents: remove the `<span class="page-placeholder">` and add:
     - `<div id="trips-calendar-view">` — contains `.trips-calendar` with `.trips-cal-header` (← MONTH YEAR →) and `.trips-cal-grid`, plus `<div id="trips-day-list"></div>` for trip cards
     - `<div id="trips-detail-view" style="display:none;">` — contains `.trip-detail-tabs` (MAP | LOG tabs), `<div id="trip-map-container" class="trip-map-container"></div>`, `<div id="trip-log-list" class="trip-log-list"></div>`, and a sub-header row for trip info + back-to-calendar button

4. **Implement calendar rendering JS.** Add a new section `// ===== S06: TRIPS PAGE =====` in the main `<script>` block (before the `// === S02: Page navigation functions ===` section). Implement:
   - Module-scoped state: `let tripsMap = null; let tripsCurrentMonth = new Date().getMonth(); let tripsCurrentYear = new Date().getFullYear(); let tripsDatesWithTrips = [];`
   - `async function initTripsPage()` — calls `getDatesWithTrips()`, stores result in `tripsDatesWithTrips`, renders calendar for current month, shows calendar view, hides detail view. Logs `[TRIPS] Initialized trips page`.
   - `function renderCalendar(year, month)` — builds the 7-column calendar grid for the given month/year. Calculates first day offset, days in month. Creates day cells, marks `.has-trip` for dates in `tripsDatesWithTrips`, marks `.today` for current date. Adds click handler on day cells calling `selectDate(dateStr)`. Adds click handlers on nav buttons for `tripsCurrentMonth` increment/decrement with year rollover, re-renders.
   - `async function selectDate(dateStr)` — calls `getTripsForDate(dateStr)`, renders trip cards in `#trips-day-list`. Each card shows start time (HH:MM), duration (minutes), event count. Card click calls `showTripDetail(trip)`. If no trips, shows empty state. Marks selected date in calendar. Logs `[TRIPS] Selected date: dateStr, N trips`.

5. **Wire showPage/hidePage hooks.** In the existing `showPage()` function (around line 3790), add: `if (pageId === 'page-trips' && typeof initTripsPage === 'function') initTripsPage();`. In the existing `hidePage()` function, add: `if (pageId === 'page-trips' && typeof tripsCleanup === 'function') tripsCleanup();`. Define `function tripsCleanup()` as a stub that logs `[TRIPS] Cleanup` — map teardown will be added in T02.

6. **Add `showTripDetail(trip)` stub.** Implement a minimal `function showTripDetail(trip)` that hides the calendar view (`#trips-calendar-view`), shows the detail view (`#trips-detail-view`), and populates a header with the trip's start time and date. Adds a "← BACK TO CALENDAR" click handler that reverses the show/hide. The actual map and log rendering will be implemented in T02 — this stub just switches the view containers. Logs `[TRIPS] Showing trip detail: tripId`.

## Must-Haves

- [ ] Leaflet 1.9.4 CSS and JS CDN links added to index.html
- [ ] All S06 CSS styles in the `<style>` block following cyberpunk HUD design language
- [ ] Calendar grid with 7 columns, day-of-week headers, correct month boundaries
- [ ] Month navigation (← YEAR MONTH →) with prev/next cycling
- [ ] Dates with trips highlighted with cyan glow via `getDatesWithTrips()` query
- [ ] Date tap → trip cards listed via `getTripsForDate()` query
- [ ] Trip cards show start time, duration, event count
- [ ] `showPage('page-trips')` triggers `initTripsPage()`
- [ ] `hidePage('page-trips')` triggers `tripsCleanup()`
- [ ] Trip detail containers exist in DOM (hidden by default) for T02 to populate
- [ ] Empty state messages for no trips and no trips on date
- [ ] `[TRIPS]` console log prefix on all log points

## Verification

- `grep -q 'leaflet@1.9.4/dist/leaflet.css' index.html` — Leaflet CSS CDN present
- `grep -q 'leaflet@1.9.4/dist/leaflet.js' index.html` — Leaflet JS CDN present
- `grep -q 'initTripsPage' index.html` — init function exists
- `grep -q 'getDatesWithTrips' index.html` — calendar uses S05 API
- `grep -q 'getTripsForDate' index.html` — date selection uses S05 API
- `grep -q 'trips-calendar-view' index.html` — calendar container exists
- `grep -q 'trips-detail-view' index.html` — detail container exists
- `grep -q 'renderCalendar' index.html` — calendar rendering function exists
- `grep -q 'selectDate' index.html` — date selection function exists
- `grep -q 'tripsCleanup' index.html` — cleanup function exists
- `grep -c '\[TRIPS\]' index.html` returns >= 5 — adequate logging

## Inputs

- `index.html` — existing 3827-line single-file app with `#page-trips` placeholder, `showPage()`/`hidePage()` nav system, S05's `getTripsForDate()`/`getDatesWithTrips()` APIs, cyberpunk CSS patterns, gallery card styling to mirror

## Expected Output

- `index.html` — modified with Leaflet CDN links, S06 CSS section, trips page HTML scaffold, calendar rendering JS, trip list JS, showPage/hidePage hooks wired
