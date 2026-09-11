#!/bin/sh
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/platform.sh"

LOG=$BIN/tailscaled_stop_log.txt

echo "[$(date)] Stopping tailscaled..." > "$LOG"
eips_log "Stopping tailscaled..."

# Kill the running daemon first so its socket is released before cleanup.
# pkill returns non-zero if nothing was running, which is fine.
pkill -f "tailscaled --tun" >> "$LOG" 2>&1 || true
sleep 3

if [ "$PLATFORM" = "kindle" ]; then
    # Kindle's tailscaled binds the OS-standard socket path, not $SOCK, and
    # needs an explicit -cleanup pass for its TUN interface teardown - Kobo
    # doesn't do either of these, so this stays a real platform branch
    # rather than a shared code path.
    rm -f /var/run/tailscale/tailscaled.sock
    "$TAILSCALED" -cleanup >> "$LOG" 2>&1
    EXIT=$?
    rm -f /var/run/tailscale/tailscaled.sock
else
    rm -f "$SOCK"
    EXIT=0
fi

if [ "$EXIT" -eq 0 ]; then
    eips_log "tailscaled stopped"
else
    eips_log "tailscaled cleanup failed - check log"
fi
