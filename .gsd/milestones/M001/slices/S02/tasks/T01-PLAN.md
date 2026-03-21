---
estimated_steps: 5
estimated_files: 2
skills_used: []
---

# T01: Add HUD nav buttons, full-screen page containers, recording indicator, and hide panel toggles

**Slice:** S02 — HUD navigation shell & recording indicator
**Milestone:** M001

## Description

Add the navigation shell that all downstream slices (S03–S06) build on top of. This means: three icon buttons on the HUD (gear ⚙, gallery 🎬, trips 📍), three full-screen placeholder page containers with back buttons, a recording indicator dot element, and hiding the toggle controls from the side panel. Also write the verification script.

This is a single-file app — all CSS, HTML, and JS go in `index.html`.

## Steps

1. **Add CSS styles** (insert before the closing `</style>` tag, after existing responsive media queries):
   - `.page-fullscreen` — `position: fixed; inset: 0; z-index: 150; background: var(--bg); display: flex; flex-direction: column; overflow-y: auto;` Start with `display: none;` by default, show via `.page-fullscreen.active { display: flex; }`
   - `.page-header` — flex row with back button and title, `padding: 16px 24px; border-bottom: 1px solid var(--border); background: linear-gradient(180deg, rgba(0,240,255,0.06) 0%, transparent 100%);`
   - `.page-back-btn` — styled like `btn-hud` but inline, with left arrow character (←)
   - `.page-title` — Orbitron font, cyan color, letter-spacing
   - `.page-content` — flex: 1, centered placeholder text
   - `.hud-nav-btn` — positioned top-right inside `#container`, `position: absolute; z-index: 20; pointer-events: auto;` Arrange three buttons vertically or horizontally at `top: 16px; right: 16px;` with gaps. Use same styling foundation as `.btn-hud` (dark background, cyan border, Orbitron font). Each button is ~32x32px with the icon character.
   - `.rec-indicator` — `position: absolute; top: 16px; left: 16px; z-index: 20; display: flex; align-items: center; gap: 6px; pointer-events: none;`
   - `.rec-dot` — 8px circle, red background, uses existing `dotPulse` animation (but initially paused or not applied — S04 activates it)
   - `.rec-label` — Orbitron font, tiny, dim red/gray text "REC"
   - `.toggle-row-hidden` — `display: none !important;` (added to toggle rows to hide them)
   - Mobile responsive adjustments in existing `@media` blocks: ensure `.hud-nav-btn` stays visible on portrait mobile (unlike `.hud-data` which is hidden)

2. **Add HTML elements**:
   - Inside `#container` (after `#sensitivity-btn`, before `#driver-check-banner`), add three nav buttons:
     ```html
     <button class="hud-nav-btn" id="nav-settings" title="Settings">⚙</button>
     <button class="hud-nav-btn" id="nav-gallery" title="Gallery">🎬</button>
     <button class="hud-nav-btn" id="nav-trips" title="Trips">📍</button>
     ```
   - Inside `#container` (near `hud-data top-left`), add recording indicator:
     ```html
     <div id="rec-indicator" class="rec-indicator">
       <span class="rec-dot"></span>
       <span class="rec-label">REC</span>
     </div>
     ```
   - After `</div><!-- close #main -->` and before `<footer>`, add three page containers:
     ```html
     <div id="page-settings" class="page-fullscreen">
       <div class="page-header">
         <button class="page-back-btn" data-page="page-settings">← BACK</button>
         <span class="page-title">SETTINGS</span>
       </div>
       <div class="page-content">
         <span class="page-placeholder">SETTINGS // COMING SOON</span>
       </div>
     </div>
     ```
     (Same pattern for `#page-gallery` with title "GALLERY" and `#page-trips` with title "TRIPS")
   - Add class `toggle-row-hidden` to the two `.toggle-row` divs in `#panel` (the ones containing `#lane-toggle` and `#driver-toggle`). Do NOT remove the elements — just add the hiding class. The toggle elements and their parent `.toggle-row` divs stay in the DOM so that existing JS references (`laneToggle`, `driverToggle`) don't break.

3. **Add JavaScript** (insert at the end of the `<script>` block, before the closing `</script>` tag):
   - Define `showPage(pageId)` — sets `document.getElementById(pageId).style.display = 'flex'`
   - Define `hidePage(pageId)` — sets `document.getElementById(pageId).style.display = 'none'`
   - Expose both on `window`: `window.showPage = showPage; window.hidePage = hidePage;`
   - Wire click handlers for nav buttons:
     ```javascript
     document.getElementById('nav-settings').addEventListener('click', () => showPage('page-settings'));
     document.getElementById('nav-gallery').addEventListener('click', () => showPage('page-gallery'));
     document.getElementById('nav-trips').addEventListener('click', () => showPage('page-trips'));
     ```
   - Wire back buttons using event delegation or querySelectorAll:
     ```javascript
     document.querySelectorAll('.page-back-btn').forEach(btn => {
       btn.addEventListener('click', () => hidePage(btn.dataset.page));
     });
     ```

4. **Verify toggle hiding doesn't break JS**: The existing `laneToggle.addEventListener('click', ...)` and `driverToggle.addEventListener('click', ...)` still reference those DOM elements. Since elements stay in DOM (just parent wrapper hidden), the references and event listeners remain valid. No null-guard changes needed. Verify by checking no `Cannot read properties of null` errors would occur — the elements are still in the DOM, just not visible.

5. **Write verification script** `verify-s02.sh`:
   - Check `#page-settings`, `#page-gallery`, `#page-trips` elements exist in HTML
   - Check `showPage` and `hidePage` functions defined
   - Check `window.showPage` and `window.hidePage` exposed globally
   - Check nav buttons `#nav-settings`, `#nav-gallery`, `#nav-trips` exist
   - Check `#rec-indicator` element exists
   - Check `.rec-dot` element exists
   - Check toggle rows have hidden class or display:none
   - Check `.page-back-btn` elements exist
   - Check existing HUD elements are untouched (`#hud-overlay`, `hud-data`, `corner-tl`, `#danger-bar`)

## Must-Haves

- [ ] `showPage(pageId)` and `hidePage(pageId)` functions exposed on `window`
- [ ] `#page-settings`, `#page-gallery`, `#page-trips` full-screen containers present
- [ ] Gear, gallery, trips nav buttons inside `#container` (NOT inside `#hud-overlay`)
- [ ] Back buttons on each page container wired to `hidePage()`
- [ ] `#rec-indicator` with `.rec-dot` and `.rec-label` present in `#container`
- [ ] Toggle rows hidden via CSS class (elements remain in DOM)
- [ ] Full-screen pages at z-index 150 (below start-overlay 200, above footer 100)
- [ ] No existing HUD elements removed or broken (R009)
- [ ] All `verify-s02.sh` checks pass

## Verification

- Run `bash .gsd/milestones/M001/slices/S02/verify-s02.sh` — all checks pass
- `grep -c 'page-fullscreen' index.html` returns >= 3
- `grep -q 'window.showPage' index.html` succeeds
- `grep -q 'window.hidePage' index.html` succeeds
- `grep -q 'rec-indicator' index.html` succeeds

## Inputs

- `index.html` — the entire single-file app (2564 lines), contains all CSS/HTML/JS

## Expected Output

- `index.html` — modified with new CSS styles, HTML elements (nav buttons, page containers, recording indicator), JS navigation functions, and hidden toggle rows
- `.gsd/milestones/M001/slices/S02/verify-s02.sh` — verification script with structural checks
