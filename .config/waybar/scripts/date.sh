#!/bin/sh

ICON="󰸗 "

# Print date in format: WED 22/01/2026
DATE=$(date "+%a %d/%m/%Y" | tr '[:lower:]' '[:upper:]')

echo "$ICON $DATE"

