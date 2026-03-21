# S05 Research: Trip Logging & Video Gallery

**Depth:** Targeted  
**Slice risk:** medium  
**Requirements owned:** R016 (video gallery), R018 (trip auto-detection), R019 (GPS coordinate tracking), R020 (accelerometer + ADAS event tagging)

## Summary

S05 has four deliverables: (1) a TripLogger that auto-detects trips via GPS speed, tracks coordinates, and tags events; (2) accelerometer impact detection via DeviceMotionEvent; (3) a video gallery page rendering chunks from S04's IndexedDB store with playback/save/share; and (4) wiring `fireCriticalAlert()` to tag ADAS events on the active trip. The codebase is well-prepared — S04's IndexedDB and VideoRecorder are solid, the GPS watchPosition callback already receives lat/lng/speed, and placeholder DOM containers (`#page-gallery`, `#page-trips`) exist. The main work is: bump the IDB version to add a `dashcam_trips` store, build the TripLogger object, add DeviceMotionEvent with iOS permission handling, build the gallery UI, and hook everything into the existing START flow.

## Recommendation

Build in three tasks:
1. **IndexedDB v2 + TripLogger + accelerometer** — The data layer. Bump `dashcam_db` to v2, add `dashcam_trips` store, build the `TripLogger` object with GPS coordinate sampling and trip boundary detection, add DeviceMotionEvent impact detection, wire `fireCriticalAlert()` to tag ADAS events on trips. Hook TripLogger start into the START button handler.
2. **Video gallery page** — The UI. Replace the `#page-gallery` placeholder with a list of recorded chunks from `dashcam_videos`, with playback (blob URL → `<video>`), save (anchor download), and share (Web Share API with blob→File fallback).
3. **Verification script** — `verify-s05.sh` confirming all contract surfaces, schema, gallery UI elements, and TripLogger API.

## Implementation Landscape

### What Exists

| Component | Location | Notes |
|---|---|---|
| `openVideoDatabase()` | line 1534 | Opens `dashcam_db` v1, creates `dashcam_videos` store. **Must be modified** to v2 with `dashcam_trips` store. |
| `VideoRecorder` object | line 1557 | Fully functional. S05 reads its IDB store for gallery, doesn't modify it. |
| `fireCriticalAlert()` | line 1474 | Already calls `videoRecorder.lockCurrentChunk()`. S05 adds `tripLogger.addEvent()` call here. |
| `initGPS()` | line 2281 | watchPosition callback receives `pos.coords.speed`, `.latitude`, `.longitude`. Currently only uses speed. S05 extends this callback. |
| `gpsSpeed` variable | line 1321 | Global, already set by initGPS. TripLogger reads this for boundary detection. |
| `#page-gallery` | line 1181 | Placeholder container with "GALLERY // COMING SOON". Replace inner content. |
| `#page-trips` | line 1191 | Placeholder — S05 doesn't need to touch this (S06's scope). |
| `showPage()` / `hidePage()` | line 3261 | Navigation system. Has init-on-show pattern for settings (D016). Gallery should follow same pattern. |
| `getSetting()` / `setSetting()` | line 1213 | Settings API. Number coercion works correctly (K005 from S04). |
| Page CSS classes | lines 759-820 | `.page-fullscreen`, `.page-header`, `.page-back-btn`, `.page-title`, `.page-content` — all styled. |
| Settings page CSS | lines 885-970 | `.settings-row`, `.settings-row-label`, `.settings-row-desc` — reusable pattern for gallery card styling. |
| Design tokens | lines 10-22 | `--cyan`, `--red`, `--amber`, `--green`, `--bg`, `--border`, Orbitron + Share Tech Mono fonts. |

### IndexedDB Version Bump Strategy

**Critical integration point.** The existing `openVideoDatabase()` opens `dashcam_db` at version 1. S05 needs to add a `dashcam_trips` object store, which requires bumping to version 2.

The `onupgradeneeded` handler must be idempotent — it should check for existing stores before creating them:

```
request = indexedDB.open('dashcam_db', 2);
request.onupgradeneeded = (e) => {
  const db = e.target.result;
  if (!db.objectStoreNames.contains('dashcam_videos')) {
    // create dashcam_videos (same as v1)
  }
  if (!db.objectStoreNames.contains('dashcam_trips')) {
    // create dashcam_trips with indexes
  }
};
```

