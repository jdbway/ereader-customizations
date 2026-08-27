#!/bin/sh
BIN=/mnt/onboard/.adds/tailscale/bin
SOCK=/tmp/tailscaled.sock
LOG=$BIN/tailscaled_stop_log.txt

echo "[$(date)] Stopping tailscaled..." > "$LOG"
pkill tailscaled >> "$LOG" 2>&1
sleep 2
rm -f "$SOCK"
echo "[$(date)] tailscaled stopped" >> "$LOG"
