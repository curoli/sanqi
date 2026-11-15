#!/usr/bin/env bash
set -euo pipefail

sanqi_app_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
sanqi_build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
sanqi_git_commit="$(git -C "$sanqi_app_dir" rev-parse --verify HEAD)"
if ! git -C "$sanqi_app_dir" diff --quiet HEAD --; then
  sanqi_git_commit="${sanqi_git_commit}-dirty"
fi
cd -- "$sanqi_app_dir"
exec flutter "$@" \
  "--dart-define=SANQI_BUILD_DATE=$sanqi_build_date" \
  "--dart-define=SANQI_GIT_COMMIT=$sanqi_git_commit"
