#!/bin/bash

# This script handles taking screenshots with grim and slurp.
# It saves screenshots with a sequential number in ~/Pictures/Screenshots.

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

# Function to get the next sequential filename
get_next_filename() {
  # Find the highest existing number to avoid overwriting and ensure sequence
  LAST_NUM=$(ls "$DIR" 2>/dev/null | grep -oP 'screenshot-\K\d+' | sort -n | tail -1)

  if [ -z "$LAST_NUM" ]; then
    NEXT_NUM=1
  else
    NEXT_NUM=$((LAST_NUM + 1))
  fi

  echo "$DIR/screenshot-$NEXT_NUM.png"
}

ACTION="$1"

# Execute the command based on the action requested
case "$ACTION" in
  "select_save")
    FILENAME=$(get_next_filename)
    grim -g "$(slurp)" "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME" --icon=image-x-generic
    ;;
  "select_clipboard")
    grim -g "$(slurp)" - | wl-copy && notify-send "Screenshot" "Copied to clipboard" --icon=dialog-information
    ;;
  "capture_focused_window")
    FILENAME=$(get_next_filename)
    # slurp -p lets the user select a window
    grim -g "$(slurp -p)" "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME" --icon=image-x-generic
    ;;
  "full_screen")
    FILENAME=$(get_next_filename)
    grim "$FILENAME" && notify-send "Screenshot" "Saved to $FILENAME" --icon=image-x-generic
    ;;
  *)
    echo "Usage: $0 {select_save|select_clipboard|capture_focused_window|full_screen}"
    exit 1
    ;;
esac