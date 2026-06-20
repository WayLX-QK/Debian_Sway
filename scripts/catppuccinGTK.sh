#!/usr/bin/env bash
set -euo pipefail

THEMEDIR="$HOME/.local/share/themes"
mkdir -p "$THEMEDIR"

# Catppuccin flavors
FLAVORS=("latte" "frappe" "macchiato" "mocha")

# Catppuccin accents
ACCENTS=("blue" "flamingo" "green" "lavender" "maroon" "mauve" "peach" "pink" "red" "rosewater" "sapphire" "sky" "teal" "yellow")

# Step 1: choose flavor
echo "Choose a flavor:"
for i in "${!FLAVORS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${FLAVORS[$i]}"
done
read -rp "Flavor number: " FN
FLAVOR="${FLAVORS[$((FN-1))]}"

# Step 2: choose accent
echo "Choose an accent:"
for i in "${!ACCENTS[@]}"; do
  printf "%2d) %s\n" $((i+1)) "${ACCENTS[$i]}"
done
read -rp "Accent number: " AN
ACCENT="${ACCENTS[$((AN-1))]}"

# Step 3: download and extract
ROOT_URL="https://github.com/catppuccin/gtk/releases/download/v1.0.3"
ZIP_NAME="catppuccin-${FLAVOR}-${ACCENT}-standard+default.zip"
URL="${ROOT_URL}/${ZIP_NAME}"

echo "Downloading ${ZIP_NAME}..."
curl -L -o "/tmp/${ZIP_NAME}" "$URL"
echo "Extracting..."
unzip -o "/tmp/${ZIP_NAME}" -d "$THEMEDIR"

echo "Done! Selected theme: ${FLAVOR}-${ACCENT} is installed"
