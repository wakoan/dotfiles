#!/bin/sh
# Mac-style CMD+C / CMD+V that works everywhere.
#
# Terminals use CTRL+SHIFT+C/V for clipboard (CTRL+C is SIGINT there), while
# GUI apps use plain CTRL+C/V. This picks the right one for the focused window.
#
# usage: mac-clipboard.sh <C|V>

KEY="$1"
[ -z "$KEY" ] && exit 1

CLASS=$(hyprctl activewindow -j | sed -n 's/.*"class": "\([^"]*\)".*/\1/p')

case "$CLASS" in
    # terminals — clipboard lives behind SHIFT
    com.mitchellh.ghostty|kitty|Alacritty|foot|footclient|org.wezfurlong.wezterm|st|URxvt|XTerm)
        MODS="CTRL SHIFT"
        ;;
    *)
        MODS="CTRL"
        ;;
esac

hyprctl dispatch sendshortcut "$MODS, $KEY, activewindow"
