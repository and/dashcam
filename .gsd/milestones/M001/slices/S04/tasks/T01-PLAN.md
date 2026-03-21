---
estimated_steps: 6
estimated_files: 1
skills_used: []
---

# T01: Build VideoRecorder with IndexedDB, cleanup, auto-lock, and rec indicator

**Slice:** S04 — Rolling video recorder
**Milestone:** M001

## Description

Create the complete video recording subsystem inside `index.html`. This includes: (1) IndexedDB database initialization for storing video blobs, (2) a `VideoRecorder` object that manages MediaRecorder lifecycle with 60-second stop-and-restart rotation, (3) chunk cleanup that enforces the retention limit, (4) a lock mechanism triggered by critical ADAS alerts, and (5) recording indicator visual activation.

The VideoRecorder uses the **stop-and-restart** pattern — NOT timeslice — to ensure every stored chunk is an independently playable video file with proper headers. It records directly from `video.srcObject` (the raw camera MediaStream), never from canvas.captureStream(). Uses raw IndexedDB API — no libraries (single-file constraint).

## Steps

1. **Add recording indicator CSS** — Add a `.rec-recording` class that, when applied to `#rec-indicator`:
   - Adds `animation: dotPulse 1.5s ease-in-out infinite` to `.rec-dot`
   - Changes `.rec-label` color to bright `var(--red)` (#ff4444 or similar)
   - The `dotPulse` keyframes already exist at line 49. The `.rec-dot` selector at line ~453 already references dotPulse but the animation may already be active — check first. The goal: rec dot should be dim/static when NOT recording, pulsing red when recording.
   
   Current state of `.rec-dot` (line ~856):
   ```css
   .rec-dot { width: 8px; height: 8px; border-radius: 50%; background: var(--red); display: inline-block; }
   ```
   Current `.rec-label` (line ~864) has `color: #5a3a3a` (dim red).
   
   Make the default state dim (opacity ~0.3 or muted color), and `.rec-recording .rec-dot` bright + pulsing, `.rec-recording .rec-label` bright.

2. **Add `getRecorderMimeType()` utility** — Insert after `window.fireCriticalAlert = fireCriticalAlert;` (line 1513). Codec detection with fallback chain:
   ```javascript
   function getRecorderMimeType() {
     const types = ['video/webm;codecs=vp9', 'video/webm;codecs=vp8', 'video/webm', 'video/mp4'];
     for (const t of types) { if (MediaRecorder.isTypeSupported(t)) return t; }
     return '';
   }
   ```

3. **Add IndexedDB initialization** — Insert right after `getRecorderMimeType()`. Function `openVideoDatabase()` that returns a Promise resolving to the IDB database handle:
   - Database name: `dashcam_db`
   - Object store: `dashcam_videos` with `keyPath: 'id'`, `autoIncrement: true`
   - Create indexes: `startTime` (non-unique), `locked` (non-unique)
   - Handle `onupgradeneeded` to create store only if it doesn't exist
   - Log `[REC] IndexedDB opened` on success

4. **Build `VideoRecorder` object** — Insert right after IndexedDB init. This is the main recording manager:
   ```
   const VideoRecorder = {
     db: null,
     recorder: null,
     chunks: [],
     rotationTimer: null,
     currentChunkStartTime: null,
     currentChunkLocked: false,
     currentChunkLockReason: '',
     isRecording: false,
     
     async start() { ... },
     stop() { ... },
     lockCurrentChunk(reason) { ... },
     _startNewRecording() { ... },
     _rotateChunk() { ... },
     async _saveChunk(blob, startTime, endTime, locked, lockReason) { ... },
     async _cleanupOldChunks() { ... },
   }
   window.videoRecorder = VideoRecorder;
   ```
   
   **`start()` method:**
   - Call `openVideoDatabase()` to get db handle, store in `this.db`
   - Get stream from `video.srcObject` — if null, log error and return
   - Call `_startNewRecording()`
   - Set `isRecording = true`
   - Add `.rec-recording` class to `#rec-indicator`
   - Update `#rec-indicator .rec-label` text to "REC"
   - Log `[REC] VideoRecorder started`
   
   **`_startNewRecording()` method:**
   - Get mimeType from `getRecorderMimeType()`
   - Create `new MediaRecorder(video.srcObject, { mimeType, videoBitsPerSecond: 1000000 })`
   - Set `this.chunks = []`
   - Set `this.currentChunkStartTime = Date.now()`
   - Set `this.currentChunkLocked = false`, `this.currentChunkLockReason = ''`
   - Wire `ondataavailable`: push `event.data` to `this.chunks` if size > 0
   - Wire `onerror`: log `[REC] Error — MediaRecorder error: <msg>`
   - Wire `onstop`: create Blob from chunks, call `_saveChunk()`, then call `_cleanupOldChunks()`
   - Call `this.recorder.start()` (no timeslice argument!)
   - Set `this.rotationTimer = setTimeout(() => this._rotateChunk(), 60000)`
   - Log `[REC] Recording chunk started — mimeType: <type>`
   
   **`_rotateChunk()` method:**
   - If `this.recorder && this.recorder.state === 'recording'`, call `this.recorder.stop()`
   - The `onstop` handler saves the chunk, then after save, call `_startNewRecording()` to begin next chunk
   - Important: `_startNewRecording()` must be called AFTER save completes (in the onstop → save promise chain)
   
   **`stop()` method:**
   - `clearTimeout(this.rotationTimer)`
   - If `this.recorder && this.recorder.state === 'recording'`, call `this.recorder.stop()` (onstop saves final chunk)
   - Set `isRecording = false`
   - Remove `.rec-recording` class from `#rec-indicator`
   - Log `[REC] VideoRecorder stopped`
   
   **`lockCurrentChunk(reason)` method:**
   - Set `this.currentChunkLocked = true`, `this.currentChunkLockReason = reason`
   - Log `[REC] Chunk locked — reason: <reason>`
   - If the chunk has already been saved (we're between rotation), find the latest record in IDB and update its locked/lockReason fields
   
   **`_saveChunk(blob, startTime, endTime, locked, lockReason)` method:**
   - Create IDB transaction on `dashcam_videos`, readwrite
   - Put record: `{ blob, startTime, endTime, locked, lockReason, size: blob.size, mimeType }`
   - Log `[REC] Chunk saved — size: <MB>MB, locked: <bool>, startTime: <ts>`
   - On QuotaExceededError: log `[REC] Error — IndexedDB write failed: QuotaExceededError, retrying after cleanup`, call `_cleanupOldChunks()`, retry put once
   - Return a Promise that resolves when transaction completes
   
   **`_cleanupOldChunks()` method:**
   - Read retention: `const maxChunks = getSetting('adas_retention_minutes', 10)`
   - Open cursor on `dashcam_videos` ordered by `startTime`
   - Count total chunks. If count <= maxChunks, return
   - Delete oldest unlocked chunks until count <= maxChunks
   - Skip locked chunks (never delete them)
   - Log `[REC] Cleanup — deleted chunk id: <id> (unlocked, oldest)` for each deletion
   - Log `[REC] Cleanup — skipped locked chunk id: <id>` when skipping
   - Log `[REC] Storage — total chunks: <n>, locked: <n>`

5. **Hook `lockCurrentChunk` into `fireCriticalAlert()`** — Inside the `fireCriticalAlert()` function body, after the line `window._lastCriticalAlert = { type, details, timestamp: now };` (line ~1512), add:
   ```javascript
   if (window.videoRecorder) window.videoRecorder.lockCurrentChunk(type);
   ```
   This is a one-line addition that makes auto-lock a no-op when recording hasn't started.

6. **Verify manually** — Check that:
   - `grep -q 'dashcam_videos' index.html` succeeds
   - `grep -q 'VideoRecorder' index.html` succeeds
   - `grep -q 'lockCurrentChunk' index.html` succeeds
   - `grep -q '_cleanupOldChunks' index.html` succeeds
   - `grep -q 'getRecorderMimeType' index.html` succeeds
   - `grep -q 'window.videoRecorder' index.html` succeeds

## Must-Haves

- [ ] IndexedDB `dashcam_db` database with `dashcam_videos` object store (id autoIncrement, blob, startTime, endTime, locked, lockReason, size, mimeType)
- [ ] Indexes on `startTime` and `locked`
- [ ] `getRecorderMimeType()` with vp9 → vp8 → webm → mp4 fallback
- [ ] `VideoRecorder` object with `start()`, `stop()`, `lockCurrentChunk(reason)` public methods
- [ ] 60-second stop-and-restart rotation (no timeslice!)
- [ ] `_saveChunk()` with QuotaExceededError retry
- [ ] `_cleanupOldChunks()` using chunk count from `getSetting('adas_retention_minutes', 10)`, never deletes locked chunks
- [ ] `window.videoRecorder` exposed globally
- [ ] `fireCriticalAlert()` calls `window.videoRecorder.lockCurrentChunk(type)`
- [ ] Rec indicator: dim by default, pulsing red `.rec-recording` class toggled by start/stop
- [ ] All operations logged with `[REC]` prefix

## Verification

- `grep -q 'dashcam_db' index.html` — database name present
- `grep -q 'dashcam_videos' index.html` — object store name present
- `grep -q 'window.videoRecorder' index.html` — global exposed
- `grep -q 'lockCurrentChunk' index.html` — lock method and fireCriticalAlert hook
- `grep -q '_cleanupOldChunks' index.html` — cleanup function present
- `grep -q 'getRecorderMimeType' index.html` — codec detection present
- `grep -q 'rec-recording' index.html` — recording indicator CSS class

## Observability Impact

- Signals added: `[REC]` prefixed console.log for all recording lifecycle events (start, stop, chunk save, lock, cleanup, errors)
- How a future agent inspects this: `window.videoRecorder` in browser console shows state; DevTools → Application → IndexedDB → `dashcam_db` shows stored chunks
- Failure state exposed: `[REC] Error —` prefix for MediaRecorder errors and IDB write failures

## Inputs

- `index.html` — Contains `fireCriticalAlert()` at line 1464, `window.fireCriticalAlert` export at line 1513, `getSetting()`/`setSetting()` at line 1204, `#rec-indicator` DOM at line 1007, `.rec-dot`/`.rec-label` CSS at lines 856/864, `dotPulse` keyframes at line 49, `video.srcObject` stream from `startCamera()` at line 1368

## Expected Output

- `index.html` — Modified: new CSS for `.rec-recording` state, `getRecorderMimeType()` function, `openVideoDatabase()` function, `VideoRecorder` object with full lifecycle, `window.videoRecorder` global, `lockCurrentChunk()` call in `fireCriticalAlert()`, recording indicator class toggle in start/stop
