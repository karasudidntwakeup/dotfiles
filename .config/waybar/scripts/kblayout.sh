
#!/bin/sh

# get current layout (works on Wayland)
LAYOUT=$(swaymsg -t get_inputs 2>/dev/null | grep -m1 xkb_active_layout_name | sed 's/.*: "\(.*\)".*/\1/')

# fallback if swaymsg is unavailable
[ -z "$LAYOUT" ] && LAYOUT=$(setxkbmap -query 2>/dev/null | awk '/layout/{print $2}')

echo "$LAYOUT"
