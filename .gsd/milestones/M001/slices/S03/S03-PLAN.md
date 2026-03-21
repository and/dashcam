# S03: Settings page

**Goal:** Full-screen settings page with HUD design language, controlling verbose mode, sensitivity, lane detection, driver monitor, and recording retention duration — all persisted via localStorage and synced with live JS variables.
**Demo:** Open settings via gear icon, toggle verbose mode on, change sensitivity to HIGH, enable lane detection, set retention to 20 minutes, press back. Reload the app. Re-open settings — all values preserved. Existing HUD elements (sensitivity button text, panel status displays) reflect the settings page changes.

## Must-Haves

- `getSetting(key, defaultValue)` and `setSetting(key, value)` utility functions on `window`, with type coercion for booleans and numbers
- Settings page rendered inside `#page-settings .page-content` — replacing the "COMING SOON" placeholder
- `.page-header` and back button from S02 preserved untouched
- 5 controls: verbose mode toggle, sensitivity 3-way selector, lane detection toggle, driver monitor toggle, retention duration selector
- All controls read current values on page open and write to localStorage on change
- Changes update the live JS variables (`verboseMode`, `sensitivity`, `laneDetectionEnabled`, `driverMonitorEnabled`) and call existing UI sync functions (`updateLaneToggleUI()`, `updateDriverToggleUI()`, HUD sensitivity button text)
- Driver monitor toggle replicates the existing permission flow (Human.js init + error handling)
- `#page-settings .page-content` CSS overridden for scrollable column layout (not centered placeholder style)
- `[SETTINGS]` console.log prefix on every setting change for observability
- `retentionMinutes` setting (key: `adas_retention_minutes`, default: 10) readable by S04 via `getSetting`

## Verification

- `bash .gsd/milestones/M001/slices/S03/verify-s03.sh` — all checks pass (23 checks including diagnostic failure-path: console.warn for missing setting controls during initSettingsPage)

## Observability / Diagnostics

- Runtime signals: `console.log('[SETTINGS] <key> changed to <value>')` on every toggle/selector change
- Inspection surfaces: `window.getSetting('adas_verbose_mode', false)` / `window.setSetting(...)` callable from browser console; `localStorage` keys directly inspectable
- Failure visibility: Console warnings if setting controls not found during initialization

## Integration Closure

- Upstream surfaces consumed: `#page-settings` container and `showPage`/`hidePage` from S02; `verboseMode`, `sensitivity`, `laneDetectionEnabled`, `driverMonitorEnabled` variables and `updateLaneToggleUI()`, `updateDriverToggleUI()` functions from existing code
- New wiring introduced: `window.getSetting` / `window.setSetting` boundary contract; `adas_retention_minutes` localStorage key
- What remains: S04 reads `retentionMinutes` via `getSetting`; S04/S05/S06 populate their page containers

## Tasks

- [x] **T01: Implement settings page with all controls, getSetting/setSetting utilities, and verification script** `est:45m`
  - Why: Single coherent unit — CSS, HTML, JS all in the same `index.html` file, plus a verification script. Splitting would create artificial dependencies.
  - Files: `index.html`, `.gsd/milestones/M001/slices/S03/verify-s03.sh`
  - Do: (1) Add settings CSS — `.settings-section`, `.settings-row`, `.settings-row-label`, `.settings-row-desc`, `.settings-select`, `.settings-segment-group`/`.settings-segment-btn` styles; override `#page-settings .page-content` for scrollable column layout. (2) Replace the `<span class="page-placeholder">SETTINGS // COMING SOON</span>` inside `#page-settings .page-content` with settings sections containing 5 controls. Use `.toggle-switch` pattern for booleans, segmented button group for sensitivity (LOW/MED/HIGH), dropdown or segmented buttons for retention (5/10/15/20/30 min). (3) Define `getSetting(key, defaultValue)` and `setSetting(key, value)` early in the `<script>` block — before existing variable initializations. Expose both on `window`. (4) Add a settings page initialization function that sets toggle/selector states from current JS variables each time the page opens. (5) Wire change handlers: update localStorage via `setSetting`, update live JS variables, call existing UI sync functions, log with `[SETTINGS]` prefix. (6) Driver monitor toggle must replicate the permission flow from lines 2621–2635. (7) Write `verify-s03.sh` with structural checks.
  - Verify: `bash .gsd/milestones/M001/slices/S03/verify-s03.sh` — all checks pass
  - Done when: Settings page renders 5 controls, all persist via localStorage, all sync with live variables, getSetting/setSetting are on window, placeholder is gone, verify script passes

## Files Likely Touched

- `index.html`
- `.gsd/milestones/M001/slices/S03/verify-s03.sh`
