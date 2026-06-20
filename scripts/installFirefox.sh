#!/usr/bin/env bash
#============================================================#
#                    Firefox Install Script                  #
#                     For Debian-based distros               #
#============================================================#

#==================#
#   Colors Setup   #
#==================#
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

warn()  { echo -e "${YELLOW}$*${RESET}"; }
info()  { echo -e "${BLUE}$*${RESET}"; }
ok()    { echo -e "${GREEN}$*${RESET}"; }

#==================#
#   Require Root   #
#==================#
if [ "$EUID" -ne 0 ]; then
    warn "This script will make system-wide changes and requires administrator (root) privileges."
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k  # force password prompt
    exec sudo bash "$0" "$@"   # re-run script as root, preserving args
fi

set -euo pipefail

#-------------------------
# Ensure required tools
#-------------------------
info "[0/5] Ensuring required packages are present (wget, gpg)..."
if ! command -v wget >/dev/null 2>&1; then
    info "Installing wget..."
    apt update -y
    apt install -y wget
fi

if ! command -v gpg >/dev/null 2>&1; then
    info "Installing gnupg..."
    apt update -y
    apt install -y gnupg
fi

#===========================#
#   Step 1: Create Key Dir  #
#===========================#
info "[1/5] Creating /etc/apt/keyrings directory..."
install -d -m 0755 /etc/apt/keyrings

#=========================================#
#   Step 2: Import Mozilla APT Key        #
#=========================================#
info "[2/5] Downloading Mozilla APT signing key to /etc/apt/keyrings/packages.mozilla.org.asc ..."
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O /etc/apt/keyrings/packages.mozilla.org.asc

#===============================#
#   Verify Fingerprint (safe)   #
#===============================#
EXPECTED_FP="35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
info "[3/5] Verifying key fingerprint..."

# Use a temporary GNUPG home so gpg doesn't try to create/use /root/.gnupg
GNUPGHOME="$(mktemp -d)"
export GNUPGHOME

# Make sure the temp dir has safe perms
chmod 0700 "$GNUPGHOME"

# Import the key only into the temporary homedir and show fingerprint
set +e
FP_OUTPUT=$(gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc 2>&1)
GPG_EXIT=$?
set -e

# Clean up GNUPG dir after capturing output
rm -rf "$GNUPGHOME"
unset GNUPGHOME

# Extract the short/long fingerprint line from gpg output.
# The import-show output contains a 'pub' line then the fingerprint on the next line.
# We'll parse the output for the 40-hex fingerprint.
FP="$(printf '%s\n' "$FP_OUTPUT" | awk '/[A-F0-9]{40}/ { gsub(/[^A-F0-9]/,"",$0); print toupper($0); exit }' || true)"

if [ "$GPG_EXIT" -ne 0 ] || [ -z "$FP" ]; then
    echo -e "${RED}✗ gpg failed while reading the key or could not find a fingerprint.${RESET}"
    echo -e "${RED}gpg output:${RESET}\n$FP_OUTPUT"
    exit 1
fi

if [ "$FP" = "$EXPECTED_FP" ]; then
    ok "✓ Key fingerprint matches (${FP})"
else
    echo -e "${RED}✗ Verification failed!${RESET}"
    echo -e "${RED}Detected: ${FP}${RESET}"
    echo -e "${RED}Expected: ${EXPECTED_FP}${RESET}"
    exit 1
fi

#=========================================#
#   Step 3: Add Mozilla APT Repository    #
#=========================================#
info "[4/5] Adding Mozilla APT repository..."
echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
  | tee /etc/apt/sources.list.d/mozilla.list > /dev/null

#===============================================#
#   Step 4: Configure APT Pinning (Priority)    #
#===============================================#
info "[5/5] Setting APT pin-priority for Mozilla packages..."
cat > /etc/apt/preferences.d/mozilla <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

#=========================================#
#   Final: Update & Install Firefox      #
#=========================================#
info "[6/6] Updating APT and installing Firefox..."
apt update && apt install -y firefox

ok "✓ Firefox installation complete!"
