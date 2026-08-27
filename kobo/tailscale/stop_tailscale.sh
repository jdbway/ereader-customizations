#!/bin/sh
BIN=/mnt/onboard/.adds/tailscale/bin
SOCK=/tmp/tailscaled.sock
LOG=$BIN/tailscale_stop_log.txt

echo "[$(date)] Stopping Tailscale..." > "$LOG"
"$BIN/tailscale" --socket="$SOCK" down >> "$LOG" 2>&1
echo "[$(date)] down exit=$?" >> "$LOG"
