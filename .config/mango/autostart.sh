#!/bin/sh
# Mirrors niri autostart.kdl + quickshell stack (also duplicated as exec-once in config.conf
# for mango versions that prefer exec-once). Backup in autostart.sh.bak.
wl-paste --watch cliphist store &
# audio stack must start in order: wireplumber needs pipewire+pulse sockets ready
pipewire &
sleep 1
pipewire-pulse &
sleep 1
wireplumber &
awww-daemon &
bash -c "python3 /home/karasu/.config/quickshell/scripts/wa-notify.py" &
bash -c "/home/karasu/.config/quickshell/scripts/wa-follow-watch.sh" &
QS_NO_SHADOW=1 qs -d --path /home/karasu/.config/quickshell/shell.qml &
bash -c "cd /home/karasu/github/bombaclip && python3 -u bombaclip.py --token \"$(cat ~/.bombaclip_token)\" >> /tmp/bombaclip.log 2>&1" &
