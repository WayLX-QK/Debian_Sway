#!/usr/bin/env bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_DIR="$HOME/.config"
BACKUP_DIR="$HOME/.config_backup_$(date +%Y%m%d_%H%M%S)"
SETUP_DIR="$SCRIPT_DIR/.config"  # relative to script, works from anywhere

# Check setup folder exists
if [ ! -d "$SETUP_DIR" ]; then
    echo "Error: Setup folder $SETUP_DIR does not exist!"
    exit 1
fi

# Backup existing .config
if [ -d "$CONFIG_DIR" ]; then
    echo "Backing up existing .config to $BACKUP_DIR"
    mv "$CONFIG_DIR" "$BACKUP_DIR"
fi

mkdir -p "$CONFIG_DIR"

# Copy everything, including empty directories
echo "Copying configs from $SETUP_DIR to $CONFIG_DIR"
rsync -avh --progress "$SETUP_DIR/" "$CONFIG_DIR/"

echo "Done. Original configs are backed up at $BACKUP_DIR"
