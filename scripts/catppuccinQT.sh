#!/usr/bin/env bash
set -euo pipefail

# Check dependencies
for cmd in curl unzip; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ Missing dependency: $cmd"
    echo "Install with: sudo apt install curl unzip"
    exit 1
  fi
done

KVANTUM_DIR="$HOME/.config/Kvantum"
mkdir -p "$KVANTUM_DIR"

# Catppuccin flavors
FLAVORS=("latte" "frappe" "macchiato" "mocha")

# Catppuccin accents
ACCENTS=("blue" "flamingo" "green" "lavender" "maroon" "mauve" "peach" "pink" "red" "rosewater" "sapphire" "sky" "teal" "yellow")

echo "🧚 Catppuccin Kvantum Theme Installer"
echo "======================================"
echo

# Step 1: choose flavor
echo "Choose a flavor:"
for i in "${!FLAVORS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${FLAVORS[$i]}"
done
read -rp "Flavor number: " FN
FLAVOR="${FLAVORS[$((FN-1))]}"

echo

# Step 2: choose accent
echo "Choose an accent:"
for i in "${!ACCENTS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${ACCENTS[$i]}"
done
read -rp "Accent number: " AN
ACCENT="${ACCENTS[$((AN-1))]}"

echo

# Step 3: download and extract the theme folder
THEME_NAME="catppuccin-${FLAVOR}-${ACCENT}"
REPO_URL="https://github.com/catppuccin/kvantum/archive/refs/heads/main.zip"
TEMP_DIR="/tmp/catppuccin-kvantum-$$"

echo "Downloading Catppuccin Kvantum themes..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

curl -L -o "kvantum.zip" "$REPO_URL" --progress-bar

echo "Extracting..."
unzip -q "kvantum.zip"

# Check if theme exists
THEME_SRC="kvantum-main/themes/$THEME_NAME"
if [[ ! -d "$THEME_SRC" ]]; then
  echo "❌ Theme '$THEME_NAME' not found!"
  echo "Available themes:"
  ls "kvantum-main/themes/" | grep -E "^catppuccin-" | head -10
  rm -rf "$TEMP_DIR"
  exit 1
fi

# Copy theme folder to Kvantum directory
THEME_DEST="$KVANTUM_DIR/$THEME_NAME"
if [[ -d "$THEME_DEST" ]]; then
  echo "⚠️  Overwriting existing theme..."
  rm -rf "$THEME_DEST"
fi

cp -r "$THEME_SRC" "$THEME_DEST"

# Clean up
rm -rf "$TEMP_DIR"

# Add QT_STYLE_OVERRIDE to shell profile
add_qt_override() {
  local line="export QT_STYLE_OVERRIDE=kvantum"
  
  # Detect shell and set appropriate profile file
  if [[ "$SHELL" == *"zsh"* ]] && [[ -f "$HOME/.zshrc" ]]; then
    local profile_file="$HOME/.zshrc"
  elif [[ "$SHELL" == *"bash"* ]] && [[ -f "$HOME/.bashrc" ]]; then
    local profile_file="$HOME/.bashrc"
  elif [[ -f "$HOME/.profile" ]]; then
    local profile_file="$HOME/.profile"
  else
    echo "⚠️  Could not detect shell profile file"
    echo "   Please manually add: $line"
    return
  fi
  
  # Check if already exists
  if grep -q "QT_STYLE_OVERRIDE=kvantum" "$profile_file" 2>/dev/null; then
    echo "ℹ️  QT_STYLE_OVERRIDE already set in $profile_file"
  else
    echo "📝 Adding QT_STYLE_OVERRIDE to $profile_file"
    echo "$line" >> "$profile_file"
    echo "✅ Added QT_STYLE_OVERRIDE to shell profile"
  fi
}

add_qt_override

echo "✅ Done! Theme '${THEME_NAME}' installed to:"
echo "   $THEME_DEST"
echo
echo "Next steps:"
echo "1. Open Kvantum Manager"
echo "2. Select '$THEME_NAME' from the theme list"
echo "3. Click 'Use this theme'"
echo "4. Restart your shell: source ~/.$(basename $SHELL)rc (or ~/.profile)"
echo "5. Restart applications to see changes"
