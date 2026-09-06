#!/usr/bin/env bash
set -euo pipefail

picture_dir="${XDG_PICTURES_DIR:-$HOME/Pictures}"
mkdir -p "$picture_dir"

filename="$picture_dir/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png"
grim "$filename"
wl-copy --type image/png < "$filename"
notify-send "Screenshot saved" "Full screen copied to clipboard and saved as $(basename "$filename")" 2>/dev/null || true
