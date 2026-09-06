#!/usr/bin/env bash
# Run through pkexec from the Quickshell battery panel.
set -eu

[ "$(id -u)" -eq 0 ] || exit 1

case "${1:-}" in
  power-saver)
    governor=powersave
    max_perf=60
    energy_bias=15
    ;;
  balanced)
    governor=schedutil
    max_perf=100
    energy_bias=6
    ;;
  performance)
    governor=performance
    max_perf=100
    energy_bias=0
    ;;
  *) exit 2 ;;
esac

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
  [ -w "$policy/scaling_governor" ] && printf '%s' "$governor" > "$policy/scaling_governor"
done

[ -w /sys/devices/system/cpu/intel_pstate/max_perf_pct ] \
  && printf '%s' "$max_perf" > /sys/devices/system/cpu/intel_pstate/max_perf_pct

for bias in /sys/devices/system/cpu/cpu*/power/energy_perf_bias; do
  [ -w "$bias" ] && printf '%s' "$energy_bias" > "$bias"
done
