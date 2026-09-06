#!/bin/bash
# Omarchy-style power profile picker, using this laptop's TLP backend.
set -eu

if command -v powerprofilesctl >/dev/null 2>&1; then
    profiles=$(powerprofilesctl list | awk '/^[*[:space:]]*[a-zA-Z0-9-]+:$/ { gsub(/^[*[:space:]]+|:$/, ""); print }')
    current=$(powerprofilesctl get)
else
    profiles=$(printf '%s\n' performance balanced power-saver)
    current=$(tlp-stat -s | sed -n 's/^TLP profile[[:space:]]*=[[:space:]]*//p')
fi

profile=$(printf '%s\n' "$profiles" | wofi --dmenu --prompt "Power Profile ${current:+($current)}") || exit 0
[[ -n $profile ]] || exit 0
[[ $'\n'$profiles$'\n' == *$'\n'"$profile"$'\n'* ]] || exit 1

if command -v powerprofilesctl >/dev/null 2>&1; then
    powerprofilesctl set "$profile"
else
    exec "$HOME/.config/hypr/scripts/launch-tui.sh" sudo tlp "$profile"
fi
