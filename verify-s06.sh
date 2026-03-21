#!/bin/bash
# verify-s06.sh — S06 (Trip History with Calendar & Map View) structural verification
# Runs 20 grep-based checks against index.html to confirm all contract surfaces.

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

echo "=== S06 Verification: Trip History with Calendar & Map View ==="
echo ""

# --- Leaflet CDN ---
echo "— Leaflet CDN —"
check "Leaflet CSS link (1.9.4)" "leaflet@1\.9\.4/dist/leaflet\.css"
check "Leaflet JS script (1.9.4)" "leaflet@1\.9\.4/dist/leaflet\.js"
echo ""

# --- Calendar UI ---
echo "— Calendar UI —"
check "Calendar container: trips-calendar-view" "trips-calendar-view"
check "Calendar grid: trips-cal-grid" "trips-cal-grid"
check "Month navigation buttons: trips-cal-nav" "trips-cal-nav"
check "getDatesWithTrips call for date highlighting" "getDatesWithTrips"
echo ""

# --- Map View ---
echo "— Map View —"
check "L.tileLayer for OSM tiles" "L\.tileLayer"
check "L.polyline for route rendering" "L\.polyline"
check "L.circleMarker for event markers" "L\.circleMarker"
check "invalidateSize for container resize fix" "invalidateSize"
echo ""

# --- Log View ---
echo "— Log View —"
check "Log list container: trip-log-list" "trip-log-list"
check "Log card class: trip-log-card" "trip-log-card"
check "Log badge classes: trip-log-badge" "trip-log-badge"
echo ""

# --- Video Linking ---
echo "— Video Linking —"
check "dashcam_videos query for video chunks" "dashcam_videos"
check "VIEW CLIP button text" "VIEW CLIP"
echo ""

# --- Navigation Hooks ---
echo "— Navigation Hooks —"
check "initTripsPage function" "initTripsPage"
check "tripsCleanup function" "tripsCleanup"
check "showTripDetail function" "showTripDetail"
echo ""

# --- Console Logging ---
echo "— Console Logging —"
TRIPS_COUNT=$(grep -cE "\[TRIPS\]" "$FILE" 2>/dev/null || echo 0)
if [ "$TRIPS_COUNT" -ge 5 ]; then
  echo "  ✅ PASS: [TRIPS] log prefix (${TRIPS_COUNT} occurrences, ≥5 required)"
  PASS=$((PASS + 1))
else
  echo "  ❌ FAIL: [TRIPS] log prefix (${TRIPS_COUNT} occurrences, ≥5 required)"
  FAIL=$((FAIL + 1))
fi

TRIPS_ERR_COUNT=$(grep -cE "\[TRIPS\] Error" "$FILE" 2>/dev/null || echo 0)
if [ "$TRIPS_ERR_COUNT" -ge 1 ]; then
  echo "  ✅ PASS: [TRIPS] Error prefix (${TRIPS_ERR_COUNT} occurrences, ≥1 required)"
  PASS=$((PASS + 1))
else
  echo "  ❌ FAIL: [TRIPS] Error prefix (${TRIPS_ERR_COUNT} occurrences, ≥1 required)"
  FAIL=$((FAIL + 1))
fi
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
