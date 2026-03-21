#!/bin/bash
# verify-s05.sh — S05 (Trip Logging & Video Gallery) structural verification
# Runs 26 grep-based checks against index.html to confirm all contract surfaces.

FILE="index.html"
PASS=0
FAIL=0

check() {
  local desc="$1"
  local pattern="$2"
  if grep -qE "$pattern" "$FILE" 2>/dev/null; then
    echo "  ✅ PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  ❌ FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== S05 Verification: Trip Logging & Video Gallery ==="
echo ""

# --- IDB Schema ---
echo "— IDB Schema —"
check "IDB v2: open('dashcam_db', 2)" "open\('dashcam_db',\s*2\)"
check "Trip store creation: dashcam_trips" "dashcam_trips"
check "Trip store date index: createIndex.*date" "createIndex\('date'"
check "Trip store startTime index" "tripStore\.createIndex\('startTime'|createIndex\('startTime'"
echo ""

# --- TripLogger API ---
echo "— TripLogger API —"
check "TripLogger exposed on window" "window\.tripLogger"
check "TripLogger startTrip method" "startTrip"
check "TripLogger endTrip method" "endTrip"
check "TripLogger addCoordinate method" "addCoordinate"
check "TripLogger addEvent method" "addEvent"
check "TripLogger getTripsForDate method" "getTripsForDate"
check "TripLogger getDatesWithTrips method" "getDatesWithTrips"
echo ""

# --- GPS & Trip Boundary ---
echo "— GPS & Trip Boundary —"
check "GPS callback: _checkTripBoundary" "_checkTripBoundary"
check "lastLat global variable" "lastLat"
check "lastLng global variable" "lastLng"
echo ""

# --- Accelerometer ---
echo "— Accelerometer —"
check "DeviceMotionEvent usage" "DeviceMotionEvent|devicemotion"
check "iOS permission: requestPermission" "requestPermission"
check "Impact threshold constant" "IMPACT_THRESHOLD"
echo ""

# --- ADAS Integration ---
echo "— ADAS Integration —"
check "fireCriticalAlert hook: tripLogger.addEvent" "tripLogger\.addEvent"
echo ""

# --- Gallery UI ---
echo "— Gallery UI —"
check "Gallery init function: initGalleryPage" "initGalleryPage"
check "Gallery card rendering: gallery-card" "gallery-card"
check "Play/blob URL: createObjectURL" "createObjectURL"
check "Blob cleanup: revokeObjectURL" "revokeObjectURL"
check "Web Share API: navigator.share or canShare" "navigator\.share|navigator\.canShare"
check "Empty state: NO RECORDINGS" "NO RECORDINGS"
echo ""

# --- Integration Wiring ---
echo "— Integration Wiring —"
check "Gallery init-on-show: page-gallery + initGalleryPage" "page-gallery.*initGalleryPage"
echo ""

# --- Log Prefixes ---
echo "— Log Prefixes —"
check "Trip log prefix: [TRIP]" "\[TRIP\]"
check "Gallery log prefix: [GALLERY]" "\[GALLERY\]"
echo ""

# --- Summary ---
TOTAL=$((PASS + FAIL))
echo "========================================"
echo "PASS: $PASS / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL checks did not pass"
  exit 1
else
  echo "All checks passed ✅"
  exit 0
fi
