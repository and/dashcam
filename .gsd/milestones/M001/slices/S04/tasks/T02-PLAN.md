---
estimated_steps: 4
estimated_files: 2
skills_used: []
---

# T02: Wire recording into START and camera switch, write verification script

**Slice:** S04 — Rolling video recorder
**Milestone:** M001

## Description

Connect the VideoRecorder (built in T01) to the app lifecycle: recording must auto-start when ADAS starts and gracefully handle camera switches. Then write the verification script that proves all S04 structural requirements are met via grep checks.

## Steps

1. **Hook recording start into START button handler** — In the START button click handler (currently at line ~2947), after `isRunning = true;` (line ~2969) and the status text assignment, add:
   ```javascript
   // Start recording
   if (window.videoRecorder) {
     window.videoRecorder.start();
   }
   ```
   This must go AFTER `await startCamera(facingMode)` so the stream is available, and AFTER `isRunning = true` so the recorder knows ADAS is active. The exact insertion point is after the `adasDetectLoop()` call or just before it — either works since recording and detection are independent.

2. **Hook recording restart into camera switch handler** — In the camera switch click handler (currently at line ~2925), modify to stop recording before camera switch and restart after:
   
   Current code:
   ```javascript
   document.getElementById('cam-switch').addEventListener('click', async () => {
     facingMode = facingMode === 'environment' ? 'user' : 'environment';
     try {
       await startCamera(facingMode);
     } catch (err) {
       statusEl.textContent = 'CAMERA SWITCH FAILED: ' + err.message;
     }
   });
   ```
   
   Modified code:
   ```javascript
   document.getElementById('cam-switch').addEventListener('click', async () => {
     facingMode = facingMode === 'environment' ? 'user' : 'environment';
     try {
       // Stop recording before switching camera (stream will be killed)
       if (window.videoRecorder && window.videoRecorder.isRecording) {
         window.videoRecorder.stop();
         console.log('[REC] Camera switch — stopping recorder');
       }
       await startCamera(facingMode);
       // Restart recording with new stream
       if (window.videoRecorder && isRunning) {
         window.videoRecorder.start();
         console.log('[REC] Camera switch — restarting recorder with new stream');
       }
     } catch (err) {
       statusEl.textContent = 'CAMERA SWITCH FAILED: ' + err.message;
     }
   });
   ```
   
   Key: stop BEFORE `startCamera()` (because it kills the old stream's tracks), restart AFTER (when new stream is ready). Only restart if `isRunning` is true (don't start recording if ADAS hasn't been started).

3. **Write `verify-s04.sh`** — Create `.gsd/milestones/M001/slices/S04/verify-s04.sh` following the same pattern as verify-s02.sh and verify-s03.sh. Include ~20 grep-based structural checks:

   ```
   Checks to include:
   1.  dashcam_db database name in code
   2.  dashcam_videos object store name in code
   3.  createObjectStore call for dashcam_videos
   4.  startTime index creation
   5.  locked index creation
   6.  getRecorderMimeType function defined
   7.  isTypeSupported call for codec detection
   8.  VideoRecorder object/variable defined
   9.  window.videoRecorder exposed
   10. start() method (look for 'start()' or 'start:' in VideoRecorder context)
   11. stop() method
   12. lockCurrentChunk method defined
   13. _rotateChunk method defined
   14. _saveChunk method defined
   15. _cleanupOldChunks method defined
   16. fireCriticalAlert contains lockCurrentChunk call
   17. getSetting('adas_retention_minutes' read present
   18. rec-recording CSS class defined
   19. dotPulse animation reference in rec-recording context
   20. [REC] console.log prefix present
   21. videoRecorder.start in START handler context
   22. videoRecorder.stop in camera switch context (or 'Camera switch' + recorder)
   23. QuotaExceededError or quota handling present
   24. MediaRecorder constructor used
   25. video.srcObject reference in recorder context (not canvas.captureStream)
   ```
   
   Use the same pass/fail counter pattern as verify-s02.sh and verify-s03.sh. Target: all checks pass. Print summary at end.

4. **Run verification** — Execute `bash .gsd/milestones/M001/slices/S04/verify-s04.sh` and confirm all checks pass.

## Must-Haves

- [ ] Recording starts automatically in START button handler after camera is initialized
- [ ] Camera switch handler stops recording before switching, restarts after with new stream
- [ ] Camera switch only restarts recording if `isRunning` is true
- [ ] `verify-s04.sh` covers all S04 structural requirements (~20+ checks)
- [ ] All verification checks pass

## Verification

- `bash .gsd/milestones/M001/slices/S04/verify-s04.sh` — all checks pass (0 failures)
- `grep -q 'videoRecorder.*start' index.html` — recording wired into START
- `grep -q 'Camera switch' index.html` — camera switch logging present

## Inputs

- `index.html` — Contains VideoRecorder object (from T01), START button handler at line ~2947, camera switch handler at line ~2925, `isRunning` flag at line ~1256
- `.gsd/milestones/M001/slices/S02/verify-s02.sh` — Pattern reference for verification script format
- `.gsd/milestones/M001/slices/S03/verify-s03.sh` — Pattern reference for verification script format

## Expected Output

- `index.html` — Modified: recording start added to START handler, recording stop/restart added to camera switch handler
- `.gsd/milestones/M001/slices/S04/verify-s04.sh` — New verification script with ~25 structural checks
