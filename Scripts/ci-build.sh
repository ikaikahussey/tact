#!/bin/zsh
# Builds Tact and runs the unit tests on an iOS simulator.
#
# Usage:
#   Scripts/ci-build.sh            # build + test
#   Scripts/ci-build.sh build      # build only
#
# Used by .github/workflows/mac-build.yml on the Mac mini runner; also runs by hand.
# Picks the newest available iPhone simulator unless SIM_NAME is set.
# Writes the full log to build/logs/xcodebuild.log and a short digest of errors,
# test failures and the tail of the log to build/logs/digest.txt.

set -uo pipefail
cd "$(dirname "$0")/.."

ACTION="${1:-test}"
LOG_DIR="build/logs"
LOG="$LOG_DIR/xcodebuild.log"
DIGEST="$LOG_DIR/digest.txt"
mkdir -p "$LOG_DIR"
rm -rf build/TestResults.xcresult

if [[ -n "${SIM_NAME:-}" ]]; then
  DEST="platform=iOS Simulator,name=$SIM_NAME"
else
  # Newest runtime is listed last; take the last available iPhone.
  SIM_ID=$(xcrun simctl list devices available \
    | grep -E '^[[:space:]]+iPhone' \
    | tail -1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [[ -z "$SIM_ID" ]]; then
    echo "No iPhone simulator available. Install an iOS runtime: Xcode > Settings > Components." | tee "$DIGEST"
    exit 1
  fi
  DEST="id=$SIM_ID"
fi

echo "==> xcodebuild $ACTION ($DEST)"
xcodebuild "$ACTION" \
  -project Tact.xcodeproj \
  -scheme Tact \
  -destination "$DEST" \
  -resultBundlePath build/TestResults.xcresult \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$LOG"
status=${pipestatus[1]}

{
  echo "xcodebuild $ACTION exit $status"
  echo "Xcode: $(xcodebuild -version | head -1)  Destination: $DEST"
  echo
  echo "--- Errors and failures ---"
  grep -E ': error: |: fatal error: |error: |Test Case .* failed|\*\* (BUILD|TEST) (FAILED|SUCCEEDED)|Executed [0-9]+ tests' "$LOG" \
    | grep -v '^warning' | awk '!seen[$0]++' | head -150
  echo
  echo "--- Last 40 lines ---"
  tail -40 "$LOG"
} > "$DIGEST"

exit $status
