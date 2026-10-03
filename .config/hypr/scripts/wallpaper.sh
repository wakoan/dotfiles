#!/bin/sh
# Point ~/.config/hypr/current-wallpaper at an image and display it, animating
# the change when swww is available.
#
# The symlink stays the persistent state: the choice survives a relogin with
# no state file to keep in sync. swww is handed the resolved path rather than
# the link, though -- it keys its cache on the path it is given, so passing the
# same link every time would read as "already showing this" and the transition
# would be skipped.
#
# Falls back to swaybg when swww is absent, so the wallpaper still works on a
# machine where swww was never built.
#
# usage: wallpaper.sh [/path/to/image]      (no arg = re-apply current)

LINK="$HOME/.config/hypr/current-wallpaper"
DEFAULT="$HOME/.config/hypr/wallpapers/1.jpg"

# Overridable per invocation: WALLPAPER_TRANSITION=wipe wallpaper.sh pic.jpg
TRANSITION=${WALLPAPER_TRANSITION:-random}
DURATION=${WALLPAPER_TRANSITION_DURATION:-1.2}
# swww composites on the CPU and this is an Iris Pro 5200 driving 2880x1800,
# so 30fps keeps the animation smooth without pinning a core.
FPS=${WALLPAPER_TRANSITION_FPS:-30}

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

if command -v swww >/dev/null 2>&1; then
    # swaybg would sit on top of swww's surface.
    pkill -x swaybg 2>/dev/null

    # `swww img` fails outright if the daemon is not up, so start it and wait
    # for it to answer before sending the image.
    if ! swww query >/dev/null 2>&1; then
        setsid swww-daemon >/dev/null 2>&1 &
        i=0
        while [ $i -lt 25 ]; do
            swww query >/dev/null 2>&1 && break
            sleep 0.2
            i=$((i + 1))
        done
    fi

    exec swww img "$WALLPAPER" \
        --transition-type "$TRANSITION" \
        --transition-duration "$DURATION" \
        --transition-fps "$FPS" \
        --transition-pos 0.5,0.5
fi

pkill -x swaybg 2>/dev/null
setsid swaybg -i "$LINK" -m fill >/dev/null 2>&1 &
