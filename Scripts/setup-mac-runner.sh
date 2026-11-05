#!/bin/zsh
# One-time setup of a Mac as the build machine for Tact.
#
# Usage (on the Mac, from the repository root or anywhere):
#   zsh Scripts/setup-mac-runner.sh
#
# What it does, each step skipped if already done:
#   1. Points the command-line tools at Xcode, accepts the licence, installs an iOS simulator runtime.
#   2. Checks the TestFlight signing pieces Scripts/testflight.sh needs (API key, Apple
#      Distribution certificate, "Tact App Store" profile) and says what is missing.
#   3. Lets codesign use the distribution key without a keychain prompt (asks for your login password).
#   4. Installs a GitHub Actions runner (label "tact") as a login agent, so pushes to
#      github.com/ikaikahussey/tact build here via .github/workflows/mac-build.yml.
#   5. Stops the Mac from sleeping, so the runner stays reachable.
#
# The runner runs as you, in your login session, because signing needs the login keychain.
# For it to survive a reboot unattended, turn on automatic login:
# System Settings > Users & Groups > Automatically log in as.

set -euo pipefail

REPO="ikaikahussey/tact"
RUNNER_DIR="$HOME/actions-runner-tact"
RUNNER_NAME="${RUNNER_NAME:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}"
missing=()

step() { print -P "\n%B==> $1%b"; }
ok()   { print "    ok: $1"; }
warn() { print "    MISSING: $1"; missing+=("$1"); }

# 1. Xcode -------------------------------------------------------------------
step "Xcode"
if [[ ! -d /Applications/Xcode.app ]]; then
  print "Xcode is not in /Applications. Install it from the App Store, open it once, then rerun this."
  exit 1
fi
if [[ "$(xcode-select -p)" != /Applications/Xcode.app/* ]]; then
  print "    Pointing command-line tools at Xcode (sudo)"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  print "    Accepting the Xcode licence and finishing first launch (sudo)"
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
fi
ok "$(xcodebuild -version | head -1)"

if xcrun simctl list devices available | grep -qE '^[[:space:]]+iPhone'; then
  ok "iPhone simulator available"
else
  print "    Downloading the iOS simulator runtime (several GB)"
  xcodebuild -downloadPlatform iOS
fi

# 2. TestFlight signing --------------------------------------------------------
step "TestFlight signing"
[[ -f "$HOME/.appstoreconnect/tact.env" ]] && source "$HOME/.appstoreconnect/tact.env"
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  ok "API key ID and issuer ID"
  key="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_$ASC_KEY_ID.p8}"
  [[ -f "$key" ]] && ok "API key file" || warn "API key file $key"
else
  warn "~/.appstoreconnect/tact.env with ASC_KEY_ID=... and ASC_ISSUER_ID=... (App Store Connect > Users and Access > Integrations > Team Keys)"
fi

if security find-identity -v -p codesigning | grep -q '"Apple Distribution'; then
  has_dist=1; ok "Apple Distribution certificate"
else
  has_dist=0; warn "Apple Distribution certificate (Xcode > Settings > Accounts > Manage Certificates > + > Apple Distribution)"
fi

profile_found=0
for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  [[ -d "$dir" ]] || continue
  for p in "$dir"/*.mobileprovision(N); do
    if security cms -D -i "$p" 2>/dev/null | grep -q '<string>Tact App Store</string>'; then
      profile_found=1; break 2
    fi
  done
done
(( profile_found )) && ok '"Tact App Store" profile' \
  || warn '"Tact App Store" provisioning profile (developer.apple.com > Profiles > regenerate for the Distribution certificate, download, double-click)'

# 3. Keychain access for codesign ---------------------------------------------
step "Keychain"
if (( has_dist )) && [[ ! -f "$HOME/.tact-keychain-ok" ]]; then
  print "    Allowing codesign to use the signing key without a prompt."
  print "    Enter your Mac login password when asked."
  if security set-key-partition-list -S apple-tool:,apple:,codesign: -s "$HOME/Library/Keychains/login.keychain-db" >/dev/null; then
    touch "$HOME/.tact-keychain-ok"; ok "codesign allowed"
  else
    warn "keychain partition list (rerun this script to try again)"
  fi
else
  ok "nothing to do"
fi

# 4. GitHub Actions runner ------------------------------------------------------
step "GitHub Actions runner"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
if [[ ! -x ./config.sh ]]; then
  version=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest \
    | sed -nE 's/.*"tag_name": *"v([^"]+)".*/\1/p' | head -1)
  [[ -n "$version" ]] || { print "Could not look up the runner version."; exit 1; }
  arch=$([[ "$(uname -m)" == arm64 ]] && echo arm64 || echo x64)
  print "    Downloading runner $version ($arch)"
  curl -fsSL -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v$version/actions-runner-osx-$arch-$version.tar.gz"
  tar xzf runner.tar.gz && rm runner.tar.gz
fi

if [[ ! -f .runner ]]; then
  token=""
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    token=$(gh api -X POST "repos/$REPO/actions/runners/registration-token" -q .token 2>/dev/null || true)
  fi
  if [[ -z "$token" ]]; then
    print "    Open https://github.com/$REPO/settings/actions/runners/new"
    print "    and copy the token shown after --token in the Configure step."
    read -rs "token?    Paste the token (input hidden): "; print
  fi
  ./config.sh --unattended --replace \
    --url "https://github.com/$REPO" --token "$token" \
    --name "$RUNNER_NAME" --labels tact --work _work
fi
ok "runner registered as $RUNNER_NAME"

if ! ./svc.sh status 2>/dev/null | grep -q 'Started'; then
  ./svc.sh install >/dev/null 2>&1 || true
  ./svc.sh start
fi
ok "runner service started"

# 5. Power -------------------------------------------------------------------------
step "Power"
if [[ "$(pmset -g | awk '$1=="sleep"{print $2}')" != 0 ]]; then
  print "    Disabling system sleep (sudo)"
  sudo pmset -a sleep 0 disksleep 0
fi
ok "system sleep off"

step "Done"
if (( ${#missing} )); then
  print "Builds and tests will run. TestFlight uploads need:"
  for m in "${missing[@]}"; do print "  - $m"; done
else
  print "Builds, tests and TestFlight uploads are ready."
fi
print "Runner logs: $RUNNER_DIR/_diag"
