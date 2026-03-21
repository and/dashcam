---
estimated_steps: 7
estimated_files: 1
skills_used: []
---

# T01: IndexedDB v2, TripLogger, accelerometer, and ADAS event hook

**Slice:** S05 — Trip Logging & Video Gallery
**Milestone:** M001

## Description

Build the entire trip data layer for the dashcam app. This is the highest-risk task in the slice because it bumps the IndexedDB version from v1→v2, which affects the existing VideoRecorder. The task delivers: (1) the `dashcam_trips` object store, (2) the `TripLogger` object with GPS coordinate tracking and trip boundary detection, (3) accelerometer impact detection via DeviceMotionEvent, and (4) ADAS event tagging via `fireCriticalAlert()`.

All work is in the single `index.html` file (vanilla HTML/CSS/JS, no bundler — R012 constraint).

## Steps

1. **Bump `openVideoDatabase()` to v2 with `dashcam_trips` store.**
   - Find `openVideoDatabase()` at ~line 1534. Change `indexedDB.open('dashcam_db', 1)` to `indexedDB.open('dashcam_db', 2)`.
   - In the `onupgradeneeded` handler, KEEP the existing `dashcam_videos` creation (already has `if (!db.objectStoreNames.contains('dashcam_videos'))` guard).
   - ADD a new block: `if (!db.objectStoreNames.contains('dashcam_trips'))` — create the store with `{ keyPath: 'id', autoIncrement: true }`, add indexes on `date` (non-unique) and `startTime` (non-unique).
   - The trip store schema: `{ id, startTime, endTime, date, coordinates: [{lat, lng, time}], events: [{type, subtype, lat, lng, time, details}] }`.

2. **Add `lastLat`/`lastLng` global variables.**
   - Near the existing `let gpsSpeed = null;` at ~line 1321, add `let lastLat = null;` and `let lastLng = null;`.
   - These hold the latest GPS position for use by the impact handler and `fireCriticalAlert()`.

3. **Build the `TripLogger` object.**
   - Place it AFTER the VideoRecorder object (after `window.videoRecorder = VideoRecorder;` at ~line 1770), in a new clearly-commented section `// ===== S05: TRIP LOGGER =====`.
   - Implement as an object literal on `window.tripLogger` with these properties and methods:
     - `db: null` — IDB connection
     - `currentTrip: null` — in-memory trip: `{ id, startTime, date, coordinates, events }`
     - `stoppedSince: null` — timestamp when speed dropped to 0
     - `flushTimer: null` — interval for periodic IDB flush
     - `lastCoordTime: 0` — throttle coordinate additions to ~5s
     - `STOP_TIMEOUT: 180000` — 3 minutes in ms
     - `COORD_INTERVAL: 5000` — 5s coordinate sampling
     - `FLUSH_INTERVAL: 30000` — 30s periodic flush
     - `async start()` — open DB via `openVideoDatabase()`, begin monitoring. Called from START handler.
     - `stop()` — end current trip if active, clear timers
     - `_checkTripBoundary(speed, lat, lng)` — called from GPS callback. If speed > 0 and no trip → `startTrip()`. If speed === 0 and trip active → set/check `stoppedSince`. If elapsed > 180s → `endTrip()`. If speed > 0 and `stoppedSince` → clear it.
     - `async startTrip(lat, lng)` — create trip object in memory, generate id via IDB (write initial record), start flush timer
     - `async endTrip()` — set endTime, final flush to IDB, clear flush timer, reset currentTrip
     - `addCoordinate(lat, lng)` — if `Date.now() - lastCoordTime > COORD_INTERVAL`, push `{lat, lng, time: Date.now()}` to `currentTrip.coordinates`, update `lastCoordTime`
     - `addEvent(type, subtype, lat, lng, details)` — push `{type, subtype, lat, lng, time: Date.now(), details}` to `currentTrip.events`. Log with `[TRIP]` prefix.
     - `async _flushToIDB()` — write current trip state to IDB (update existing record by id)
     - `async getTripsForDate(dateStr)` — query `dashcam_trips` store using `date` index, return matching trips. dateStr format: 'YYYY-MM-DD'.
     - `async getDatesWithTrips()` — open cursor on `date` index, collect unique date strings.
   - All methods log with `[TRIP]` prefix. Error logs use `[TRIP] Error —`.

4. **Extend the GPS callback in `initGPS()`.**
   - Find the `initGPS()` function at ~line 2281. Inside the `pos =>` callback, AFTER the existing speed/display code, add:
   ```
   lastLat = pos.coords.latitude;
   lastLng = pos.coords.longitude;
   if (window.tripLogger) {
     const speed = pos.coords.speed !== null ? pos.coords.speed * 3.6 : 0;
     window.tripLogger._checkTripBoundary(speed, lastLat, lastLng);
     if (window.tripLogger.currentTrip) {
       window.tripLogger.addCoordinate(lastLat, lastLng);
     }
   }
   ```
   - IMPORTANT: Place `lastLat`/`lastLng` updates OUTSIDE the `if (pos.coords.speed !== null)` guard — latitude/longitude are always available when the position callback fires, even if speed is null.

