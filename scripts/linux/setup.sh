#!/usr/bin/env bash
# Check notify-send availability
if command -v notify-send &>/dev/null; then
  echo "notify-send found. Setup complete."
else
  echo "notify-send not found. Install libnotify (e.g. apt install libnotify-bin)."
  exit 1
fi
