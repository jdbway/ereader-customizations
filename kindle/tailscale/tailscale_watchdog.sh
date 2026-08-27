#!/bin/sh
# Runs as a persistent loop under upstart (respawn), since /etc/crontab is
# read-only on this device's squashfs system partition. Cheap by design:
# each cycle is a local pgrep and a local socket query, both no-ops for the
# radio. Only touches Wi-Fi (via start_tailscale.sh's `tailscale up`) when
# something is actually down. Spends nearly all its time blocked in sleep.
BIN=/mnt/us/extensions/tailscale/bin
LOG=$BIN/tailscale_watchdog_log.txt
INTERVAL=300

while true; do
    if ! pgrep -f tailscaled >/dev/null 2>&1; then
        echo "[$(date)] watchdog: tailscaled not running, restarting daemon" >> "$LOG"
        "$BIN/start_tailscaled_tun.sh" >/dev/null 2>&1
        sleep 3
    fi

    if ! "$BIN/tailscale" status >/dev/null 2>&1; then
        echo "[$(date)] watchdog: tailscale not connected, running start_tailscale.sh" >> "$LOG"
        "$BIN/start_tailscale.sh" >/dev/null 2>&1
    fi

    sleep "$INTERVAL"
done
