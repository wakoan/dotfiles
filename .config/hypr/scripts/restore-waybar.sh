#!/bin/sh
# End the session-only DMS trial and restore the usual bar and notifications.
dms kill || exit 1
if ! pgrep -u "$(id -u)" -x waybar >/dev/null; then
    hyprctl dispatch exec 'waybar -c $HOME/.config/hypr/waybar.conf -s $HOME/.config/hypr/waybar.css'
fi
if ! pgrep -u "$(id -u)" -x mako >/dev/null; then
    hyprctl dispatch exec mako
fi
