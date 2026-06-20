#!/usr/bin/env bash
#============================================================#
#            Debian 13 Sway Full Setup Script               #
#      Fully automatic, no prompts, ready for fresh system  #
#============================================================#

#==================#
#   Colors Setup   #
#==================#
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
RESET="\033[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }

#==================#
#   Require Root   #
#==================#
if [ "$EUID" -ne 0 ]; then
    warn "This script will make system-wide changes and requires administrator (root) privileges."
    echo
    read -p "Press Enter to continue and enter your sudo password... " _
    sudo -k    # invalidate existing timestamp to force password prompt
    exec sudo bash "$0" "$@"   # re-run script as root, preserving args
fi

set -euo pipefail

# Get actual user
ACTUAL_USER="${SUDO_USER:-$(logname)}"
USER_HOME=$(eval echo ~$ACTUAL_USER)

info "Installing for user: $ACTUAL_USER"

#==================#
# Update System
#==================#
info "Updating system..."
apt update && apt upgrade -y
success "System updated!"

#==================#
# Basic Tools
#==================#
info "Installing essential tools..."
apt install -y zram-tools curl git wget pipewire-audio-client-libraries \
libspa-0.2-bluetooth
success "Basic tools installed!"

#==================#
# Python & Dev Tools
#==================#
info "Installing Python and development essentials..."
apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    python3-numpy \
    python3-scipy \
    python3-matplotlib \
    python3-pandas
success "Python and scientific libraries installed!"

#==================#
# Sway & WLR
#==================#
info "Installing Sway and related packages..."
apt install -y sway swaylock swayidle swaybg sway-notification-center \
foot xdg-desktop-portal-wlr xwayland xdg-desktop-portal
success "Sway installed!"

#==================#
# Waybar & UI
#==================#
info "Installing Waybar, brightness, audio, clipboard, notifications..."
apt install -y waybar upower brightnessctl pavucontrol cliphist \
wl-clipboard libnotify-bin network-manager-applet autotiling
success "Waybar and UI utilities installed!"

#==================#
# File Managers
#==================#
info "Installing Thunar and archive tools..."
apt install -y thunar thunar-volman thunar-archive-plugin xarchiver \
tumbler ffmpegthumbnailer zenity unar zip p7zip-full p7zip unzip \
gvfs-backends gvfs-fuse smbclient lxpolkit geany geany-plugin-addons \
geany-plugin-git-changebar geany-plugin-overview geany-plugin-spellcheck \
geany-plugin-treebrowser geany-plugin-vimode geany-plugin-markdown
success "File managers installed!"

#==================#
# Media Packages
#==================#
info "Installing multimedia packages..."
apt install -y ffmpeg mpv imv audacious mediainfo-gui flameshot \
shotcut audacity
success "Media packages installed!"

#==================#
# Terminal Tools
#==================#
info "Installing terminal tools..."
apt install -y bat duf htop btop eza rsync
success "Terminal tools installed!"

#==================#
# Rofi-Wayland
#==================#
info "Downloading and installing latest Rofi-Wayland..."
apt install -y rofi
# Temporary folder for download
# TMP_DIR=$(mktemp -d)
# pushd "$TMP_DIR" > /dev/null
#
# # Get latest .deb
# ROFI_URL=$(curl -s https://api.github.com/repos/mmBesar/rofi-wayland-debian/releases/latest \
#     | grep "browser_download_url.*trixie.*\.deb" | grep -v "dbgsym" | cut -d '"' -f 4)
#
# wget "$ROFI_URL"
#
# # Install
# apt install -y ./*.deb
#
# popd > /dev/null
#
# # Clean up
# rm -rf "$TMP_DIR"

success "Rofi-Wayland installed!"

#==================#
# Greetd
#==================#
info "Installing greetd and tuigreet..."
apt install -y greetd tuigreet

GREETD_CONFIG="/etc/greetd/config.toml"

# Backup
if [ -f "$GREETD_CONFIG" ]; then
    cp "$GREETD_CONFIG" "${GREETD_CONFIG}.bak"
    success "Backup created at ${GREETD_CONFIG}.bak"
fi

# Write new config
cat > "$GREETD_CONFIG" <<'EOF'
[terminal]
vt = 7

[default_session]
command = "tuigreet --remember --asterisks --no-xsession-wrapper --cmd sway"
user = "_greetd"
EOF

success "Configured greetd with tuigreet"

warn "Reboot to test the login manager."

#==================#
# Theme packages
#==================#
info "Installing essential tools..."
apt install -y nwg-look qt5-style-kvantum qt6-style-kvantum papirus-icon-theme
success "Theme packages installed!"

#==================#
# Done
#==================#
success "All steps completed! Reboot recommended."
