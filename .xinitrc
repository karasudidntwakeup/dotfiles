#!/bin/sh
xrandr --setprovideroutputsource NVIDIA-G0
xrandr --auto
xmodmap ~/.Xmodmap &
/usr/bin/wireplumber &
/usr/bin/pipewire &
/usr/bin/pipewire-pulse &
picom -f &
slstatus &
redshift &
xwallpaper --zoom github/github/dotfiles/CustomWallpapers/white/6444A989D4D179437DA8201E7789235A_1737299071815.jpg
xset r rate 220 50
#while true; do
#        dwm >/dev/null 2>&1
#done
exec dbus-run-session dwm
