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
apt install -y zram-tools curl git wget
success "Basic tools installed!"

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
wl-clipboard libnotify-bin network-manager-applet
success "Waybar and UI utilities installed!"

#==================#
# File Managers
#==================#
info "Installing Thunar and archive tools..."
apt install -y thunar thunar-volman thunar-archive-plugin xarchiver \
tumbler ffmpegthumbnailer zenity rar unar zip 7zip 7zip-rar zip unzip \
gvfs-backends gvfs-fuse smbclient mate-polkit geany
success "File managers installed!"

#==================#
# Media Packages
#==================#
info "Installing multimedia packages..."
apt install -y ffmpeg mpv imv audacious mediainfo-gui
success "Media packages installed!"

#==================#
# Terminal Tools
#==================#
info "Installing terminal tools..."
apt install -y alacritty bat duf htop eza rsync
success "Terminal tools installed!"

#==================#
# Rofi-Wayland
#==================#
info "Downloading and installing latest Rofi-Wayland..."

# Temporary folder for download
TMP_DIR=$(mktemp -d)
pushd "$TMP_DIR" > /dev/null

# Get latest .deb
ROFI_URL=$(curl -s https://api.github.com/repos/mmBesar/rofi-wayland-debian/releases/latest \
    | grep "browser_download_url.*trixie.*\.deb" | grep -v "dbgsym" | cut -d '"' -f 4)

wget "$ROFI_URL"

# Install
apt install -y ./*.deb

popd > /dev/null

# Clean up
rm -rf "$TMP_DIR"

success "Rofi-Wayland installed!"

#==================#
# Greetd
#==================#
info "Installing greetd..."
apt install -y greetd

# Backup config
GREETD_CONFIG="/etc/greetd/config.toml"
cp "$GREETD_CONFIG" "${GREETD_CONFIG}.bak"
success "Backup created at ${GREETD_CONFIG}.bak"

# Replace /bin/sh with /bin/bash
sed -i "s|\${SHELL:-/bin/sh}|\${SHELL:-/bin/bash}|g" "$GREETD_CONFIG"
success "Updated default shell to bash in greetd config"

# Append initial_session
cat <<EOF >> "$GREETD_CONFIG"

[initial_session]
command = "sway"
user = "$SUDO_USER"
EOF
success "Appended initial_session with user $SUDO_USER"

warn "Please review /etc/greetd/config if you want to tweak other options."

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
