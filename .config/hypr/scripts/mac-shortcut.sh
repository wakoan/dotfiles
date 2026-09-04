#!/bin/sh
# Translate a Mac-style CMD+<key> into CTRL+<key>, but only when a browser
# is focused. Anywhere else the keypress is swallowed, so shortcuts like
# CTRL+W (delete-word) can't fire inside a terminal by accident.
#
# usage: mac-shortcut.sh <KEY> [EXTRA_MODS]
#   mac-shortcut.sh T          -> sends CTRL, T
#   mac-shortcut.sh T SHIFT    -> sends CTRL SHIFT, T

KEY="$1"
EXTRA="$2"
[ -z "$KEY" ] && exit 1

if [ -n "$EXTRA" ]; then
    MODS="CTRL $EXTRA"
else
    MODS="CTRL"
fi

# window classes that should receive the translated shortcut
case "$(hyprctl activewindow -j | sed -n 's/.*"class": "\([^"]*\)".*/\1/p')" in
    chromium|google-chrome|google-chrome-stable|brave-browser|firefox|zen)
        hyprctl dispatch sendshortcut "$MODS, $KEY, activewindow"
        ;;
esac
