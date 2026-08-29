#!/bin/sh
BIN=/mnt/onboard/.adds/tailscale/bin
SOCK=/tmp/tailscaled.sock
UP_ARGS_FILE=$BIN/up.args
LOG=$BIN/tailscale_start_log.txt

# Arguments passed verbatim to `tailscale up` from the up.args file
# (put all flags on a single line, e.g. "--accept-routes --ssh"; no comments).
UP_ARGS=""
if [ -f "$UP_ARGS_FILE" ]; then
    UP_ARGS=$(cat "$UP_ARGS_FILE")
fi

echo "[$(date)] Starting Tailscale..." > "$LOG"

if ! pgrep -f tailscaled >/dev/null 2>&1; then
    sh /mnt/onboard/.adds/tailscale/start_tailscaled.sh >> "$LOG" 2>&1
    sleep 2
fi

# PID-file locking instead of `ps | grep`: a grep-based check races if this
# script runs multiple times in quick succession (manual toggles), so each
# invocation could see "not running yet" before the previous one's
# background launch shows up in `ps`, spawning duplicates. Same fix
# already applied on the Kindle's start_tailscale.sh.
start_once() {
    target="$1"
    pidfile="$BIN/.$(basename "$target").pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        return 0
    fi
    "$target" &
    echo $! > "$pidfile"
}

start_once "$BIN/immich_upload_watch.sh"

timeout 20 "$BIN/tailscale" --socket="$SOCK" up $UP_ARGS >> "$LOG" 2>&1
echo "[$(date)] up exit=$?" >> "$LOG"
