---
estimated_steps: 5
estimated_files: 1
skills_used:
  - frontend-design
  - accessibility
---

# T02: Map view with route + event markers, log view with video links, and tab toggle

**Slice:** S06 — Trip History with Calendar & Map View
**Milestone:** M001

## Description

Implements the trip detail experience — the Leaflet map with route polyline and event markers (R022) and the chronological event log with video chunk links (R023). When a user taps a trip from the calendar's trip list, they see a map showing the route and events, or can switch to a log tab for a timeline view. This is the core visualization that makes trip history useful.

The app is a single `index.html` file. T01 already added Leaflet CDN links, all S06 CSS, the trips page HTML scaffold with `#trips-detail-view` container, the `showTripDetail(trip)` stub, and MAP/LOG tab containers. This task fills in the map and log rendering logic.

## Steps

1. **Implement `showTripDetail(trip)` map rendering.** Replace the T01 stub's body or extend it. When called:
   - Hide `#trips-calendar-view`, show `#trips-detail-view`
   - Populate a trip info header (date, start time, duration, event count)
   - Add "← BACK TO CALENDAR" handler (hide detail, show calendar, destroy map)
   - **Map tab:** If `trip.coordinates.length > 0`:
     - Create Leaflet map in `#trip-map-container`: `tripsMap = L.map('trip-map-container')`
     - Add OSM tile layer: `L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap contributors', maxZoom: 19 })`
     - Draw route polyline: `L.polyline(trip.coordinates.map(c => [c.lat, c.lng]), { color: '#00f0ff', weight: 3, opacity: 0.8 })` and add to map
     - Fit bounds: `tripsMap.fitBounds(polyline.getBounds(), { padding: [30, 30] })`
     - **Critical invalidateSize:** `setTimeout(() => { if (tripsMap) tripsMap.invalidateSize(); }, 150)` — the container starts hidden, Leaflet can't measure dimensions until this fires
     - Add event markers: for each event in `trip.events`, create `L.circleMarker([event.lat, event.lng], { radius: 8, fillColor: event.type === 'impact' ? '#ff3344' : '#ff006a', color: event.type === 'impact' ? '#ff3344' : '#ff006a', weight: 2, opacity: 0.9, fillOpacity: 0.6 })` with `bindPopup()` showing event subtype, time (HH:MM:SS), and details
   - If `trip.coordinates.length === 0`: hide map tab button, show log tab as default, display message "NO GPS DATA FOR THIS TRIP" in map container
   - Log `[TRIPS] Showing trip detail: id=trip.id, coordinates=N, events=N`

2. **Implement MAP/LOG tab toggle.** The tab buttons exist in HTML from T01. Add click handlers:
   - MAP tab: show `#trip-map-container`, hide `#trip-log-list`, mark MAP tab active. Call `tripsMap.invalidateSize()` if map exists (switching back to map tab also needs resize).
   - LOG tab: show `#trip-log-list`, hide `#trip-map-container`, mark LOG tab active.
   - Default to MAP tab if coordinates exist, LOG tab otherwise.

3. **Implement log view rendering.** Function `renderTripLog(trip)`:
   - Sort events by time (ascending — chronological order)
   - For each event, create a `.trip-log-card` with:
     - `.trip-log-time`: formatted HH:MM:SS from event.time
     - `.trip-log-badge`: "IMPACT" (class `.impact`, red) for `type === 'impact'`, or "ADAS" (class `.adas`, magenta) for `type === 'adas'`
     - Subtype text (e.g., "crossing", "ttc_imminent", "accelerometer")
     - `.trip-log-details`: stringified details object or key info
     - Video link placeholder (a data attribute `data-event-time` on the card for the video linking step)
   - If `trip.events.length === 0`: show "NO EVENTS DURING THIS TRIP" empty state
   - Append all cards to `#trip-log-list`
   - Log `[TRIPS] Rendered log: N events`

