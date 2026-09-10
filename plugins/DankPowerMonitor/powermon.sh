#!/usr/bin/env bash
# powermon.sh — emits the current APU package power (watts) and CPU temp (°C)
# as JSON. Zero-setup: reads world-readable hwmon nodes, no root required.
#
# Power source: the `amdgpu` hwmon exposes the SMU "PPT" (Package Power
# Tracking) value on AMD APUs, which is the whole socket (CPU + iGPU). On
# systems without it this simply reports null and the widget stays empty.
#
# Temp source: `k10temp` temp1_input (Tctl) on AMD, falling back to the first
# readable thermal zone.

read_hwmon() { # $1 = hwmon name, $2 = file under the hwmon dir
    local h
    for h in /sys/class/hwmon/hwmon*/; do
        if [ "$(cat "$h/name" 2>/dev/null)" = "$1" ] && [ -r "$h/$2" ]; then
            printf '%s' "$h/$2"
            return 0
        fi
    done
    return 1
}

# amdgpu: prefer an averaged channel if present, else the instantaneous one
power_file=$(read_hwmon amdgpu power1_average 2>/dev/null || read_hwmon amdgpu power1_input 2>/dev/null || true)
# k10temp: Tctl is temp1 on this platform
temp_file=$(read_hwmon k10temp temp1_input 2>/dev/null || true)

power_uw=""
temp_mc=""
[ -n "$power_file" ] && power_uw=$(cat "$power_file" 2>/dev/null || true)
[ -n "$temp_file" ] && temp_mc=$(cat "$temp_file" 2>/dev/null || true)

# fall back to the first readable thermal zone if k10temp is unavailable
if [ -z "$temp_mc" ]; then
    for z in /sys/class/thermal/thermal_zone*/temp; do
        [ -r "$z" ] || continue
        temp_mc=$(cat "$z" 2>/dev/null || true)
        [ -n "$temp_mc" ] && break
    done
fi

awk -v p="$power_uw" -v t="$temp_mc" 'BEGIN {
    pw = (p == "" ? "null" : sprintf("%.3f", p / 1000000))
    tc = (t == "" ? "null" : sprintf("%.2f", t / 1000))
    printf "{\"power_w\": %s, \"temp_c\": %s}\n", pw, tc
}'
