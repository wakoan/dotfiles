#!/bin/bash
# Show UPower's status for every battery without depending on Omarchy helpers.
set -eu

devices=$(upower -e) || exit 1
message=""
while IFS= read -r device; do
    [[ $device == */battery_* ]] || continue
    info=$(upower -i "$device")
    status=$(awk '
        /state:/ { state = $2 }
        /percentage:/ { charge = $2 }
        /energy-rate:/ { rate = $2 " " $3 }
        /time to empty:/ { remaining = $4 " " $5 " remaining" }
        /time to full:/ { remaining = $4 " " $5 " to full" }
        /energy-full:/ { capacity = $2 " " $3 }
        END {
            printf "%s · %s · %s", charge, state, rate
            if (remaining != "") printf "\n%s", remaining
            if (capacity != "") printf "\nFull capacity: %s", capacity
        }
    ' <<< "$info")
    message+="${message:+$'\n\n'}$status"
done <<< "$devices"

notify-send -u low "Battery" "${message:-No battery detected}"
