#!/usr/bin/env bash
# ==========================================
# 🧩  Ordered Script Runner (with defaults)
# Runs setup scripts in the order you define,
# asks Y/N per script with a default value.
# ==========================================

set -e  # stop on error

# --- Colors ---
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RED="\e[31m"
RESET="\e[0m"

# --- Directory setup ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# --- Ordered list: "script|description|default"
SCRIPTS=(
    "swayInstall.sh|Install base system packages and tools|Y"
    "swayConfig.sh|Configure Sway window manager and related settings|Y"
    "installFirefox.sh|Install Firefox|Y"
    "installFonts.sh|Install system fonts|Y"
    "updateConfig.sh|Copy and update .config|Y"
    "bashrc.sh|Update bashrc|Y"
    "catppuccinGTK.sh|Install Catppuccin GTK|Y"
    "catppuccinQT.sh|Install Catppuccin QT|Y"
    "bibataCursor.sh|Install Bibata Cursors|Y"
    "addUserToGroups.sh|Add your user to the needed groups|Y"
    "chromeWaylandFix.sh|Apply a fix for Chrome on Wayland for older systems|N"
)


# --- Header ---
echo -e "${BLUE}=========================================="
echo -e "      🔧 Install and configure Sway for Debian 13"
echo -e "==========================================${RESET}\n"

# --- Main loop ---
for ENTRY in "${SCRIPTS[@]}"; do
    SCRIPT="${ENTRY%%|*}"             # part before first |
    REST="${ENTRY#*|}"
    DESC="${REST%%|*}"                # middle part
    DEFAULT="${REST##*|}"             # last part
    SCRIPT_PATH="$SCRIPTS_DIR/$SCRIPT"

    echo -e "${YELLOW}▶ ${SCRIPT}${RESET}"
    echo -e "   ${BLUE}${DESC}${RESET}"

    if [ ! -f "$SCRIPT_PATH" ]; then
        echo -e "${RED}   ❌ Script not found: $SCRIPT_PATH${RESET}\n"
        continue
    fi

    # Normalize default (Y/N)
    DEFAULT=${DEFAULT^^}
    PROMPT="   ➤ Run this script? (y/N): "
    [ "$DEFAULT" == "Y" ] && PROMPT="   ➤ Run this script? (Y/n): "

    read -rp "$PROMPT" ANSWER
    ANSWER=${ANSWER:-$DEFAULT}  # use default if empty
    echo

    case "${ANSWER^^}" in
        Y)
            echo -e "${GREEN}   ✅ Running $SCRIPT...${RESET}"
            bash "$SCRIPT_PATH"
            echo -e "${GREEN}   ✅ Done: $SCRIPT${RESET}\n"
            ;;
        *)
            echo -e "${YELLOW}   ⚠ Skipped: $SCRIPT${RESET}\n"
            ;;
    esac
done

echo -e "${BLUE}=========================================="
echo -e "     🏁 All tasks processed."
echo -e "==========================================${RESET}"
