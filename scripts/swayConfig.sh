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
# Nerd Fonts
#==================#
info "Installing JetBrainsMono Nerd Font..."
mkdir -p ~/.local/share/fonts
pushd ~/.local/share/fonts > /dev/null

curl -OL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
bash -c 'mkdir "${1%.tar.xz}" && tar -xf "$1" -C "${1%.tar.xz}"' _ JetBrainsMono.tar.xz
rm JetBrainsMono.tar.xz
fc-cache -fv

popd > /dev/null
success "Nerd font installed!"

#==================#
# Starship Prompt
#==================#
info "Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh
echo 'eval "$(starship init bash)"' >> ~/.bashrc
success "Starship installed!"

#==================#
# fzf
#==================#
info "Installing fzf..."
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install --all
success "fzf installed!"

#==================#
# Sway Config
#==================#
info "Copying Sway config..."
mkdir -p ~/.config/sway
cp /etc/sway/config ~/.config/sway/config
success "Sway config copied!"

#==================#
# Waybar Config
#==================#
info "Copying Waybar config..."
mkdir -p ~/.config/waybar
cp -r /etc/xdg/waybar/* ~/.config/waybar/
success "Waybar config copied!"

#==================#
# Create GTK theme config folders
#==================#
info "Creating .config/gtk-3.0 and .config/gtk-4.0 ..."
mkdir -p ~/.config/{gtk-3.0,gtk-4.0}
success "GTK theme config folders created!"

#==================#
# Done
#==================#
success "All steps completed! Reboot recommended."