**Risk:** If the VideoRecorder opens the DB at v1 and then TripLogger opens at v2 (or vice versa), there will be a `versionchange` event that closes the first connection. **Solution:** Have a single shared `openVideoDatabase()` that always opens at the latest version (v2). Both VideoRecorder and TripLogger use the same function. The existing `openVideoDatabase()` already checks `!db.objectStoreNames.contains('dashcam_videos')` — just extend the pattern.

### Trip Store Schema

Per boundary map contract:
```
dashcam_trips: {
  id,           // autoIncrement
  startTime,    // timestamp ms
  endTime,      // timestamp ms (null while active)
  date,         // 'YYYY-MM-DD' string for calendar queries
  coordinates,  // [{lat, lng, time}]
  events        // [{type, subtype, lat, lng, time, details}]
}
```

Indexes needed:
- `date` — for `getTripsForDate()` (S06 consumes this)
- `startTime` — for ordering

### TripLogger Object Design

```
window.tripLogger = {
  db: null,
  currentTrip: null,      // { id, startTime, date, coordinates, events }
  stoppedSince: null,      // timestamp when speed dropped to 0
  coordSampleTimer: null,  // interval for coordinate sampling
  lastCoordTime: 0,        // throttle coordinate additions

  start(),                 // open DB, begin monitoring (called from START handler)
  stop(),                  // end current trip if active, clean up
  _checkTripBoundary(speed, lat, lng),  // called from GPS callback
  startTrip(lat, lng),     // create new trip record
  endTrip(),               // finalize and save trip
  addCoordinate(lat, lng), // append to current trip coordinates
  addEvent(type, subtype, lat, lng, details),  // tag event on trip
  getTripsForDate(dateStr),  // query for S06
  getDatesWithTrips(),       // query for S06
}
```

**Trip boundary logic:**
- GPS callback calls `_checkTripBoundary()` with speed and coords
- If speed > 0 and no current trip → `startTrip()`
- If speed === 0 and trip active → set `stoppedSince = Date.now()`
- If speed > 0 and `stoppedSince` set → clear `stoppedSince`
- If `stoppedSince` and `(Date.now() - stoppedSince) > 180000` → `endTrip()`

**Coordinate sampling:**
- Every GPS callback (watchPosition fires ~every 1-3s) already provides lat/lng
- Throttle to ~5 second intervals to avoid excessive storage
- Store in the `coordinates` array on the in-memory trip object
- Flush to IDB on `endTrip()` and periodically (every 30s) during active trip as crash protection

### GPS Callback Extension

The existing `initGPS()` callback at line 2282 needs extension. Currently:
```js
pos => {
  if (pos.coords.speed !== null && pos.coords.speed >= 0) {
    gpsSpeed = Math.round(pos.coords.speed * 3.6);
    gpsSpeedVal.textContent = gpsSpeed;
    updateSpeedDisplay();
    calibrateVisualSpeed(gpsSpeed);
  }
}
```

S05 adds after the existing code:
```js
// Trip logging — always pass coords and speed
if (window.tripLogger) {
  const lat = pos.coords.latitude;
  const lng = pos.coords.longitude;
  const speed = pos.coords.speed !== null ? pos.coords.speed * 3.6 : 0;
  window.tripLogger._checkTripBoundary(speed, lat, lng);
}
```

Note: `pos.coords.latitude` and `pos.coords.longitude` are always available when the position callback fires successfully. Speed can be null on some devices, but lat/lng are required fields in the Position interface.

### DeviceMotionEvent — Accelerometer Impact Detection

**Permission model:**
- Android Chrome: No permission needed. Just `window.addEventListener('devicemotion', handler)`.
- iOS Safari (13+): Requires `DeviceMotionEvent.requestPermission()` called from a user gesture (click handler). Returns `'granted'` or `'denied'`.
- Desktop: Generally unsupported (irrelevant — app is mobile-targeted).

**Implementation pattern:**
```js
async function initAccelerometer() {
  if (!('DeviceMotionEvent' in window)) {
    console.log('[TRIP] DeviceMotionEvent not supported');
    return;
  }
  // iOS permission check
  if (typeof DeviceMotionEvent.requestPermission === 'function') {
    try {
      const perm = await DeviceMotionEvent.requestPermission();
      if (perm !== 'granted') {
        console.log('[TRIP] Accelerometer permission denied');
        return;
      }
    } catch (err) {
      console.error('[TRIP] Accelerometer permission error:', err);
      return;
    }
  }
  window.addEventListener('devicemotion', handleDeviceMotion);
}
```

