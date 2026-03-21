---
estimated_steps: 7
estimated_files: 2
skills_used:
  - frontend-design
  - accessibility
  - best-practices
---

# T01: Implement settings page with all controls, getSetting/setSetting utilities, and verification script

**Slice:** S03 — Settings page
**Milestone:** M001

## Description

Build the full settings page inside the existing `#page-settings` container. This is the only task in the slice — it covers CSS, HTML, JS utilities, event wiring, and verification. The settings page uses the cyberpunk HUD design language already established in the app (Orbitron font, cyan/amber accents, dark backgrounds, glowing borders).

The page has 5 controls:
1. **Verbose Mode** — toggle switch (default: off). Key: `adas_verbose_mode`. Updates `verboseMode` and `window.verboseMode`.
2. **Sensitivity** — 3-way segmented button group LOW/MED/HIGH (default: MED). Key: `adas_sensitivity`. Updates `sensitivity` variable and `sensitivityBtn.textContent` on HUD.
3. **Lane Detection** — toggle switch (default: off). Key: `adas_lane_detection`. Updates `laneDetectionEnabled`, calls `updateLaneToggleUI()`.
4. **Driver Monitor** — toggle switch (default: off). Key: `adas_driver_monitor`. Updates `driverMonitorEnabled`, calls `updateDriverToggleUI()`, replicates the existing permission flow (init Human.js, handle errors, revert on failure).
5. **Recording Retention** — selector with options 5/10/15/20/30 minutes (default: 10). Key: `adas_retention_minutes`. New setting consumed by S04 via `getSetting('adas_retention_minutes', 10)`.

Also introduces `getSetting(key, defaultValue)` and `setSetting(key, value)` as the boundary contract for downstream slices (S04, S05).

## Steps

1. **Add settings CSS** inside the existing `<style>` block (after the `.toggle-row-hidden` rule near line 872). Add styles for:
   - `#page-settings .page-content` — override to `align-items: stretch; justify-content: flex-start; flex-direction: column; overflow-y: auto; padding: 16px; gap: 8px;`
   - `.settings-section` — group container with optional section header
   - `.settings-row` — flex row with label on left, control on right. Similar to existing `.toggle-row` but styled for the settings page context (no border-bottom, slightly different padding)
   - `.settings-row-label` — Orbitron font, small, cyan-ish color, letter-spacing
   - `.settings-row-desc` — smaller text below label, muted color, describes what the setting does
   - `.settings-segment-group` — flex container for the 3-way sensitivity selector
   - `.settings-segment-btn` — individual segment button, with `.active` state matching the cyan glow pattern
   - `.settings-select` — styled select element for retention duration, matching HUD aesthetics (dark bg, cyan border, Orbitron font)

2. **Replace placeholder HTML** — Inside `#page-settings`, find the `<div class="page-content">` and replace the `<span class="page-placeholder">SETTINGS // COMING SOON</span>` with settings sections. Structure:
   ```html
   <div class="settings-section">
     <div class="settings-row" id="setting-verbose">
       <div>
         <div class="settings-row-label">VERBOSE MODE</div>
         <div class="settings-row-desc">Narrate all detected objects aloud</div>
       </div>
       <div class="toggle-switch" id="settings-verbose-toggle"></div>
     </div>
     <!-- sensitivity row with segment group -->
     <!-- lane detection toggle row -->
     <!-- driver monitor toggle row -->
     <!-- retention duration selector row -->
   </div>
   ```
   Use IDs: `settings-verbose-toggle`, `settings-sensitivity-group`, `settings-sensitivity-low`, `settings-sensitivity-med`, `settings-sensitivity-high`, `settings-lane-toggle`, `settings-driver-toggle`, `settings-retention-select`. Preserve the existing `.page-header` and back button — only replace the content inside `.page-content`.

3. **Define getSetting/setSetting utilities** — Add these EARLY in the `<script>` block, before the existing variable declarations (before line ~1081). They must be defined before any code that might use them:
   ```js
   // ===== SETTINGS UTILITIES (S03 boundary contract) =====
   function getSetting(key, defaultValue) {
     const val = localStorage.getItem(key);
     if (val === null) return defaultValue;
     if (typeof defaultValue === 'boolean') return val === 'true';
     if (typeof defaultValue === 'number') return Number(val);
     return val;
   }
   function setSetting(key, value) {
     localStorage.setItem(key, String(value));
   }
   window.getSetting = getSetting;
   window.setSetting = setSetting;
   ```

4. **Add settings page initialization function** — Define `initSettingsPage()` that reads current JS variable values and sets the toggle/selector states accordingly. This function must be called each time the settings page is shown (hook into `showPage` or add a listener). Key sync points:
   - `settings-verbose-toggle`: add/remove `.active` class based on `verboseMode`
   - `settings-sensitivity-*`: add `.active` to the matching segment button, remove from others, based on `sensitivity`
   - `settings-lane-toggle`: add/remove `.active` based on `laneDetectionEnabled`
   - `settings-driver-toggle`: add/remove `.active` based on `driverMonitorEnabled`
   - `settings-retention-select`: set `.value` to current `getSetting('adas_retention_minutes', 10)`

   To hook initialization into page show: modify the `showPage` function (or the nav-settings click handler) to call `initSettingsPage()` after showing. The simplest approach: add `if (pageId === 'page-settings' && typeof initSettingsPage === 'function') initSettingsPage();` inside the existing `showPage()` function body, right after the display:flex line.

