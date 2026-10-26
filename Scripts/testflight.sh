#!/bin/zsh
# Archives Tact for the App Store and uploads it to TestFlight.
#
# Usage:
#   Scripts/testflight.sh
#
# Authenticates with an App Store Connect API key, not the Xcode login: xcodebuild
# run from a terminal cannot read the accounts Xcode keeps. ASC_KEY_ID and
# ASC_ISSUER_ID come from the environment or from ~/.appstoreconnect/tact.env
# (two lines: ASC_KEY_ID=... and ASC_ISSUER_ID=...); the key file is
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 unless ASC_KEY_PATH says
# otherwise.
#
# Signing is manual: the "Apple Distribution" certificate in the login keychain
# and the "Tact App Store" profile (Scripts/ExportOptions.plist), because the
# team's cloud-managed certificate is not available to API keys. To set up a new
# Mac: in Xcode > Settings > Accounts > Manage Certificates add an Apple
# Distribution certificate, then regenerate the "Tact App Store" profile for it
# in the developer portal and download it.
#
# The build number is the current UTC time, so every upload is unique and increasing.
# The marketing version comes from MARKETING_VERSION in the project.

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:-3D52FT6PP7}"
BUILD_NUMBER="${BUILD_NUMBER:-$(date -u +%Y%m%d%H%M)}"
ARCHIVE="build/Tact.xcarchive"
EXPORT_DIR="build/export"

[[ -f "$HOME/.appstoreconnect/tact.env" ]] && source "$HOME/.appstoreconnect/tact.env"
: "${ASC_KEY_ID:?Set ASC_KEY_ID (or put it in ~/.appstoreconnect/tact.env)}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (or put it in ~/.appstoreconnect/tact.env)}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
[[ -f "$ASC_KEY_PATH" ]] || { echo "No API key at $ASC_KEY_PATH (see the comment above)"; exit 1; }
auth=(-authenticationKeyPath "$ASC_KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

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
  "${auth[@]}"

echo "==> Done. Build $BUILD_NUMBER is processing; it appears in TestFlight in a few minutes."
