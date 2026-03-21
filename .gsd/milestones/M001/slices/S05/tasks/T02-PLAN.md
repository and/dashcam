---
estimated_steps: 5
estimated_files: 1
skills_used:
  - frontend-design
  - make-interfaces-feel-better
---

# T02: Video gallery page with playback, save, and share

**Slice:** S05 — Trip Logging & Video Gallery
**Milestone:** M001

## Description

Build the user-facing video gallery page (R016). Replace the `#page-gallery` placeholder with a dynamic list of recorded video chunks from IndexedDB. Each chunk shows timestamp, duration, size, and an incident badge if locked. Users can play (inline `<video>`), save (download via anchor), and share (Web Share API) clips. Follows the existing cyberpunk HUD design language and init-on-show pattern (D016).

All work is in the single `index.html` file. The gallery reads from the `dashcam_videos` IDB store (established in S04, accessed via the v2 `openVideoDatabase()` from T01).

## Steps

1. **Add gallery CSS in `<style>`.**
   - Place after the existing settings CSS block (ends ~line 970, before `</style>`).
   - Add a section comment `/* === S05: Gallery page === */`.
   - Style `#page-gallery .page-content` like settings: `align-items: stretch; justify-content: flex-start; flex-direction: column; overflow-y: auto; padding: 16px; gap: 12px;`.
   - `.gallery-card` — card for each chunk: `background: rgba(0, 15, 25, 0.6); border: 1px solid var(--border); border-radius: 4px; padding: 12px 16px; display: flex; flex-direction: column; gap: 8px;`.
   - `.gallery-card-header` — flex row with timestamp, duration, size, badge: `display: flex; align-items: center; justify-content: space-between; gap: 8px;`.
   - `.gallery-card-time` — timestamp text: Orbitron, 0.5rem, cyan, letter-spacing 0.15em.
   - `.gallery-card-meta` — duration/size: Share Tech Mono, 0.4rem, #3a6a7a.
   - `.gallery-card-badge` — incident badge: Orbitron, 0.35rem, `background: rgba(255,51,68,0.15); border: 1px solid var(--red); color: var(--red); padding: 2px 8px; border-radius: 2px; letter-spacing: 0.1em;`.
   - `.gallery-card-actions` — button row: `display: flex; gap: 8px;`.
   - `.gallery-action-btn` — action button: Orbitron, 0.4rem, same style as `.page-back-btn` (border, background, cursor, transitions), `flex: 1; text-align: center; padding: 8px;`.
   - `.gallery-action-btn:hover` and `:active` — same hover/active pattern as `.page-back-btn`.
   - `.gallery-video-container` — inline player wrapper: `margin-top: 4px;`.
   - `.gallery-video-container video` — `width: 100%; border-radius: 4px; border: 1px solid var(--border);`.
   - `.gallery-empty` — empty state: same as `.page-placeholder` style.
   - `.gallery-card.incident` — incident card highlight: `border-color: var(--red); box-shadow: 0 0 8px rgba(255,51,68,0.2);`.

2. **Update `#page-gallery` HTML.**
   - Replace the inner content of `#page-gallery .page-content` — remove the `<span class="page-placeholder">GALLERY // COMING SOON</span>`.
   - Replace with `<div id="gallery-list"></div>` — dynamic content container.

3. **Build `initGalleryPage()` function.**
   - Place in the JS section before the event listeners, in a section `// ===== S05: VIDEO GALLERY =====`.
   - `async function initGalleryPage()`:
     - Open DB via `openVideoDatabase()`. Log `[GALLERY] Loading recordings...`.
     - Create a read transaction on `dashcam_videos`, open cursor on `startTime` index in `'prev'` direction (newest first).
     - Collect all records into an array.
     - Get `#gallery-list` element.
     - If no records: set innerHTML to `<span class="gallery-empty">NO RECORDINGS YET</span>`. Return.
     - For each record, render a `.gallery-card` with:
       - Header row: time (`new Date(record.startTime).toLocaleTimeString()`), meta (duration in seconds: `Math.round((record.endTime - record.startTime) / 1000) + 's'`, size: `(record.size / (1024*1024)).toFixed(1) + ' MB'`).
       - If `record.locked`: add `.incident` class to card, show `.gallery-card-badge` with `record.lockReason || 'INCIDENT'` (uppercased).
       - Action buttons row: ▶ PLAY, 💾 SAVE, 📤 SHARE.
       - Each button has a `data-id` attribute with the record id.
     - Wire click handlers via event delegation on `#gallery-list`:
       - PLAY button: call `galleryPlayVideo(recordId)`.
       - SAVE button: call `gallerySaveVideo(recordId)`.
       - SHARE button: call `galleryShareVideo(recordId)`.
     - Track active blob URLs in an array `galleryBlobUrls` for cleanup.
   - Keep the records array accessible for the action handlers (store on a module-level variable like `let galleryRecords = [];`).

