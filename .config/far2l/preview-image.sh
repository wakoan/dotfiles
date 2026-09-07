#!/bin/sh
# Preview an image inside far2l as coloured text.
#
# far2l has no graphics protocol -- no sixel, no kitty, no iTerm2 -- in either
# its TTY or GUI backend, so an image cannot be drawn in a panel or the viewer.
# chafa sidesteps that by rendering to coloured Unicode blocks, which is just
# ANSI text and therefore survives far2l, tmux and ghostty untouched.
#
# usage: preview-image.sh <file>

[ -n "$1" ] || exit 1

if ! command -v chafa >/dev/null 2>&1; then
    printf 'chafa is not installed.\nInstall it with: sudo pacman -S chafa\n'
    printf '\nPress Enter to close.'
    read -r _
    exit 1
fi

# Leave two rows for the header and the prompt below.
rows=$(( ${LINES:-24} - 4 ))
[ "$rows" -lt 8 ] && rows=8

printf '%s\n\n' "$1"

# --format symbols is not optional here. Left to itself chafa probes the
# terminal, finds ghostty behind tmux, and emits kitty graphics protocol --
# which tmux drops (allow-passthrough is off) and far2l cannot render at all,
# so the preview comes out empty or as raw escape soup.
chafa --format symbols --size "${COLUMNS:-80}x${rows}" \
      --symbols=block --colors=full "$1"

printf '\nPress Enter to close.'
read -r _