**iOS permission must be requested from a user gesture.** The natural place is the START button click handler — it's already a user gesture and the right lifecycle moment. Call `initAccelerometer()` alongside `initGPS()` in the START handler.

**Impact detection logic:**
```js
function handleDeviceMotion(event) {
  const acc = event.accelerationIncludingGravity;
  if (!acc) return;
  const totalG = Math.sqrt(acc.x**2 + acc.y**2 + acc.z**2) / 9.81;
  // Normal gravity is ~1g. Impacts/braking are >2g.
  if (totalG > IMPACT_THRESHOLD && tripLogger.currentTrip) {
    // Debounce: don't fire more than once per 5 seconds
    tripLogger.addEvent('impact', 'accelerometer', lastLat, lastLng, { g: totalG.toFixed(1) });
  }
}
```

**Threshold:** Starting with 2g (per M001 risk notes). This is `totalG > 2.0` after subtracting baseline gravity. The right approach: use `accelerationIncludingGravity`, compute total magnitude, and trigger when it exceeds ~2g above baseline (~3g total since baseline is 1g at rest). Actually, using `event.acceleration` (without gravity) is cleaner — it reads 0 at rest and spikes on impacts. If available, prefer `event.acceleration`; fall back to `accelerationIncludingGravity` with gravity subtraction.

**Cooldown:** 5-second debounce between impact events to avoid flooding.

### Video Gallery Page (R016)

Replace `#page-gallery .page-content` inner HTML with a dynamic list of video chunks.

**Data source:** `dashcam_db` → `dashcam_videos` store, same DB the TripLogger uses (v2).

**Gallery card for each chunk:**
- Timestamp: `new Date(record.startTime).toLocaleTimeString()`
- Duration: `((record.endTime - record.startTime) / 1000).toFixed(0) + 's'`
- Size: `(record.size / (1024*1024)).toFixed(1) + ' MB'`
- Incident badge: if `record.locked`, show badge with `record.lockReason`
- Action buttons: ▶ PLAY, 💾 SAVE, 📤 SHARE

**Playback:**
```js
const blobUrl = URL.createObjectURL(record.blob);
videoEl.src = blobUrl;
videoEl.play();
// Revoke on ended/close
```

**Save (download):**
```js
const a = document.createElement('a');
a.href = URL.createObjectURL(record.blob);
a.download = `dashcam_${new Date(record.startTime).toISOString()}.${ext}`;
a.click();
setTimeout(() => URL.revokeObjectURL(a.href), 1000);
```

**Share (Web Share API):**
```js
if (navigator.canShare) {
  const file = new File([record.blob], filename, { type: record.mimeType });
  const data = { files: [file], title: 'Dashcam clip' };
  if (navigator.canShare(data)) {
    await navigator.share(data);
    return;
  }
}
// Fallback: download
```

Key constraint from research: `navigator.share()` requires **File objects**, not raw Blobs. Must wrap the blob: `new File([blob], name, { type })`. Also requires HTTPS and transient activation (click handler). Web Share for video files is supported on Chrome Android and Safari iOS.

**Gallery init-on-show:** Following D016 pattern, add `initGalleryPage()` call in `showPage()` when `pageId === 'page-gallery'`. This function queries IDB and renders the list fresh each time the gallery is opened.

**Empty state:** When no chunks exist, show a message like "NO RECORDINGS YET" in the page-placeholder style.

### fireCriticalAlert() Extension

Add one line inside `fireCriticalAlert()` after the existing `lockCurrentChunk()` call:

```js
if (window.tripLogger && window.tripLogger.currentTrip) {
  window.tripLogger.addEvent('adas', type, lastLat, lastLng, details);
}
```

This tags the ADAS alert as an event on the active trip. `lastLat`/`lastLng` need to be captured from the GPS callback and stored as module-level variables (similar to how `gpsSpeed` works).

### Downstream Contract (S05 → S06)

S05 must produce these exact surfaces for S06:

1. **IndexedDB `dashcam_trips` store** — schema as above, accessible via `openVideoDatabase()` at v2
2. **`TripLogger` on `window.tripLogger`** with methods:
   - `getTripsForDate(dateStr)` → Promise<Trip[]> where dateStr is 'YYYY-MM-DD'
   - `getDatesWithTrips()` → Promise<string[]> returning dates with records