4. **Implement video-to-event linking.** After rendering log cards, query `dashcam_videos` IDB store to find video chunks that overlap each event's timestamp:
   - Open DB via `openVideoDatabase()`
   - Read all records from `dashcam_videos` store
   - For each event, find a video chunk where `chunk.startTime <= event.time && event.time <= chunk.endTime`
   - If found, append a `.trip-log-video-btn` button ("▶ VIEW CLIP") to that event's log card
   - Button click: create a `<video>` element inline (same pattern as gallery playback — `URL.createObjectURL(chunk.blob)`, playsInline, autoplay), insert below the log card. Toggle: click again removes the video. Track blob URLs in a `tripsBlobUrls` array.
   - Log `[TRIPS] Linked N video clips to events`

5. **Complete `tripsCleanup()`.** Replace the T01 stub with full cleanup:
   - If `tripsMap` exists: `tripsMap.remove(); tripsMap = null;`
   - Revoke all blob URLs in `tripsBlobUrls`
   - Reset detail view: hide `#trips-detail-view`, show `#trips-calendar-view`
   - Clear `#trip-log-list` innerHTML
   - Log `[TRIPS] Cleanup complete`

## Must-Haves

- [ ] Leaflet map creates correctly in `#trip-map-container` with OSM tiles
- [ ] Route polyline drawn from trip.coordinates in cyan
- [ ] Event markers as circleMarkers — red for impact, magenta for ADAS — with popups
- [ ] `map.fitBounds()` auto-zooms to route extent
- [ ] `map.invalidateSize()` called after container shown (with setTimeout)
- [ ] MAP/LOG tab toggle switches between map and log views
- [ ] Chronological event log with time, type badge, subtype, details
- [ ] Video chunk lookup by timestamp overlap from `dashcam_videos` IDB store
- [ ] "VIEW CLIP" button on events that have matching video chunks
- [ ] Video playback inline with blob URL lifecycle management
- [ ] `tripsCleanup()` destroys map and revokes blob URLs
- [ ] Empty states: no coordinates, no events
- [ ] `[TRIPS]` console log prefix on all new log points; `[TRIPS] Error —` on failures

## Verification

- `grep -q 'L.tileLayer' index.html` — OSM tile layer
- `grep -q 'L.polyline' index.html` — route polyline
- `grep -q 'L.circleMarker' index.html` — event markers
- `grep -q 'invalidateSize' index.html` — Leaflet resize fix
- `grep -q 'fitBounds' index.html` — auto-zoom to route
- `grep -q 'bindPopup' index.html` — marker popups
- `grep -q 'VIEW CLIP' index.html` — video link buttons
- `grep -q 'dashcam_videos' index.html` — video store queried (existing + new references)
- `grep -q 'tripsMap.remove' index.html` — map cleanup
- `grep -q 'tripsBlobUrls' index.html` — blob URL tracking

## Inputs

- `index.html` — modified by T01 with Leaflet CDN, S06 CSS, trips page HTML scaffold, `#trips-detail-view` container with map/log sub-containers, `showTripDetail()` stub, `tripsCleanup()` stub, calendar + trip list logic

## Expected Output

- `index.html` — modified with complete map rendering, event markers, log view, video linking, tab toggle, and cleanup logic

## Observability Impact

- **New signals:** `[TRIPS] Showing trip detail: id=X, coordinates=N, events=N` — logged on every detail view open with coordinate/event counts; `[TRIPS] Rendered log: N events` — logged after log view populated; `[TRIPS] Linked N video clips to events` — logged after video chunk matching; `[TRIPS] Playing event video clip` — logged on VIEW CLIP button click; `[TRIPS] Toggled off video clip` — logged on video toggle close; `[TRIPS] Cleanup complete` — replaces former `[TRIPS] Cleanup` with explicit completion
- **Error signals:** `[TRIPS] Error — Leaflet map init failed:` — logged if L.map() or tile layer setup throws; `[TRIPS] Error — video linking failed:` — logged if IDB query for video chunks fails
- **Inspection surfaces:** `tripsMap` — Leaflet map instance, accessible in browser console after detail view opens; `tripsBlobUrls` — array of active blob URLs for video playback; DOM `#trip-log-list .trip-log-card` for log card inspection; DOM `#trip-map-container` for map state
- **Failure visibility:** Map init failures show "MAP INITIALIZATION FAILED" empty state in container; No-GPS trips show "NO GPS DATA FOR THIS TRIP"; No-events trips show "NO EVENTS DURING THIS TRIP"
