#!/bin/sh
# Keeps /etc/resolv.conf pointed at Tailscale MagicDNS (100.100.100.100),
# since wifid overwrites it with DHCP-provided servers on every reconnect.
RESOLV=/var/run/resolv.conf
while true; do
    if ! grep -q '^nameserver 100\.100\.100\.100$' "$RESOLV" 2>/dev/null; then
        echo 'nameserver 100.100.100.100' > "$RESOLV"
    fi
    sleep 10
done
