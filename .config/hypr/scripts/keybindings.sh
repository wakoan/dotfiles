#!/bin/sh
# Searchable keybinding cheatsheet, built from Hyprland's own bind list.
# Any bind declared with `bindd` (description variant) shows up here
# automatically, so this never goes stale.
#
#   keybindings.sh            show the wofi picker
#   keybindings.sh --print    dump to stdout

list() {
    hyprctl binds -j | python3 -c '
import json, sys

MODS = {
    0: "", 1: "SHIFT", 4: "CTRL", 5: "SHIFT CTRL", 8: "ALT", 9: "SHIFT ALT",
    12: "CTRL ALT", 13: "SHIFT CTRL ALT", 64: "SUPER", 65: "SUPER SHIFT",
    68: "SUPER CTRL", 69: "SUPER SHIFT CTRL", 72: "SUPER ALT",
    73: "SUPER SHIFT ALT", 76: "SUPER CTRL ALT", 77: "SUPER SHIFT CTRL ALT",
}

# Whether the media keys or the F-keys need Fn depends on the hid_apple fnmode
# (1 = media keys are primary, 2 = F-keys are primary), so read it live.
try:
    FN = "" if open("/sys/module/hid_apple/parameters/fnmode").read().strip() == "1" else "Fn+"
except OSError:
    FN = "Fn+"

FKEY = {
    "XF86AudioMute": FN + "F10", "XF86AudioLowerVolume": FN + "F11",
    "XF86AudioRaiseVolume": FN + "F12", "XF86AudioPrev": FN + "F7",
    "XF86AudioPlay": FN + "F8", "XF86AudioNext": FN + "F9",
    "XF86MonBrightnessDown": FN + "F1", "XF86MonBrightnessUp": FN + "F2",
    "XF86KbdBrightnessDown": FN + "F5", "XF86KbdBrightnessUp": FN + "F6",
    "XF86AudioMicMute": FN + "F4",
}

rows = []
for b in json.load(sys.stdin):
    desc = b.get("description")
    if not desc:
        continue
    key = FKEY.get(b["key"], b["key"])
    mods = MODS.get(b["modmask"], str(b["modmask"]))
    combo = f"{mods} + {key}" if mods else key
    rows.append((combo, desc))

width = max(len(c) for c, _ in rows) if rows else 0
for combo, desc in sorted(rows, key=lambda r: (r[1].lower())):
    print(f"{combo:<{width}}   {desc}")
'
}

if [ "$1" = "--print" ] || [ "$1" = "-p" ]; then
    list
else
    list | wofi --dmenu --prompt "Keybindings" --width 700 --height 500 \
                --insensitive >/dev/null 2>&1
fi
