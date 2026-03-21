# S05: Trip Logging & Video Gallery

**Goal:** Trips auto-detect on movement with GPS coordinate tracking and event tagging; video gallery shows recorded chunks with playback, save, and share.
**Demo:** Start ADAS, simulate movement — a trip record appears in IndexedDB with coordinates and events. Open gallery — recorded video chunks listed with timestamps and incident badges. Play, save, and share clips.

## Must-Haves

- IndexedDB `dashcam_db` bumped to v2 with `dashcam_trips` object store (schema: id, startTime, endTime, date, coordinates, events)
- `TripLogger` on `window.tripLogger` with `startTrip()`, `endTrip()`, `addCoordinate()`, `addEvent()`, `getTripsForDate()`, `getDatesWithTrips()`
- Trip auto-start on GPS speed > 0, auto-end after 3 minutes at speed 0
- GPS coordinates sampled every ~5 seconds during active trip
- Periodic IDB flush (~30s) during active trip for crash protection
- DeviceMotionEvent accelerometer impact detection with iOS permission handling and ~2g threshold
- `fireCriticalAlert()` extended to tag ADAS events on the active trip
- `lastLat`/`lastLng` global variables capturing latest GPS position
- `initAccelerometer()` called from START handler (user gesture for iOS)
- Gallery page replaces placeholder with dynamic video chunk list from `dashcam_videos`
- Each gallery card shows timestamp, duration, size, and incident badge if locked
- Play (blob URL → `<video>`), Save (anchor download), Share (Web Share API with File wrapping) actions
- Init-on-show pattern for gallery (following D016)
- Empty state shown when no recordings exist
- Blob URL cleanup on video end and gallery close

## Proof Level

