#!/bin/sh
# Cycle to the next (or previous, with -p) wallpaper in the wallpapers dir.
# wallpaper.sh does the actual swaybg work; this only picks the file.

DIR="$HOME/.config/hypr/wallpapers"
LINK="$HOME/.config/hypr/current-wallpaper"

LIST=$(find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort)
[ -z "$LIST" ] && { notify-send "Wallpaper" "no images in $DIR" 2>/dev/null; exit 1; }

COUNT=$(printf '%s\n' "$LIST" | wc -l)

CURRENT=$(readlink "$LINK" 2>/dev/null)
IDX=$(printf '%s\n' "$LIST" | grep -nxF "$CURRENT" | cut -d: -f1)
[ -z "$IDX" ] && IDX=1

if [ "$1" = "-p" ]; then
    NEXT=$((IDX - 1))
    [ "$NEXT" -lt 1 ] && NEXT=$COUNT
else
    NEXT=$((IDX + 1))
    [ "$NEXT" -gt "$COUNT" ] && NEXT=1
fi

WALL=$(printf '%s\n' "$LIST" | sed -n "${NEXT}p")

"$HOME/.config/hypr/scripts/wallpaper.sh" "$WALL"
notify-send -t 1500 "Wallpaper" "$(basename "$WALL")  ($NEXT/$COUNT)" 2>/dev/null
