#!/bin/bash

# Check dependencies
missing_deps=()
for dep in free df sensors; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
    echo "Install with: doas apt install procps coreutils lm-sensors" >&2
    exit 1
fi

# System monitoring script for waybar or terminal use
MODE="${1:-waybar}"

get_cpu_usage() {
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.0f", usage}'
}

get_memory_usage() {
    free | awk 'NR==2{printf "%.0f", $3*100/$2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2{print $5}' | tr -d '%'
}

get_temperature() {
    if command -v sensors &> /dev/null; then
        # Try to get CPU temperature
        TEMP=$(sensors 2>/dev/null | grep -E "(Core 0|Package id 0|Tctl)" | head -1 | grep -oP '\+\K[0-9]+' | head -1)
        if [ -n "$TEMP" ]; then
            echo "${TEMP}°C"
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ','
}

if [ "$MODE" = "waybar" ]; then
    # JSON output for waybar
    CPU=$(get_cpu_usage)
    MEM=$(get_memory_usage)
    DISK=$(get_disk_usage)
    TEMP=$(get_temperature)
    LOAD=$(get_load_average)

    # Create tooltip
    TOOLTIP="CPU: ${CPU}%\nMemory: ${MEM}%\nDisk: ${DISK}%\nTemp: ${TEMP}\nLoad: ${LOAD}"

    # Output JSON for waybar
    echo "{\"text\":\"󰍛 ${CPU}% 󰘚 ${MEM}%\", \"tooltip\":\"${TOOLTIP}\", \"class\":\"system-monitor\"}"
else
    # Terminal output
    echo "=== System Monitor ==="
    echo "CPU Usage:     $(get_cpu_usage)%"
    echo "Memory Usage:  $(get_memory_usage)%"
    echo "Disk Usage:    $(get_disk_usage)%"
    echo "Temperature:   $(get_temperature)"
    echo "Load Average:  $(get_load_average)"
    echo "======================"
fi