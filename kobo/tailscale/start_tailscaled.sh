#!/bin/sh
cd /mnt/onboard/.adds/tailscale/bin
mkdir -p /mnt/onboard/.adds/tailscale/state
nohup ./tailscaled --tun=tailscale0 --statedir=/mnt/onboard/.adds/tailscale/state --socket=/tmp/tailscaled.sock > /mnt/onboard/.adds/tailscale/tailscaled.log 2>&1 < /dev/null &
sleep 3
ps aux | grep tailscaled | grep -v grep
echo ---LOG---
tail -20 /mnt/onboard/.adds/tailscale/tailscaled.log
