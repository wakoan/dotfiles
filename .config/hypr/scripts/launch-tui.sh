#!/bin/sh
# Open a TUI in its own floating terminal window, or focus that window if it is
# already open, so clicking a bar module twice does not stack up duplicates.
#
# The window gets the class org.wako.<command>, which is what the float/center/
# size windowrules in hyprland.conf match on.
#
# usage: launch-tui.sh <command> [args...]

[ -z "$1" ] && exit 1
CLASS="org.wako.$(basename "$1")"

ADDR=$(hyprctl clients -j \
    | jq -r --arg c "$CLASS" '.[] | select(.class == $c) | .address' \
    | head -n1)

if [ -n "$ADDR" ]; then
    hyprctl dispatch focuswindow "address:$ADDR"
else
    exec setsid ghostty --class="$CLASS" -e "$@"
fi
