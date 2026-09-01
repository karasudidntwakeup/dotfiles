#!/bin/sh

# Show the local IP address of the connected network interface
IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

if [ -z "$IP" ]; then
    echo "󰖪  "
    exit 0
fi

echo "󰖩   $IP"