5. **Add `initAccelerometer()` with iOS permission handling.**
   - Place after the TripLogger object, in a section `// ===== S05: ACCELEROMETER IMPACT DETECTION =====`.
   - Define `const IMPACT_THRESHOLD_G = 2.0;` and `let lastImpactTime = 0;` and `const IMPACT_COOLDOWN = 5000;`.
   - `async function initAccelerometer()`:
     - Feature-detect `'DeviceMotionEvent' in window`. Return early if not supported (log `[TRIP] DeviceMotionEvent not supported`).
     - iOS permission: check `typeof DeviceMotionEvent.requestPermission === 'function'`. If so, call it, check result is `'granted'`. Log denial. This MUST be called from a user gesture (START button click).
     - Add `window.addEventListener('devicemotion', handleDeviceMotion)`.
   - `function handleDeviceMotion(event)`:
     - Prefer `event.acceleration` (reads 0 at rest). Fall back to `event.accelerationIncludingGravity` with note that baseline is ~1g.
     - Compute `totalG = Math.sqrt(x**2 + y**2 + z**2) / 9.81` (for accelerationIncludingGravity) or just `Math.sqrt(x**2 + y**2 + z**2) / 9.81` (for acceleration, where resting is ~0).
     - For `event.acceleration`: trigger when `totalG > IMPACT_THRESHOLD_G`.
     - For `accelerationIncludingGravity` fallback: trigger when `totalG > (IMPACT_THRESHOLD_G + 1.0)` (accounting for ~1g baseline).
     - Cooldown: skip if `Date.now() - lastImpactTime < IMPACT_COOLDOWN`.
     - On trigger: `lastImpactTime = Date.now()`, call `window.tripLogger.addEvent('impact', 'accelerometer', lastLat, lastLng, { g: totalG.toFixed(1) })` if tripLogger has an active trip.
     - Log impact detection with `[TRIP] Impact detected`.

6. **Extend `fireCriticalAlert()` to tag ADAS events on trips.**
   - Find `fireCriticalAlert()` at ~line 1474. After the existing `if (window.videoRecorder) window.videoRecorder.lockCurrentChunk(type);` line (~line 1522), add:
   ```
   if (window.tripLogger && window.tripLogger.currentTrip) {
     window.tripLogger.addEvent('adas', type, lastLat, lastLng, details);
   }
   ```

7. **Extend the START button handler.**
   - Find the START handler at ~line 3212. After the `initGPS();` call, add `await initAccelerometer();`.
   - After the `window.videoRecorder.start()` block, add:
   ```
   if (window.tripLogger) {
     window.tripLogger.start();
   }
   ```
   - This ordering ensures: GPS starts first (provides coordinates), then accelerometer (needs user gesture), then video recorder, then trip logger (needs DB).

## Must-Haves

- [ ] `openVideoDatabase()` opens `dashcam_db` at version 2 with both `dashcam_videos` and `dashcam_trips` stores
- [ ] `dashcam_trips` store has `date` and `startTime` indexes
- [ ] `lastLat` and `lastLng` globals defined and updated in GPS callback
- [ ] `window.tripLogger` exposed with all contract methods: `start`, `stop`, `startTrip`, `endTrip`, `addCoordinate`, `addEvent`, `_checkTripBoundary`, `getTripsForDate`, `getDatesWithTrips`
- [ ] Trip auto-starts on speed > 0, auto-ends after 3 minutes at speed 0
- [ ] Coordinates sampled at ~5s intervals during active trip
- [ ] Periodic IDB flush every ~30s during active trip
- [ ] `initAccelerometer()` handles iOS permission with `DeviceMotionEvent.requestPermission()`
- [ ] Impact threshold at ~2g with 5-second cooldown
- [ ] `fireCriticalAlert()` calls `tripLogger.addEvent('adas', type, ...)` when trip is active
- [ ] START handler calls `initAccelerometer()` and `tripLogger.start()`
- [ ] All logs use `[TRIP]` prefix

## Verification

- `grep -q "open('dashcam_db', 2)" index.html` — IDB version bumped to 2
- `grep -q "dashcam_trips" index.html` — trip store exists
- `grep -q "window.tripLogger" index.html` — TripLogger exposed globally
- `grep -q "getTripsForDate" index.html` — query API for S06
- `grep -q "getDatesWithTrips" index.html` — query API for S06
- `grep -q "lastLat" index.html && grep -q "lastLng" index.html` — GPS position globals
- `grep -q "devicemotion\|DeviceMotionEvent" index.html` — accelerometer support
- `grep -q "requestPermission" index.html` — iOS permission handling
- `grep -q "tripLogger.addEvent" index.html` — event tagging in fireCriticalAlert

## Inputs

- `index.html` — existing codebase with S01-S04 complete. Key integration points: `openVideoDatabase()` at ~line 1534, `fireCriticalAlert()` at ~line 1474, `initGPS()` at ~line 2281, `gpsSpeed` at ~line 1321, VideoRecorder at ~line 1557, START handler at ~line 3212.

## Expected Output

- `index.html` — modified with IDB v2 schema, TripLogger object, accelerometer detection, GPS callback extension, fireCriticalAlert hook, and START handler extension.
