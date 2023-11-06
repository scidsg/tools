#!/bin/bash

# Directory where screenshots will be saved (with space handled)
DIR="/Volumes/external/screenshots"
mkdir -p "$DIR"

# Infinite loop to capture screenshots
while true; do
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  screencapture -x "$DIR/screenshot_$TIMESTAMP.png"
  sleep 1
done