3. **Trip record schema** — `{ id, startTime, endTime, date, coordinates: [{lat, lng, time}], events: [{type, subtype, lat, lng, time, details}] }`

## Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| IDB v2 upgrade closes v1 connections | High | Single `openVideoDatabase()` always opens v2. Both VideoRecorder and TripLogger use it. Existing v1 data preserved — `onupgradeneeded` is additive. |
| iOS DeviceMotionEvent requires user gesture | Medium | Request in START button handler (already a click). Feature-detect `requestPermission`. Graceful fallback — impact detection is optional, ADAS events still tag trips. |
| Large coordinate arrays for long trips | Low | 5s sampling → 720 points/hour. At ~40 bytes/point, that's ~29KB/hour. Negligible vs video chunks. |
| Blob URLs not revoked → memory leak | Medium | Revoke on video ended, on gallery close, and on timer. Track active blob URLs. |
| Web Share API not available on desktop/HTTP | Low | Feature-detect with `navigator.canShare`. Fallback to download. Gallery always shows Save button. |
| Trip not saved if app crashes mid-drive | Medium | Periodic IDB flush every 30s during active trip. On `endTrip()`, final write. Worst case: lose last 30s of coordinates. |

## Verification Approach

A `verify-s05.sh` script using `grep` to confirm:

1. **IDB v2**: `indexedDB.open('dashcam_db', 2)` present
2. **Trip store creation**: `dashcam_trips` object store with `date` and `startTime` indexes
3. **TripLogger object**: `window.tripLogger` exposed with `startTrip`, `endTrip`, `addCoordinate`, `addEvent`, `getTripsForDate`, `getDatesWithTrips`
4. **GPS callback extended**: `tripLogger._checkTripBoundary` or similar in the watchPosition callback
5. **DeviceMotionEvent**: `devicemotion` listener and `requestPermission` check
6. **Impact threshold**: ~2g constant defined
7. **fireCriticalAlert hook**: `tripLogger.addEvent` called inside `fireCriticalAlert()`
8. **Gallery page**: `#page-gallery` contains video list rendering, play/save/share buttons
9. **Blob URL management**: `URL.createObjectURL` and `URL.revokeObjectURL` for playback/download
10. **Web Share API**: `navigator.share` or `navigator.canShare` with File wrapping
11. **Init-on-show**: `showPage` calls gallery init function
12. **Empty state**: "NO RECORDINGS" or similar fallback text
13. **Log prefix**: `[TRIP]` for TripLogger, `[GALLERY]` for gallery operations

## Forward Intelligence for Planner

1. **Single `openVideoDatabase()` modification** — The function at line 1534 must be changed from v1→v2 with the new `dashcam_trips` store. This is the highest-risk change because VideoRecorder calls it too. Test that existing video chunks survive the version bump.

2. **GPS callback is the integration nexus** — The `initGPS()` callback at line 2282 is where trip boundary detection and coordinate tracking hook in. Keep the extension minimal — call a single `tripLogger` method and let TripLogger handle the logic internally.

3. **`lastLat`/`lastLng` global variables** — Need two new globals (like `gpsSpeed` at line 1321) to hold the latest GPS coordinates. These are read by both the impact handler and `fireCriticalAlert()` for event tagging.

4. **START button handler ordering** — Currently: TF init → camera → `initGPS()` → `adasDetectLoop()` → `videoRecorder.start()`. Add `initAccelerometer()` after `initGPS()` (needs user gesture for iOS). Add `tripLogger.start()` after `videoRecorder.start()`. The TripLogger needs the DB open, so it should open its own connection via `openVideoDatabase()`.

5. **Gallery page pattern** — Follow the settings page exactly: CSS in `<style>`, HTML in `#page-gallery`, JS functions defined before the event listeners section, init-on-show hook in `showPage()`.

6. **Video playback needs a modal or inline player** — Don't navigate away. Either expand the card inline with a `<video>` element, or show a simple overlay. Keep it minimal — an inline `<video>` with controls below the card is simplest.

7. **File extension for download/share** — Read from `record.mimeType`. Map `video/webm` → `.webm`, `video/mp4` → `.mp4`. Default to `.webm`.