4. **Implement play, save, share functions.**
   - `galleryPlayVideo(id)`:
     - Find record from `galleryRecords` by id.
     - Find the card element for this record.
     - Check if a `.gallery-video-container` already exists in the card — if so, remove it (toggle behavior).
     - Create a `<div class="gallery-video-container">` with a `<video controls>` element inside.
     - `const blobUrl = URL.createObjectURL(record.blob);` — add to `galleryBlobUrls`.
     - Set `video.src = blobUrl;`. Call `video.play()`.
     - On video `ended` event: `URL.revokeObjectURL(blobUrl)`, remove from tracking array.
     - Append the container to the card.
     - Log `[GALLERY] Playing clip ${id}`.
   - `gallerySaveVideo(id)`:
     - Find record. Determine extension from mimeType: `video/webm` → `.webm`, `video/mp4` → `.mp4`, default `.webm`.
     - Generate filename: `dashcam_${new Date(record.startTime).toISOString().replace(/[:.]/g, '-')}${ext}`.
     - Create anchor element, set href to `URL.createObjectURL(record.blob)`, set download attribute to filename, click it.
     - Revoke blob URL after 1 second via `setTimeout`.
     - Log `[GALLERY] Saving clip ${id}`.
   - `galleryShareVideo(id)`:
     - Find record. Build filename as in save.
     - Create `new File([record.blob], filename, { type: record.mimeType || 'video/webm' })`.
     - Check `navigator.canShare && navigator.canShare({ files: [file] })`.
     - If shareable: `await navigator.share({ files: [file], title: 'Dashcam Clip' })`.
     - If not shareable or share fails: fallback to `gallerySaveVideo(id)`.
     - Log `[GALLERY] Sharing clip ${id}`.

5. **Wire init-on-show and blob cleanup.**
   - In the `showPage()` function (~line 3261), add a check for gallery alongside the existing settings check:
     ```
     if (pageId === 'page-gallery' && typeof initGalleryPage === 'function') initGalleryPage();
     ```
   - In the `hidePage()` function, add blob URL cleanup when gallery is closed:
     ```
     if (pageId === 'page-gallery') { galleryCleanupBlobUrls(); }
     ```
   - `function galleryCleanupBlobUrls()`:
     - Iterate `galleryBlobUrls`, call `URL.revokeObjectURL()` on each.
     - Clear the array. Log `[GALLERY] Cleaned up blob URLs`.

## Must-Haves

- [ ] Gallery CSS follows existing design language (Orbitron font, cyan accents, dark backgrounds, consistent spacing)
- [ ] `#page-gallery` placeholder replaced with dynamic `#gallery-list` container
- [ ] `initGalleryPage()` queries `dashcam_videos` and renders newest-first card list
- [ ] Each card shows timestamp, duration, size
- [ ] Locked chunks show incident badge with lock reason and red highlight
- [ ] Play creates inline `<video>` with blob URL, toggles on re-click
- [ ] Save triggers download with ISO-timestamp filename and correct extension
- [ ] Share uses Web Share API with File object wrapping, feature-detects `canShare`, falls back to download
- [ ] Init-on-show wired in `showPage()` for `page-gallery` (D016 pattern)
- [ ] Blob URLs tracked and revoked on gallery close and video end
- [ ] Empty state shows "NO RECORDINGS YET" when no chunks exist
- [ ] All logs use `[GALLERY]` prefix

## Verification

- `grep -q "initGalleryPage" index.html` — gallery init function exists
- `grep -q "gallery-list\|gallery-card" index.html` — gallery card rendering
- `grep -q "navigator.share\|navigator.canShare" index.html` — Web Share API
- `grep -q "NO RECORDINGS" index.html` — empty state
- `grep -q "createObjectURL" index.html` — blob URL for playback/download
- `grep -q "revokeObjectURL" index.html` — blob URL cleanup
- `grep -q "page-gallery.*initGalleryPage\|gallery.*initGalleryPage" index.html` — init-on-show wired
- `grep -q "\[GALLERY\]" index.html` — log prefix

## Inputs

- `index.html` — with T01 changes applied (IDB v2, TripLogger). Key areas: `#page-gallery` HTML at ~line 1181, CSS block ending before `</style>`, `showPage()`/`hidePage()` at ~line 3261, design tokens at lines 10-22, settings page CSS at lines 885-970 (pattern to follow).

## Expected Output

- `index.html` — modified with gallery CSS, HTML, JS functions, init-on-show wiring, and blob cleanup.

## Observability Impact

- **New signals:** 14 console log points with `[GALLERY]` prefix covering: page load, record count, play/stop/toggle, save, share, share fallback, blob cleanup, and error states
- **Failure visibility:** 6 `[GALLERY] Error` log points for: missing DOM element, IDB load failure, missing record/blob (play/save/share), share API failure with download fallback
- **Inspection:** Open gallery page → filter console by `[GALLERY]` to see lifecycle. `galleryRecords` variable holds loaded records for console inspection
- **Cleanup observability:** `[GALLERY] Cleaned up blob URLs` confirms blob URL revocation on gallery close
