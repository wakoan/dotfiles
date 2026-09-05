#!/bin/sh
# Point ~/.config/hypr/current-wallpaper at an image and (re)start swaybg on it.
#
# The symlink is the persistent state: swaybg is always launched against the
# link, never the real file, so the choice survives a relogin with no state
# file to keep in sync.
#
# usage: wallpaper.sh [/path/to/image]      (no arg = re-apply current)

LINK="$HOME/.config/hypr/current-wallpaper"
DEFAULT="$HOME/.config/hypr/wallpapers/1.jpg"

if [ -n "$1" ]; then
    WALLPAPER=$1
elif [ -L "$LINK" ]; then
    WALLPAPER=$(readlink "$LINK")
else
    WALLPAPER=$DEFAULT
fi

# Fall back if the remembered image was deleted or renamed.
[ -f "$WALLPAPER" ] || WALLPAPER=$DEFAULT

ln -sfn "$WALLPAPER" "$LINK"

pkill -x swaybg 2>/dev/null
setsid swaybg -i "$LINK" -m fill >/dev/null 2>&1 &
