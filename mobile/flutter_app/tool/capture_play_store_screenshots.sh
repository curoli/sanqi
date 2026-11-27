#!/usr/bin/env bash
set -euo pipefail

if (( $# > 2 )) || [[ ${1:-} == --help ]]; then
  echo "Usage: $0 [output-directory] [adb-device-serial]"
  exit 0
fi

app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$app_dir/build/play-store-screenshots/$(date -u +%Y%m%dT%H%M%SZ)}"
if [[ -n ${2:-} ]]; then
  serial="$2"
  [[ "$(adb -s "$serial" get-state)" == device ]]
else
  serial="$(adb -d get-serialno)"
fi

if [[ -e "$output" ]]; then
  echo "Choose a new output directory: $output already exists." >&2
  exit 1
fi
mkdir -p -- "$output"
SANQI_SCREENSHOT_OUTPUT="$(cd -- "$output" && pwd)"
export SANQI_SCREENSHOT_OUTPUT

# Keep the screen on during the build as well as the capture. A USB-connected
# device may report either USB or AC charging, depending on the charger.
stay_awake_key=stay_on_while_plugged_in
previous="$(adb -s "$serial" shell settings get global "$stay_awake_key")"
previous="${previous%$'\r'}"
if [[ "$previous" == null ]]; then
  keep_awake=3
elif [[ "$previous" =~ ^[0-9]{1,10}$ ]]; then
  keep_awake=$((10#$previous | 3))
else
  echo "Unable to read the phone's stay-awake setting." >&2
  exit 1
fi

restore_stay_awake() {
  local status=$?
  local -a restore=(put global "$stay_awake_key" "$previous")
  if [[ "$previous" == null ]]; then
    restore=(delete global "$stay_awake_key")
  fi
  if ! adb -s "$serial" shell settings "${restore[@]}" >/dev/null; then
    echo "Could not restore the phone's stay-awake setting (previous value: $previous)." >&2
    if (( status == 0 )); then status=1; fi
  fi
  exit "$status"
}

if [[ "$keep_awake" != "$previous" ]]; then
  trap restore_stay_awake EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  adb -s "$serial" shell settings put global "$stay_awake_key" "$keep_awake"
fi

cd -- "$app_dir"
flutter drive --debug -d "$serial" \
  --driver=test_driver/play_store_screenshots.dart \
  --target=integration_test/play_store_screenshots.dart

echo "Screenshots saved to $SANQI_SCREENSHOT_OUTPUT"
