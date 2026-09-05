#!/bin/sh
# Open a GUI app in a floating window, or focus its window if already open.
#
# Native apps set their own window class, so unlike launch-tui.sh we cannot
# derive it from the command: the caller passes a pattern to match instead.
# Matching is a case-insensitive substring, which survives the vendor prefixes
# GTK apps use (org.pulseaudio.pavucontrol, io.missioncenter.MissionCenter).
#
# usage: launch-app.sh <class-pattern> <command> [args...]

PATTERN=$1
[ -z "$PATTERN" ] && exit 1
shift
[ -z "$1" ] && exit 1

if ! command -v "$1" >/dev/null 2>&1; then
    notify-send -u critical "$1 is not installed" "Install it with: sudo pacman -S $1"
    exit 1
fi

ADDR=$(hyprctl clients -j \
    | jq -r --arg p "$PATTERN" '.[] | select(.class | ascii_downcase | contains($p|ascii_downcase)) | .address' \
    | head -n1)

if [ -n "$ADDR" ]; then
    hyprctl dispatch focuswindow "address:$ADDR"
else
    exec setsid "$@"
fi
