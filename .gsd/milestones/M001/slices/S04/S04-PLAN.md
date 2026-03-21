# S04: Rolling video recorder

**Goal:** App auto-records 1-minute video chunks to IndexedDB from ADAS start, rolls oldest unlocked chunks off when the buffer exceeds retention, and auto-locks the current chunk on any critical ADAS alert.
**Demo:** Start ADAS, wait 2+ minutes, open DevTools → Application → IndexedDB → `dashcam_db` → `dashcam_videos` — see timestamped video records. Trigger a critical alert — latest chunk shows `locked: true`. Rec dot pulses red during recording.

## Must-Haves

- IndexedDB `dashcam_db` with `dashcam_videos` object store (schema: id, blob, startTime, endTime, locked, lockReason, size, mimeType)
- `VideoRecorder` object with `start()`, `stop()`, `lockCurrentChunk(reason)` methods, exposed on `window.videoRecorder`
- Stop-and-restart pattern: recorder stops every 60s, saves complete playable chunk, restarts immediately
- Codec auto-detection with vp9 → vp8 → webm → mp4 fallback chain
- Cleanup deletes oldest unlocked chunks when count exceeds `retentionMinutes` (from `getSetting`)
- `fireCriticalAlert()` calls `lockCurrentChunk()` on every critical alert
- Recording starts automatically when ADAS starts (START button handler)
- Camera switch stops and restarts recording with new stream
- Rec indicator dot pulses when recording, dims when not
- `[REC]` console.log prefix on all recording operations

## Proof Level

- This slice proves: integration (MediaRecorder → IndexedDB → fireCriticalAlert hook)
- Real runtime required: yes (MediaRecorder needs a live camera stream)
- Human/UAT required: yes (verify IndexedDB contents in DevTools, rec dot animation)

## Verification

- `bash .gsd/milestones/M001/slices/S04/verify-s04.sh` — structural grep checks covering all must-haves
- Manual: DevTools → Application → IndexedDB → `dashcam_db` → `dashcam_videos` shows records after 1+ min
- Manual: Console shows `[REC]` logs during recording lifecycle

## Observability / Diagnostics

- Runtime signals: `[REC]` prefixed console.log for start, stop, chunk save, lock, cleanup, error, camera switch
- Inspection surfaces: `window.videoRecorder` object in console; IndexedDB `dashcam_videos` store in DevTools
- Failure visibility: `[REC] Error —` logs for MediaRecorder errors and IndexedDB write failures (QuotaExceededError with retry)
- Redaction constraints: none (video blobs are user's own camera data)

## Integration Closure

- Upstream surfaces consumed: `window.fireCriticalAlert()` (S01), `window.getSetting('adas_retention_minutes', 10)` (S03), `#rec-indicator` DOM (S02), `video.srcObject` stream, START button handler, camera switch handler
- New wiring introduced: `window.videoRecorder` global, `lockCurrentChunk()` call inside `fireCriticalAlert()`, recording start in START handler, recording restart in camera switch handler
- What remains before the milestone is truly usable end-to-end: S05 (trip logging + gallery UI to browse/play stored chunks), S06 (trip history with map)

## Tasks

- [x] **T01: Build VideoRecorder with IndexedDB, cleanup, auto-lock, and rec indicator** `est:25m`
  - Why: Creates the complete recording subsystem — IndexedDB database, VideoRecorder object with 60s rotation, chunk cleanup, lock mechanism, fireCriticalAlert hook, and recording indicator activation. This is the core of R013/R014/R015.
  - Files: `index.html`
  - Do: (1) Add IndexedDB open/create for `dashcam_db` with `dashcam_videos` store after the fireCriticalAlert export line. (2) Build `VideoRecorder` object with start/stop/lockCurrentChunk/rotate/save/cleanup methods. (3) Add `getRecorderMimeType()` codec detection. (4) Add `lockCurrentChunk()` call inside `fireCriticalAlert()` body. (5) Add CSS class `.rec-recording` that activates dotPulse animation on `.rec-dot` and brightens `.rec-label`. (6) Toggle `.rec-recording` class in VideoRecorder start/stop. Stop-and-restart pattern only — never timeslice. Record from `video.srcObject` — never canvas.captureStream. Raw IndexedDB — no libraries.
  - Verify: `grep -q 'dashcam_videos' index.html && grep -q 'VideoRecorder' index.html && grep -q 'lockCurrentChunk' index.html && grep -q '_cleanupOldChunks' index.html`
  - Done when: VideoRecorder object with full lifecycle exists in index.html, fireCriticalAlert calls lockCurrentChunk, rec indicator has recording-state CSS

- [x] **T02: Wire recording into START and camera switch, write verification script** `est:15m`
  - Why: Connects the recording subsystem to the app lifecycle — recording must start when ADAS starts and handle camera switches gracefully. Verification script proves all structural requirements are met.
  - Files: `index.html`, `.gsd/milestones/M001/slices/S04/verify-s04.sh`
  - Do: (1) In START button handler, after `isRunning = true`, add `if (window.videoRecorder) window.videoRecorder.start()`. (2) In camera switch handler, before `await startCamera(facingMode)`, add stop recording; after await, add start recording with new stream. (3) Write verify-s04.sh with ~20 grep checks covering: IDB open, dashcam_videos store, VideoRecorder methods, window.videoRecorder, fireCriticalAlert hook, cleanup, codec detection, rec indicator, START integration, camera switch integration, retention setting read, [REC] logging.
  - Verify: `bash .gsd/milestones/M001/slices/S04/verify-s04.sh` — all checks pass
  - Done when: verify-s04.sh passes all checks, recording starts on START and restarts on camera switch

## Files Likely Touched

- `index.html`
- `.gsd/milestones/M001/slices/S04/verify-s04.sh`
