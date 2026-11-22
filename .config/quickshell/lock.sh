#!/bin/sh
lock_dir="$HOME/.cache/quickshell"
mkdir -p -- "$lock_dir" &&
    printf 'lock\n' > "$lock_dir/lock-request"