- This slice proves: integration (trip logging wired into GPS/ADAS/accelerometer; gallery reads from VideoRecorder's IDB store)
- Real runtime required: yes (GPS, DeviceMotionEvent, MediaRecorder are browser APIs)
- Human/UAT required: yes (accelerometer threshold tuning, playback quality)

## Verification

- `bash verify-s05.sh` — contract/structural verification (13+ grep checks)
- Manual: start ADAS → gallery shows chunks → play/save/share work on mobile
- Diagnostic: `grep -c "\[TRIP\] Error\|\[GALLERY\] Error" index.html` returns ≥3 — confirms failure-path logging is present for both trip and gallery subsystems

## Observability / Diagnostics

- Runtime signals: `[TRIP]` log prefix for TripLogger lifecycle, `[GALLERY]` for gallery operations
- Inspection surfaces: `window.tripLogger` console object, DevTools → IndexedDB → `dashcam_db` → `dashcam_trips`
- Failure visibility: Error logs with `[TRIP] Error` and `[GALLERY] Error` prefixes, accelerometer permission denial logged

## Integration Closure

- Upstream surfaces consumed: `openVideoDatabase()` (S04), `fireCriticalAlert()` (S01), `initGPS()` callback (existing), `#page-gallery` container (S02), `showPage()`/`hidePage()` navigation (S02), `getSetting()` (S03), design tokens and page CSS classes (S02/S03)
- New wiring introduced: GPS callback extended for trip boundary detection + coordinate sampling; `fireCriticalAlert()` extended for trip event tagging; START handler extended for `initAccelerometer()` + `tripLogger.start()`; `showPage()` extended for gallery init-on-show
- What remains before milestone is truly usable end-to-end: S06 (trip history calendar + map view)

## Tasks

- [x] **T01: IndexedDB v2, TripLogger, accelerometer, and ADAS event hook** `est:2h`
  - Why: Builds the entire trip data layer — the IDB schema, TripLogger object, GPS callback extension, accelerometer impact detection, and fireCriticalAlert hook. This is the highest-risk work (IDB version bump affects existing VideoRecorder) and must land first since the gallery depends on a working DB.
  - Files: `index.html`
  - Do: (1) Bump `openVideoDatabase()` from v1→v2, add `dashcam_trips` store with `date` and `startTime` indexes, keep existing `dashcam_videos` creation idempotent. (2) Add `lastLat`/`lastLng` globals near `gpsSpeed`. (3) Build `TripLogger` object on `window.tripLogger` with full API. (4) Extend GPS callback to update `lastLat`/`lastLng` and call `tripLogger._checkTripBoundary()`. (5) Add `initAccelerometer()` with iOS permission handling and impact detection at ~2g threshold with 5s cooldown. (6) Add `tripLogger.addEvent()` call inside `fireCriticalAlert()`. (7) Add `initAccelerometer()` and `tripLogger.start()` calls in START handler. Trip boundary: start on speed > 0, end after 3 min stopped. Coordinate sampling throttled to ~5s. Periodic IDB flush every ~30s during active trip.
  - Verify: `grep -q "dashcam_db.*2\|open('dashcam_db', 2)" index.html && grep -q "dashcam_trips" index.html && grep -q "tripLogger" index.html && grep -q "devicemotion\|DeviceMotionEvent" index.html && grep -q "lastLat\|lastLng" index.html`
  - Done when: `openVideoDatabase()` opens v2 with both stores, TripLogger exposed on window with all contract methods, GPS callback feeds trip boundary + coordinates, accelerometer handler fires impact events, fireCriticalAlert tags ADAS events on active trip.

- [x] **T02: Video gallery page with playback, save, and share** `est:1.5h`
  - Why: Delivers the user-facing gallery (R016) — users can browse, play, download, and share their dashcam recordings. Independent UI work that reads from the IDB store established by S04, using the DB connection from T01's v2 schema.
  - Files: `index.html`
  - Do: (1) Add gallery CSS in `<style>` — card layout, action buttons, video player, incident badge, empty state. Follow existing design tokens (Orbitron, cyan, dark backgrounds). (2) Replace `#page-gallery .page-content` inner HTML from placeholder to a container div for dynamic content. (3) Build `initGalleryPage()` — queries `dashcam_videos` store, renders cards with timestamp/duration/size/incident badge, wires play/save/share buttons. (4) Wire init-on-show in `showPage()` for `page-gallery`. (5) Play: create blob URL, show inline `<video>` with controls, revoke URL on ended. (6) Save: anchor download with ISO timestamp filename and correct extension from mimeType. (7) Share: Web Share API with `new File([blob], name, {type})`, feature-detect `navigator.canShare`, fallback to download. (8) Track and revoke blob URLs on gallery close. (9) Show "NO RECORDINGS YET" empty state when store is empty.
  - Verify: `grep -q "initGalleryPage" index.html && grep -q "navigator.share\|navigator.canShare" index.html && grep -q "NO RECORDINGS" index.html && grep -q "createObjectURL" index.html && grep -q "revokeObjectURL" index.html`
  - Done when: Gallery page shows recorded chunks with timestamps and incident badges, play/save/share work, empty state shown when no recordings, blob URLs cleaned up.

- [x] **T03: Verification script and requirement validation** `est:30m`
  - Why: Creates the objective stopping condition for S05 — a verification script that confirms all contract surfaces, schema, gallery UI, and TripLogger API are present. Also validates requirements R016, R018, R019, R020.
  - Files: `verify-s05.sh`
  - Do: Write `verify-s05.sh` with 15+ grep checks covering: IDB v2, trip store creation with indexes, TripLogger object and all methods, GPS callback extension, DeviceMotionEvent with iOS permission, impact threshold, fireCriticalAlert hook, gallery rendering, play/save/share, blob URL management, init-on-show, empty state, log prefixes. Each check prints PASS/FAIL with description. Final summary.
  - Verify: `bash verify-s05.sh` — all checks pass
  - Done when: `verify-s05.sh` passes all checks against `index.html`

## Files Likely Touched

- `index.html`
- `verify-s05.sh`
