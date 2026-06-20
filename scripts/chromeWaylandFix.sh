#!/usr/bin/env bash
# =======================================================
# Chrome Desktop Fixer
# -------------------------------------------------------
# Copies /usr/share/applications/google-chrome.desktop
# → ~/.local/share/applications/google-chrome.desktop
# and patches *all* Exec lines with your VA-API flags.
# Keeps an optional X11 fallback inside the file.
# =======================================================

set -e

# ---------------- CONFIG ----------------
SRC_DESKTOP="/usr/share/applications/google-chrome.desktop"
DEST_DIR="$HOME/.local/share/applications"
DEST_DESKTOP="$DEST_DIR/google-chrome.desktop"
BACKUP_DESKTOP="$DEST_DESKTOP.bak"

# ---------------- COLORS ----------------
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# ---------------- FLAGS ----------------
CHROME_FLAGS="--disable-gpu-compositing \
 --disable-gpu-rasterization \
 --disable-features=UseSkiaRenderer \
 --enable-features=VaapiVideoDecoder,VaapiVideoDecodeLinuxGL"

CHROME_FLAGS_X11="--ozone-platform=x11 ${CHROME_FLAGS}"

# ---------------- SCRIPT ----------------
echo -e "${BLUE}==> Customizing Chrome desktop launcher...${RESET}"

# Ensure source exists
if [[ ! -f "$SRC_DESKTOP" ]]; then
    echo -e "${RED}Error: ${SRC_DESKTOP} not found!${RESET}"
    exit 1
fi

# Backup if exists
mkdir -p "$DEST_DIR"
if [[ -f "$DEST_DESKTOP" ]]; then
    echo -e "${YELLOW}Backing up old launcher → ${BACKUP_DESKTOP}${RESET}"
    cp "$DEST_DESKTOP" "$BACKUP_DESKTOP"
fi

# Copy launcher
cp "$SRC_DESKTOP" "$DEST_DESKTOP"

# Patch ALL Exec lines (main, new-window, incognito)
sed -i \
    -e "s|^Exec=/usr/bin/google-chrome-stable %U|Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS} %U|" \
    -e "s|^Exec=/usr/bin/google-chrome-stable$|Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS}|" \
    -e "s|^Exec=/usr/bin/google-chrome-stable --incognito|Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS} --incognito|" \
    "$DEST_DESKTOP"

# Append optional X11 section
cat <<EOF >> "$DEST_DESKTOP"

# ================================
# OPTIONAL X11 FALLBACK
# Uncomment these Exec lines if you want
# Chrome to always run under XWayland:
# Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS_X11} %U
# Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS_X11}
# Exec=/usr/bin/google-chrome-stable ${CHROME_FLAGS_X11} --incognito
# ================================
EOF

echo -e "${GREEN}✔ New launcher saved to:${RESET} ${DEST_DESKTOP}"
echo -e "${YELLOW}Default: Wayland with VA-API flags${RESET}"
echo -e "${YELLOW}Optional: Uncomment X11 fallback inside the file if needed${RESET}"
echo -e "${GREEN}Done.${RESET}"
