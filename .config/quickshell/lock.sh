#!/bin/sh
mkdir -p ~/.cache/quickshell
mkfifo ~/.cache/quickshell/lock-fifo 2>/dev/null
echo "lock" > ~/.cache/quickshell/lock-fifo
