#!/bin/sh
# Cycle to the next (or previous, with -p) wallpaper in the wallpapers dir.
# Remembers the choice in ~/.config/hypr/.wallpaper so it survives a relogin.

DIR="$HOME/.config/hypr/wallpapers"
STATE="$HOME/.config/hypr/.wallpaper"

# sorted list of images
LIST=$(find "$DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    | sort)
[ -z "$LIST" ] && { notify-send "wallpaper" "no images in $DIR" 2>/dev/null; exit 1; }

COUNT=$(printf '%s\n' "$LIST" | wc -l)

# current wallpaper: prefer what hyprpaper reports, fall back to state file
CURRENT=$(hyprctl hyprpaper listactive 2>/dev/null | head -1 | sed 's/^[^:]*: *//')
[ -z "$CURRENT" ] && [ -f "$STATE" ] && CURRENT=$(cat "$STATE")

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

hyprctl hyprpaper wallpaper ",$WALL" >/dev/null 2>&1
printf '%s\n' "$WALL" > "$STATE"
notify-send -t 1500 "Wallpaper" "$(basename "$WALL")  ($NEXT/$COUNT)" 2>/dev/null
