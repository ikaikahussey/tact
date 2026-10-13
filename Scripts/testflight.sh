#!/bin/zsh
# Archives Tact for the App Store and uploads it to TestFlight.
#
# Usage:
#   Scripts/testflight.sh                              # upload with your Xcode login
#   ASC_KEY_PATH=~/AuthKey_XXXX.p8 ASC_KEY_ID=XXXX ASC_ISSUER_ID=... Scripts/testflight.sh
#
# Requirements: Xcode signed in to the Apple Developer account that owns TEAM_ID
# (Xcode > Settings > Accounts), the bundle id registered in App Store Connect, and
# an app record created there. Signing is automatic; -allowProvisioningUpdates lets
# xcodebuild create the distribution profile.
#
# The build number is the current UTC time, so every upload is unique and increasing.
# The marketing version comes from MARKETING_VERSION in the project.

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:-3D52FT6PP7}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
ARCHIVE="build/Tact.xcarchive"
EXPORT_DIR="build/export"

auth=()
if [[ -n "${ASC_KEY_PATH:-}" ]]; then
  auth=(-authenticationKeyPath "$ASC_KEY_PATH"
        -authenticationKeyID "${ASC_KEY_ID:?}"
        -authenticationKeyIssuerID "${ASC_ISSUER_ID:?}")
fi

echo "==> Archiving build $BUILD_NUMBER for team $TEAM_ID"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
xcodebuild archive \
  -project Tact.xcodeproj \
  -scheme Tact \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates "${auth[@]}" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

[[ -d "$ARCHIVE" ]] || { echo "Archive failed"; exit 1; }

echo "==> Uploading to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist Scripts/ExportOptions.plist \
  -exportPath "$EXPORT_DIR" \
  -allowProvisioningUpdates "${auth[@]}"

echo "==> Done. Build $BUILD_NUMBER is processing; it appears in TestFlight in a few minutes."
