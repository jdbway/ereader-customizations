#!/bin/sh
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/platform.sh"

if [ "$PLATFORM" = "kindle" ]; then
    # Kindle's tailscaled bring-up has three real variants on-device
    # (start_tailscaled.sh / _tun.sh / _proxy.sh) reflecting network-mode
    # complexity that hasn't been audited here - rather than guess which
    # applies when, delegate to the one tailscale_watchdog.sh already
    # treats as canonical.
    exec "$BIN/start_tailscaled_tun.sh" "$@"
fi

# Kobo: no separate variants, start tailscaled directly.
mkdir -p /mnt/onboard/.adds/tailscale/state
cd "$BIN" || exit 1
nohup ./tailscaled --tun=tailscale0 --statedir=/mnt/onboard/.adds/tailscale/state --socket="$SOCK" \
    > /mnt/onboard/.adds/tailscale/tailscaled.log 2>&1 < /dev/null &
sleep 3
ps aux | grep tailscaled | grep -v grep
echo ---LOG---
tail -20 /mnt/onboard/.adds/tailscale/tailscaled.log
