#! /bin/bash

red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cian="\e[36m"
white="\e[97m"
bold="\033[1m"
normal="033[0m"

os=$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
kernel=$(uname -r)
host=$(cat /sys/devices/virtual/dmi/id/product_name)
shell=$(echo $SHELL | rev | cut -d'/' -f1 | rev)
theme=$(cat ~/.config/gtk-3.0/settings.ini | grep gtk-theme-name | cut -d'=' -f2)
icons=$(cat ~/.config/gtk-3.0/settings.ini | grep gtk-icon-theme-name | cut -d'=' -f2)
wm=$(wmctrl -m | grep Name | cut -d':' -f2)
packages=$(ls /bin | wc -l)
storage=$(df -h | grep /home | awk '{print $4}')

echo ""
echo -e "$bold$blue      /\_/\      $white$red os: $blue$os"    
echo -e "$bold$blue     ( > < )     $white$red kernel: $blue$kernel"
echo -e "$bold$blue  ___\  ^  /___  $white$red host: $blue$host"
echo -e "$bold$blue (___   _   ___) $white$red shell: $blue$shell"
echo -e "$bold$blue     \ ( ) /  /\ $white$red theme: $blue$theme"
echo -e "$bold$blue     | (_) |_/ / $white$red icons:$blue$icons"
echo -e "$bold$blue     \  _  /__/  $white$red wm:$blue$wm"
echo -e "$bold$blue     | | | |     $white$red packages: $blue$packages"
echo -e "$bold$blue     (_) (_)     $white$red free space: $blue $storage"
echo ""
