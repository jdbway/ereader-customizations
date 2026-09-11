#!/bin/sh
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SELF_DIR/platform.sh"

AUTH_KEY=$BIN/auth.key
LOG=$BIN/tailscale_start_log.txt
UP_ARGS_FILE=$BIN/up.args

# Arguments passed verbatim to `tailscale up` from the up.args file (put all
# flags on a single line, e.g. "--ssh --accept-routes --hostname=kindle";
# no comments). Per-device, not shared - hostname and any device-specific
# tuning differ, so each device keeps its own up.args rather than this
# being unified with the scripts.
UP_ARGS=""
if [ -f "$UP_ARGS_FILE" ]; then
    UP_ARGS=$(cat "$UP_ARGS_FILE")
fi

echo "[$(date)] Starting Tailscale..." > "$LOG"

# Bootstrap tailscaled if it isn't already running. Normally a no-op - on
# Kindle the upstart boot hook and tailscale_watchdog.sh already keep it
# running; on Kobo there's no equivalent init system, so this inline check
# is that device's only way to ensure the daemon exists before `up`.
if ! pgrep -f tailscaled >/dev/null 2>&1; then
    "$SELF_DIR/start_tailscaled.sh" >> "$LOG" 2>&1
    sleep 2
fi

kindle_extra_start
eips_log "Reconnecting to Tailscale..."

# Try reconnecting without re-authenticating first (works when the node is
# already registered and key expiry is disabled). A timeout prevents hanging
# indefinitely: on a fresh/reset node tailscale up prints a login URL and
# waits forever rather than returning an error.
if timeout 15 "$TAILSCALE" $SOCK_ARG up $UP_ARGS >> "$LOG" 2>&1; then
    eips_log "Tailscale connected!"
    exit 0
fi

eips_log "Reconnect failed, trying auth key..."

# Fall back to auth key for first-time registration or after a manual reset.
if [ -s "$AUTH_KEY" ]; then
    eips_log "Authenticating with auth key..."
    if "$TAILSCALE" $SOCK_ARG up $UP_ARGS --auth-key="$(cat "$AUTH_KEY")" >> "$LOG" 2>&1; then
        eips_log "Tailscale connected!"
    else
        eips_log "Auth key login failed - check log"
        exit 1
    fi
else
    eips_log "Tailscale: fill in auth.key and retry"
    exit 1
fi
