#!/bin/sh

TAILSCALE=/mnt/us/extensions/tailscale/bin/tailscale
AUTH_KEY=/mnt/us/extensions/tailscale/bin/auth.key
LOG=/mnt/us/extensions/tailscale/bin/tailscale_start_log.txt
UP_ARGS_FILE=/mnt/us/extensions/tailscale/bin/up.args

# Arguments passed verbatim to `tailscale up` from the up.args file
# (put all flags on a single line, e.g. "--ssh --accept-routes"; no comments).
UP_ARGS=""
if [ -f "$UP_ARGS_FILE" ]; then
    UP_ARGS=$(cat "$UP_ARGS_FILE")
fi

eips_log() {
    echo "$1" >> "$LOG"
    eips 0 22 "$(printf '%-50s' "$1")" 2>/dev/null
}

echo "[$(date)] Starting Tailscale..." > "$LOG"

# Background watcher (resolv.conf fixup only -- the screenshot uploader is
# now immichupload.koplugin, a real KOReader plugin, deliberately NOT tied
# to Tailscale's lifecycle: it only touches the network via KOReader's own
# Wi-Fi manager when it finds a genuinely new screenshot, regardless of
# whether Tailscale itself is running).
#
# PID-file locking instead of `ps | grep`: the grep-based check raced when
# this script ran multiple times in quick succession (manual toggles plus,
# formerly, the watchdog's own restart cycle) - multiple invocations could
# each see "not running yet" before the first one's background launch showed
# up in `ps`, spawning duplicates (found 6 of each watcher stacked up).
start_once() {
    target="$1"
    pidfile="/mnt/us/extensions/tailscale/bin/.$(basename "$target").pid"
    if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        return 0
    fi
    "$target" &
    echo $! > "$pidfile"
}

start_once "/mnt/us/extensions/tailscale/bin/dns_watch.sh"
eips_log "Reconnecting to Tailscale..."

# Try reconnecting without re-authenticating first (works when the node is
# already registered and key expiry is disabled).  A timeout prevents hanging
# indefinitely: on a fresh/reset node tailscale up prints a login URL and
# waits forever rather than returning an error.
if timeout 15 "$TAILSCALE" up $UP_ARGS >> "$LOG" 2>&1; then
    eips_log "Tailscale connected!"
    exit 0
fi

eips_log "Reconnect failed, trying auth key..."

# Fall back to auth key for first-time registration or after a manual reset.
if [ -s "$AUTH_KEY" ]; then
    eips_log "Authenticating with auth key..."
    if "$TAILSCALE" up $UP_ARGS --auth-key="$(cat "$AUTH_KEY")" >> "$LOG" 2>&1; then
        eips_log "Tailscale connected!"
    else
        eips_log "Auth key login failed - check log"
        exit 1
    fi
else
    eips_log "Tailscale: fill in auth.key and retry"
    exit 1
fi


