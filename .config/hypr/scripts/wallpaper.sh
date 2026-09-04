#!/bin/sh
# Start hyprpaper and apply the wallpaper via IPC.
# (config-file `preload`/`wallpaper` directives are not honoured by the
#  installed hyprpaper build, so we set it over IPC once the socket is up.)

STATE="$HOME/.config/hypr/.wallpaper"
DEFAULT="$HOME/.config/hypr/wallpapers/1.jpg"

if [ -n "$1" ]; then
    WALLPAPER="$1"
elif [ -f "$STATE" ] && [ -f "$(cat "$STATE")" ]; then
    WALLPAPER=$(cat "$STATE")
else
    WALLPAPER="$DEFAULT"
fi

pkill -x hyprpaper 2>/dev/null
hyprpaper >/dev/null 2>&1 &

# wait for the hyprpaper IPC socket
i=0
while [ "$i" -lt 50 ]; do
    hyprctl hyprpaper listactive >/dev/null 2>&1 && break
    i=$((i + 1))
    sleep 0.1
done

hyprctl hyprpaper wallpaper ",$WALLPAPER"
printf '%s\n' "$WALLPAPER" > "$STATE"
