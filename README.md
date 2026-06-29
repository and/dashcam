# ADAS Road Monitor

A browser-based Advanced Driver Assistance System (ADAS) dashcam that runs entirely on your device — no server, no cloud. Point your phone or laptop camera at the road and get real-time object detection, collision warnings, lane departure alerts, driver drowsiness monitoring, and automatic incident recording.

## How to use

1. Visit **[and.github.io/dashcam/](https://and.github.io/dashcam/)** in your browser (Chrome or Firefox recommended)
2. Grant camera and location permissions when prompted
3. Tap **START ADAS** to initialise the detection engine
4. Mount your device so the camera faces the road ahead

---

## What it does

### Object detection & collision warning

The app uses an on-device AI model (COCO-SSD via TensorFlow.js) to detect road hazards in real time:

- People, cyclists, motorcycles, animals, vehicles, traffic lights, stop signs
- Each detected object is assigned a **threat level** (0–100) based on its size, position, and closing speed
- The screen border and an audio beep indicate the current danger level:
  - **Green** — clear
  - **Amber** — caution
  - **Orange** — warning
  - **Red** — danger / imminent collision

The **side panel** lists every detected object with its confidence score and individual threat bar.

### Detection zones

Two horizontal lines are overlaid on the camera feed:

- **Caution zone** (amber dashed line) — objects crossing this line trigger a caution alert
- **Danger zone** (red dashed line) — objects crossing this line trigger a danger alert

You can drag both lines up or down in Settings to exclude your vehicle's bonnet from the detection area.

### Speed display

Speed is shown in the panel in km/h. The app fuses two sources:

| Source | How it works |
|--------|-------------|
| **GPS** | Uses the device's built-in GPS (when available) |
| **Camera (visual)** | Estimates motion from frame-to-frame optical flow; self-calibrates when GPS is also active |

### Lane departure warning

When enabled, the app detects lane markings and alerts you (with a voice announcement) if the vehicle drifts across a lane boundary.

Enable in **Settings → Lane Detection**.

### Driver monitor

Periodically checks whether the driver is alert. Every ~45 seconds the system briefly activates the front camera and analyses eye openness. If sustained eye closure is detected:

- A red **DROWSINESS DETECTED** overlay flashes on screen
- An audio alarm sounds
- On-screen text instructs you to pull over safely

Enable in **Settings → Driver Monitor**.

### Incident recording

The app maintains a rolling video buffer (10 minutes by default). When a high-danger event is detected, that clip is automatically saved to the **Gallery**.

- **Gallery** (`🎬` button) — browse and play saved incident clips
- **Trips** (`📍` button) — browse past trips by calendar date; tap a trip to see a GPS map and event log

---

## Controls

| Control | What it does |
|---------|-------------|
| `SWITCH CAM` button | Toggle between front and rear camera |
| `SENS` button | Cycle detection sensitivity: LOW / MED / HIGH |
| `⚙` (top-right) | Open Settings |
| `🎬` (top-right) | Open Gallery of saved clips |
| `📍` (top-right) | Open Trips history |

---

## Settings

Open with the **⚙** button.

| Setting | Description |
|---------|-------------|
| **Verbose Mode** | When on, the app narrates every detected object aloud. Off by default — only critical alerts are spoken. |
| **Sensitivity** | LOW / MED / HIGH. Higher sensitivity detects objects at lower confidence, producing more alerts. |
| **Lane Detection** | Enable/disable lane departure warnings. |
| **Driver Monitor** | Enable/disable periodic drowsiness checks. |
| **Recording Retention** | How long of a rolling buffer to keep (5 – 30 minutes). |
| **Detection Zones** | Sliders to move the Caution and Danger zone lines. Push them down if your bonnet is triggering false alerts. |

Settings are saved automatically and persist between sessions.

---

## Requirements

- A modern browser with WebGL support (Chrome 90+, Firefox 88+, Safari 15+)
- A camera (rear-facing recommended for road detection, front-facing for driver monitoring)
- Location permission for GPS speed (optional but recommended)
- Served over HTTPS or `localhost`

No installation, no account, no internet connection required after the page loads. All AI inference runs locally on your device.

---

## Tips

- **False bonnet alerts?** Go to Settings → Detection Zones and drag the Caution/Danger sliders down until the bonnet is below both lines.
- **Slow on older devices?** Set Sensitivity to LOW — this raises the confidence threshold and reduces the number of objects processed per frame.
- **No GPS speed?** The camera-based optical flow estimator will self-calibrate once it has a few seconds of data, but accuracy improves significantly with GPS active.
- **Portrait vs landscape?** The UI adapts to both orientations. Landscape gives a wider camera view; portrait stacks the panel below the feed.
