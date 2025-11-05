#!/bin/bash

# Compact System Monitor for Waybar
# Shows CPU% with expanded info on click

set -e

# Configuration
CPU_WARN_THRESHOLD=75
CPU_CRITICAL_THRESHOLD=90
STATE_FILE="$HOME/.cache/system-monitor-mode"

# Function to get CPU usage
get_cpu_usage() {
    awk '/^cpu / {usage=100-($5*100)/($2+$3+$4+$5+$6+$7+$8); printf "%.0f", usage}' /proc/stat
}

# Function to get memory usage
get_memory_usage() {
    awk '/^MemTotal:/ {total=$2} /^MemAvailable:/ {avail=$2} END {printf "%.0f", (total-avail)*100/total}' /proc/meminfo
}

# Function to get disk usage
get_disk_usage() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to get CPU temperature
get_cpu_temp() {
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        local temp=$(cat /sys/class/thermal/thermal_zone0/temp)
        echo $((temp / 1000))
    elif command -v sensors >/dev/null 2>&1; then
        sensors | grep -E "Core 0|Package id 0|Tctl" | head -1 | grep -oE '[0-9]+\.[0-9]+°C' | head -1 | sed 's/°C//' | sed 's/\..*//' || echo "N/A"
    else
        echo "N/A"
    fi
}

# Function to get network usage
get_network_usage() {
    local interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -n "$interface" ] && [ -f "/sys/class/net/$interface/statistics/rx_bytes" ]; then
        local rx_bytes=$(cat "/sys/class/net/$interface/statistics/rx_bytes")
        local tx_bytes=$(cat "/sys/class/net/$interface/statistics/tx_bytes")

        # Simple format (no historical tracking for compact version)
        local rx_mb=$((rx_bytes / 1024 / 1024))
        local tx_mb=$((tx_bytes / 1024 / 1024))
        echo "$rx_mb $tx_mb"
    else
        echo "0 0"
    fi
}

# Function to get uptime
get_uptime() {
    uptime -p | sed 's/up //' | sed 's/, / /'
}

# Function to get available memory in GB
get_available_memory() {
    awk '/^MemAvailable:/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}

# Function to get total memory in GB
get_total_memory() {
    awk '/^MemTotal:/ {printf "%.1f", $2/1024/1024}' /proc/meminfo
}

# Function to get system load
get_system_load() {
    awk '{printf "%.1f", $1}' /proc/loadavg
}

# Function to toggle display mode
toggle_mode() {
    if [ -f "$STATE_FILE" ]; then
        rm "$STATE_FILE"
    else
        touch "$STATE_FILE"
    fi
}

# Main waybar output function
waybar_output() {
    local cpu_usage=$(get_cpu_usage)
    local memory_usage=$(get_memory_usage)
    local disk_usage=$(get_disk_usage)
    local cpu_temp=$(get_cpu_temp)
    local load_avg=$(get_system_load)
    local network_data=($(get_network_usage))
    local rx_total=${network_data[0]}
    local tx_total=${network_data[1]}
    local uptime=$(get_uptime)
    local mem_available=$(get_available_memory)
    local mem_total=$(get_total_memory)

    # Determine icon and class based on CPU
    local icon=""
    local class="normal"

    # Check multiple thresholds for warnings
    if [ "$cpu_usage" -ge "$CPU_CRITICAL_THRESHOLD" ] || [ "$memory_usage" -ge 90 ] || [ "$disk_usage" -ge 90 ]; then
        icon=""
        class="critical"
    elif [ "$cpu_usage" -ge "$CPU_WARN_THRESHOLD" ] || [ "$memory_usage" -ge 80 ] || [ "$disk_usage" -ge 80 ]; then
        icon=""
        class="warning"
    fi

    # Compact mode by default, expanded info in tooltip
    local text="󰌢 ${cpu_usage}%"

    # Create expanded preview for tooltip
    local expanded_preview=" ${cpu_usage}%  ${memory_usage}%  󱛟 ${disk_usage}%"
    if [ "  $cpu_temp" != "N/A" ]; then
        expanded_preview+="  ${cpu_temp}°C"
    fi

    # Create comprehensive tooltip with all system info
    local tooltip="── System Monitor ──\\n"
    tooltip+=" $expanded_preview\\n\\n"
    tooltip+=" ${cpu_usage}% (Load: ${load_avg})\\n"

    if [ " $cpu_temp" != "N/A" ]; then
        tooltip+=" ${cpu_temp}°C\\n"
    fi

    tooltip+=" ${memory_usage}% (${mem_available}GB free of ${mem_total}GB)\\n"
    tooltip+="󱛟 ${disk_usage}% used\\n"

    if [ "$rx_total" != "0" ] || [ "$tx_total" != "0" ]; then
        tooltip+=" ↓${rx_total}MB ↑${tx_total}MB total\\n"
    fi

    tooltip+=" $uptime\\n"
    tooltip+=" $(date '+%H:%M:%S')\\n"
    tooltip+="Click to toggle view"

    # Output JSON for waybar
    echo "{\"text\": \"$text\", \"alt\": \"$expanded_preview\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
}

# Handle different modes
case "${1:-waybar}" in
    "waybar")
        waybar_output
        ;;
    "toggle")
        toggle_mode
        ;;
    "status")
        echo "=== Compact System Monitor ==="
        echo "CPU: $(get_cpu_usage)%"
        echo "Memory: $(get_memory_usage)%"
        echo "Disk: $(get_disk_usage)%"
        echo "Load: $(get_system_load)"
        local temp=$(get_cpu_temp)
        if [ "$temp" != "N/A" ]; then
            echo "Temperature: ${temp}°C"
        fi
        ;;
    *)
        echo "Usage: $0 {waybar|toggle|status}"
        echo "  waybar - Output JSON for waybar (default)"
        echo "  toggle - Toggle between compact/expanded view"
        echo "  status - Show system status"
        exit 1
        ;;
esac
