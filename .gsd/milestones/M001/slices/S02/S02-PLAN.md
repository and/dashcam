# S02: HUD navigation shell & recording indicator

**Goal:** Gear, gallery, and trips icons on the HUD navigate to placeholder full-screen pages with back buttons. Recording indicator dot visible on HUD. Toggle controls hidden from side panel (elements kept in DOM for JS compatibility).
**Demo:** Tap gear icon → full-screen settings placeholder appears with back button → tap back → returns to HUD. Same for gallery and trips icons. Recording indicator dot visible top-left. Lane/driver toggle rows no longer visible in side panel.

## Must-Haves

- `showPage(pageId)` and `hidePage(pageId)` functions exposed on `window`
- Three full-screen page containers: `#page-settings`, `#page-gallery`, `#page-trips`
- Gear (⚙), gallery (🎬), and trips (📍) icon buttons on the HUD inside `#container`
- Each page has a back button that calls `hidePage()` to return to HUD
- `#rec-indicator` element with dot and label, initially not animated
- Lane and driver toggle rows hidden from panel (elements remain in DOM)
- No JS errors from toggle references after hiding
- Existing HUD elements untouched (R009: bounding boxes, stats, danger display, etc.)

## Verification

- `bash .gsd/milestones/M001/slices/S02/verify-s02.sh` — all checks pass

## Integration Closure

- Upstream surfaces consumed: `window.verboseMode` from S01 (not directly wired here — S03 controls it)
- New wiring introduced in this slice: `window.showPage()` / `window.hidePage()` global navigation functions; `#page-settings`, `#page-gallery`, `#page-trips` DOM containers; `#rec-indicator` DOM element
- What remains before the milestone is truly usable end-to-end: S03 settings UI, S04 recording logic, S05 trip logging + gallery, S06 trip history

## Tasks

- [x] **T01: Add HUD nav buttons, full-screen page containers, recording indicator, and hide panel toggles** `est:45m`

## Observability / Diagnostics

- **Console logging:** `showPage(pageId)` and `hidePage(pageId)` log `[NAV] showPage: <pageId>` / `[NAV] hidePage: <pageId>` to browser console on every call, enabling navigation flow tracing.
- **Missing element warnings:** Both functions emit `console.warn('[NAV] ...: element not found: <pageId>')` if the target page container doesn't exist, making wiring mistakes immediately visible in DevTools.
- **DOM inspection:** All page containers (`#page-settings`, `#page-gallery`, `#page-trips`) are inspectable via `document.getElementById('page-settings').style.display` to check open/closed state. Nav buttons and recording indicator are queryable via standard DOM APIs.
- **Toggle row visibility:** Hidden toggle rows retain their DOM elements (`#lane-toggle`, `#driver-toggle`) — verify visibility state by checking `getComputedStyle(el.closest('.toggle-row')).display`.
- **Failure diagnostics check in verify-s02.sh:** The verification script includes checks for `console.warn` instrumentation in both `showPage` and `hidePage`, ensuring failure paths produce structured output.

## Tasks
  - Why: This is the entire S02 deliverable — the navigation shell that S03–S06 build on top of, plus the recording indicator S04 drives, plus cleaning up the side panel by hiding toggle controls
  - Files: `index.html`, `.gsd/milestones/M001/slices/S02/verify-s02.sh`
  - Do: (1) Add CSS for `.page-fullscreen` (fixed, inset 0, z-index 150), `.page-header`, `.page-back-btn`, `.hud-nav-btn` (positioned top-right cluster in container), `.rec-indicator` with dot reusing `dotPulse` animation. (2) Add three `#page-*` divs after the `</div><!-- /main -->` closing, each with header bar + back button + placeholder content. Add nav icon buttons inside `#container` as siblings of `#cam-switch`. Add `#rec-indicator` element near top-left of container. (3) Hide `.toggle-row` elements in panel via `display: none` style. (4) Add `showPage()`/`hidePage()` JS functions and wire click handlers. Expose both on `window`. (5) Nav buttons must NOT be children of `#hud-overlay` (pointer-events: none). Must be inside `#container` with their own positioning. (6) Full-screen pages must be below start-overlay (z-index 200) but above footer (z-index 100) — use z-index 150. (7) Toggle elements stay in DOM for JS compatibility — only their `.toggle-row` parent wrappers get hidden. (8) Write `verify-s02.sh` with structural checks.
  - Verify: `bash .gsd/milestones/M001/slices/S02/verify-s02.sh`
  - Done when: All verify-s02.sh checks pass, nav buttons visible on HUD, pages navigate correctly, toggle rows hidden, no JS errors

## Files Likely Touched

- `index.html`
- `.gsd/milestones/M001/slices/S02/verify-s02.sh`
