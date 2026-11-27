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

cd -- "$app_dir"
flutter drive --debug -d "$serial" \
  --driver=test_driver/play_store_screenshots.dart \
  --target=integration_test/play_store_screenshots.dart

echo "Screenshots saved to $SANQI_SCREENSHOT_OUTPUT"
