#!/bin/sh
# Long-running background watcher for multi-day passive monitoring: logs
# wlan0 up/down transitions and restarts the packet capture whenever wlan0
# comes back up (a raw AF_PACKET socket bound to the old interface index
# goes stale once the interface is actually torn down and recreated - it
# doesn't error, it just silently stops receiving forever).
#
# Runs forever (no duration cap - the earlier 6-hour-capped version would
# silently go quiet on a multi-day run). Polls every 30s rather than every
# 1s - cheap enough to not be a meaningful background cost itself over
# days, still frequent enough to catch state changes that matter on the
# timescale we care about (minutes, not seconds). Logs to /mnt/us (real
# flash, not tmpfs) so history survives a reboot and doesn't eat RAM.
BIN=/mnt/us/extensions/tailscale/bin
LOG="$BIN/wifiwatch.log"
PKTLOG="$BIN/pktlog.txt"

: > "$LOG"
last_state="unknown"

# Initial launch - the down->up restart logic below only fires on an actual
# transition, which never happens on first start (last_state is "unknown",
# not "down"), so this covers fresh boot / first run explicitly.
pkill -f "luajit $BIN/pktlog.lua" 2>/dev/null
nohup /mnt/us/koreader/luajit "$BIN/pktlog.lua" 604800 wlan0 "$PKTLOG" b0:8b:a8:88:19:8f > /tmp/pktlog.err 2>&1 < /dev/null &

while true; do
    if [ -d /sys/class/net/wlan0 ]; then
        state="up"
    else
        state="down"
    fi
    if [ "$state" != "$last_state" ]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S) wlan0 state: $last_state -> $state" >> "$LOG"
        if [ "$last_state" = "down" ] && [ "$state" = "up" ]; then
            echo "$(date +%Y-%m-%d\ %H:%M:%S) restarting pktlog.lua after wlan0 came back up" >> "$LOG"
            pkill -f "luajit $BIN/pktlog.lua" 2>/dev/null
            sleep 1
            nohup /mnt/us/koreader/luajit "$BIN/pktlog.lua" 604800 wlan0 "$PKTLOG" b0:8b:a8:88:19:8f > /tmp/pktlog.err 2>&1 < /dev/null &
        fi
        last_state="$state"
    fi
    sleep 30
done
