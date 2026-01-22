#!/bin/sh

# Read memory info (Linux)
MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
MEM_AVAILABLE=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)

MEM_USED=$(( (MEM_TOTAL - MEM_AVAILABLE) / 1024 ))

echo "󰍛  ${MEM_USED}MB"