5. **Wire change handlers for all 5 controls:**
   - **Verbose toggle click**: Toggle `verboseMode`, set `window.verboseMode`, call `setSetting('adas_verbose_mode', verboseMode)`, toggle `.active` class, log `[SETTINGS] adas_verbose_mode changed to <value>`.
   - **Sensitivity segment clicks** (one handler per button, or event delegation on the group): Set `sensitivity` to clicked value, call `setSetting('adas_sensitivity', sensitivity)`, update `sensitivityBtn.textContent` to `SENS: ${sensitivity}`, update active classes on segment buttons, log `[SETTINGS] adas_sensitivity changed to <value>`.
   - **Lane toggle click**: Toggle `laneDetectionEnabled`, call `setSetting('adas_lane_detection', laneDetectionEnabled)`, call `updateLaneToggleUI()`, toggle `.active` class on settings toggle, log `[SETTINGS] adas_lane_detection changed to <value>`.
   - **Driver toggle click**: Toggle `driverMonitorEnabled`, call `setSetting('adas_driver_monitor', driverMonitorEnabled)`, call `updateDriverToggleUI()`, toggle `.active` class. Replicate the permission flow from the existing handler (lines 2621–2635): if enabling and `isRunning`, try to init Human.js; on failure, revert `driverMonitorEnabled` to false, save, update UI. Log `[SETTINGS] adas_driver_monitor changed to <value>`.
   - **Retention select change**: Read selected value, call `setSetting('adas_retention_minutes', selectedValue)`, log `[SETTINGS] adas_retention_minutes changed to <value>`.

6. **Ensure sensitivity is loaded from localStorage on startup** — The existing `loadSettings()` function (line ~2666) already loads sensitivity. Verify it doesn't need changes. The `adas_retention_minutes` key doesn't need to be loaded into a variable at startup — it's read on-demand via `getSetting` by S04.

7. **Write `verify-s03.sh`** — Bash script with grep-based structural checks:
   1. `getSetting` function definition exists
   2. `setSetting` function definition exists
   3. `window.getSetting` assignment exists
   4. `window.setSetting` assignment exists
   5. `settings-verbose-toggle` element exists in HTML
   6. `settings-sensitivity` group/buttons exist
   7. `settings-lane-toggle` element exists
   8. `settings-driver-toggle` element exists
   9. `settings-retention-select` element exists
   10. `adas_verbose_mode` appears in a setSetting/localStorage call
   11. `adas_sensitivity` appears in settings handler
   12. `adas_lane_detection` appears in settings handler
   13. `adas_driver_monitor` appears in settings handler
   14. `adas_retention_minutes` appears in setSetting/localStorage call
   15. Settings CSS classes defined (`.settings-row`, `.settings-segment-btn`, etc.)
   16. `#page-settings .page-content` CSS override exists
   17. `[SETTINGS]` log prefix exists in JS
   18. `.page-header` and `.page-back-btn` still exist inside `#page-settings`
   19. "COMING SOON" does NOT appear inside `#page-settings`
   20. `initSettingsPage` function exists
   21. `updateLaneToggleUI` called from settings handler
   22. `updateDriverToggleUI` called from settings handler

## Must-Haves

- [ ] `getSetting(key, defaultValue)` handles boolean coercion (`'true'` → `true`) and number coercion
- [ ] `setSetting(key, value)` stringifies before storing
- [ ] Both utilities exposed on `window` for downstream slice consumption
- [ ] 5 settings controls rendered with IDs matching the verification script
- [ ] Verbose mode toggle updates `verboseMode` AND `window.verboseMode`
- [ ] Sensitivity segmented buttons update `sensitivity` variable AND `sensitivityBtn.textContent`
- [ ] Lane detection toggle calls `updateLaneToggleUI()` after changing `laneDetectionEnabled`
- [ ] Driver monitor toggle calls `updateDriverToggleUI()` and replicates Human.js permission flow
- [ ] Retention selector writes `adas_retention_minutes` to localStorage
- [ ] `initSettingsPage()` syncs all control states from live variables when page opens
- [ ] Settings page placeholder ("COMING SOON") removed
- [ ] `.page-header` and back button from S02 preserved — only `.page-content` inner content replaced
- [ ] `#page-settings .page-content` CSS override scoped to avoid breaking other pages
- [ ] `[SETTINGS]` console.log on every setting change

## Verification

- `bash .gsd/milestones/M001/slices/S03/verify-s03.sh` — all checks pass (22 structural checks)
- Manual spot-check in browser: open settings, toggle verbose mode, change sensitivity, reload, verify persistence

## Observability Impact

- Signals added: `console.log('[SETTINGS] <key> changed to <value>')` on every setting change (5 controls × change event)
- How a future agent inspects this: Filter browser console by `[SETTINGS]` to trace all setting changes; call `window.getSetting(key, default)` from console to read any setting
- Failure state exposed: Console warnings if setting control elements not found during `initSettingsPage()`

## Inputs

- `index.html` — existing page container (`#page-settings`), CSS patterns (`.toggle-switch`, `.toggle-row`), JS variables (`verboseMode`, `sensitivity`, `laneDetectionEnabled`, `driverMonitorEnabled`), UI sync functions (`updateLaneToggleUI`, `updateDriverToggleUI`), `showPage`/`hidePage` navigation, `loadSettings()`, `sensitivityBtn`, `SENSITIVITY_LEVELS`

## Expected Output

- `index.html` — modified with settings CSS, settings HTML inside `#page-settings .page-content`, `getSetting`/`setSetting` utilities, `initSettingsPage()`, and 5 control change handlers
- `.gsd/milestones/M001/slices/S03/verify-s03.sh` — verification script with 22 structural grep checks
