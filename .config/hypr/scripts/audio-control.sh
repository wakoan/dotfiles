#!/usr/bin/env bash
# Control the selected PipeWire output even while WirePlumber is recovering
# from a disconnected Bluetooth device and has no @DEFAULT_AUDIO_SINK@.

set -eu

status=$(wpctl status)
sink=$(printf '%s\n' "$status" | sed -n '/Sinks:/,/Sources:/ { /\*/ s/^[^0-9]*\([0-9][0-9]*\)\..*/\1/p }' | head -1)

if [ -z "$sink" ]; then
  sink=$(printf '%s\n' "$status" | sed -n '/Sinks:/,/Sources:/ { s/^[^0-9]*\([0-9][0-9]*\)\..*/\1/p }' | head -1)
fi

[ -n "$sink" ] || exit 0

case "${1:-}" in
  up) wpctl set-volume -l 1.0 "$sink" 5%+ ;;
  down) wpctl set-volume "$sink" 5%- ;;
  mute) wpctl set-mute "$sink" toggle ;;
esac
