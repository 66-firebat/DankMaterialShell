#!/usr/bin/env bash
# sysmon.sh — emits JSON with aggregate + per-core CPU, RAM, load, temp.
set -euo pipefail

SAMPLE_INTERVAL="${1:-0.3}"

read_stat_lines() {
    # Matches "cpu  ..." (aggregate) and "cpu0 ...", "cpu1 ...", etc.
    grep -E '^cpu[0-9]*[[:space:]]' /proc/stat
}

mapfile -t sample1 < <(read_stat_lines)
sleep "$SAMPLE_INTERVAL"
mapfile -t sample2 < <(read_stat_lines)

compute_pct() {
    local line1="$1" line2="$2"
    read -r _ u1 n1 s1 i1 iw1 irq1 sirq1 st1 _ _ <<< "$line1"
    read -r _ u2 n2 s2 i2 iw2 irq2 sirq2 st2 _ _ <<< "$line2"
    local busy1=$((u1+n1+s1+irq1+sirq1+st1)) idle1=$((i1+iw1))
    local busy2=$((u2+n2+s2+irq2+sirq2+st2)) idle2=$((i2+iw2))
    local bd=$((busy2-busy1)) td=$((busy2-busy1 + idle2-idle1))
    if [ "$td" -gt 0 ]; then
        awk -v b="$bd" -v t="$td" 'BEGIN{printf "%.1f", (b/t)*100}'
    else
        echo "0.0"
    fi
}

agg_pct=$(compute_pct "${sample1[0]}" "${sample2[0]}")

num_cores=$(( ${#sample1[@]} - 1 ))
core_pcts=()
for ((i = 1; i <= num_cores; i++)); do
    core_pcts+=("$(compute_pct "${sample1[$i]}" "${sample2[$i]}")")
done

core_json="["
for i in "${!core_pcts[@]}"; do
    [ "$i" -gt 0 ] && core_json+=","
    core_json+="${core_pcts[$i]}"
done
core_json+="]"

# --- Memory ---
mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
mem_used_kb=$((mem_total_kb - mem_avail_kb))
mem_percent=$(awk -v u="$mem_used_kb" -v t="$mem_total_kb" 'BEGIN{printf "%.1f", (u/t)*100}')
mem_used_gb=$(awk -v k="$mem_used_kb" 'BEGIN{printf "%.2f", k/1024/1024}')
mem_total_gb=$(awk -v k="$mem_total_kb" 'BEGIN{printf "%.2f", k/1024/1024}')

# --- Load average ---
load1=$(awk '{print $1}' /proc/loadavg)

# --- CPU temp (best effort) ---
cpu_temp=""
for zone in /sys/class/thermal/thermal_zone*/temp; do
    [ -r "$zone" ] || continue
    raw=$(cat "$zone" 2>/dev/null || echo "")
    if [[ "$raw" =~ ^[0-9]+$ ]] && [ "$raw" -gt 0 ]; then
        cpu_temp=$(awk -v t="$raw" 'BEGIN{printf "%.1f", t/1000}')
        break
    fi
done

printf '{"cpu_percent": %s, "cpu_cores": %s, "core_count": %s, "mem_used_gb": %s, "mem_total_gb": %s, "mem_percent": %s, "load1": %s, "cpu_temp": "%s"}\n' \
    "$agg_pct" "$core_json" "$num_cores" "$mem_used_gb" "$mem_total_gb" "$mem_percent" "$load1" "$cpu_temp"
