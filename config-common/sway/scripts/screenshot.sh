#!/bin/bash
#
# Handles taking screenshots with grim and slurp.
# Saves screenshots with a sequential number in ~/Pictures/Screenshots.
#
# Dependencies: grim, slurp, wl-clipboard, jq, libnotify (for notify-send)
#

# Check dependencies
check_dependencies() {
    local missing_deps=()
    for dep in grim slurp wl-copy jq notify-send swaymsg; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
        echo "Please install: ${missing_deps[*]}" >&2
        exit 1
    fi
}

check_dependencies

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

get_next_filename() {
  LAST_NUM=$(ls "$DIR" 2>/dev/null | grep -oP 'screenshot-\K\d+' | sort -n | tail -1)

  if [ -z "$LAST_NUM" ]; then
    NEXT_NUM=1
  else
    NEXT_NUM=$((LAST_NUM + 1))
  fi

  echo "$DIR/screenshot-$NEXT_NUM.png"
}

# Função para congelar a tela criando um overlay temporário
freeze_screen() {
    local temp_image="/tmp/screenshot_overlay_$$.png"
    # Captura a tela atual
    grim "$temp_image"
    # Cria um overlay com a imagem capturada usando swaybg
    swaybg -i "$temp_image" -m fill &
    local overlay_pid=$!
    echo "$overlay_pid:$temp_image"
}

# Função para remover o freeze da tela
unfreeze_screen() {
    local freeze_info="$1"
    local overlay_pid="${freeze_info%:*}"
    local temp_image="${freeze_info#*:}"

    # Mata o processo swaybg
    kill "$overlay_pid" 2>/dev/null || true
    # Remove o arquivo temporário
    rm -f "$temp_image"
}

ACTION="$1"

case "$ACTION" in
  "select_save")
    FILENAME=$(get_next_filename)
    # Congela a tela antes da seleção
    FREEZE_INFO=$(freeze_screen)
    # Aguarda um momento para o overlay aparecer
    sleep 0.1
    # Captura a região selecionada da imagem original (sem overlay)
    SELECTION=$(slurp)
    # Remove o freeze
    unfreeze_screen "$FREEZE_INFO"
    # Captura a área selecionada
    if [ -n "$SELECTION" ]; then
        grim -g "$SELECTION" "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME"
    fi
    ;;
  "select_clipboard")
    # Congela a tela antes da seleção
    FREEZE_INFO=$(freeze_screen)
    # Aguarda um momento para o overlay aparecer
    sleep 0.1
    # Captura a região selecionada
    SELECTION=$(slurp)
    # Remove o freeze
    unfreeze_screen "$FREEZE_INFO"
    # Captura a área selecionada para clipboard
    if [ -n "$SELECTION" ]; then
        grim -g "$SELECTION" - | wl-copy && notify-send "Screenshot" "Copied to clipboard" --icon=dialog-information
    fi
    ;;
  "capture_focused_window")
    FILENAME=$(get_next_filename)
    # Safely get focused window geometry with validation
    RAW_GEOMETRY=$(swaymsg -t get_tree | jq -r '.. | select(.type?) | select(.focused).rect | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null)
    # Validate geometry format (numbers and specific characters only)
    if [[ "$RAW_GEOMETRY" =~ ^[0-9]+,[0-9]+\ [0-9]+x[0-9]+$ ]]; then
      GEOMETRY="$RAW_GEOMETRY"
      grim -g "$GEOMETRY" "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME"
    else
      notify-send "Screenshot Failed" "Could not find focused window geometry or invalid geometry format."
    fi
    ;;
  "full_screen")
    FILENAME=$(get_next_filename)
    grim "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME"
    ;;
  *)
    echo "Usage: $0 {select_save|select_clipboard|capture_focused_window|full_screen}"
    exit 1
    ;;
esac