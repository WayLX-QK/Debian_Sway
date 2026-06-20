#!/usr/bin/env bash

# cliphist list | rofi -dmenu -i \
#     -theme-str 'listview {lines: 6; columns: 1;}' \
#     -theme-str 'window {width: 40%; height: 45%; border-radius: 15px;}' \
#     | cliphist decode | wl-copy

rofi -modi clipboard:~/.config/rofi/scripts/cliphist-rofi-img \
    -show clipboard -show-icons -i -hover-select \
    -me-select-entry '' -me-accept-entry MousePrimary \
    -theme-str 'listview {lines: 6; columns: 1;}' \
    -theme-str 'window {width: 40%; height: 45%; border-radius: 15px;}'